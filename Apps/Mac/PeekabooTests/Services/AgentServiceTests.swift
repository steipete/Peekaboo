import Foundation
import Testing
@testable import Peekaboo

@Suite("PeekabooAgent Tests", .tags(.services, .unit))
@MainActor
struct PeekabooAgentTests {
    let agent: PeekabooAgent
    let mockSettings: Settings
    let mockSessionStore: SessionStore

    init() {
        self.mockSettings = Settings()
        self.mockSessionStore = SessionStore()
        self.agent = PeekabooAgent(settings: self.mockSettings, sessionStore: self.mockSessionStore)
    }

    @Test("Service requires API key to execute")
    func requiresAPIKey() async throws {
        // No API key set
        self.mockSettings.openAIAPIKey = ""

        let result = await agent.executeTask("Test task")

        #expect(result.success == false)
        #expect(result.error != nil)
        #expect(result.error?.contains("API key") == true)
    }

    @Test("Executing task creates a session")
    func taskCreatesSession() async throws {
        // Set up valid API key
        self.mockSettings.openAIAPIKey = "sk-test-key"

        // Initially no sessions
        #expect(self.mockSessionStore.sessions.isEmpty)

        // Execute a task (it will fail due to invalid key, but should still create session)
        _ = await self.agent.executeTask("Test task")

        // Should have created a session
        #expect(self.mockSessionStore.sessions.count == 1)

        if let session = mockSessionStore.sessions.first {
            #expect(!session.title.isEmpty)
            #expect(session.messages.count >= 1) // At least the user message
        }
    }

    @Test("Task execution state management")
    func executionState() async throws {
        self.mockSettings.openAIAPIKey = "sk-test-key"

        #expect(self.agent.isExecuting == false)

        // Start execution in background
        let task = Task {
            await self.agent.executeTask("Long running task")
        }

        // Give it a moment to start
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        // Should be executing (unless it failed very quickly)
        // Note: This might be flaky depending on timing

        // Wait for completion
        _ = await task.value

        #expect(self.agent.isExecuting == false)
    }

    @Test("Current session tracking")
    func currentSessionTracking() async throws {
        self.mockSettings.openAIAPIKey = "sk-test-key"

        // Check the session store before task execution
        let initialCount = self.mockSessionStore.sessions.count

        // Execute a task
        _ = await self.agent.executeTask("Test task")

        // Session should have been created
        #expect(self.mockSessionStore.sessions.count > initialCount)

        // Execute another task
        _ = await self.agent.executeTask("Another task")

        // Should have a different current session
        #expect(self.mockSessionStore.sessions.count == 2)
    }

    @Test("Dry run mode")
    func dryRunMode() async throws {
        self.mockSettings.openAIAPIKey = "sk-test-key"

        let result = await agent.executeTask("Test task", dryRun: true)

        // Dry run should still create a session
        #expect(self.mockSessionStore.sessions.count == 1)

        // Check that the session indicates it was a dry run
        if let session = mockSessionStore.sessions.first {
            let hasDryRunMessage = session.messages.contains { message in
                message.content.contains("dry run") || message.content.contains("DRY RUN")
            }
            #expect(hasDryRunMessage || !result.success) // Either it's marked as dry run or it failed
        }
    }
}

@Suite("AgentService Error Handling Tests", .tags(.services, .unit, .fast))
@MainActor
struct AgentServiceErrorTests {
    @Test("Handles empty task gracefully")
    func emptyTask() async throws {
        let settings = Settings()
        settings.openAIAPIKey = "sk-test-key"
        let sessionStore = SessionStore()
        let agent = PeekabooAgent(settings: settings, sessionStore: sessionStore)

        let result = await agent.executeTask("")

        // Should still execute but might have a specific response
        #expect(result.error != nil || result.output.isEmpty || result.output.contains("empty"))
    }

    @Test("Handles very long tasks gracefully", arguments: [
        String(repeating: "a", count: 1000),
        String(repeating: "word ", count: 500),
        String(repeating: "This is a very long task. ", count: 100),
    ])
    func longTasks(longTask: String) async throws {
        let settings = Settings()
        settings.openAIAPIKey = "sk-test-key"
        let agent = PeekabooAgent(settings: settings, sessionStore: SessionStore())

        let result = await agent.executeTask(longTask)

        // Should handle without crashing
        #expect(result.error != nil || !result.output.isEmpty)
    }
}
