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
    private let permissionsService: any ObservablePermissionsServiceProtocol
    private let logger = Logger(subsystem: "com.peekaboo.peekaboo", category: "Permissions")

    var screenRecordingStatus: ObservablePermissionsService.PermissionState = .notDetermined
    var accessibilityStatus: ObservablePermissionsService.PermissionState = .notDetermined
    var appleScriptStatus: ObservablePermissionsService.PermissionState = .notDetermined

    var hasAllPermissions: Bool {
        self.screenRecordingStatus == .authorized && self.accessibilityStatus == .authorized
    }

    private var monitorTimer: Timer?
    private var isChecking = false
    private var registrations = 0
    private var lastCheck: Date?
    private let minimumCheckInterval: TimeInterval = 0.5

    init(permissionsService: (any ObservablePermissionsServiceProtocol)? = nil) {
        self.permissionsService = permissionsService ?? ObservablePermissionsService()
        self.syncFromService()
    }

    func check() async {
        self.check(force: true)
    }

    func requestScreenRecording() {
        do {
            try self.permissionsService.requestScreenRecording()
        } catch {
            self.logger.error("Failed to request screen recording permission: \(error)")
        }
        self.syncFromService()
    }

    func requestAccessibility() {
        do {
            try self.permissionsService.requestAccessibility()
        } catch {
            self.logger.error("Failed to request accessibility permission: \(error)")
        }
        self.syncFromService()
    }

    func requestAppleScript() {
        do {
            try self.permissionsService.requestAppleScript()
        } catch {
            self.logger.error("Failed to request AppleScript permission: \(error)")
        }
        self.syncFromService()
    }

    func startMonitoring() {
        self.registerMonitoring()
    }

    func stopMonitoring() {
        self.unregisterMonitoring()
    }

    func registerMonitoring() {
        self.registrations += 1
        if self.registrations == 1 {
            self.startMonitoringTimer()
        }
    }

    func unregisterMonitoring() {
        guard self.registrations > 0 else { return }
        self.registrations -= 1
        if self.registrations == 0 {
            self.stopMonitoringTimer()
        }
    }

    private func startMonitoringTimer() {
        self.check(force: true)

        self.monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.check(force: false)
            }
        }
    }

    private func stopMonitoringTimer() {
        self.monitorTimer?.invalidate()
        self.monitorTimer = nil
        self.lastCheck = nil
    }

    private func syncFromService() {
        self.screenRecordingStatus = self.permissionsService.screenRecordingStatus
        self.accessibilityStatus = self.permissionsService.accessibilityStatus
        self.appleScriptStatus = self.permissionsService.appleScriptStatus
    }

    private func check(force: Bool) {
        if self.isChecking { return }

        let now = Date()
        if !force, let lastCheck, now.timeIntervalSince(lastCheck) < self.minimumCheckInterval {
            return
        }

        self.isChecking = true
        defer { self.isChecking = false }

        self.logger.info("Checking all permissions...")
        self.permissionsService.checkPermissions()
        self.syncFromService()
        self.lastCheck = Date()
    }
}
