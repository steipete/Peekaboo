import ApplicationServices
import AVFoundation
import AXorcist
import CoreGraphics
import Foundation
import os.log
import PeekabooFoundation
import ScreenCaptureKit

/// Service for checking and managing macOS system permissions
@MainActor
public final class PermissionsService {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "PermissionsService")

    public init() {}

    private static var isRunningUnderTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            ProcessInfo.processInfo.arguments.contains("--test-mode") ||
            NSClassFromString("XCTest") != nil
    }

    /// Check if Screen Recording permission is granted
    public func checkScreenRecordingPermission() -> Bool {
        self.logger.debug("Checking screen recording permission")

        if #available(macOS 10.15, *) {
            let hasPermission = CGPreflightScreenCaptureAccess()
            self.logger.info("Screen recording permission: \(hasPermission)")
            return hasPermission
        }

        self.logger.info("Screen recording permission: true (pre-10.15 fallback)")
        return true
    }

    @discardableResult
    public func requestScreenRecordingPermission(interactive: Bool = true) -> Bool {
        self.logger.debug("Requesting screen recording permission")

        guard interactive else { return self.checkScreenRecordingPermission() }
        if Self.isRunningUnderTests {
            return self.checkScreenRecordingPermission()
        }

        if #available(macOS 10.15, *) {
            _ = CGRequestScreenCaptureAccess()
        }

        return self.checkScreenRecordingPermission()
    }

    /// Check if Accessibility permission is granted
    public func checkAccessibilityPermission() -> Bool {
        self.logger.debug("Checking accessibility permission")

        // Check if we have accessibility permission through AXorcist helper
        let hasPermission = AXPermissionHelpers.hasAccessibilityPermissions()

        self.logger.info("Accessibility permission: \(hasPermission)")
        return hasPermission
    }

    @discardableResult
    public func requestAccessibilityPermission(interactive: Bool = true) -> Bool {
        self.logger.debug("Requesting accessibility permission")

        guard interactive else { return self.checkAccessibilityPermission() }
        let hasPermission = AXPermissionHelpers.askForAccessibilityIfNeeded()
        self.logger.info("Accessibility permission (after request): \(hasPermission)")
        return hasPermission
    }

    /// Check if AppleScript permission is granted
    public func checkAppleScriptPermission() -> Bool {
        self.logger.debug("Checking AppleScript permission")

        // Apple Events automation permission is evaluated against a target app.
        // We probe System Events since it's the most common automation target.
        let bundleIdentifier = "com.apple.systemevents"

        var permissionStatus = Self.determineAppleScriptAutomationPermissionStatus(
            targetBundleIdentifier: bundleIdentifier,
            askUser: false)

        if permissionStatus == procNotFound, !Self.isRunningUnderTests {
            self.logger.debug("AppleScript permission probe returned procNotFound; launching target and retrying")
            Self.launchApplication(bundleIdentifier: bundleIdentifier, logger: self.logger)
            permissionStatus = Self.determineAppleScriptAutomationPermissionStatus(
                targetBundleIdentifier: bundleIdentifier,
                askUser: false)
        }

        let hasPermission = permissionStatus == noErr
        self.logger.info("AppleScript permission status: \(permissionStatus), has permission: \(hasPermission)")
        return hasPermission
    }

    @discardableResult
    public func requestAppleScriptPermission(interactive: Bool = true) -> Bool {
        self.logger.debug("Requesting AppleScript permission")

        guard interactive else { return self.checkAppleScriptPermission() }
        if Self.isRunningUnderTests {
            return self.checkAppleScriptPermission()
        }

        let bundleIdentifier = "com.apple.systemevents"

        var permissionStatus = Self.determineAppleScriptAutomationPermissionStatus(
            targetBundleIdentifier: bundleIdentifier,
            askUser: true)

        if permissionStatus == procNotFound {
            self.logger.debug("AppleScript permission request returned procNotFound; launching target and retrying")
            Self.launchApplication(bundleIdentifier: bundleIdentifier, logger: self.logger)
            permissionStatus = Self.determineAppleScriptAutomationPermissionStatus(
                targetBundleIdentifier: bundleIdentifier,
                askUser: true)
        }

        let hasPermission = permissionStatus == noErr
        self.logger.info("AppleScript permission request status: \(permissionStatus), has permission: \(hasPermission)")
        return self.checkAppleScriptPermission()
    }

    private static func determineAppleScriptAutomationPermissionStatus(
        targetBundleIdentifier: String,
        askUser: Bool) -> OSStatus
    {
        guard var addressDesc = makeAppleEventTargetAddressDesc(bundleIdentifier: targetBundleIdentifier) else {
            return OSStatus(paramErr)
        }
        defer { AEDisposeDesc(&addressDesc) }

        // IMPORTANT:
        // Use an Apple Event that reflects *automation* (not just launching an app). `oapp` (open app)
        // can succeed even when automation is not authorized, and will not reliably trigger the TCC prompt.
        //
        // `core/getd` (get data) is a common, benign automation event that maps well to "tell app ... return ...".
        let eventClass = AEEventClass(0x636F_7265) // 'core'
        let eventID = AEEventID(0x6765_7464) // 'getd'

        return autoreleasepool {
            AEDeterminePermissionToAutomateTarget(&addressDesc, eventClass, eventID, askUser)
        }
    }

    static func makeAppleEventTargetAddressDesc(bundleIdentifier: String) -> AEDesc? {
        guard let bundleIDData = bundleIdentifier.data(using: .utf8), !bundleIDData.isEmpty else {
            return nil
        }

        var addressDesc = AEDesc()
        let status = bundleIDData.withUnsafeBytes { buffer -> OSStatus in
            guard let baseAddress = buffer.baseAddress else { return OSStatus(paramErr) }
            return OSStatus(AECreateDesc(DescType(typeApplicationBundleID), baseAddress, buffer.count, &addressDesc))
        }
        guard status == noErr else { return nil }
        return addressDesc
    }

    private static func launchApplication(bundleIdentifier: String, logger: Logger) {
        guard !self.isRunningUnderTests else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-g", "-b", bundleIdentifier]

        do {
            try process.run()
        } catch {
            logger
                .debug(
                    """
                    Failed to launch app \(bundleIdentifier, privacy: .public): \
                    \(String(describing: error), privacy: .public)
                    """)
        }
    }

    /// Require Screen Recording permission, throwing if not granted
    public func requireScreenRecordingPermission() throws {
        // Require Screen Recording permission, throwing if not granted
        self.logger.debug("Requiring screen recording permission")

        if !self.checkScreenRecordingPermission() {
            self.logger.error("Screen recording permission denied")
            throw PeekabooError.permissionDeniedScreenRecording
        }
    }

    /// Require Accessibility permission, throwing if not granted
    public func requireAccessibilityPermission() throws {
        // Require Accessibility permission, throwing if not granted
        self.logger.debug("Requiring accessibility permission")

        if !self.checkAccessibilityPermission() {
            self.logger.error("Accessibility permission denied")
            throw PeekabooError.permissionDeniedAccessibility
        }
    }

    /// Require AppleScript permission, throwing if not granted
    public func requireAppleScriptPermission() throws {
        // Require AppleScript permission, throwing if not granted
        self.logger.debug("Requiring AppleScript permission")

        if !self.checkAppleScriptPermission() {
            self.logger.error("AppleScript permission denied")
            throw PeekabooError.operationError(message: "AppleScript permission denied")
        }
    }

    /// Check all permissions and return their status
    public func checkAllPermissions() -> PermissionsStatus {
        // Check all permissions and return their status
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
        self.screenRecording && self.accessibility
    }

    public var missingPermissions: [String] {
        var missing: [String] = []
        if !self.screenRecording { missing.append("Screen Recording") }
        if !self.accessibility { missing.append("Accessibility") }
        return missing
    }

    public var missingOptionalPermissions: [String] {
        var missing: [String] = []
        if !self.appleScript { missing.append("AppleScript") }
        return missing
    }
}
