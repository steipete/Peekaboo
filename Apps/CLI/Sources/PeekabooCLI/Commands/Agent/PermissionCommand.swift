import ApplicationServices
@preconcurrency import ArgumentParser
import CoreGraphics
import Foundation
import PeekabooCore

/// Manage and request system permissions
@MainActor
struct PermissionCommand: @MainActor MainActorAsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "permission",
        abstract: "Manage system permissions for Peekaboo",
        discussion: """
        Request and check system permissions required by Peekaboo.

        EXAMPLES:
          # Check current permission status
          peekaboo agent permission status

          # Request screen recording permission
          peekaboo agent permission request-screen-recording

          # Request accessibility permission
          peekaboo agent permission request-accessibility
        """,
        subcommands: [
            StatusSubcommand.self,
            RequestScreenRecordingSubcommand.self,
            RequestAccessibilitySubcommand.self
        ],
        defaultSubcommand: StatusSubcommand.self
    )
}

// MARK: - Status Subcommand

@MainActor
struct StatusSubcommand: @MainActor MainActorAsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Check current permission status"
    )

    /// Summarize the current permission state for the agent-centric workflow.
    func run() async throws {
        // Reuse the existing permissions check logic
        let screenRecording = await PeekabooServices.shared.screenCapture.hasScreenRecordingPermission()
        let accessibility = await PeekabooServices.shared.automation.hasAccessibilityPermission()

        print("Peekaboo Permission Status")
        print("==========================")
        print("")
        print("Screen Recording: \(screenRecording ? "✅ Granted" : "❌ Not granted")")
        print("Accessibility:    \(accessibility ? "✅ Granted" : "❌ Not granted")")

        if !screenRecording || !accessibility {
            print("\nTo grant missing permissions:")
            if !screenRecording {
                print("- Run: peekaboo agent permission request-screen-recording")
            }
            if !accessibility {
                print("- Run: peekaboo agent permission request-accessibility")
            }
        }
    }
}

// MARK: - Request Screen Recording Subcommand

@MainActor
struct RequestScreenRecordingSubcommand: @MainActor MainActorAsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "request-screen-recording",
        abstract: "Trigger screen recording permission prompt"
    )

    /// Trigger the screen recording permission prompt using the best available mechanism.
    func run() async throws {
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

        // Method 1: Try CGRequestScreenCaptureAccess if available (macOS 10.15+)
        if #available(macOS 10.15, *) {
            let granted = CGRequestScreenCaptureAccess()
            if granted {
                print("✅ Screen Recording permission granted!")
            } else {
                print("❌ Screen Recording permission denied")
                print("")
                print("To grant manually:")
                print("1. Open System Settings")
                print("2. Go to Privacy & Security > Screen Recording")
                print("3. Enable Peekaboo")
            }
        } else {
            // Fallback: Trigger by attempting to capture
            print("Attempting screen capture to trigger permission prompt...")

            // This will trigger the permission dialog
            _ = CGWindowListCreateImage(
                CGRect(x: 0, y: 0, width: 1, height: 1),
                .optionAll,
                kCGNullWindowID,
                .nominalResolution
            )

            print("")
            print("If a permission dialog appeared:")
            print("- Click 'Open System Settings'")
            print("- Enable Screen Recording for Peekaboo")
            print("")
            print("If no dialog appeared, grant manually in:")
            print("System Settings > Privacy & Security > Screen Recording")
        }
    }
}

// MARK: - Request Accessibility Subcommand

@MainActor
struct RequestAccessibilitySubcommand: @MainActor MainActorAsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "request-accessibility",
        abstract: "Request accessibility permission"
    )

    /// Prompt the user to grant accessibility permission and open the relevant System Settings pane.
    func run() async throws {
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