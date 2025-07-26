import Foundation

// Test-specific protocol for permissions checking
public protocol PermissionsServiceProtocol: Sendable {
    func hasScreenRecordingPermission() async -> Bool
    func hasAccessibilityPermission() async -> Bool
    func requestScreenRecordingPermission() async -> Bool
    func requestAccessibilityPermission() async -> Bool
}