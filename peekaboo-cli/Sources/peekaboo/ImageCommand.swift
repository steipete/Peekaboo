import AppKit
import ArgumentParser
import CoreGraphics
import Foundation
import ScreenCaptureKit
import UniformTypeIdentifiers

// Define the wrapper struct
struct FileHandleTextOutputStream: TextOutputStream {
    private let fileHandle: FileHandle

    init(_ fileHandle: FileHandle) {
        self.fileHandle = fileHandle
    }

    mutating func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        fileHandle.write(data)
    }
}

struct ImageCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "image",
        abstract: "Capture screen or window images"
    )

    @Option(name: .long, help: "Target application identifier")
    var app: String?

    @Option(name: .long, help: "Base output path for saved images")
    var path: String?

    @Option(name: .long, help: "Capture mode")
    var mode: CaptureMode?

    @Option(name: .long, help: "Window title to capture")
    var windowTitle: String?

    @Option(name: .long, help: "Window index to capture (0=frontmost)")
    var windowIndex: Int?

    @Option(name: .long, help: "Screen index to capture (0-based)")
    var screenIndex: Int?

    @Option(name: .long, help: "Image format")
    var format: ImageFormat = .png

    @Option(name: .long, help: "Capture focus behavior")
    var captureFocus: CaptureFocus = .background

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    func run() {
        Logger.shared.setJsonOutputMode(jsonOutput)
        do {
            try PermissionsChecker.requireScreenRecordingPermission()
            let savedFiles = try performCapture()
            outputResults(savedFiles)
        } catch {
            handleError(error)
        }
    }

    private func performCapture() throws -> [SavedFile] {
        let captureMode = determineMode()

        switch captureMode {
        case .screen:
            return try captureScreens()
        case .window:
            guard let app else {
                throw CaptureError.appNotFound("No application specified for window capture")
            }
            return try captureApplicationWindow(app)
        case .multi:
            if let app {
                return try captureAllApplicationWindows(app)
            } else {
                return try captureScreens()
            }
        }
    }

    private func outputResults(_ savedFiles: [SavedFile]) {
        let data = ImageCaptureData(saved_files: savedFiles)

        if jsonOutput {
            outputSuccess(data: data)
        } else {
            print("Captured \(savedFiles.count) image(s):")
            for file in savedFiles {
                print("  \(file.path)")
            }
        }
    }

    private func handleError(_ error: Error) {
        let captureError: CaptureError = if let err = error as? CaptureError {
            err
        } else {
            .unknownError(error.localizedDescription)
        }

        if jsonOutput {
            let code: ErrorCode = switch captureError {
            case .screenRecordingPermissionDenied:
                .PERMISSION_ERROR_SCREEN_RECORDING
            case .accessibilityPermissionDenied:
                .PERMISSION_ERROR_ACCESSIBILITY
            case .appNotFound:
                .APP_NOT_FOUND
            case .windowNotFound:
                .WINDOW_NOT_FOUND
            case .fileWriteError:
                .FILE_IO_ERROR
            case .invalidArgument:
                .INVALID_ARGUMENT
            case .unknownError:
                .UNKNOWN_ERROR
            default:
                .CAPTURE_FAILED
            }
            outputError(
                message: captureError.localizedDescription,
                code: code,
                details: "Image capture operation failed"
            )
        } else {
            var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
            print("Error: \(captureError.localizedDescription)", to: &localStandardErrorStream)
        }
        Foundation.exit(captureError.exitCode)
    }

    private func determineMode() -> CaptureMode {
        if let mode {
            return mode
        }
        return app != nil ? .window : .screen
    }

    private func captureScreens() throws(CaptureError) -> [SavedFile] {
        var savedFiles: [SavedFile] = []

        var displayCount: UInt32 = 0
        let result = CGGetActiveDisplayList(0, nil, &displayCount)
        guard result == .success && displayCount > 0 else {
            throw CaptureError.noDisplaysAvailable
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        let listResult = CGGetActiveDisplayList(displayCount, &displays, nil)
        guard listResult == .success else {
            throw CaptureError.noDisplaysAvailable
        }

        // If screenIndex is specified, capture only that screen
        if let screenIndex {
            if screenIndex >= 0 && screenIndex < displays.count {
                let displayID = displays[screenIndex]
                let fileName = generateFileName(displayIndex: screenIndex)
                let filePath = getOutputPath(fileName)

                try captureDisplay(displayID, to: filePath)

                let savedFile = SavedFile(
                    path: filePath,
                    item_label: "Display \(screenIndex + 1) (Index \(screenIndex))",
                    window_title: nil,
                    window_id: nil,
                    window_index: nil,
                    mime_type: format == .png ? "image/png" : "image/jpeg"
                )
                savedFiles.append(savedFile)
            } else {
                Logger.shared.debug("Screen index \(screenIndex) is out of bounds. Capturing all screens instead.")
                // Fall through to capture all screens
                for (index, displayID) in displays.enumerated() {
                    let fileName = generateFileName(displayIndex: index)
                    let filePath = getOutputPath(fileName)

                    try captureDisplay(displayID, to: filePath)

                    let savedFile = SavedFile(
                        path: filePath,
                        item_label: "Display \(index + 1)",
                        window_title: nil,
                        window_id: nil,
                        window_index: nil,
                        mime_type: format == .png ? "image/png" : "image/jpeg"
                    )
                    savedFiles.append(savedFile)
                }
            }
        } else {
            // Capture all screens
            for (index, displayID) in displays.enumerated() {
                let fileName = generateFileName(displayIndex: index)
                let filePath = getOutputPath(fileName)

                try captureDisplay(displayID, to: filePath)

                let savedFile = SavedFile(
                    path: filePath,
                    item_label: "Display \(index + 1)",
                    window_title: nil,
                    window_id: nil,
                    window_index: nil,
                    mime_type: format == .png ? "image/png" : "image/jpeg"
                )
                savedFiles.append(savedFile)
            }
        }

        return savedFiles
    }

    private func captureApplicationWindow(_ appIdentifier: String) throws -> [SavedFile] {
        let targetApp = try ApplicationFinder.findApplication(identifier: appIdentifier)

        if captureFocus == .foreground {
            try PermissionsChecker.requireAccessibilityPermission()
            targetApp.activate()
            Thread.sleep(forTimeInterval: 0.2) // Brief delay for activation
        }

        let windows = try WindowManager.getWindowsForApp(pid: targetApp.processIdentifier)
        guard !windows.isEmpty else {
            throw CaptureError.windowNotFound
        }

        let targetWindow: WindowData
        if let windowTitle {
            guard let window = windows.first(where: { $0.title.contains(windowTitle) }) else {
                throw CaptureError.windowNotFound
            }
            targetWindow = window
        } else if let windowIndex {
            guard windowIndex >= 0 && windowIndex < windows.count else {
                throw CaptureError.invalidWindowIndex(windowIndex)
            }
            targetWindow = windows[windowIndex]
        } else {
            targetWindow = windows[0] // frontmost window
        }

        let fileName = generateFileName(appName: targetApp.localizedName, windowTitle: targetWindow.title)
        let filePath = getOutputPath(fileName)

        try captureWindow(targetWindow, to: filePath)

        let savedFile = SavedFile(
            path: filePath,
            item_label: targetApp.localizedName,
            window_title: targetWindow.title,
            window_id: targetWindow.windowId,
            window_index: targetWindow.windowIndex,
            mime_type: format == .png ? "image/png" : "image/jpeg"
        )

        return [savedFile]
    }

    private func captureAllApplicationWindows(_ appIdentifier: String) throws -> [SavedFile] {
        let targetApp = try ApplicationFinder.findApplication(identifier: appIdentifier)

        if captureFocus == .foreground {
            try PermissionsChecker.requireAccessibilityPermission()
            targetApp.activate()
            Thread.sleep(forTimeInterval: 0.2)
        }

        let windows = try WindowManager.getWindowsForApp(pid: targetApp.processIdentifier)
        guard !windows.isEmpty else {
            throw CaptureError.windowNotFound
        }

        var savedFiles: [SavedFile] = []

        for (index, window) in windows.enumerated() {
            let fileName = generateFileName(
                appName: targetApp.localizedName, windowIndex: index, windowTitle: window.title
            )
            let filePath = getOutputPath(fileName)

            try captureWindow(window, to: filePath)

            let savedFile = SavedFile(
                path: filePath,
                item_label: targetApp.localizedName,
                window_title: window.title,
                window_id: window.windowId,
                window_index: index,
                mime_type: format == .png ? "image/png" : "image/jpeg"
            )
            savedFiles.append(savedFile)
        }

        return savedFiles
    }

    private func captureDisplay(_ displayID: CGDirectDisplayID, to path: String) throws(CaptureError) {
        do {
            let semaphore = DispatchSemaphore(value: 0)
            var captureError: Error?

            Task {
                do {
                    try await captureDisplayWithScreenCaptureKit(displayID, to: path)
                } catch {
                    captureError = error
                }
                semaphore.signal()
            }

            semaphore.wait()

            if let error = captureError {
                throw error
            }
        } catch let error as CaptureError {
            // Re-throw CaptureError as-is
            throw error
        } catch {
            // Check if this is a permission error from ScreenCaptureKit
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("screen recording") || errorString.contains("permission") {
                throw CaptureError.screenRecordingPermissionDenied
            }
            throw CaptureError.captureCreationFailed
        }
    }

    private func captureDisplayWithScreenCaptureKit(_ displayID: CGDirectDisplayID, to path: String) async throws {
        do {
            // Get available content
            let availableContent = try await SCShareableContent.current

            // Find the display by ID
            guard let scDisplay = availableContent.displays.first(where: { $0.displayID == displayID }) else {
                throw CaptureError.captureCreationFailed
            }

            // Create content filter for the entire display
            let filter = SCContentFilter(display: scDisplay, excludingWindows: [])

            // Configure capture settings
            let configuration = SCStreamConfiguration()
            configuration.width = scDisplay.width
            configuration.height = scDisplay.height
            configuration.backgroundColor = .black
            configuration.shouldBeOpaque = true
            configuration.showsCursor = true

            // Capture the image
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )

            try saveImage(image, to: path)
        } catch {
            // Check if this is a permission error
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("screen recording") || errorString.contains("permission") {
                throw CaptureError.screenRecordingPermissionDenied
            }
            throw error
        }
    }

    private func captureWindow(_ window: WindowData, to path: String) throws(CaptureError) {
        do {
            let semaphore = DispatchSemaphore(value: 0)
            var captureError: Error?

            Task {
                do {
                    try await captureWindowWithScreenCaptureKit(window, to: path)
                } catch {
                    captureError = error
                }
                semaphore.signal()
            }

            semaphore.wait()

            if let error = captureError {
                throw error
            }
        } catch let error as CaptureError {
            // Re-throw CaptureError as-is
            throw error
        } catch {
            // Check if this is a permission error from ScreenCaptureKit
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("screen recording") || errorString.contains("permission") {
                throw CaptureError.screenRecordingPermissionDenied
            }
            throw CaptureError.windowCaptureFailed
        }
    }

    private func captureWindowWithScreenCaptureKit(_ window: WindowData, to path: String) async throws {
        do {
            // Get available content
            let availableContent = try await SCShareableContent.current

            // Find the window by ID
            guard let scWindow = availableContent.windows.first(where: { $0.windowID == window.windowId }) else {
                throw CaptureError.windowNotFound
            }

            // Create content filter for the specific window
            let filter = SCContentFilter(desktopIndependentWindow: scWindow)

            // Configure capture settings
            let configuration = SCStreamConfiguration()
            configuration.width = Int(window.bounds.width)
            configuration.height = Int(window.bounds.height)
            configuration.backgroundColor = .clear
            configuration.shouldBeOpaque = true
            configuration.showsCursor = false

            // Capture the image
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )

            try saveImage(image, to: path)
        } catch {
            // Check if this is a permission error
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("screen recording") || errorString.contains("permission") {
                throw CaptureError.screenRecordingPermissionDenied
            }
            throw error
        }
    }

    private func saveImage(_ image: CGImage, to path: String) throws(CaptureError) {
        let url = URL(fileURLWithPath: path)

        let utType: UTType = format == .png ? .png : .jpeg
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            utType.identifier as CFString,
            1,
            nil
        ) else {
            throw CaptureError.fileWriteError(path)
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw CaptureError.fileWriteError(path)
        }
    }

    private func generateFileName(
        displayIndex: Int? = nil,
        appName: String? = nil,
        windowIndex: Int? = nil,
        windowTitle: String? = nil
    ) -> String {
        let timestamp = DateFormatter.timestamp.string(from: Date())
        let ext = format.rawValue

        if let displayIndex {
            return "screen_\(displayIndex + 1)_\(timestamp).\(ext)"
        } else if let appName {
            let cleanAppName = appName.replacingOccurrences(of: " ", with: "_")
            if let windowIndex {
                return "\(cleanAppName)_window_\(windowIndex)_\(timestamp).\(ext)"
            } else if let windowTitle {
                let cleanTitle = windowTitle.replacingOccurrences(of: " ", with: "_").prefix(20)
                return "\(cleanAppName)_\(cleanTitle)_\(timestamp).\(ext)"
            } else {
                return "\(cleanAppName)_\(timestamp).\(ext)"
            }
        } else {
            return "capture_\(timestamp).\(ext)"
        }
    }

    private func getOutputPath(_ fileName: String) -> String {
        if let basePath = path {
            "\(basePath)/\(fileName)"
        } else {
            "/tmp/\(fileName)"
        }
    }
}

extension DateFormatter {
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}
