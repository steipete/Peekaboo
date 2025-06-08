import Foundation

/// Protocol defining cross-platform permissions checking functionality
protocol PermissionsProtocol: Sendable {
    /// Checks if screen recording permission is granted
    /// - Returns: True if permission is granted
    func hasScreenRecordingPermission() async -> Bool
    
    /// Requests screen recording permission (if possible)
    /// - Returns: True if permission was granted
    func requestScreenRecordingPermission() async -> Bool
    
    /// Checks if accessibility permission is granted (for window management)
    /// - Returns: True if permission is granted
    func hasAccessibilityPermission() async -> Bool
    
    /// Requests accessibility permission (if possible)
    /// - Returns: True if permission was granted
    func requestAccessibilityPermission() async -> Bool
    
    /// Gets a user-friendly message about missing permissions
    /// - Returns: Instructions for the user to grant permissions
    func getPermissionInstructions() -> String
    
    /// Checks if permissions are available on this platform
    /// - Returns: True if permission checking is supported
    static func isSupported() -> Bool
}

/// Permission status enumeration
enum PermissionStatus: String, Sendable, Codable {
    case granted = "granted"
    case denied = "denied"
    case notDetermined = "not_determined"
    case notSupported = "not_supported"
}

