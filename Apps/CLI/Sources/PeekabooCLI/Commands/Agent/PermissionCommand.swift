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

        private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        /// Summarize the current permission state for the agent-centric workflow.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.prepare(using: runtime)
            let status = await self.fetchPermissionStatus()
            self.render(status: status)
        }

        private mutating func prepare(using runtime: CommandRuntime) {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)
        }

        @MainActor
        private func fetchPermissionStatus() async -> AgentPermissionStatusPayload {
            let screenRecording = await self.services.screenCapture.hasScreenRecordingPermission()
            let accessibility = await AutomationServiceBridge.hasAccessibilityPermission(automation: self.services.automation)
            return AgentPermissionStatusPayload(
                screen_recording: screenRecording,
                accessibility: accessibility
            )
        }

        private func render(status: AgentPermissionStatusPayload) {
            if self.jsonOutput {
                outputSuccessCodable(data: status, logger: self.logger)
                return
            }

            print("Peekaboo Permission Status")
            print("==========================\n")
            self.printStatusLine(label: "Screen Recording", granted: status.screen_recording)
            self.printStatusLine(label: "Accessibility", granted: status.accessibility)

            guard !status.screen_recording || !status.accessibility else { return }

            print("\nTo grant missing permissions:")
            if !status.screen_recording {
                print("- Run: peekaboo agent permission request-screen-recording")
            }
            if !status.accessibility {
                print("- Run: peekaboo agent permission request-accessibility")
            }
        }

        private func printStatusLine(label: String, granted: Bool) {
            let state = granted ? "✅ Granted" : "❌ Not granted"
            print("\(label): \(state)")
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

        private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        /// Trigger the screen recording permission prompt using the best available mechanism.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.prepare(using: runtime)
            if await self.renderIfAlreadyGranted() { return }
            let result = await self.requestScreenRecordingPermission()
            self.render(result: result)
        }

        private mutating func prepare(using runtime: CommandRuntime) {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)
        }

        private func renderIfAlreadyGranted() async -> Bool {
            let hasPermission = await self.services.screenCapture.hasScreenRecordingPermission()
            guard hasPermission else { return false }
            let payload = AgentPermissionActionResult(
                action: "request-screen-recording",
                already_granted: true,
                prompt_triggered: false,
                granted: true
            )
            self.render(result: payload)
            return true
        }

        private func requestScreenRecordingPermission() async -> AgentPermissionActionResult {
            if !self.jsonOutput {
                print("Requesting Screen Recording permission...\n")
                print("Triggering permission prompt...\n")
            }

            if #available(macOS 10.15, *) {
                return self.handleModernPrompt()
            } else {
                return self.handleLegacyPrompt()
            }
        }

        private func handleModernPrompt() -> AgentPermissionActionResult {
            let granted = CGRequestScreenCaptureAccess()
            if !self.jsonOutput {
                self.printModernResult(granted: granted)
            }
            return AgentPermissionActionResult(
                action: "request-screen-recording",
                already_granted: false,
                prompt_triggered: true,
                granted: granted
            )
        }

        private func handleLegacyPrompt() -> AgentPermissionActionResult {
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
                self.printLegacyGuidance()
            }

            return AgentPermissionActionResult(
                action: "request-screen-recording",
                already_granted: false,
                prompt_triggered: true,
                granted: nil
            )
        }

        private func printModernResult(granted: Bool) {
            guard !self.jsonOutput else { return }
            if granted {
                print("✅ Screen Recording permission granted!")
                return
            }

            print("❌ Screen Recording permission denied\n")
            print("To grant manually:")
            print("1. Open System Settings")
            print("2. Go to Privacy & Security > Screen Recording")
            print("3. Enable Peekaboo")
        }

        private func printLegacyGuidance() {
            guard !self.jsonOutput else { return }
            print("")
            print("If a permission dialog appeared:")
            print("- Click 'Open System Settings'")
            print("- Enable Screen Recording for Peekaboo")
            print("")
            print("If no dialog appeared, grant manually in:")
            print("System Settings > Privacy & Security > Screen Recording")
        }

        private func render(result: AgentPermissionActionResult) {
            if self.jsonOutput {
                outputSuccessCodable(data: result, logger: self.logger)
            } else if result.already_granted {
                print("✅ Screen Recording permission is already granted!")
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

        private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        /// Prompt the user to grant accessibility permission and open the relevant System Settings pane.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.prepare(using: runtime)
            if await self.renderIfAlreadyGranted() { return }
            let granted = self.promptAccessibilityDialog()
            self.renderAccessibilityResult(granted: granted)
        }

        private mutating func prepare(using runtime: CommandRuntime) {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)
        }

        private func renderIfAlreadyGranted() async -> Bool {
            let hasPermission = await AutomationServiceBridge.hasAccessibilityPermission(automation: self.services.automation)
            guard hasPermission else { return false }
            let payload = AgentPermissionActionResult(
                action: "request-accessibility",
                already_granted: true,
                prompt_triggered: false,
                granted: true
            )
            self.renderAccessibilityResult(payload: payload)
            return true
        }

        private func promptAccessibilityDialog() -> Bool {
            if !self.jsonOutput {
                print("Requesting Accessibility permission...\n")
                print("Opening System Settings to Accessibility permissions...\n")
            }

            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }

        private func renderAccessibilityResult(granted: Bool) {
            let payload = AgentPermissionActionResult(
                action: "request-accessibility",
                already_granted: false,
                prompt_triggered: true,
                granted: granted
            )
            self.renderAccessibilityResult(payload: payload)
        }

        private func renderAccessibilityResult(payload: AgentPermissionActionResult) {
            if self.jsonOutput {
                outputSuccessCodable(data: payload, logger: self.logger)
                return
            }

            guard !payload.already_granted else {
                print("✅ Accessibility permission is already granted!")
                return
            }

            if payload.granted == true {
                print("✅ Accessibility permission granted!")
            } else {
                print("A dialog should have appeared.\n")
                print("To grant permission:")
                print("1. Click 'Open System Settings' in the dialog")
                print("2. Enable Peekaboo in the Accessibility list")
                print("3. You may need to restart Peekaboo after granting")
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
