import Foundation

/// Protocol defining the interface for permission management across all platforms
protocol PermissionsProtocol {
    /// Check if screen capture permission is granted
    /// - Returns: True if permission is granted
    func checkScreenCapturePermission() -> Bool
    
    /// Check if window access permission is granted
    /// - Returns: True if permission is granted
    func checkWindowAccessPermission() -> Bool
    
    /// Check if application management permission is granted
    /// - Returns: True if permission is granted
    func checkApplicationManagementPermission() -> Bool
    
    /// Request screen capture permission (may show system dialog)
    /// - Returns: True if permission was granted
    func requestScreenCapturePermission() async -> Bool
    
    /// Request window access permission (may show system dialog)
    /// - Returns: True if permission was granted
    func requestWindowAccessPermission() async -> Bool
    
    /// Request application management permission (may show system dialog)
    /// - Returns: True if permission was granted
    func requestApplicationManagementPermission() async -> Bool
    
    /// Get the current permission status for all required permissions
    /// - Returns: Dictionary of permission types and their status
    func getAllPermissionStatuses() -> [PermissionType: PermissionStatus]
    
    /// Check if the platform requires explicit permissions
    /// - Returns: True if explicit permissions are required
    func requiresExplicitPermissions() -> Bool
    
    /// Get platform-specific permission instructions for the user
    /// - Returns: Array of instruction steps
    func getPermissionInstructions() -> [PermissionInstruction]
    
    /// Require screen capture permission (throws if not granted)
    func requireScreenCapturePermission() throws
    
    /// Require window access permission (throws if not granted)
    func requireWindowAccessPermission() throws
    
    /// Require application management permission (throws if not granted)
    func requireApplicationManagementPermission() throws
}

/// Types of permissions that may be required
enum PermissionType: String, CaseIterable {
    case screenCapture = "screen_capture"
    case windowAccess = "window_access"
    case applicationManagement = "application_management"
    case accessibility = "accessibility"
    case systemEvents = "system_events"
    
    var displayName: String {
        switch self {
        case .screenCapture:
            return "Screen Recording"
        case .windowAccess:
            return "Window Access"
        case .applicationManagement:
            return "Application Management"
        case .accessibility:
            return "Accessibility"
        case .systemEvents:
            return "System Events"
        }
    }
}

/// Status of a permission
enum PermissionStatus {
    case granted
    case denied
    case notDetermined
    case notRequired
    case notSupported
    
    var isGranted: Bool {
        return self == .granted || self == .notRequired
    }
}

/// Instruction for obtaining a permission
struct PermissionInstruction {
    let step: Int
    let title: String
    let description: String
    let isAutomated: Bool // Whether this step can be automated
    let platformSpecific: Bool // Whether this is platform-specific
}

/// Errors that can occur during permission operations
enum PermissionError: Error, LocalizedError {
    case screenRecordingPermissionDenied
    case accessibilityPermissionDenied
    case applicationManagementPermissionDenied
    case windowAccessPermissionDenied
    case permissionRequestFailed(PermissionType)
    case notSupported(PermissionType)
    case systemError(Error)
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .screenRecordingPermissionDenied:
            return "Screen recording permission is required but not granted"
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required but not granted"
        case .applicationManagementPermissionDenied:
            return "Application management permission is required but not granted"
        case .windowAccessPermissionDenied:
            return "Window access permission is required but not granted"
        case .permissionRequestFailed(let type):
            return "Failed to request \(type.displayName) permission"
        case .notSupported(let type):
            return "\(type.displayName) permission is not supported on this platform"
        case .systemError(let error):
            return "System error: \(error.localizedDescription)"
        case .userCancelled:
            return "Permission request was cancelled by user"
        }
    }
    
    var exitCode: Int32 {
        switch self {
        case .screenRecordingPermissionDenied, .accessibilityPermissionDenied,
             .applicationManagementPermissionDenied, .windowAccessPermissionDenied:
            return 2 // Permission error
        case .permissionRequestFailed, .notSupported:
            return 3 // Configuration error
        case .systemError:
            return 4 // System error
        case .userCancelled:
            return 5 // User cancelled
        }
    }
}

