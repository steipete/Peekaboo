import AVFoundation
import CoreGraphics
import Foundation
import ScreenCaptureKit
import os.log

/// Service for checking and managing macOS system permissions
@MainActor
public final class PermissionsService: Sendable {
    
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "PermissionsService")
    
    public init() {}
    
    /// Check if Screen Recording permission is granted
    public func checkScreenRecordingPermission() -> Bool {
        logger.debug("Checking screen recording permission")
        
        // Use CGWindowListCreateImage which doesn't require async
        // This is the traditional way to check screen recording permission
        let windowList = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID)
        let hasPermission = windowList != nil && CFArrayGetCount(windowList) > 0
        
        logger.info("Screen recording permission: \(hasPermission)")
        return hasPermission
    }
    
    /// Check if Accessibility permission is granted
    public func checkAccessibilityPermission() -> Bool {
        logger.debug("Checking accessibility permission")
        
        // Check if we have accessibility permission
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        let hasPermission = AXIsProcessTrustedWithOptions(options)
        
        logger.info("Accessibility permission: \(hasPermission)")
        return hasPermission
    }
    
    /// Check if AppleScript permission is granted
    public func checkAppleScriptPermission() -> Bool {
        logger.debug("Checking AppleScript permission")
        
        // Check if we have permission to send AppleEvents
        // This checks permission for sending events to System Events
        let targetBundleID = "com.apple.systemevents"
        
        guard var addressDesc = NSAppleEventDescriptor(bundleIdentifier: targetBundleID).aeDesc?.pointee else {
            logger.warning("Failed to create AppleEvent descriptor")
            return false
        }
        
        defer {
            AEDisposeDesc(&addressDesc)
        }
        
        let permissionStatus = AEDeterminePermissionToAutomateTarget(
            &addressDesc,
            typeWildCard,
            typeWildCard,
            true  // async notification
        )
        
        let hasPermission = permissionStatus == noErr
        logger.info("AppleScript permission status: \(permissionStatus), has permission: \(hasPermission)")
        return hasPermission
    }
    
    /// Require Screen Recording permission, throwing if not granted
    public func requireScreenRecordingPermission() throws {
        logger.debug("Requiring screen recording permission")
        
        if !checkScreenRecordingPermission() {
            logger.error("Screen recording permission denied")
            throw CaptureError.screenRecordingPermissionDenied
        }
    }
    
    /// Require Accessibility permission, throwing if not granted
    public func requireAccessibilityPermission() throws {
        logger.debug("Requiring accessibility permission")
        
        if !checkAccessibilityPermission() {
            logger.error("Accessibility permission denied")
            throw CaptureError.accessibilityPermissionDenied
        }
    }
    
    /// Require AppleScript permission, throwing if not granted
    public func requireAppleScriptPermission() throws {
        logger.debug("Requiring AppleScript permission")
        
        if !checkAppleScriptPermission() {
            logger.error("AppleScript permission denied")
            throw CaptureError.appleScriptPermissionDenied
        }
    }
    
    /// Check all permissions and return their status
    public func checkAllPermissions() -> PermissionsStatus {
        logger.debug("Checking all permissions")
        
        let screenRecording = checkScreenRecordingPermission()
        let accessibility = checkAccessibilityPermission()
        let appleScript = checkAppleScriptPermission()
        
        return PermissionsStatus(
            screenRecording: screenRecording,
            accessibility: accessibility,
            appleScript: appleScript
        )
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
        screenRecording && accessibility && appleScript
    }
    
    public var missingPermissions: [String] {
        var missing: [String] = []
        if !screenRecording { missing.append("Screen Recording") }
        if !accessibility { missing.append("Accessibility") }
        if !appleScript { missing.append("AppleScript") }
        return missing
    }
}