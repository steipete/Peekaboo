import Foundation
import CoreGraphics

#if os(macOS)
import AVFoundation
import ScreenCaptureKit
#endif

// Legacy PermissionsChecker class for backward compatibility
// New code should use PlatformFactory.createPermissionsChecker()
final class PermissionsChecker: Sendable {
    #if os(macOS)
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
        if !checkScreenRecordingPermission() {
            throw CaptureError.screenRecordingPermissionDenied
        }
    }

    static func requireAccessibilityPermission() throws {
        if !checkAccessibilityPermission() {
            throw CaptureError.accessibilityPermissionDenied
        }
    }

    static func requestScreenRecordingPermission() async -> Bool {
        // On macOS 14+, we can use ScreenCaptureKit to request permission
        if #available(macOS 14.0, *) {
            do {
                // This will prompt for permission if not already granted
                _ = try await SCShareableContent.current
                return checkScreenRecordingPermission()
            } catch {
                return false
            }
        } else {
            // For older macOS versions, we can't programmatically request permission
            return checkScreenRecordingPermission()
        }
    }

    static func requestAccessibilityPermission() -> Bool {
        // This will show the system prompt if permission is not granted
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    #else
    // Non-macOS platforms - use platform factory
    static func checkScreenRecordingPermission() async -> Bool {
        let permissionsChecker = PlatformFactory.createPermissionsChecker()
        return await permissionsChecker.hasScreenRecordingPermission()
    }

    static func checkAccessibilityPermission() async -> Bool {
        let permissionsChecker = PlatformFactory.createPermissionsChecker()
        return await permissionsChecker.hasAccessibilityPermission()
    }

    static func requireScreenRecordingPermission() async throws {
        if !(await checkScreenRecordingPermission()) {
            throw CaptureError.screenRecordingPermissionDenied
        }
    }

    static func requireAccessibilityPermission() async throws {
        if !(await checkAccessibilityPermission()) {
            throw CaptureError.accessibilityPermissionDenied
        }
    }

    static func requestScreenRecordingPermission() async -> Bool {
        let permissionsChecker = PlatformFactory.createPermissionsChecker()
        return await permissionsChecker.requestScreenRecordingPermission()
    }

    static func requestAccessibilityPermission() async -> Bool {
        let permissionsChecker = PlatformFactory.createPermissionsChecker()
        return await permissionsChecker.requestAccessibilityPermission()
    }
    #endif
}

// Permission error detection
struct PermissionErrorDetector: Sendable {
    #if os(macOS)
    static func isScreenRecordingPermissionError(_ error: Error) -> Bool {
        let errorString = error.localizedDescription.lowercased()
        return errorString.contains("screen recording") ||
               errorString.contains("permission") ||
               errorString.contains("not authorized") ||
               errorString.contains("access denied")
    }
    #else
    static func isScreenRecordingPermissionError(_ error: Error) -> Bool {
        // Platform-specific permission error detection would go here
        return false
    }
    #endif
}

