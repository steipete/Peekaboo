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
    private let permissionsService: ObservablePermissionsServiceProtocol
    private let logger = Logger(subsystem: "com.peekaboo.peekaboo", category: "Permissions")

    var screenRecordingStatus: ObservablePermissionsService.PermissionState {
        self.permissionsService.screenRecordingStatus
    }

    var accessibilityStatus: ObservablePermissionsService.PermissionState {
        self.permissionsService.accessibilityStatus
    }

    var appleScriptStatus: ObservablePermissionsService.PermissionState {
        self.permissionsService.appleScriptStatus
    }

    var hasAllPermissions: Bool {
        self.permissionsService.hasAllPermissions
    }

    @MainActor
    init(permissionsService: ObservablePermissionsServiceProtocol = ObservablePermissionsService()) {
        self.permissionsService = permissionsService
    }

    func check() async {
        self.logger.info("Checking all permissions...")
        self.permissionsService.checkPermissions()
        self.logger
            .info(
                "Permission check complete - Accessibility: \(String(describing: self.accessibilityStatus)), Screen Recording: \(String(describing: self.screenRecordingStatus))")
    }

    func requestScreenRecording() {
        do {
            try self.permissionsService.requestScreenRecording()
        } catch {
            self.logger.error("Failed to request screen recording permission: \(error)")
        }
    }

    func requestAccessibility() {
        do {
            try self.permissionsService.requestAccessibility()
        } catch {
            self.logger.error("Failed to request accessibility permission: \(error)")
        }
    }

    func requestAppleScript() {
        do {
            try self.permissionsService.requestAppleScript()
        } catch {
            self.logger.error("Failed to request AppleScript permission: \(error)")
        }
    }

    func startMonitoring() {
        self.permissionsService.startMonitoring(interval: 1.0)
    }

    func stopMonitoring() {
        self.permissionsService.stopMonitoring()
    }
}
