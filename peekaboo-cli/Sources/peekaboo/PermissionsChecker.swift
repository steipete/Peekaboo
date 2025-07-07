import AVFoundation
import CoreGraphics
import Foundation
import ScreenCaptureKit

/// Utility for checking and enforcing macOS system permissions.
///
/// Verifies that required permissions (Screen Recording) and optional permissions
/// (Accessibility) are granted before performing operations that require them.
final class PermissionsChecker: Sendable {
    static func checkScreenRecordingPermission() -> Bool {
        // Use a simpler approach - check CGWindowListCreateImage which doesn't require async
        // This is the traditional way to check screen recording permission
        let windowList = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID)
        return windowList != nil && CFArrayGetCount(windowList) > 0
    }

    static func checkAccessibilityPermission() -> Bool {
        // Check if we have accessibility permission
        // Create options dictionary without using the global constant directly
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requireScreenRecordingPermission() throws {
        if !self.checkScreenRecordingPermission() {
            throw CaptureError.screenRecordingPermissionDenied
        }
    }

    static func requireAccessibilityPermission() throws {
        if !self.checkAccessibilityPermission() {
            throw CaptureError.accessibilityPermissionDenied
        }
    }
}
