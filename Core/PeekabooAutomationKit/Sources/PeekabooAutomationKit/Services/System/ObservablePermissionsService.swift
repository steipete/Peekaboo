import Foundation
import Observation
import os.log

@MainActor
public protocol ObservablePermissionsServiceProtocol {
    var screenRecordingStatus: ObservablePermissionsService.PermissionState { get }
    var accessibilityStatus: ObservablePermissionsService.PermissionState { get }
    var appleScriptStatus: ObservablePermissionsService.PermissionState { get }
    var hasAllPermissions: Bool { get }
    /// Refresh the cached permission states by querying the underlying services.
    func checkPermissions()
    /// Trigger the screen recording permission prompt if needed.
    func requestScreenRecording() throws
    /// Trigger the accessibility permission prompt if needed.
    func requestAccessibility() throws
    /// Trigger the AppleScript permission prompt if needed.
    func requestAppleScript() throws
    /// Begin periodic permission polling with the given interval.
    func startMonitoring(interval: TimeInterval)
    /// Stop any in-flight monitoring timers.
    func stopMonitoring()
}

/// Observable wrapper for PermissionsService that provides UI-friendly state management
@available(macOS 14.0, *)
@Observable
@MainActor
public final class ObservablePermissionsService: ObservablePermissionsServiceProtocol {
    // MARK: - Properties

    /// Core permissions service
    private let core: PermissionsService

    /// Current permission status
    public private(set) var status: PermissionsStatus

    /// Individual permission states for UI binding
    public private(set) var screenRecordingStatus: PermissionState = .notDetermined
    public private(set) var accessibilityStatus: PermissionState = .notDetermined
    public private(set) var appleScriptStatus: PermissionState = .notDetermined

    /// Timer for monitoring permission changes
    private var monitorTimer: Timer?

    /// Whether monitoring is active
    public private(set) var isMonitoring = false

    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "ObservablePermissions")

    // MARK: - Permission State

    public enum PermissionState: String, Sendable {
        case notDetermined
        case denied
        case authorized

        public var displayName: String {
            switch self {
            case .notDetermined: "Not Determined"
            case .denied: "Denied"
            case .authorized: "Authorized"
            }
        }
    }

    // MARK: - Initialization

    @MainActor
    public init(core: PermissionsService = PermissionsService()) {
        self.core = core
        self.status = core.checkAllPermissions()
        self.updatePermissionStates()
    }

    // MARK: - Public Methods

    /// Check all permissions and update state
    public func checkPermissions() {
        // Check all permissions and update state
        self.logger.debug("Checking all permissions")
        self.status = self.core.checkAllPermissions()
        self.updatePermissionStates()
    }

    /// Start monitoring permission changes
    public func startMonitoring(interval: TimeInterval = 1.0) {
        // Start monitoring permission changes
        guard !self.isMonitoring else { return }

        self.logger.info("Starting permission monitoring")
        self.isMonitoring = true

        // Initial check
        self.checkPermissions()

        // Set up timer
        self.monitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPermissions()
            }
        }
    }

    /// Stop monitoring permission changes
    public func stopMonitoring() {
        // Stop monitoring permission changes
        guard self.isMonitoring else { return }

        self.logger.info("Stopping permission monitoring")
        self.isMonitoring = false
        self.monitorTimer?.invalidate()
        self.monitorTimer = nil
    }

    /// Request screen recording permission
    public func requestScreenRecording() throws {
        // Request screen recording permission
        try self.core.requireScreenRecordingPermission()
    }

    /// Request accessibility permission
    public func requestAccessibility() throws {
        // Request accessibility permission
        try self.core.requireAccessibilityPermission()
    }

    /// Request AppleScript permission
    public func requestAppleScript() throws {
        // Request AppleScript permission
        try self.core.requireAppleScriptPermission()
    }

    /// Check if all permissions are granted
    public var hasAllPermissions: Bool {
        self.status.allGranted
    }

    /// Get list of missing permissions
    public var missingPermissions: [String] {
        self.status.missingPermissions
    }

    // MARK: - Private Methods

    private func updatePermissionStates() {
        self.screenRecordingStatus = self.status.screenRecording ? .authorized : .denied
        self.accessibilityStatus = self.status.accessibility ? .authorized : .denied
        self.appleScriptStatus = self.status.appleScript ? .authorized : .denied
    }

    deinit {
        // Can't call MainActor methods from deinit
        // Timer will be cleaned up automatically
    }
}

// MARK: - Convenience Extensions

extension ObservablePermissionsService {
    /// Permission display information
    public struct PermissionInfo {
        public let type: PermissionType
        public let status: PermissionState
        public let displayName: String
        public let explanation: String
        public let settingsURL: URL?

        public enum PermissionType: String, CaseIterable {
            case screenRecording
            case accessibility
            case appleScript

            public var displayName: String {
                switch self {
                case .screenRecording: "Screen Recording"
                case .accessibility: "Accessibility"
                case .appleScript: "AppleScript"
                }
            }

            public var explanation: String {
                switch self {
                case .screenRecording:
                    "Required to capture screenshots and analyze screen content"
                case .accessibility:
                    "Required to interact with UI elements and send input events"
                case .appleScript:
                    "Required to control applications and automate system tasks"
                }
            }

            public var settingsURLString: String {
                switch self {
                case .screenRecording:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                case .accessibility:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                case .appleScript:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
                }
            }
        }
    }

    /// Get all permission information for UI display
    public var allPermissions: [PermissionInfo] {
        [
            PermissionInfo(
                type: .screenRecording,
                status: self.screenRecordingStatus,
                displayName: PermissionInfo.PermissionType.screenRecording.displayName,
                explanation: PermissionInfo.PermissionType.screenRecording.explanation,
                settingsURL: URL(string: PermissionInfo.PermissionType.screenRecording.settingsURLString)),
            PermissionInfo(
                type: .accessibility,
                status: self.accessibilityStatus,
                displayName: PermissionInfo.PermissionType.accessibility.displayName,
                explanation: PermissionInfo.PermissionType.accessibility.explanation,
                settingsURL: URL(string: PermissionInfo.PermissionType.accessibility.settingsURLString)),
            PermissionInfo(
                type: .appleScript,
                status: self.appleScriptStatus,
                displayName: PermissionInfo.PermissionType.appleScript.displayName,
                explanation: PermissionInfo.PermissionType.appleScript.explanation,
                settingsURL: URL(string: PermissionInfo.PermissionType.appleScript.settingsURLString)),
        ]
    }
}
