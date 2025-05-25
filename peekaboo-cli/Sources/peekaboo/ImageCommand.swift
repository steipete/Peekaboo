import AppKit
import ArgumentParser
import CoreGraphics
import Foundation
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

    @Option(name: .long, help: "Image format")
    var format: ImageFormat = .png

    @Option(name: .long, help: "Capture focus behavior")
    var captureFocus: CaptureFocus = .background

    @Flag(name: .long, help: "Output results in JSON format")
    var jsonOutput = false

    func run() throws {
        Logger.shared.setJsonOutputMode(jsonOutput)

        do {
            try PermissionsChecker.requireScreenRecordingPermission()

            let captureMode = determineMode()
            let savedFiles: [SavedFile]

            switch captureMode {
            case .screen:
                savedFiles = try captureAllScreens()
            case .window:
                if let app = app {
                    savedFiles = try captureApplicationWindow(app)
                } else {
                    throw CaptureError.appNotFound("No application specified for window capture")
                }
            case .multi:
                if let app = app {
                    savedFiles = try captureAllApplicationWindows(app)
                } else {
                    savedFiles = try captureAllScreens()
                }
            }

            let data = ImageCaptureData(saved_files: savedFiles)

            if jsonOutput {
                outputSuccess(data: data)
            } else {
                print("Captured \(savedFiles.count) image(s):")
                for file in savedFiles {
                    print("  \(file.path)")
                }
            }

        } catch {
            if jsonOutput {
                let code: ErrorCode = .CAPTURE_FAILED
                outputError(
                    message: error.localizedDescription,
                    code: code,
                    details: "Image capture operation failed"
                )
            } else {
                // Create an instance for standard error for this specific print call
                var localStandardErrorStream = FileHandleTextOutputStream(FileHandle.standardError)
                print("Error: \(error.localizedDescription)", to: &localStandardErrorStream)
            }
            throw ExitCode.failure
        }
    }

    private func determineMode() -> CaptureMode {
        if let mode = mode {
            return mode
        }
        return app != nil ? .window : .screen
    }

    private func captureAllScreens() throws(CaptureError) -> [SavedFile] {
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

        return savedFiles
    }

    private func captureApplicationWindow(_ appIdentifier: String) throws -> [SavedFile] {
        let targetApp = try ApplicationFinder.findApplication(identifier: appIdentifier)

        if captureFocus == .foreground {
            try PermissionsChecker.requireAccessibilityPermission()
            targetApp.activate(options: [.activateIgnoringOtherApps])
            Thread.sleep(forTimeInterval: 0.2) // Brief delay for activation
        }

        let windows = try WindowManager.getWindowsForApp(pid: targetApp.processIdentifier)
        guard !windows.isEmpty else {
            throw CaptureError.windowNotFound
        }

        let targetWindow: WindowData
        if let windowTitle = windowTitle {
            guard let window = windows.first(where: { $0.title.contains(windowTitle) }) else {
                throw CaptureError.windowNotFound
            }
            targetWindow = window
        } else if let windowIndex = windowIndex {
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
            targetApp.activate(options: [.activateIgnoringOtherApps])
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
        guard let image = CGDisplayCreateImage(displayID) else {
            throw CaptureError.captureCreationFailed
        }
        try saveImage(image, to: path)
    }

    private func captureWindow(_ window: WindowData, to path: String) throws(CaptureError) {
        let options: CGWindowImageOption = [.boundsIgnoreFraming, .shouldBeOpaque]

        guard let image = CGWindowListCreateImage(
            window.bounds,
            .optionIncludingWindow,
            window.windowId,
            options
        ) else {
            throw CaptureError.windowCaptureFailed
        }

        try saveImage(image, to: path)
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

        if let displayIndex = displayIndex {
            return "screen_\(displayIndex + 1)_\(timestamp).\(ext)"
        } else if let appName = appName {
            let cleanAppName = appName.replacingOccurrences(of: " ", with: "_")
            if let windowIndex = windowIndex {
                return "\(cleanAppName)_window_\(windowIndex)_\(timestamp).\(ext)"
            } else if let windowTitle = windowTitle {
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
            return "\(basePath)/\(fileName)"
        } else {
            return "/tmp/\(fileName)"
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
