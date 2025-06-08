import CoreGraphics
import Foundation

#if os(macOS)
@preconcurrency import ScreenCaptureKit
#endif

// Legacy ScreenCapture class for backward compatibility
// New code should use PlatformFactory.createScreenCapture()
struct ScreenCapture: Sendable {
    #if os(macOS)
    static func captureDisplay(
        _ displayID: CGDirectDisplayID, to path: String, format: ImageFormat = .png
    ) async throws {
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

            // Save the image
            try await ImageSaver.saveImage(image, to: path, format: format)

        } catch let error as CaptureError {
            throw error
        } catch {
            // Check if this is a permission error
            if PermissionErrorDetector.isScreenRecordingPermissionError(error) {
                throw CaptureError.screenRecordingPermissionDenied
            }
            
            // Try fallback to CGImage
            try await captureDisplayWithCGImage(displayID, to: path, format: format)
        }
    }

    static func captureWindow(
        _ window: WindowData, to path: String, format: ImageFormat = .png
    ) async throws {
        do {
            // Get available content
            let availableContent = try await SCShareableContent.current

            // Find the window by ID
            guard let scWindow = availableContent.windows.first(where: { $0.windowID == window.windowId }) else {
                // Fallback to CGImage capture
                try await captureWindowWithCGImage(window, to: path, format: format)
                return
            }

            // Create content filter for the specific window
            let filter = SCContentFilter(desktopIndependentWindow: scWindow)

            // Configure capture settings
            let configuration = SCStreamConfiguration()
            configuration.width = Int(window.bounds.width)
            configuration.height = Int(window.bounds.height)
            configuration.backgroundColor = .clear
            configuration.shouldBeOpaque = false
            configuration.showsCursor = false

            // Capture the image
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )

            // Save the image
            try await ImageSaver.saveImage(image, to: path, format: format)

        } catch let error as CaptureError {
            throw error
        } catch {
            // Check if this is a permission error
            if PermissionErrorDetector.isScreenRecordingPermissionError(error) {
                throw CaptureError.screenRecordingPermissionDenied
            }
            
            // Try fallback to CGImage
            try await captureWindowWithCGImage(window, to: path, format: format)
        }
    }

    // Fallback methods using CGImage
    private static func captureDisplayWithCGImage(
        _ displayID: CGDirectDisplayID, to path: String, format: ImageFormat
    ) async throws {
        guard let cgImage = CGDisplayCreateImage(displayID) else {
            throw CaptureError.captureCreationFailed(nil)
        }

        try await ImageSaver.saveImage(cgImage, to: path, format: format)
    }

    private static func captureWindowWithCGImage(
        _ window: WindowData, to path: String, format: ImageFormat
    ) async throws {
        let windowID = CGWindowID(window.windowId)
        let imageRef = CGWindowListCreateImage(
            window.bounds,
            .optionIncludingWindow,
            windowID,
            .bestResolution
        )

        guard let cgImage = imageRef else {
            throw CaptureError.windowCaptureFailed(nil)
        }

        try await ImageSaver.saveImage(cgImage, to: path, format: format)
    }
    #else
    // Non-macOS platforms - use platform factory
    static func captureDisplay(
        _ displayIndex: Int, to path: String, format: ImageFormat = .png
    ) async throws {
        let screenCapture = PlatformFactory.createScreenCapture()
        let imageData = try await screenCapture.captureScreen(screenIndex: displayIndex)
        try imageData.write(to: URL(fileURLWithPath: path))
    }

    static func captureWindow(
        _ window: WindowData, to path: String, format: ImageFormat = .png
    ) async throws {
        let screenCapture = PlatformFactory.createScreenCapture()
        let imageData = try await screenCapture.captureWindow(windowId: String(window.windowId), bounds: window.bounds)
        try imageData.write(to: URL(fileURLWithPath: path))
    }
    #endif
}

