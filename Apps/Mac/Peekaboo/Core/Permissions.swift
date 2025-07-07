import AppKit
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
    private let systemPermissions = SystemPermissionManager.shared
    
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
        // Check all permissions through SystemPermissionManager
        await self.systemPermissions.checkAllPermissions()
        await self.updateFromSystemPermissions()
    }

    private func updateFromSystemPermissions() async {
        // Update our status from SystemPermissionManager
        self.screenRecordingStatus = self.systemPermissions.hasPermission(.screenRecording) ? .authorized : .denied
        self.accessibilityStatus = self.systemPermissions.hasPermission(.accessibility) ? .authorized : .denied
        self.appleScriptStatus = self.systemPermissions.hasPermission(.appleScript) ? .authorized : .denied
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