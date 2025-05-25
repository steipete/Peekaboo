import AVFoundation
import CoreGraphics
import Foundation

class PermissionsChecker {
    static func checkScreenRecordingPermission() -> Bool {
        // Check if we can capture screen content by trying to get display bounds
        var displayCount: UInt32 = 0
        let result = CGGetActiveDisplayList(0, nil, &displayCount)
        if result != .success || displayCount == 0 {
            return false
        }

        // Try to capture a small image to test permissions
        guard let mainDisplayID = CGMainDisplayID() as CGDirectDisplayID? else {
            return false
        }

        // Test by trying to get display bounds - this requires screen recording permission
        let bounds = CGDisplayBounds(mainDisplayID)
        return bounds != CGRect.zero
    }

    static func checkAccessibilityPermission() -> Bool {
        // Check if we have accessibility permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func requireScreenRecordingPermission() throws(CaptureError) {
        if !checkScreenRecordingPermission() {
            throw CaptureError.capturePermissionDenied
        }
    }

    static func requireAccessibilityPermission() throws(CaptureError) {
        if !checkAccessibilityPermission() {
            throw CaptureError.capturePermissionDenied
        }
    }
}

enum PermissionError: Error {
    case screenRecordingDenied
    case accessibilityDenied
}
