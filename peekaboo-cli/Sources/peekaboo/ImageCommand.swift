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
            let savedFiles = try runAsyncCapture()
            outputResults(savedFiles)
        } catch {
            handleError(error)
        }
    }
    
    private func runAsyncCapture() throws -> [SavedFile] {
        // Create a new event loop using RunLoop to handle async properly
        var result: Result<[SavedFile], Error>?
        let runLoop = RunLoop.current
        
        Task {
            do {
                let savedFiles = try await performCapture()
                result = .success(savedFiles)
            } catch {
                result = .failure(error)
            }
            // Stop the run loop
            CFRunLoopStop(runLoop.getCFRunLoop())
        }
        
        // Run the event loop until the task completes
        runLoop.run()
        
        guard let result = result else {
            throw CaptureError.captureCreationFailed(nil)
        }
        return try result.get()
    }

    private func performCapture() async throws -> [SavedFile] {
        let captureMode = determineMode()

        switch captureMode {
        case .screen:
            return try await captureScreens()
        case .window:
            guard let app else {
                throw CaptureError.appNotFound("No application specified for window capture")
            }
            return try await captureApplicationWindow(app)
        case .multi:
            if let app {
                return try await captureAllApplicationWindows(app)
            } else {
                return try await captureScreens()
            }
        case .frontmost:
            return try await captureFrontmostWindow()
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

    private func handleError(_ error: Error) -> Never {
        ImageErrorHandler.handleError(error, jsonOutput: jsonOutput)
    }

    private func determineMode() -> CaptureMode {
        if let mode {
            return mode
        }
        return app != nil ? .window : .screen
    }

    private func captureScreens() async throws(CaptureError) -> [SavedFile] {
        let displays = try getActiveDisplays()
        var savedFiles: [SavedFile] = []

        if let screenIndex {
            savedFiles = try await captureSpecificScreen(displays: displays, screenIndex: screenIndex)
        } else {
            savedFiles = try await captureAllScreens(displays: displays)
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
    ) async throws(CaptureError) -> [SavedFile] {
        if screenIndex >= 0 && screenIndex < displays.count {
            let displayID = displays[screenIndex]
            let labelSuffix = " (Index \(screenIndex))"
            return try await [captureSingleDisplay(displayID: displayID, index: screenIndex, labelSuffix: labelSuffix)]
        } else {
            Logger.shared.debug("Screen index \(screenIndex) is out of bounds. Capturing all screens instead.")
            // When falling back to all screens, use fallback-aware capture to prevent filename conflicts
            return try await captureAllScreensWithFallback(displays: displays)
        }
    }

    private func captureAllScreens(displays: [CGDirectDisplayID]) async throws(CaptureError) -> [SavedFile] {
        var savedFiles: [SavedFile] = []
        for (index, displayID) in displays.enumerated() {
            let savedFile = try await captureSingleDisplay(displayID: displayID, index: index, labelSuffix: "")
            savedFiles.append(savedFile)
        }
        return savedFiles
    }

    private func captureAllScreensWithFallback(displays: [CGDirectDisplayID]) async throws(CaptureError) -> [SavedFile] {
        var savedFiles: [SavedFile] = []
        for (index, displayID) in displays.enumerated() {
            let savedFile = try await captureSingleDisplayWithFallback(displayID: displayID, index: index, labelSuffix: "")
            savedFiles.append(savedFile)
        }
        return savedFiles
    }

    private func captureSingleDisplay(
        displayID: CGDirectDisplayID,
        index: Int,
        labelSuffix: String
    ) async throws(CaptureError) -> SavedFile {
        let fileName = FileNameGenerator.generateFileName(displayIndex: index, format: format)
        let filePath = OutputPathResolver.getOutputPath(basePath: path, fileName: fileName)

        try await captureDisplay(displayID, to: filePath)

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
    ) async throws(CaptureError) -> SavedFile {
        let fileName = FileNameGenerator.generateFileName(displayIndex: index, format: format)
        let filePath = OutputPathResolver.getOutputPathWithFallback(basePath: path, fileName: fileName)

        try await captureDisplay(displayID, to: filePath)

        return SavedFile(
            path: filePath,
            item_label: "Display \(index + 1)\(labelSuffix)",
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: format == .png ? "image/png" : "image/jpeg"
        )
    }

    private func captureApplicationWindow(_ appIdentifier: String) async throws -> [SavedFile] {
        let targetApp: NSRunningApplication
        do {
            targetApp = try ApplicationFinder.findApplication(identifier: appIdentifier)
        } catch let ApplicationError.notFound(identifier) {
            throw CaptureError.appNotFound(identifier)
        } catch let ApplicationError.ambiguous(identifier, matches) {
            // For ambiguous matches, capture all windows from all matching applications
            Logger.shared.debug("Multiple applications match '\(identifier)', capturing all windows from all matches")
            return try await captureWindowsFromMultipleApps(matches, appIdentifier: identifier)
        }

        if captureFocus == .foreground || (captureFocus == .auto && !targetApp.isActive) {
            try PermissionsChecker.requireAccessibilityPermission()
            targetApp.activate()
            try await Task.sleep(nanoseconds: 200_000_000) // Brief delay for activation
        }

        let windows = try WindowManager.getWindowsForApp(pid: targetApp.processIdentifier)
        guard !windows.isEmpty else {
            throw CaptureError.noWindowsFound(targetApp.localizedName ?? appIdentifier)
        }

        let targetWindow: WindowData
        if let windowTitle {
            guard let window = windows.first(where: { $0.title.contains(windowTitle) }) else {
                // Create detailed error message with available window titles for debugging
                let availableTitles = windows.map { "\"\($0.title)\"" }.joined(separator: ", ")
                let searchTerm = windowTitle
                let appName = targetApp.localizedName ?? "Unknown"
                
                Logger.shared.debug(
                    "Window not found. Searched for '\(searchTerm)' in \(appName). " +
                    "Available windows: \(availableTitles)"
                )
                
                throw CaptureError.windowTitleNotFound(searchTerm, appName, availableTitles)
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

        let fileName = FileNameGenerator.generateFileName(
            appName: targetApp.localizedName, windowTitle: targetWindow.title, format: format
        )
        let filePath = OutputPathResolver.getOutputPath(basePath: path, fileName: fileName)

        try await captureWindow(targetWindow, to: filePath)

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

    private func captureAllApplicationWindows(_ appIdentifier: String) async throws -> [SavedFile] {
        let targetApp: NSRunningApplication
        do {
            targetApp = try ApplicationFinder.findApplication(identifier: appIdentifier)
        } catch let ApplicationError.notFound(identifier) {
            throw CaptureError.appNotFound(identifier)
        } catch let ApplicationError.ambiguous(identifier, matches) {
            // For ambiguous matches, capture all windows from all matching applications
            Logger.shared.debug("Multiple applications match '\(identifier)', capturing all windows from all matches")
            return try await captureWindowsFromMultipleApps(matches, appIdentifier: identifier)
        }

        if captureFocus == .foreground || (captureFocus == .auto && !targetApp.isActive) {
            try PermissionsChecker.requireAccessibilityPermission()
            targetApp.activate()
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        let windows = try WindowManager.getWindowsForApp(pid: targetApp.processIdentifier)
        guard !windows.isEmpty else {
            throw CaptureError.noWindowsFound(targetApp.localizedName ?? appIdentifier)
        }

        var savedFiles: [SavedFile] = []

        for (index, window) in windows.enumerated() {
            let fileName = FileNameGenerator.generateFileName(
                appName: targetApp.localizedName, windowIndex: index, windowTitle: window.title, format: format
            )
            let filePath = OutputPathResolver.getOutputPath(basePath: path, fileName: fileName)

            try await captureWindow(window, to: filePath)

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

    private func captureWindowsFromMultipleApps(
        _ apps: [NSRunningApplication], appIdentifier: String
    ) async throws -> [SavedFile] {
        var allSavedFiles: [SavedFile] = []
        var totalWindowIndex = 0

        for targetApp in apps {
            // Log which app we're processing
            Logger.shared.debug("Capturing windows for app: \(targetApp.localizedName ?? "Unknown")")

            // Handle focus behavior for each app (if needed)
            if captureFocus == .foreground || (captureFocus == .auto && !targetApp.isActive) {
                try PermissionsChecker.requireAccessibilityPermission()
                targetApp.activate()
                try await Task.sleep(nanoseconds: 200_000_000)
            }

            let windows = try WindowManager.getWindowsForApp(pid: targetApp.processIdentifier)
            if windows.isEmpty {
                Logger.shared.debug("No windows found for app: \(targetApp.localizedName ?? "Unknown")")
                continue
            }

            for window in windows {
                let fileName = FileNameGenerator.generateFileName(
                    appName: targetApp.localizedName,
                    windowIndex: totalWindowIndex,
                    windowTitle: window.title,
                    format: format
                )
                let filePath = OutputPathResolver.getOutputPath(basePath: path, fileName: fileName)

                try await captureWindow(window, to: filePath)

                let savedFile = SavedFile(
                    path: filePath,
                    item_label: targetApp.localizedName,
                    window_title: window.title,
                    window_id: window.windowId,
                    window_index: totalWindowIndex,
                    mime_type: format == .png ? "image/png" : "image/jpeg"
                )
                allSavedFiles.append(savedFile)
                totalWindowIndex += 1
            }
        }

        guard !allSavedFiles.isEmpty else {
            throw CaptureError.noWindowsFound("No windows found for any matching applications of '\(appIdentifier)'")
        }

        return allSavedFiles
    }

    private func captureDisplay(_ displayID: CGDirectDisplayID, to path: String) async throws(CaptureError) {
        do {
            try await ScreenCapture.captureDisplay(displayID, to: path, format: format)
        } catch let error as CaptureError {
            // Re-throw CaptureError as-is
            throw error
        } catch {
            // Check if this is a permission error from ScreenCaptureKit
            if PermissionErrorDetector.isScreenRecordingPermissionError(error) {
                throw CaptureError.screenRecordingPermissionDenied
            }
            throw CaptureError.captureCreationFailed(error)
        }
    }

    private func captureWindow(_ window: WindowData, to path: String) async throws(CaptureError) {
        do {
            try await ScreenCapture.captureWindow(window, to: path, format: format)
        } catch let error as CaptureError {
            // Re-throw CaptureError as-is
            throw error
        } catch {
            // Check if this is a permission error from ScreenCaptureKit
            if PermissionErrorDetector.isScreenRecordingPermissionError(error) {
                throw CaptureError.screenRecordingPermissionDenied
            }
            throw CaptureError.windowCaptureFailed(error)
        }
    }
    
    private func captureFrontmostWindow() async throws -> [SavedFile] {
        Logger.shared.debug("Capturing frontmost window")
        
        // Get the frontmost (active) application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            throw CaptureError.appNotFound("No frontmost application found")
        }
        
        Logger.shared.debug("Frontmost app: \(frontmostApp.localizedName ?? "Unknown")")
        
        // Get windows for the frontmost app
        let windows = try WindowManager.getWindowsForApp(pid: frontmostApp.processIdentifier)
        guard !windows.isEmpty else {
            throw CaptureError.noWindowsFound(frontmostApp.localizedName ?? "frontmost application")
        }
        
        // Get the frontmost window (index 0)
        let frontmostWindow = windows[0]
        
        Logger.shared.debug("Capturing frontmost window: '\(frontmostWindow.title)'")
        
        // Generate output path
        let timestamp = DateFormatter.timestamp.string(from: Date())
        let appName = frontmostApp.localizedName ?? "UnknownApp"
        let safeName = appName.replacingOccurrences(of: " ", with: "_")
        let fileName = "frontmost_\(safeName)_\(timestamp).\(format.rawValue)"
        let filePath = OutputPathResolver.getOutputPathWithFallback(basePath: path, fileName: fileName)
        
        // Capture the window
        try await captureWindow(frontmostWindow, to: filePath)
        
        return [SavedFile(
            path: filePath,
            item_label: appName,
            window_title: frontmostWindow.title,
            window_id: UInt32(frontmostWindow.windowId),
            window_index: frontmostWindow.windowIndex,
            mime_type: format == .png ? "image/png" : "image/jpeg"
        )]
    }
}
