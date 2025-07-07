import CoreGraphics
import Foundation

/// Handles screen capture operations for the ImageCommand
struct ScreenCaptureHandler {
    let format: ImageFormat
    let path: String?

    /// Captures all screens or a specific screen based on the index
    func captureScreens(screenIndex: Int? = nil) async throws(CaptureError) -> [SavedFile] {
        let displays = try getActiveDisplays()

        if let screenIndex {
            return try await self.captureSpecificScreen(displays: displays, screenIndex: screenIndex)
        } else {
            return try await self.captureAllScreens(displays: displays)
        }
    }

    /// Gets the list of active displays
    private func getActiveDisplays() throws(CaptureError) -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        let result = CGGetActiveDisplayList(0, nil, &displayCount)
        guard result == .success, displayCount > 0 else {
            throw CaptureError.noDisplaysAvailable
        }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        let listResult = CGGetActiveDisplayList(displayCount, &displays, nil)
        guard listResult == .success else {
            throw CaptureError.noDisplaysAvailable
        }

        return displays
    }

    /// Captures a specific screen by index
    private func captureSpecificScreen(
        displays: [CGDirectDisplayID],
        screenIndex: Int) async throws(CaptureError) -> [SavedFile]
    {
        if screenIndex >= 0, screenIndex < displays.count {
            let displayID = displays[screenIndex]
            let labelSuffix = " (Index \(screenIndex))"
            let isSingleCapture = displays.count == 1 || self.path != nil
            return try await [self.captureSingleDisplay(
                displayID: displayID,
                index: screenIndex,
                labelSuffix: labelSuffix,
                isSingleCapture: isSingleCapture)]
        } else {
            Logger.shared.debug("Screen index \(screenIndex) is out of bounds. Capturing all screens instead.")
            // When falling back to all screens, use fallback-aware capture to prevent filename conflicts
            return try await self.captureAllScreensWithFallback(displays: displays)
        }
    }

    /// Captures all screens
    private func captureAllScreens(displays: [CGDirectDisplayID]) async throws(CaptureError) -> [SavedFile] {
        var savedFiles: [SavedFile] = []
        let isSingleCapture = displays.count == 1 && self.path != nil
        for (index, displayID) in displays.enumerated() {
            let savedFile = try await captureSingleDisplay(
                displayID: displayID,
                index: index,
                labelSuffix: "",
                isSingleCapture: isSingleCapture)
            savedFiles.append(savedFile)
        }
        return savedFiles
    }

    /// Captures all screens with fallback naming
    private func captureAllScreensWithFallback(
        displays: [CGDirectDisplayID]) async throws(CaptureError) -> [SavedFile]
    {
        var savedFiles: [SavedFile] = []
        for (index, displayID) in displays.enumerated() {
            let savedFile = try await captureSingleDisplayWithFallback(
                displayID: displayID,
                index: index,
                labelSuffix: "")
            savedFiles.append(savedFile)
        }
        return savedFiles
    }

    /// Captures a single display
    private func captureSingleDisplay(
        displayID: CGDirectDisplayID,
        index: Int,
        labelSuffix: String,
        isSingleCapture: Bool = false) async throws(CaptureError) -> SavedFile
    {
        let fileName = FileNameGenerator.generateFileName(displayIndex: index, format: self.format)
        let filePath = OutputPathResolver.getOutputPath(
            basePath: self.path,
            fileName: fileName,
            isSingleCapture: isSingleCapture)

        try await self.captureDisplay(displayID, to: filePath)

        return SavedFile(
            path: filePath,
            item_label: "Display \(index + 1)\(labelSuffix)",
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: self.format == .png ? "image/png" : "image/jpeg")
    }

    /// Captures a single display with fallback naming
    private func captureSingleDisplayWithFallback(
        displayID: CGDirectDisplayID,
        index: Int,
        labelSuffix: String) async throws(CaptureError) -> SavedFile
    {
        let fileName = FileNameGenerator.generateFileName(displayIndex: index, format: self.format)
        // Fallback mode means multiple screens, so never single capture
        let filePath = OutputPathResolver.getOutputPathWithFallback(
            basePath: self.path,
            fileName: fileName,
            isSingleCapture: false)

        try await self.captureDisplay(displayID, to: filePath)

        return SavedFile(
            path: filePath,
            item_label: "Display \(index + 1)\(labelSuffix)",
            window_title: nil,
            window_id: nil,
            window_index: nil,
            mime_type: self.format == .png ? "image/png" : "image/jpeg")
    }

    /// Captures a display to the specified path
    private func captureDisplay(_ displayID: CGDirectDisplayID, to path: String) async throws(CaptureError) {
        do {
            try await ScreenCapture.captureDisplay(displayID, to: path, format: self.format)
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
}
