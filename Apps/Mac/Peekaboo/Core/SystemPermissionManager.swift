import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Observation
import OSLog
@preconcurrency import ScreenCaptureKit

extension Notification.Name {
    static let permissionsUpdated = Notification.Name("com.peekaboo.permissionsUpdated")
}

/// Types of system permissions that Peekaboo requires.
enum SystemPermission {
    case appleScript
    case screenRecording
    case accessibility

    var displayName: String {
        switch self {
        case .appleScript:
            "Automation"
        case .screenRecording:
            "Screen Recording"
        case .accessibility:
            "Accessibility"
        }
    }

    var explanation: String {
        switch self {
        case .appleScript:
            "Required to control applications and execute automation commands"
        case .screenRecording:
            "Required to capture screenshots and analyze screen content"
        case .accessibility:
            "Required to interact with UI elements and send input events"
        }
    }

    fileprivate var settingsURLString: String {
        switch self {
        case .appleScript:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        case .screenRecording:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .accessibility:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }
    }
}

/// Unified manager for all system permissions required by Peekaboo.
@MainActor
@Observable
final class SystemPermissionManager {
    static let shared = SystemPermissionManager()

    /// Permission states
    private(set) var permissions: [SystemPermission: Bool] = [
        .appleScript: false,
        .screenRecording: false,
        .accessibility: false
    ]

    private let logger = Logger(
        subsystem: "com.peekaboo.peekaboo",
        category: "SystemPermissions"
    )

    /// Timer for monitoring permission changes
    private var monitorTimer: Timer?

    /// Count of views that have registered for monitoring
    private var monitorRegistrationCount = 0

    init() {
        // No automatic monitoring - UI components will register when visible
    }

    // MARK: - Public API

    /// Check if a specific permission is granted
    func hasPermission(_ permission: SystemPermission) -> Bool {
        permissions[permission] ?? false
    }

    /// Check if all permissions are granted
    var hasAllPermissions: Bool {
        permissions.values.allSatisfy(\.self)
    }

    /// Get list of missing permissions
    var missingPermissions: [SystemPermission] {
        permissions.compactMap { permission, granted in
            granted ? nil : permission
        }
    }

    /// Request a specific permission
    func requestPermission(_ permission: SystemPermission) {
        logger.info("Requesting \(permission.displayName) permission")

        switch permission {
        case .appleScript:
            requestAppleScriptPermission()
        case .screenRecording:
            openSystemSettings(for: permission)
        case .accessibility:
            requestAccessibilityPermission()
        }
    }

    /// Request all missing permissions
    func requestAllMissingPermissions() {
        for permission in missingPermissions {
            requestPermission(permission)
        }
    }

    // MARK: - Permission Monitoring

    /// Register for permission monitoring (call when a view appears)
    func registerForMonitoring() {
        monitorRegistrationCount += 1
        logger.debug("Registered for monitoring, count: \(self.monitorRegistrationCount)")

        if monitorRegistrationCount == 1 {
            // First registration, start monitoring
            startMonitoring()
        }
    }

    /// Unregister from permission monitoring (call when a view disappears)
    func unregisterFromMonitoring() {
        monitorRegistrationCount = max(0, monitorRegistrationCount - 1)
        logger.debug("Unregistered from monitoring, count: \(self.monitorRegistrationCount)")

        if monitorRegistrationCount == 0 {
            // No more registrations, stop monitoring
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        logger.info("Starting permission monitoring")

        // Initial check
        Task {
            await checkAllPermissions()
        }

        // Start timer for periodic checks
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.checkAllPermissions()
            }
        }
    }

    private func stopMonitoring() {
        logger.info("Stopping permission monitoring")
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    // MARK: - Permission Checking

    func checkAllPermissions() async {
        let oldPermissions = permissions

        // Check each permission type
        permissions[.appleScript] = await checkAppleScriptPermission()
        permissions[.screenRecording] = await checkScreenRecordingPermission()
        permissions[.accessibility] = checkAccessibilityPermission()

        // Post notification if any permissions changed
        if oldPermissions != permissions {
            NotificationCenter.default.post(name: .permissionsUpdated, object: nil)
        }
    }

    // MARK: - AppleScript Permission

    private func checkAppleScriptPermission() async -> Bool {
        // Try a simple AppleScript that doesn't require automation permission
        let testScript = "return \"test\""
        
        if let script = NSAppleScript(source: testScript) {
            var error: NSDictionary?
            _ = script.executeAndReturnError(&error)
            
            if error == nil {
                return true
            } else {
                logger.debug("AppleScript check failed: \(String(describing: error))")
                return false
            }
        }
        
        return false
    }

    private func requestAppleScriptPermission() {
        Task {
            // Trigger permission dialog by targeting a common app
            let triggerScript = """
                tell application "Finder"
                    exists
                end tell
            """

            if let script = NSAppleScript(source: triggerScript) {
                var error: NSDictionary?
                _ = script.executeAndReturnError(&error)
                
                if error != nil {
                    logger.info("AppleScript permission dialog triggered")
                }
            }

            // Open System Settings after a delay
            try? await Task.sleep(for: .milliseconds(500))
            openSystemSettings(for: .appleScript)
        }
    }

    // MARK: - Screen Recording Permission

    private func checkScreenRecordingPermission() async -> Bool {
        // Use ScreenCaptureKit to check permission status
        do {
            // Try to get shareable content - this will fail without permission
            _ = try await SCShareableContent.current
            logger.debug("Screen recording permission verified through ScreenCaptureKit")
            return true
        } catch {
            logger.debug("Screen recording permission check failed: \(error)")
            return false
        }
    }

    // MARK: - Accessibility Permission

    private func checkAccessibilityPermission() -> Bool {
        // First check the API
        let apiResult = AXIsProcessTrusted()

        // Then do a direct test - try to get the focused element
        let systemElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        // If we can get the focused element, we truly have permission
        if result == .success {
            logger.debug("Accessibility permission verified through direct test")
            return true
        } else if apiResult {
            // API says yes but direct test failed - permission might be pending
            logger.debug("Accessibility API reports true but direct test failed")
            return false
        }

        return false
    }

    private func requestAccessibilityPermission() {
        // Trigger the system dialog
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
        let alreadyTrusted = AXIsProcessTrustedWithOptions(options)

        if alreadyTrusted {
            logger.info("Accessibility permission already granted")
        } else {
            logger.info("Accessibility permission dialog triggered")

            // Also open System Settings as a fallback
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.openSystemSettings(for: .accessibility)
            }
        }
    }

    // MARK: - Utilities

    private func openSystemSettings(for permission: SystemPermission) {
        if let url = URL(string: permission.settingsURLString) {
            NSWorkspace.shared.open(url)
        }
    }
}