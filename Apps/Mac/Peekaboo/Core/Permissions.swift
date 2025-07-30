import AppKit
import Foundation
import Observation
import os.log
import PeekabooCore

/// Manages and monitors system permission states for Peekaboo.
///
/// `Permissions` provides a centralized interface for checking and monitoring the system
/// permissions required by Peekaboo, including Screen Recording and Accessibility.
/// It uses the ObservablePermissionsService from PeekabooCore under the hood.
@Observable
@MainActor
final class Permissions {
    private let permissionsService = ObservablePermissionsService()
    private let logger = Logger(subsystem: "com.peekaboo.peekaboo", category: "Permissions")
    
    var screenRecordingStatus: ObservablePermissionsService.PermissionState {
        permissionsService.screenRecordingStatus
    }
    
    var accessibilityStatus: ObservablePermissionsService.PermissionState {
        permissionsService.accessibilityStatus
    }
    
    var appleScriptStatus: ObservablePermissionsService.PermissionState {
        permissionsService.appleScriptStatus
    }

    var hasAllPermissions: Bool {
        permissionsService.hasAllPermissions
    }

    init() {
        // ObservablePermissionsService handles its own monitoring
    }

    func check() async {
        logger.info("Checking all permissions...")
        permissionsService.checkPermissions()
        logger.info("Permission check complete - Accessibility: \(String(describing: self.accessibilityStatus)), Screen Recording: \(String(describing: self.screenRecordingStatus))")
    }

    func requestScreenRecording() {
        do {
            try permissionsService.requestScreenRecording()
        } catch {
            logger.error("Failed to request screen recording permission: \(error)")
        }
    }

    func requestAccessibility() {
        do {
            try permissionsService.requestAccessibility()
        } catch {
            logger.error("Failed to request accessibility permission: \(error)")
        }
    }

    func requestAppleScript() {
        do {
            try permissionsService.requestAppleScript()
        } catch {
            logger.error("Failed to request AppleScript permission: \(error)")
        }
    }

    func startMonitoring() {
        permissionsService.startMonitoring()
    }

    func stopMonitoring() {
        permissionsService.stopMonitoring()
    }
}