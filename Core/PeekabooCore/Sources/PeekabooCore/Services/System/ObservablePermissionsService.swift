import Foundation
import Observation
import os.log

/// Observable wrapper for PermissionsService that provides UI-friendly state management
@available(macOS 14.0, *)
@Observable
@MainActor
public final class ObservablePermissionsService {
    // MARK: - Properties
    
    /// Core permissions service
    private let core: PermissionsService
    
    /// Current permission status
    public private(set) var status: PermissionsStatus
    
    /// Individual permission states for UI binding
    public private(set) var screenRecordingStatus: PermissionState = .notDetermined
    public private(set) var accessibilityStatus: PermissionState = .notDetermined
    
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
            case .notDetermined: return "Not Determined"
            case .denied: return "Denied"
            case .authorized: return "Authorized"
            }
        }
    }
    
    // MARK: - Initialization
    
    public init(core: PermissionsService = PermissionsService()) {
        self.core = core
        self.status = core.checkAllPermissions()
        self.updatePermissionStates()
    }
    
    // MARK: - Public Methods
    
    /// Check all permissions and update state
    public func checkPermissions() {
        logger.debug("Checking all permissions")
        status = core.checkAllPermissions()
        updatePermissionStates()
    }
    
    /// Start monitoring permission changes
    public func startMonitoring(interval: TimeInterval = 1.0) {
        guard !isMonitoring else { return }
        
        logger.info("Starting permission monitoring")
        isMonitoring = true
        
        // Initial check
        checkPermissions()
        
        // Set up timer
        monitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPermissions()
            }
        }
    }
    
    /// Stop monitoring permission changes
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        logger.info("Stopping permission monitoring")
        isMonitoring = false
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
    
    /// Request screen recording permission
    public func requestScreenRecording() throws {
        try core.requireScreenRecordingPermission()
    }
    
    /// Request accessibility permission
    public func requestAccessibility() throws {
        try core.requireAccessibilityPermission()
    }
    
    /// Check if all permissions are granted
    public var hasAllPermissions: Bool {
        status.allGranted
    }
    
    /// Get list of missing permissions
    public var missingPermissions: [String] {
        status.missingPermissions
    }
    
    // MARK: - Private Methods
    
    private func updatePermissionStates() {
        screenRecordingStatus = status.screenRecording ? .authorized : .denied
        accessibilityStatus = status.accessibility ? .authorized : .denied
    }
    
    deinit {
        // Can't call MainActor methods from deinit
        // Timer will be cleaned up automatically
    }
}

// MARK: - Convenience Extensions

public extension ObservablePermissionsService {
    /// Permission display information
    struct PermissionInfo {
        public let type: PermissionType
        public let status: PermissionState
        public let displayName: String
        public let explanation: String
        public let settingsURL: URL?
        
        public enum PermissionType: String, CaseIterable {
            case screenRecording
            case accessibility
            
            public var displayName: String {
                switch self {
                case .screenRecording: return "Screen Recording"
                case .accessibility: return "Accessibility"
                }
            }
            
            public var explanation: String {
                switch self {
                case .screenRecording:
                    return "Required to capture screenshots and analyze screen content"
                case .accessibility:
                    return "Required to interact with UI elements and send input events"
                }
            }
            
            public var settingsURLString: String {
                switch self {
                case .screenRecording:
                    return "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                case .accessibility:
                    return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                }
            }
        }
    }
    
    /// Get all permission information for UI display
    var allPermissions: [PermissionInfo] {
        [
            PermissionInfo(
                type: .screenRecording,
                status: screenRecordingStatus,
                displayName: PermissionInfo.PermissionType.screenRecording.displayName,
                explanation: PermissionInfo.PermissionType.screenRecording.explanation,
                settingsURL: URL(string: PermissionInfo.PermissionType.screenRecording.settingsURLString)
            ),
            PermissionInfo(
                type: .accessibility,
                status: accessibilityStatus,
                displayName: PermissionInfo.PermissionType.accessibility.displayName,
                explanation: PermissionInfo.PermissionType.accessibility.explanation,
                settingsURL: URL(string: PermissionInfo.PermissionType.accessibility.settingsURLString)
            )
        ]
    }
}