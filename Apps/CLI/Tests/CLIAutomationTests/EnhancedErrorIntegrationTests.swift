import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite(
    "Enhanced Error Integration Tests",
    .serialized,
    .tags(.automation),
    .enabled(if: CLITestEnvironment.runAutomationActions)
)
struct EnhancedErrorIntegrationTests {
    // These tests run against the actual services to verify error messages
    // They are marked with a condition to only run when explicitly enabled

    @Test(
        "Shell command errors show detailed output",
        .enabled(if: ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] != nil)
    )
    func actualShellErrors() async throws {
        let services = await MainActor.run { PeekabooServices() }
        guard let agent = services.agent else {
            Issue.record("Agent service not available - set OPENAI_API_KEY")
            return
        }

        // Test non-existent command
        let delegate = TestEventDelegate()
        _ = try await agent.executeTask(
            "Run shell command 'nonexistentcommand123 --help'",
            maxSteps: 10,
            dryRun: false,
            queueMode: .oneAtATime,
            eventDelegate: delegate
        )

        // Check that error was displayed with details
        let events = delegate.getEvents()
        let errorEvent = events.first { event in
            if case let .toolCallCompleted(name, result) = event,
               name == "shell" {
                return result.contains("exit code") || result.contains("Exit code")
            }
            return false
        }

        #expect(errorEvent != nil, "Should have shell error event with exit code")
    }

    @Test(
        "App launch with typo shows suggestions",
        .enabled(if: ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] != nil)
    )
    func actualAppLaunchSuggestions() async throws {
        let services = await MainActor.run { PeekabooServices() }
        guard let agent = services.agent else {
            Issue.record("Agent service not available")
            return
        }

        let delegate = TestEventDelegate()
        _ = try await agent.executeTask(
            "Launch app 'Safary'", // Typo
            maxSteps: 10,
            dryRun: false,
            queueMode: .oneAtATime,
            eventDelegate: delegate
        )

        let events = delegate.getEvents()
        let errorEvent = events.first { event in
            if case let .toolCallCompleted(name, result) = event,
               name == "launch_app" {
                return result.contains("Did you mean") || result.contains("Safari")
            }
            return false
        }

        #expect(errorEvent != nil, "Should suggest Safari for Safary typo")
    }

    @Test(
        "Click without snapshot shows helpful message",
        .enabled(if: ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] != nil)
    )
    func actualClickWithoutSnapshot() async throws {
        let services = await MainActor.run { PeekabooServices() }
        guard let agent = services.agent else {
            Issue.record("Agent service not available")
            return
        }

        let delegate = TestEventDelegate()
        _ = try await agent.executeTask(
            "Click on 'NonExistentButton123'",
            maxSteps: 10,
            dryRun: false,
            queueMode: .oneAtATime,
            eventDelegate: delegate
        )

        let events = delegate.getEvents()
        let hasSeeSuggestion = events.contains { event in
            if case let .toolCallCompleted(_, result) = event {
                return result.contains("Use 'see' tool first") ||
                    result.contains("capture screen")
            }
            return false
        }

        #expect(hasSeeSuggestion, "Should suggest using see tool first")
    }

    @Test(
        "Type without focus shows available fields",
        .enabled(if: ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] != nil)
    )
    func actualTypeWithoutFocus() async throws {
        let services = await MainActor.run { PeekabooServices() }
        guard let agent = services.agent else {
            Issue.record("Agent service not available")
            return
        }

        let delegate = TestEventDelegate()
        _ = try await agent.executeTask(
            "Type 'Hello World' without clicking anywhere first",
            maxSteps: 10,
            dryRun: false,
            queueMode: .oneAtATime,
            eventDelegate: delegate
        )

        let events = delegate.getEvents()
        let hasFocusError = events.contains { event in
            if case let .toolCallCompleted(name, result) = event,
               name == "type" {
                return result.contains("No text field") ||
                    result.contains("focused") ||
                    result.contains("Click on a text field first")
            }
            return false
        }

        #expect(hasFocusError, "Should indicate no field is focused")
    }

    @Test(
        "Invalid hotkey format shows examples",
        .enabled(if: ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] != nil)
    )
    func actualInvalidHotkey() async throws {
        let services = await MainActor.run { PeekabooServices() }
        guard let agent = services.agent else {
            Issue.record("Agent service not available")
            return
        }

        let delegate = TestEventDelegate()
        _ = try await agent.executeTask(
            "Press hotkey 'cmd+shift+a'", // Wrong format
            maxSteps: 10,
            dryRun: false,
            queueMode: .oneAtATime,
            eventDelegate: delegate
        )

        let events = delegate.getEvents()
        let hasFormatError = events.contains { event in
            if case let .toolCallCompleted(name, result) = event,
               name == "hotkey" {
                return result.contains("Use commas") ||
                    result.contains("cmd,shift,a") ||
                    result.contains("instead of '+'")
            }
            return false
        }

        #expect(hasFormatError, "Should suggest comma format")
    }
}

// MARK: - Test Event Delegate

// @available not needed for test helpers
@MainActor
final class TestEventDelegate: AgentEventDelegate {
    private var events: [AgentEvent] = []

    nonisolated init() {}

    func agentDidEmitEvent(_ event: AgentEvent) {
        self.events.append(event)
    }

    func getEvents() -> [AgentEvent] {
        self.events
    }

    func findToolResult(toolName: String) -> String? {
        for event in self.events {
            if case let .toolCallCompleted(name, result) = event,
               name == toolName {
                return result
            }
        }
        return nil
    }

    func hasErrorContaining(_ text: String) -> Bool {
        self.events.contains { event in
            if case let .toolCallCompleted(_, result) = event {
                return result.contains(text)
            }
            if case let .error(message) = event {
                return message.contains(text)
            }
            return false
        }
    }
}
#endif
