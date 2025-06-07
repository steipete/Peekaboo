import AVFoundation
import CoreGraphics
import Foundation
import ScreenCaptureKit

class PermissionsChecker {
    static func checkScreenRecordingPermission() -> Bool {
        // ScreenCaptureKit requires screen recording permission
        // We check by attempting to get shareable content
        let semaphore = DispatchSemaphore(value: 0)
        var hasPermission = false
        
        Task {
            do {
                // This will fail if we don't have screen recording permission
                _ = try await SCShareableContent.current
                hasPermission = true
            } catch {
                // If we get an error, we don't have permission
                hasPermission = false
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return hasPermission
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
