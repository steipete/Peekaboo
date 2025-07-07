import AppKit
import AXorcistLib
import Foundation
import Observation

enum PermissionStatus {
    case notDetermined
    case denied
    case authorized
}

@Observable
@MainActor
final class Permissions {
    var screenRecordingStatus: PermissionStatus = .notDetermined
    var accessibilityStatus: PermissionStatus = .notDetermined

    var hasAllPermissions: Bool {
        self.screenRecordingStatus == .authorized && self.accessibilityStatus == .authorized
    }

    func check() async {
        // Check screen recording permission
        if CGPreflightScreenCaptureAccess() {
            self.screenRecordingStatus = CGRequestScreenCaptureAccess() ? .authorized : .denied
        } else {
            self.screenRecordingStatus = .denied
        }

        // Check accessibility permission using AXorcist
        var debugLogs: [String] = []
        let status = getPermissionsStatus(
            checkAutomationFor: [],
            isDebugLoggingEnabled: false,
            currentDebugLogs: &debugLogs)

        self.accessibilityStatus = status.isProcessTrustedForAccessibility ? .authorized : .denied
    }

    func requestScreenRecording() {
        if self.screenRecordingStatus != .authorized {
            CGRequestScreenCaptureAccess()
            // Open System Preferences
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func requestAccessibility() {
        if self.accessibilityStatus != .authorized {
            // Use AXorcist to check with prompt
            var debugLogs: [String] = []
            do {
                try checkAccessibilityPermissions(
                    isDebugLoggingEnabled: false,
                    currentDebugLogs: &debugLogs)
            } catch {
                // The prompt will have been shown
                print("Accessibility permission check: \(error)")
            }
        }
    }
}
