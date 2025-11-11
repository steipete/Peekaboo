import ApplicationServices
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Manage and request system permissions
struct PermissionCommand: ParsableCommand {
    static let commandDescription = CommandDescription(
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

extension PermissionCommand {
    // MARK: - Status Subcommand

    struct StatusSubcommand: OutputFormattable {
        nonisolated(unsafe) static var commandDescription: CommandDescription {
            MainActorCommandDescription.describe {
                CommandDescription(
                    commandName: "status",
                    abstract: "Check current permission status"
                )
            }
        }

        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: PeekabooServices { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        /// Summarize the current permission state for the agent-centric workflow.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            let screenRecording = await self.services.screenCapture.hasScreenRecordingPermission()
            let accessibility = await AutomationServiceBridge.hasAccessibilityPermission(services: self.services)

            let payload = AgentPermissionStatusPayload(
                screen_recording: screenRecording,
                accessibility: accessibility
            )

            if self.jsonOutput {
                outputSuccessCodable(data: payload, logger: self.logger)
                return
            }

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

    struct RequestScreenRecordingSubcommand: OutputFormattable {
        nonisolated(unsafe) static var commandDescription: CommandDescription {
            MainActorCommandDescription.describe {
                CommandDescription(
                    commandName: "request-screen-recording",
                    abstract: "Trigger screen recording permission prompt"
                )
            }
        }

        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: PeekabooServices { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        /// Trigger the screen recording permission prompt using the best available mechanism.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            let hasPermission = await self.services.screenCapture.hasScreenRecordingPermission()
            if hasPermission {
                if self.jsonOutput {
                    outputSuccessCodable(
                        data: AgentPermissionActionResult(
                            action: "request-screen-recording",
                            already_granted: true,
                            prompt_triggered: false,
                            granted: true
                        ),
                        logger: self.logger
                    )
                } else {
                    print("✅ Screen Recording permission is already granted!")
                }
                return
            }

            if !self.jsonOutput {
                print("Requesting Screen Recording permission...")
                print("")
                print("Triggering permission prompt...")
                print("")
            }

            var promptTriggered = false
            var grantedResult: Bool?

            if #available(macOS 10.15, *) {
                promptTriggered = true
                let granted = CGRequestScreenCaptureAccess()
                grantedResult = granted

                if !self.jsonOutput {
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
                }
            } else {
                promptTriggered = true

                if !self.jsonOutput {
                    print("Attempting screen capture to trigger permission prompt...")
                }

                _ = CGWindowListCreateImage(
                    CGRect(x: 0, y: 0, width: 1, height: 1),
                    .optionAll,
                    kCGNullWindowID,
                    .nominalResolution
                )

                if !self.jsonOutput {
                    print("")
                    print("If a permission dialog appeared:")
                    print("- Click 'Open System Settings'")
                    print("- Enable Screen Recording for Peekaboo")
                    print("")
                    print("If no dialog appeared, grant manually in:")
                    print("System Settings > Privacy & Security > Screen Recording")
                }
            }

            if self.jsonOutput {
                outputSuccessCodable(
                    data: AgentPermissionActionResult(
                        action: "request-screen-recording",
                        already_granted: false,
                        prompt_triggered: promptTriggered,
                        granted: grantedResult
                    ),
                    logger: self.logger
                )
            }
        }
    }

    // MARK: - Request Accessibility Subcommand

    struct RequestAccessibilitySubcommand: OutputFormattable {
        nonisolated(unsafe) static var commandDescription: CommandDescription {
            MainActorCommandDescription.describe {
                CommandDescription(
                    commandName: "request-accessibility",
                    abstract: "Request accessibility permission"
                )
            }
        }

        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: PeekabooServices { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        /// Prompt the user to grant accessibility permission and open the relevant System Settings pane.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            let hasPermission = await AutomationServiceBridge.hasAccessibilityPermission(services: self.services)

            if hasPermission {
                if self.jsonOutput {
                    outputSuccessCodable(
                        data: AgentPermissionActionResult(
                            action: "request-accessibility",
                            already_granted: true,
                            prompt_triggered: false,
                            granted: true
                        ),
                        logger: self.logger
                    )
                } else {
                    print("✅ Accessibility permission is already granted!")
                }
                return
            }

            if !self.jsonOutput {
                print("Requesting Accessibility permission...")
                print("")
                print("Opening System Settings to Accessibility permissions...")
                print("")
            }

            let optionKey = "AXTrustedCheckOptionPrompt"
            let options = [optionKey: true] as CFDictionary
            let trusted = AXIsProcessTrustedWithOptions(options)

            if !self.jsonOutput {
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

            if self.jsonOutput {
                outputSuccessCodable(
                    data: AgentPermissionActionResult(
                        action: "request-accessibility",
                        already_granted: false,
                        prompt_triggered: true,
                        granted: trusted
                    ),
                    logger: self.logger
                )
            }
        }
    }
}

// MARK: - Response Types

private struct AgentPermissionStatusPayload: Codable {
    let screen_recording: Bool
    let accessibility: Bool
}

private struct AgentPermissionActionResult: Codable {
    let action: String
    let already_granted: Bool
    let prompt_triggered: Bool
    let granted: Bool?
}

extension PermissionCommand.StatusSubcommand: ParsableCommand {}

extension PermissionCommand.StatusSubcommand: AsyncRuntimeCommand {}

extension PermissionCommand.RequestScreenRecordingSubcommand: ParsableCommand {}

extension PermissionCommand.RequestScreenRecordingSubcommand: AsyncRuntimeCommand {}

extension PermissionCommand.RequestAccessibilitySubcommand: ParsableCommand {}

extension PermissionCommand.RequestAccessibilitySubcommand: AsyncRuntimeCommand {}
