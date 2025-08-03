import ApplicationServices
import ArgumentParser
import CoreGraphics
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
        abstract: "Check and request system permissions required for Peekaboo",
        discussion: """
        SYNOPSIS:
          peekaboo permissions [check|request] [OPTIONS]

        DESCRIPTION:
          Checks and requests system permissions required for Peekaboo operations.

        PERMISSIONS:
          Screen Recording  Required for screenshots and improves window listing performance
                           Grant via: System Settings > Privacy & Security > Screen Recording

                           Benefits:
                           • Enables screen capture functionality
                           • Allows fast window enumeration via CGWindowList
                           • Provides full window metadata including names

          Accessibility     Required for UI automation (clicking, typing, etc.)
                           Grant via: System Settings > Privacy & Security > Accessibility

        EXAMPLES:
          # Check permissions (default)
          peekaboo permissions
          peekaboo permissions check
          peekaboo permissions check --json-output

          # Request specific permissions
          peekaboo permissions request screen-recording
          peekaboo permissions request accessibility
          peekaboo permissions request all

          # Use in scripts
          if peekaboo permissions check --json-output | jq -e '.data.permissions.screen_recording'; then
            echo "Screen recording permission granted"
          fi

        EXIT STATUS:
          0  All required permissions granted
          1  Missing required permissions
        """,
        subcommands: [
            CheckSubcommand.self,
            RequestSubcommand.self
        ],
        defaultSubcommand: CheckSubcommand.self
    )
}

// MARK: - Check Subcommand

struct CheckSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Check current permission status"
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

        // Check CGWindowList access (indicates full screen recording permission)
        let cgWindowListAccess = self.checkCGWindowListAccess()

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
            print("")

            // Show screen recording with performance info
            if let screenRecordingInfo = permissionInfos.first(where: { $0.name == "Screen Recording" }) {
                print("  \(PermissionHelpers.formatPermissionStatus(screenRecordingInfo))")
                if screenRecordingInfo.isGranted && cgWindowListAccess {
                    print("    ✅ Full CGWindowList access confirmed (optimal performance)")
                } else if screenRecordingInfo.isGranted && !cgWindowListAccess {
                    print("    ⚠️  Limited access - window names may not be visible")
                }
                if !screenRecordingInfo.isGranted {
                    print("    Grant via: \(screenRecordingInfo.grantInstructions)")
                    print("    → To trigger prompt: peekaboo permissions request screen-recording")
                }
            }

            // Show accessibility
            if let accessibilityInfo = permissionInfos.first(where: { $0.name == "Accessibility" }) {
                print("")
                print("  \(PermissionHelpers.formatPermissionStatus(accessibilityInfo))")
                if !accessibilityInfo.isGranted {
                    print("    Grant via: \(accessibilityInfo.grantInstructions)")
                    print("    → To trigger prompt: peekaboo permissions request accessibility")
                }
            }

            if screenRecording && accessibility {
                print("\n✅ All permissions granted - Peekaboo is fully operational!")
            }
        }

        // Exit with error if required permissions are missing
        let hasAllRequired = permissionInfos.filter(\.isRequired).allSatisfy(\.isGranted)
        if !hasAllRequired {
            throw ExitCode(1)
        }
    }

    private func checkCGWindowListAccess() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        let ourPID = ProcessInfo.processInfo.processIdentifier

        // Check if we can see window names from other processes
        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID != ourPID,
                  let _ = window[kCGWindowName as String] as? String else {
                continue
            }
            return true
        }

        return false
    }
}

// MARK: - Request Subcommand

struct RequestSubcommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "request",
        abstract: "Request system permissions",
        discussion: """
        Request specific system permissions or all at once.

        EXAMPLES:
          peekaboo permissions request screen-recording
          peekaboo permissions request accessibility
          peekaboo permissions request all
        """
    )

    enum Permission: String, ExpressibleByArgument {
        case screenRecording = "screen-recording"
        case accessibility
        case all
    }

    @Argument(help: "Permission to request")
    var permission: Permission

    func run() async throws {
        switch self.permission {
        case .screenRecording:
            try await self.requestScreenRecording()
        case .accessibility:
            try await self.requestAccessibility()
        case .all:
            print("Requesting all permissions...\n")
            try await self.requestScreenRecording()
            print("")
            try await self.requestAccessibility()
        }
    }

    private func requestScreenRecording() async throws {
        print("Requesting Screen Recording permission...")
        print("")

        // Check current status first
        let hasPermission = await PeekabooServices.shared.screenCapture.hasScreenRecordingPermission()

        if hasPermission {
            print("✅ Screen Recording permission is already granted!")
            return
        }

        print("Triggering permission prompt...")
        print("")

        // This will trigger the permission dialog
        _ = CGWindowListCreateImage(
            CGRect(x: 0, y: 0, width: 1, height: 1),
            .optionAll,
            kCGNullWindowID,
            .nominalResolution
        )

        print("If a permission dialog appeared:")
        print("1. Click 'Open System Settings'")
        print("2. Enable Screen Recording for Peekaboo")
        print("")
        print("If no dialog appeared, grant manually in:")
        print("System Settings > Privacy & Security > Screen Recording")
    }

    private func requestAccessibility() async throws {
        print("Requesting Accessibility permission...")
        print("")

        // Check current status first
        let hasPermission = await PeekabooServices.shared.automation.hasAccessibilityPermission()

        if hasPermission {
            print("✅ Accessibility permission is already granted!")
            return
        }

        print("Opening System Settings to Accessibility permissions...")
        print("")

        // Open System Settings to the Accessibility pane
        let optionKey = "AXTrustedCheckOptionPrompt" // Use string literal to avoid concurrency issue
        let options = [optionKey: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            print("✅ Accessibility permission granted!")
        } else {
            print("A dialog should have appeared.")
            print("")
            print("To grant permission:")
            print("1. Click 'Open System Settings' in the dialog")
            print("2. Enable Peekaboo in the Accessibility list")
            print("3. You may need to restart Peekaboo after granting")
        }
    }
}
