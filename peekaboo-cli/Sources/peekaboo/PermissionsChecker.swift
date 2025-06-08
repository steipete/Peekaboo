import AVFoundation
import CoreGraphics
import Foundation
import ScreenCaptureKit

class PermissionsChecker {
    static func checkScreenRecordingPermission() -> Bool {
        // ScreenCaptureKit requires screen recording permission
        // We check by attempting to get shareable content using RunLoop to avoid semaphore deadlock
        var result: Result<Bool, Error>?
        let runLoop = RunLoop.current

        Task {
            do {
                // This will fail if we don't have screen recording permission
                _ = try await SCShareableContent.current
                result = .success(true)
            } catch {
                // If we get an error, we don't have permission
                Logger.shared.debug("Screen recording permission check failed: \(error)")
                result = .success(false)
            }
            // Stop the run loop
            CFRunLoopStop(runLoop.getCFRunLoop())
        }

        // Run the event loop until the task completes
        runLoop.run()

        guard let result = result else {
            return false
        }
        
        return (try? result.get()) ?? false
    }

    static func checkAccessibilityPermission() -> Bool {
        // Check if we have accessibility permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func requireScreenRecordingPermission() throws {
        if !checkScreenRecordingPermission() {
            throw CaptureError.screenRecordingPermissionDenied
        }
    }

    static func requireAccessibilityPermission() throws {
        if !checkAccessibilityPermission() {
            throw CaptureError.accessibilityPermissionDenied
        }
    }
}
