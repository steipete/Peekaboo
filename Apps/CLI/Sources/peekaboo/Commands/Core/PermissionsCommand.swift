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
/// This is a test comment to verify Poltergeist auto-rebuild functionality.
/// Edit 2: Testing incremental rebuild detection.
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
        """)

    @Flag(name: .long, help: "Output results in JSON format for scripting")
    var jsonOutput = false

    func run() async throws {
        Logger.shared.setJsonOutputMode(self.jsonOutput)

        // Get permissions from PeekabooCore services
        let screenRecording = await PeekabooServices.shared.screenCapture.hasScreenRecordingPermission()
        let accessibility = await PeekabooServices.shared.automation.hasAccessibilityPermission()

        // Create permission status
        let permissions = PermissionStatus(
            screenRecording: screenRecording,
            accessibility: accessibility)

        if self.jsonOutput {
            let data = PermissionStatusData(permissions: permissions)
            outputSuccessCodable(data: data)
        } else {
            print("Peekaboo Permissions Status:")
            print("  Screen Recording: \(screenRecording ? "✅ Granted" : "❌ Not Granted")")
            print("  Accessibility: \(accessibility ? "✅ Granted" : "⚠️  Not Granted (Optional)")")

            if !screenRecording {
                print("\nScreen Recording permission is required for capturing screenshots.")
                print("Grant via: System Settings > Privacy & Security > Screen Recording")
            }

            if !accessibility {
                print("\nAccessibility permission is optional but needed for window focus control.")
                print("Grant via: System Settings > Privacy & Security > Accessibility")
            }
        }

        // Exit with error if required permissions are missing
        if !screenRecording {
            throw ExitCode(1)
        }
    }
}
