import AVFoundation
import CoreGraphics
import Foundation
import os.log
import ScreenCaptureKit

/// Service for checking and managing macOS system permissions
@MainActor
public final class PermissionsService {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "PermissionsService")

    public init() {}

    /// Check if Screen Recording permission is granted
    public func checkScreenRecordingPermission() -> Bool {
        self.logger.debug("Checking screen recording permission")

        // Use CGWindowListCreateImage which doesn't require async
        // This is the traditional way to check screen recording permission
        let windowList = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID)
        let hasPermission = windowList != nil && CFArrayGetCount(windowList) > 0

        self.logger.info("Screen recording permission: \(hasPermission)")
        return hasPermission
    }

    /// Check if Accessibility permission is granted
    public func checkAccessibilityPermission() -> Bool {
        self.logger.debug("Checking accessibility permission")

        // Check if we have accessibility permission
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        let hasPermission = AXIsProcessTrustedWithOptions(options)

        self.logger.info("Accessibility permission: \(hasPermission)")
        return hasPermission
    }

    /// Check if AppleScript permission is granted
    public func checkAppleScriptPermission() -> Bool {
        self.logger.debug("Checking AppleScript permission")

        // Check if we have permission to send AppleEvents
        // This checks permission for sending events to System Events
        let targetBundleID = "com.apple.systemevents"

        guard var addressDesc = NSAppleEventDescriptor(bundleIdentifier: targetBundleID).aeDesc?.pointee else {
            self.logger.warning("Failed to create AppleEvent descriptor")
            return false
        }

        defer {
            AEDisposeDesc(&addressDesc)
        }

        let permissionStatus = AEDeterminePermissionToAutomateTarget(
            &addressDesc,
            typeWildCard,
            typeWildCard,
            true // async notification
        )

        let hasPermission = permissionStatus == noErr
        self.logger.info("AppleScript permission status: \(permissionStatus), has permission: \(hasPermission)")
        return hasPermission
    }

    /// Require Screen Recording permission, throwing if not granted
    public func requireScreenRecordingPermission() throws {
        self.logger.debug("Requiring screen recording permission")

        if !self.checkScreenRecordingPermission() {
            self.logger.error("Screen recording permission denied")
            throw CaptureError.screenRecordingPermissionDenied
        }
    }

    /// Require Accessibility permission, throwing if not granted
    public func requireAccessibilityPermission() throws {
        self.logger.debug("Requiring accessibility permission")

        if !self.checkAccessibilityPermission() {
            self.logger.error("Accessibility permission denied")
            throw CaptureError.accessibilityPermissionDenied
        }
    }

    /// Require AppleScript permission, throwing if not granted
    public func requireAppleScriptPermission() throws {
        self.logger.debug("Requiring AppleScript permission")

        if !self.checkAppleScriptPermission() {
            self.logger.error("AppleScript permission denied")
            throw CaptureError.appleScriptPermissionDenied
        }
    }

    /// Check all permissions and return their status
    public func checkAllPermissions() -> PermissionsStatus {
        self.logger.debug("Checking all permissions")

        let screenRecording = self.checkScreenRecordingPermission()
        let accessibility = self.checkAccessibilityPermission()
        let appleScript = self.checkAppleScriptPermission()

        return PermissionsStatus(
            screenRecording: screenRecording,
            accessibility: accessibility,
            appleScript: appleScript)
    }
}

/// Status of system permissions
public struct PermissionsStatus: Sendable {
    public let screenRecording: Bool
    public let accessibility: Bool
    public let appleScript: Bool

    public init(screenRecording: Bool, accessibility: Bool, appleScript: Bool = false) {
        self.screenRecording = screenRecording
        self.accessibility = accessibility
        self.appleScript = appleScript
    }

    public var allGranted: Bool {
        self.screenRecording && self.accessibility && self.appleScript
    }

    public var missingPermissions: [String] {
        var missing: [String] = []
        if !self.screenRecording { missing.append("Screen Recording") }
        if !self.accessibility { missing.append("Accessibility") }
        if !self.appleScript { missing.append("AppleScript") }
        return missing
    }
}
