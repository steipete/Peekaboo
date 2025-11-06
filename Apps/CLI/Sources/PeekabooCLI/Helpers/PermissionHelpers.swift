import Foundation
import PeekabooCore

/// Shared permission checking and formatting utilities
enum PermissionHelpers {
    struct PermissionInfo {
        let name: String
        let isRequired: Bool
        let isGranted: Bool
        let grantInstructions: String
    }

    /// Get current permission status for all Peekaboo permissions
    static func getCurrentPermissions() async -> [PermissionInfo] {
        // Get current permission status for all Peekaboo permissions
        let screenRecording = await PeekabooServices.shared.screenCapture.hasScreenRecordingPermission()
        let accessibility = await PeekabooServices.shared.automation.hasAccessibilityPermission()

        return [
            PermissionInfo(
                name: "Screen Recording",
                isRequired: true,
                isGranted: screenRecording,
                grantInstructions: "System Settings > Privacy & Security > Screen Recording"
            ),
            PermissionInfo(
                name: "Accessibility",
                isRequired: false,
                isGranted: accessibility,
                grantInstructions: "System Settings > Privacy & Security > Accessibility"
            )
        ]
    }

    /// Format permission status for display
    static func formatPermissionStatus(_ permission: PermissionInfo) -> String {
        // Format permission status for display
        let status = permission.isGranted ? "Granted" : "Not Granted"
        let requirement = permission.isRequired ? "Required" : "Optional"
        return "\(permission.name) (\(requirement)): \(status)"
    }

    /// Format permissions for help display with dynamic status
    static func formatPermissionsForHelp() async -> String {
        // Format permissions for help display with dynamic status
        let permissions = await getCurrentPermissions()
        var output = ["PERMISSIONS:"]

        for permission in permissions {
            output.append("  \(self.formatPermissionStatus(permission))")

            // Only show grant instructions if permission is not granted
            if !permission.isGranted {
                output.append("    Grant via: \(permission.grantInstructions)")
            }
        }

        output.append("")
        output.append("Check detailed permission status:")
        output.append("  peekaboo permissions")

        return output.joined(separator: "\n")
    }
}
