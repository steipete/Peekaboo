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
    var captureFocus: CaptureFocus = .auto

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

        // Log the full error details for debugging
        Logger.shared.debug("Image capture error: \(error)")

        // If it's a CaptureError with an underlying error, log that too
        switch captureError {
        case let .captureCreationFailed(underlyingError):
            if let underlying = underlyingError {
                Logger.shared.debug("Underlying capture creation error: \(underlying)")
            }
        case let .windowCaptureFailed(underlyingError):
            if let underlying = underlyingError {
                Logger.shared.debug("Underlying window capture error: \(underlying)")
            }
        case let .fileWriteError(_, underlyingError):
            if let underlying = underlyingError {
                Logger.shared.debug("Underlying file write error: \(underlying)")
            }
        default:
            break
        }

        if jsonOutput {
            let code: ErrorCode = switch captureError {
            case .screenRecordingPermissionDenied:
                .PERMISSION_ERROR_SCREEN_RECORDING
            case .accessibilityPermissionDenied:
                .PERMISSION_ERROR_ACCESSIBILITY
            case .appNotFound:
                .APP_NOT_FOUND
            case .windowNotFound, .noWindowsFound:
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

            // Provide additional details for app not found errors
            var details: String? = nil
            if case .appNotFound = captureError {
                let runningApps = NSWorkspace.shared.runningApplications
                    .filter { $0.activationPolicy == .regular }
                    .compactMap(\.localizedName)
                    .sorted()
                    .joined(separator: ", ")
                details = "Available applications: \(runningApps)"
            }

            outputError(
                message: captureError.localizedDescription,
                code: code,
                details: details ?? "Image capture operation failed"
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
        let displays = try getActiveDisplays()
        var savedFiles: [SavedFile] = []

        if let screenIndex {
            savedFiles = try captureSpecificScreen(displays: displays, screenIndex: screenIndex)
        } else {
            savedFiles = try captureAllScreens(displays: displays)
        }

        return savedFiles
    }

    private func getActiveDisplays() throws(CaptureError) -> [CGDirectDisplayID] {
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

        return displays
    }

    private func captureSpecificScreen(
        displays: [CGDirectDisplayID],
        screenIndex: Int
    ) throws(CaptureError) -> [SavedFile] {
        if screenIndex >= 0 && screenIndex < displays.count {
            let displayID = displays[screenIndex]
            let labelSuffix = " (Index \(screenIndex))"
            return try [captureSingleDisplay(displayID: displayID, index: screenIndex, labelSuffix: labelSuffix)]
        } else {
            Logger.shared.debug("Screen index \(screenIndex) is out of bounds. Capturing all screens instead.")
            // When falling back to all screens, use fallback-aware capture to prevent filename conflicts
            return try captureAllScreensWithFallback(displays: displays)
        }
    }

    private func captureAllScreens(displays: [CGDirectDisplayID]) throws(CaptureError) -> [SavedFile] {
        var savedFiles: [SavedFile] = []
        for (index, displayID) in displays.enumerated() {
            let savedFile = try captureSingleDisplay(displayID: displayID, index: index, labelSuffix: "")
            savedFiles.append(savedFile)
        }
        return savedFiles
    }
    
    private func captureAllScreensWithFallback(displays: [CGDirectDisplayID]) throws(CaptureError) -> [SavedFile] {
        var savedFiles: [SavedFile] = []
        for (index, displayID) in displays.enumerated() {
            let savedFile = try captureSingleDisplayWithFallback(displayID: displayID, index: index, labelSuffix: "")
            savedFiles.append(savedFile)
        }
        return savedFiles
    }

    private func captureSingleDisplay(
        displayID: CGDirectDisplayID,
        index: Int,
        labelSuffix: String
    ) throws(CaptureError) -> SavedFile {
        let fileName = generateFileName(displayIndex: index)
        let filePath = getOutputPath(fileName)

        try captureDisplay(displayID, to: filePath)

        return SavedFile(
            path: filePath,
            item_label: "Display \(index + 1)\(labelSuffix)",
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: format == .png ? "image/png" : "image/jpeg"
        )
    }
    
    private func captureSingleDisplayWithFallback(
        displayID: CGDirectDisplayID,
        index: Int,
        labelSuffix: String
    ) throws(CaptureError) -> SavedFile {
        let fileName = generateFileName(displayIndex: index)
        let filePath = getOutputPathWithFallback(fileName)

        try captureDisplay(displayID, to: filePath)

        return SavedFile(
            path: filePath,
            item_label: "Display \(index + 1)\(labelSuffix)",
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: format == .png ? "image/png" : "image/jpeg"
        )
    }

    private func captureApplicationWindow(_ appIdentifier: String) throws -> [SavedFile] {
        let targetApp: NSRunningApplication
        do {
            targetApp = try ApplicationFinder.findApplication(identifier: appIdentifier)
        } catch let ApplicationError.notFound(identifier) {
            throw CaptureError.appNotFound(identifier)
        } catch let ApplicationError.ambiguous(identifier, matches) {
            let appNames = matches.map { $0.localizedName ?? $0.bundleIdentifier ?? "Unknown" }
            throw CaptureError
                .unknownError("Multiple applications match '\(identifier)': \(appNames.joined(separator: ", "))")
        }

        if captureFocus == .foreground || (captureFocus == .auto && !targetApp.isActive) {
            try PermissionsChecker.requireAccessibilityPermission()
            targetApp.activate()
            Thread.sleep(forTimeInterval: 0.2) // Brief delay for activation
        }

        let windows = try WindowManager.getWindowsForApp(pid: targetApp.processIdentifier)
        guard !windows.isEmpty else {
            throw CaptureError.noWindowsFound(targetApp.localizedName ?? appIdentifier)
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
        let targetApp: NSRunningApplication
        do {
            targetApp = try ApplicationFinder.findApplication(identifier: appIdentifier)
        } catch let ApplicationError.notFound(identifier) {
            throw CaptureError.appNotFound(identifier)
        } catch let ApplicationError.ambiguous(identifier, matches) {
            let appNames = matches.map { $0.localizedName ?? $0.bundleIdentifier ?? "Unknown" }
            throw CaptureError
                .unknownError("Multiple applications match '\(identifier)': \(appNames.joined(separator: ", "))")
        }

        if captureFocus == .foreground || (captureFocus == .auto && !targetApp.isActive) {
            try PermissionsChecker.requireAccessibilityPermission()
            targetApp.activate()
            Thread.sleep(forTimeInterval: 0.2)
        }

        let windows = try WindowManager.getWindowsForApp(pid: targetApp.processIdentifier)
        guard !windows.isEmpty else {
            throw CaptureError.noWindowsFound(targetApp.localizedName ?? appIdentifier)
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
            if isScreenRecordingPermissionError(error) {
                throw CaptureError.screenRecordingPermissionDenied
            }
            throw CaptureError.captureCreationFailed(error)
        }
    }

    private func captureDisplayWithScreenCaptureKit(_ displayID: CGDirectDisplayID, to path: String) async throws {
        do {
            // Get available content
            let availableContent = try await SCShareableContent.current

            // Find the display by ID
            guard let scDisplay = availableContent.displays.first(where: { $0.displayID == displayID }) else {
                throw CaptureError.captureCreationFailed(nil)
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
            if isScreenRecordingPermissionError(error) {
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
            if isScreenRecordingPermissionError(error) {
                throw CaptureError.screenRecordingPermissionDenied
            }
            throw CaptureError.windowCaptureFailed(error)
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
            if isScreenRecordingPermissionError(error) {
                throw CaptureError.screenRecordingPermissionDenied
            }
            throw error
        }
    }

    private func isScreenRecordingPermissionError(_ error: Error) -> Bool {
        let errorString = error.localizedDescription.lowercased()

        // Check for specific screen recording related errors
        if errorString.contains("screen recording") {
            return true
        }

        // Check for NSError codes specific to screen capture permissions
        if let nsError = error as NSError? {
            // ScreenCaptureKit specific error codes
            if nsError.domain == "com.apple.screencapturekit" && nsError.code == -3801 {
                // SCStreamErrorUserDeclined = -3801
                return true
            }

            // CoreGraphics error codes for screen capture
            if nsError.domain == "com.apple.coregraphics" && nsError.code == 1002 {
                // kCGErrorCannotComplete when permissions are denied
                return true
            }
        }

        // Only consider it a permission error if it mentions both "permission" and capture-related terms
        if errorString.contains("permission") &&
            (errorString.contains("capture") || errorString.contains("recording") || errorString.contains("screen")) {
            return true
        }

        return false
    }

    private func saveImage(_ image: CGImage, to path: String) throws(CaptureError) {
        let url = URL(fileURLWithPath: path)

        // Check if the parent directory exists
        let directory = url.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            let error = NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileNoSuchFileError,
                userInfo: [NSLocalizedDescriptionKey: "No such file or directory"]
            )
            throw CaptureError.fileWriteError(path, error)
        }

        let utType: UTType = format == .png ? .png : .jpeg
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            utType.identifier as CFString,
            1,
            nil
        ) else {
            // Try to create a more specific error for common cases
            if !FileManager.default.isWritableFile(atPath: directory.path) {
                let error = NSError(
                    domain: NSPOSIXErrorDomain,
                    code: Int(EACCES),
                    userInfo: [NSLocalizedDescriptionKey: "Permission denied"]
                )
                throw CaptureError.fileWriteError(path, error)
            }
            throw CaptureError.fileWriteError(path, nil)
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw CaptureError.fileWriteError(path, nil)
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

    func getOutputPath(_ fileName: String) -> String {
        if let basePath = path {
            determineOutputPath(basePath: basePath, fileName: fileName)
        } else {
            "/tmp/\(fileName)"
        }
    }
    
    func getOutputPathWithFallback(_ fileName: String) -> String {
        if let basePath = path {
            determineOutputPathWithFallback(basePath: basePath, fileName: fileName)
        } else {
            "/tmp/\(fileName)"
        }
    }

    func determineOutputPath(basePath: String, fileName: String) -> String {
        // Check if basePath looks like a file (has extension and doesn't end with /)
        // Exclude special directory cases like "." and ".."
        let isLikelyFile = basePath.contains(".") && !basePath.hasSuffix("/") &&
            basePath != "." && basePath != ".."

        if isLikelyFile {
            // Create parent directory if needed
            let parentDir = (basePath as NSString).deletingLastPathComponent
            if !parentDir.isEmpty && parentDir != "/" {
                do {
                    try FileManager.default.createDirectory(
                        atPath: parentDir,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                } catch {
                    // Log but don't fail - maybe directory already exists
                    // Logger.debug("Could not create parent directory \(parentDir): \(error)")
                }
            }

            // For multiple screens, append screen index to avoid overwriting
            if screenIndex == nil {
                // Multiple screens - modify filename to include screen info
                let pathExtension = (basePath as NSString).pathExtension
                let pathWithoutExtension = (basePath as NSString).deletingPathExtension

                // Extract screen info from fileName (e.g., "screen_1_20250608_120000.png" -> "1_20250608_120000")
                let fileNameWithoutExt = (fileName as NSString).deletingPathExtension
                let screenSuffix = fileNameWithoutExt.replacingOccurrences(of: "screen_", with: "")

                return "\(pathWithoutExtension)_\(screenSuffix).\(pathExtension)"
            }

            return basePath
        } else {
            // Treat as directory - ensure it exists
            do {
                try FileManager.default.createDirectory(
                    atPath: basePath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                // Log but don't fail - maybe directory already exists
                // Logger.debug("Could not create directory \(basePath): \(error)")
            }
            return "\(basePath)/\(fileName)"
        }
    }
    
    func determineOutputPathWithFallback(basePath: String, fileName: String) -> String {
        // Check if basePath looks like a file (has extension and doesn't end with /)
        // Exclude special directory cases like "." and ".."
        let isLikelyFile = basePath.contains(".") && !basePath.hasSuffix("/") &&
            basePath != "." && basePath != ".."

        if isLikelyFile {
            // Create parent directory if needed
            let parentDir = (basePath as NSString).deletingLastPathComponent
            if !parentDir.isEmpty && parentDir != "/" {
                do {
                    try FileManager.default.createDirectory(
                        atPath: parentDir,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                } catch {
                    // Log but don't fail - maybe directory already exists
                    // Logger.debug("Could not create parent directory \(parentDir): \(error)")
                }
            }

            // For fallback mode (invalid screen index that fell back to all screens),
            // always treat as multiple screens to avoid overwriting
            let pathExtension = (basePath as NSString).pathExtension
            let pathWithoutExtension = (basePath as NSString).deletingPathExtension

            // Extract screen info from fileName (e.g., "screen_1_20250608_120000.png" -> "1_20250608_120000")
            let fileNameWithoutExt = (fileName as NSString).deletingPathExtension
            let screenSuffix = fileNameWithoutExt.replacingOccurrences(of: "screen_", with: "")

            return "\(pathWithoutExtension)_\(screenSuffix).\(pathExtension)"
        } else {
            // Treat as directory - ensure it exists
            do {
                try FileManager.default.createDirectory(
                    atPath: basePath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                // Log but don't fail - maybe directory already exists
                // Logger.debug("Could not create directory \(basePath): \(error)")
            }
            return "\(basePath)/\(fileName)"
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
