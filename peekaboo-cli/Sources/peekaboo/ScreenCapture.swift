import Foundation
import CoreGraphics
import ScreenCaptureKit

struct ScreenCapture {
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

            try ImageSaver.saveImage(image, to: path, format: format)
        } catch let captureError as CaptureError {
            // Re-throw CaptureError as-is (no need to check for screen recording permission)
            throw captureError
        } catch {
            // Check if this is a permission error from ScreenCaptureKit
            if PermissionErrorDetector.isScreenRecordingPermissionError(error) {
                throw CaptureError.screenRecordingPermissionDenied
            }
            throw error
        }
    }

    static func captureWindow(_ window: WindowData, to path: String, format: ImageFormat = .png) async throws {
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

            try ImageSaver.saveImage(image, to: path, format: format)
        } catch let captureError as CaptureError {
            // Re-throw CaptureError as-is (no need to check for screen recording permission)
            throw captureError
        } catch {
            // Check if this is a permission error from ScreenCaptureKit
            if PermissionErrorDetector.isScreenRecordingPermissionError(error) {
                throw CaptureError.screenRecordingPermissionDenied
            }
            throw error
        }
    }
}
