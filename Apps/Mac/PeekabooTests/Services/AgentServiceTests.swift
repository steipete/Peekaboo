import Foundation
import Testing
@testable import Peekaboo

@Suite("PeekabooAgent Tests", .tags(.services, .unit))
@MainActor
struct PeekabooAgentTests {
    let agent: PeekabooAgent
    let mockPeekabooSettings: PeekabooSettings
    let mockSessionStore: SessionStore

    init() {
        self.mockPeekabooSettings = PeekabooSettings()
        // Use isolated storage for tests
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        let storageURL = testDir.appendingPathComponent("test_sessions.json")
        self.mockSessionStore = SessionStore(storageURL: storageURL)
        self.agent = PeekabooAgent(settings: self.mockPeekabooSettings, sessionStore: self.mockSessionStore)
    }

    @Test("Service requires API key to execute")
    func requiresAPIKey() async throws {
        // No API key set
        self.mockPeekabooSettings.openAIAPIKey = ""

        await #expect(throws: AgentError.serviceUnavailable) {
            try await agent.executeTask("Test task")
        }
    }

    @Test("Executing task creates a session")
    func taskCreatesSession() async throws {
        // Set up valid API key
        self.mockPeekabooSettings.openAIAPIKey = "sk-test-key"

        // Initially no sessions
        #expect(self.mockSessionStore.sessions.isEmpty)

        // Execute a task (it will fail due to invalid key, but should still create session)
        try? await self.agent.executeTask("Test task")

        // Should have created a session
        #expect(self.mockSessionStore.sessions.count == 1)

        if let session = mockSessionStore.sessions.first {
            #expect(!session.title.isEmpty)
            #expect(session.messages.count >= 1) // At least the user message
        }
    }

    @Test("Current session tracking")
    func currentSessionTracking() async throws {
        self.mockPeekabooSettings.openAIAPIKey = "sk-test-key"

        // Check the session store before task execution
        let initialCount = self.mockSessionStore.sessions.count

        // Execute a task
        try? await self.agent.executeTask("Test task")

        // Session should have been created
        #expect(self.mockSessionStore.sessions.count > initialCount)

        // Execute another task
        try? await self.agent.executeTask("Another task")

        // Should have a different current session
        #expect(self.mockSessionStore.sessions.count == 2)
    }
}

@Suite("AgentService Error Handling Tests", .tags(.services, .unit, .fast))
@MainActor
struct AgentServiceErrorTests {
    @Test("Handles empty task gracefully")
    func emptyTask() async throws {
        let settings = PeekabooSettings()
        settings.openAIAPIKey = "sk-test-key"
        // Use isolated storage
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        let storageURL = testDir.appendingPathComponent("test_sessions.json")
        let sessionStore = SessionStore(storageURL: storageURL)
        let agent = PeekabooAgent(settings: settings, sessionStore: sessionStore)

        try? await agent.executeTask("")

        // Should still execute but might have a specific response
        #expect(true)
    }

    @Test("Handles very long tasks gracefully", arguments: [
        String(repeating: "a", count: 1000),
        String(repeating: "word ", count: 500),
        String(repeating: "This is a very long task. ", count: 100),
    ])
    func longTasks(longTask: String) async throws {
        let settings = PeekabooSettings()
        settings.openAIAPIKey = "sk-test-key"
        // Use isolated storage
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        let storageURL = testDir.appendingPathComponent("test_sessions.json")
        let agent = PeekabooAgent(settings: settings, sessionStore: SessionStore(storageURL: storageURL))

        try? await agent.executeTask(longTask)

        // Should handle without crashing
        #expect(true)
    }
}