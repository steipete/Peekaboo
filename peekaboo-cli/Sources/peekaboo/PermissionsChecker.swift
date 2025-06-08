import AVFoundation
import CoreGraphics
import Foundation
import ScreenCaptureKit

class PermissionsChecker {
    static func checkScreenRecordingPermission() -> Bool {
        // Use a simpler approach - check CGWindowListCreateImage which doesn't require async
        // This is the traditional way to check screen recording permission
        let windowList = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID)
        return windowList != nil && CFArrayGetCount(windowList) > 0
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
