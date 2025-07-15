import AppKit
import Foundation
import Observation
import os.log

enum PermissionStatus {
    case notDetermined
    case denied
    case authorized
}

/// Manages and monitors system permission states for Peekaboo.
///
/// `Permissions` provides a centralized interface for checking and monitoring the system
/// permissions required by Peekaboo, including Screen Recording, Accessibility, and AppleScript
/// permissions. It automatically updates when permissions change and provides observable state.
///
/// ## Overview
///
/// The permissions manager:
/// - Tracks the authorization status of required system permissions
/// - Automatically updates when permissions change at the system level
/// - Provides methods to request permissions from the user
/// - Offers a consolidated view of overall permission status
///
/// ## Topics
///
/// ### Permission States
///
/// - ``screenRecordingStatus``
/// - ``accessibilityStatus``
/// - ``appleScriptStatus``
/// - ``hasAllPermissions``
/// - ``PermissionStatus``
///
/// ### Permission Management
///
/// - ``check()``
/// - ``requestAccessibility()``
/// - ``requestScreenRecording()``
///
/// ### System Integration
///
/// Works with ``SystemPermissionManager`` to interface with macOS permission APIs.
@Observable
@MainActor
final class Permissions {
    private let systemPermissions = SystemPermissionManager.shared
    private let logger = Logger(subsystem: "com.peekaboo.peekaboo", category: "Permissions")
    
    var screenRecordingStatus: PermissionStatus = .notDetermined
    var accessibilityStatus: PermissionStatus = .notDetermined
    var appleScriptStatus: PermissionStatus = .notDetermined

    var hasAllPermissions: Bool {
        self.screenRecordingStatus == .authorized && 
        self.accessibilityStatus == .authorized &&
        self.appleScriptStatus == .authorized
    }

    init() {
        // Register for permission updates
        NotificationCenter.default.addObserver(
            forName: .permissionsUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.updateFromSystemPermissions()
            }
        }
    }

    func check() async {
        logger.info("Checking all permissions...")
        // Check all permissions through SystemPermissionManager
        await self.systemPermissions.checkAllPermissions()
        await self.updateFromSystemPermissions()
        logger.info("Permission check complete - Accessibility: \(self.accessibilityStatus == .authorized ? "authorized" : "denied"), Screen Recording: \(self.screenRecordingStatus == .authorized ? "authorized" : "denied")")
    }

    private func updateFromSystemPermissions() async {
        // Update our status from SystemPermissionManager
        let oldAccessibility = self.accessibilityStatus
        
        self.screenRecordingStatus = self.systemPermissions.hasPermission(.screenRecording) ? .authorized : .denied
        self.accessibilityStatus = self.systemPermissions.hasPermission(.accessibility) ? .authorized : .denied
        self.appleScriptStatus = self.systemPermissions.hasPermission(.appleScript) ? .authorized : .denied
        
        if oldAccessibility != self.accessibilityStatus {
            logger.info("Accessibility status changed from \(oldAccessibility == .authorized ? "authorized" : "denied") to \(self.accessibilityStatus == .authorized ? "authorized" : "denied")")
        }
    }

    func requestScreenRecording() {
        self.systemPermissions.requestPermission(.screenRecording)
    }

    func requestAccessibility() {
        self.systemPermissions.requestPermission(.accessibility)
    }

    func requestAppleScript() {
        self.systemPermissions.requestPermission(.appleScript)
    }

    func startMonitoring() {
        self.systemPermissions.registerForMonitoring()
    }

    func stopMonitoring() {
        self.systemPermissions.unregisterFromMonitoring()
    }
}