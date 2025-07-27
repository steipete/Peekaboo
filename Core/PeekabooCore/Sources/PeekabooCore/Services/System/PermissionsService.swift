import AVFoundation
import CoreGraphics
import Foundation
import ScreenCaptureKit
import os.log

/// Service for checking and managing macOS system permissions
public final class PermissionsService: Sendable {
    
    private let logger = Logger(subsystem: "com.steipete.PeekabooCore", category: "PermissionsService")
    
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
    
    /// Check all permissions and return their status
    public func checkAllPermissions() -> PermissionsStatus {
        logger.debug("Checking all permissions")
        
        let screenRecording = checkScreenRecordingPermission()
        let accessibility = checkAccessibilityPermission()
        
        return PermissionsStatus(
            screenRecording: screenRecording,
            accessibility: accessibility
        )
    }
}

/// Status of system permissions
public struct PermissionsStatus: Sendable {
    public let screenRecording: Bool
    public let accessibility: Bool
    
    public var allGranted: Bool {
        screenRecording && accessibility
    }
    
    public var missingPermissions: [String] {
        var missing: [String] = []
        if !screenRecording { missing.append("Screen Recording") }
        if !accessibility { missing.append("Accessibility") }
        return missing
    }
}