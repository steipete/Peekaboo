import AppKit
import Foundation
import ScreenCaptureKit

/// Handles window capture operations for the ImageCommand
struct WindowCaptureHandler {
    let captureFocus: CaptureFocus
    let format: ImageFormat
    let path: String?

    /// Captures windows from multiple applications
    func captureWindowsFromMultipleApps(
        _ apps: [NSRunningApplication],
        appIdentifier: String) async throws -> [SavedFile]
    {
        var allSavedFiles: [SavedFile] = []
        var totalWindowIndex = 0

        for targetApp in apps {
            let capturedFiles = try await captureAppWindows(
                targetApp: targetApp,
                totalWindowIndex: &totalWindowIndex)
            allSavedFiles.append(contentsOf: capturedFiles)
        }

        guard !allSavedFiles.isEmpty else {
            throw CaptureError.noWindowsFound("No windows found for any matching applications of '\(appIdentifier)'")
        }

        return allSavedFiles
    }

    /// Captures all windows for a single application
    private func captureAppWindows(
        targetApp: NSRunningApplication,
        totalWindowIndex: inout Int) async throws -> [SavedFile]
    {
        Logger.shared.debug("Capturing windows for app: \(targetApp.localizedName ?? "Unknown")")

        try await self.activateAppIfNeeded(targetApp)

        let windows = try WindowManager.getWindowsForApp(pid: targetApp.processIdentifier)
        if windows.isEmpty {
            Logger.shared.debug("No windows found for app: \(targetApp.localizedName ?? "Unknown")")
            return []
        }

        var savedFiles: [SavedFile] = []
        for window in windows {
            let savedFile = try await captureSingleWindowWithIndex(
                window: window,
                targetApp: targetApp,
                windowIndex: totalWindowIndex)
            savedFiles.append(savedFile)
            totalWindowIndex += 1
        }

        return savedFiles
    }

    /// Activates the app if needed based on capture focus settings
    private func activateAppIfNeeded(_ app: NSRunningApplication) async throws {
        if self.captureFocus == .foreground || (self.captureFocus == .auto && !app.isActive) {
            try PermissionsChecker.requireAccessibilityPermission()
            app.activate()
            try await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    /// Captures a single window with index
    private func captureSingleWindowWithIndex(
        window: WindowData,
        targetApp: NSRunningApplication,
        windowIndex: Int) async throws -> SavedFile
    {
        let fileName = FileNameGenerator.generateFileName(
            appName: targetApp.localizedName,
            windowIndex: windowIndex,
            windowTitle: window.title,
            format: self.format)
        // Multiple windows from multiple apps means not a single capture
        let filePath = OutputPathResolver.getOutputPath(
            basePath: self.path,
            fileName: fileName,
            isSingleCapture: false)

        try await self.captureWindow(window, to: filePath)

        return SavedFile(
            path: filePath,
            item_label: targetApp.localizedName,
            window_title: window.title,
            window_id: window.windowId,
            window_index: windowIndex,
            mime_type: self.format == .png ? "image/png" : "image/jpeg")
    }

    /// Finds the target window based on title or index
    func findTargetWindow(
        from windows: [WindowData],
        windowTitle: String?,
        windowIndex: Int?,
        appName: String) throws -> WindowData
    {
        if let windowTitle {
            guard let window = windows.first(where: { $0.title.contains(windowTitle) }) else {
                // Create detailed error message with available window titles for debugging
                let availableTitles = windows.map { "\"\($0.title)\"" }.joined(separator: ", ")
                let searchTerm = windowTitle

                Logger.shared.debug(
                    "Window not found. Searched for '\(searchTerm)' in \(appName). " +
                        "Available windows: \(availableTitles)")

                throw CaptureError.windowTitleNotFound(searchTerm, appName, availableTitles)
            }
            return window
        } else if let windowIndex {
            guard windowIndex >= 0, windowIndex < windows.count else {
                throw CaptureError.invalidWindowIndex(windowIndex)
            }
            return windows[windowIndex]
        } else {
            return windows[0] // frontmost window
        }
    }

    /// Captures a window to the specified path
    func captureWindow(_ window: WindowData, to path: String) async throws {
        do {
            try await ScreenCapture.captureWindow(window, to: path, format: self.format)
        } catch let error as CaptureError {
            throw error
        } catch {
            if PermissionErrorDetector.isScreenRecordingPermissionError(error) {
                throw CaptureError.screenRecordingPermissionDenied
            } else {
                throw CaptureError.windowCaptureFailed(error)
            }
        }
    }
}
