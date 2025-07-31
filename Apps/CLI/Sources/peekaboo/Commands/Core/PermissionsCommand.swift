import ArgumentParser
import Foundation
import PeekabooCore

// Permission status structures for JSON output
struct PermissionStatus: Codable {
    let screenRecording: Bool
    let accessibility: Bool

    private enum CodingKeys: String, CodingKey {
        case screenRecording = "screen_recording"
        case accessibility
    }
}

struct PermissionStatusData: Codable {
    let permissions: PermissionStatus
}

/// Standalone command for checking system permissions using PeekabooCore services.
///
/// Provides a direct way to check permissions without going through the list subcommand.
/// Testing notifications: This change should trigger a build notification.
struct PermissionsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "permissions",
        abstract: "Check system permissions required for Peekaboo",
        discussion: """
        SYNOPSIS:
          peekaboo permissions [--json-output]

        DESCRIPTION:
          Checks system permissions required for Peekaboo operations. Use this
          command to verify that necessary permissions are granted.

        PERMISSIONS:
          Screen Recording  Required for all screenshot operations
                           Grant via: System Settings > Privacy & Security > Screen Recording

          Accessibility     Optional, needed for window focus control  
                           Grant via: System Settings > Privacy & Security > Accessibility

        EXAMPLES:
          peekaboo permissions
          peekaboo permissions --json-output

          # Check specific permission
          peekaboo permissions --json-output | jq '.data.permissions.screen_recording'

          # Use in scripts
          if peekaboo permissions --json-output | jq -e '.data.permissions.screen_recording'; then
            echo "Screen recording permission granted"
          fi

        EXIT STATUS:
          0  All required permissions granted
          1  Missing required permissions
        """
    )

    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false

    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        // Get permissions using shared helper
        let permissionInfos = await PermissionHelpers.getCurrentPermissions()
        
        // Extract status for JSON output
        let screenRecording = permissionInfos.first { $0.name == "Screen Recording" }?.isGranted ?? false
        let accessibility = permissionInfos.first { $0.name == "Accessibility" }?.isGranted ?? false
        
        // Create permission status for JSON
        let permissions = PermissionStatus(
            screenRecording: screenRecording,
            accessibility: accessibility
        )

        if self.jsonOutput {
            let data = PermissionStatusData(permissions: permissions)
            outputSuccessCodable(data: data)
        } else {
            print("Peekaboo Permissions Status:")
            
            for permission in permissionInfos {
                print("  \(PermissionHelpers.formatPermissionStatus(permission))")
                
                // Only show grant instructions if permission is not granted
                if !permission.isGranted {
                    print("    Grant via: \(permission.grantInstructions)")
                }
            }
        }

        // Exit with error if required permissions are missing
        let hasAllRequired = permissionInfos.filter { $0.isRequired }.allSatisfy { $0.isGranted }
        if !hasAllRequired {
            throw ExitCode(1)
        }
    }
}
