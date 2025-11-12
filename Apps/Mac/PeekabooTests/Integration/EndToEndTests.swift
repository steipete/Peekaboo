import Foundation
import PeekabooCore
import Testing
@testable import Peekaboo

@Suite("End-to-End Integration Tests", .tags(.integration, .slow))
@MainActor
struct EndToEndTests {
    var settings: PeekabooSettings!
    var sessionStore: SessionStore!
    var agentService: PeekabooAgentService!
    var agent: PeekabooAgent!

    mutating func setup() throws {
        self.settings = PeekabooSettings()
        self.sessionStore = SessionStore()
        self.agentService = try PeekabooAgentService(services: .shared)
        self.agent = PeekabooAgent(settings: self.settings, sessionStore: self.sessionStore)
    }

    @Test("Full agent execution flow", .enabled(if: !Test.isCI))
    mutating func fullAgentFlow() async throws {
        try self.setup()
        // This test requires a valid API key, so skip in CI
        guard !self.settings.openAIAPIKey.isEmpty else {
            Issue.record("No API key configured - skipping test")
            return
        }

        // Execute a simple task
        _ = try await self.agent.executeTask("What time is it?")

        // Verify session was created
        let sessions = await sessionStore.sessions
        #expect(sessions.count >= 1)

        if let session = sessions.first {
            #expect(!session.messages.isEmpty)
            #expect(session.messages.first?.role == .user)
        }
    }
}

@Suite("Error Recovery Tests", .tags(.unit, .fast))
@MainActor
struct ErrorRecoveryTests {
    var settings: PeekabooSettings!
    var sessionStore: SessionStore!
    var agentService: PeekabooAgentService!
    var agent: PeekabooAgent!

    mutating func setup() throws {
        self.settings = PeekabooSettings()
        self.sessionStore = SessionStore()
        self.agentService = try PeekabooAgentService(services: .shared)
        self.agent = PeekabooAgent(settings: self.settings, sessionStore: self.sessionStore)
    }

    @Test("Agent handles invalid API key gracefully")
    mutating func invalidAPIKeyHandling() async throws {
        try self.setup()
        self.settings.openAIAPIKey = "invalid-key"

        await #expect(throws: AgentError.serviceUnavailable) {
            try await agent.executeTask("Test task")
        }
    }

    @Test("Session service handles corrupt data")
    mutating func corruptDataHandling() async throws {
        try self.setup()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("sessions.json")

        // Create a session service and add a session
        let store1 = SessionStore()
        let session = await store1.createSession(title: "Test", modelName: "test")
        await store1.addMessage(
            ConversationMessage(role: .user, content: "Test"),
            to: session)

        // Verify it works normally
        #expect(await store1.sessions.count == 1)

        // Simulate corrupt data
        try "{ invalid json }".write(to: path, atomically: true, encoding: .utf8)

        // Create new instance - should handle corrupt data gracefully
        let store2 = SessionStore(storageURL: path)

        // Should have no sessions and not crash
        #expect(await store2.sessions.isEmpty)

        try? FileManager.default.removeItem(at: dir)
    }
}

@Suite("Concurrency Tests", .tags(.unit, .fast))
@MainActor
struct ConcurrencyTests {
    var settings: PeekabooSettings!
    var sessionStore: SessionStore!
    var agentService: PeekabooAgentService!
    var agent: PeekabooAgent!

    mutating func setup() throws {
        self.settings = PeekabooSettings()
        self.sessionStore = SessionStore()
        self.agentService = try PeekabooAgentService(services: .shared)
        self.agent = PeekabooAgent(settings: self.settings, sessionStore: self.sessionStore)
    }

    @Test("Multiple simultaneous agent executions")
    mutating func concurrentExecutions() async throws {
        try self.setup()
        self.settings.openAIAPIKey = "test-key"

        // Start multiple tasks concurrently
        async let result1: () = try agent.executeTask("Task 1")
        async let result2: () = try agent.executeTask("Task 2")
        async let result3: () = try agent.executeTask("Task 3")

        // Wait for all to complete
        _ = try await [result1, result2, result3]

        // All should complete
        #expect(true)
    }

    @Test("Session service thread safety")
    mutating func sessionStoreThreadSafety() async throws {
        try self.setup()
        let store = self.sessionStore!
        // Create sessions from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let session = await store.createSession(title: "Session \(i)", modelName: "test")
                    await store.addMessage(
                        ConversationMessage(
                            role: .user,
                            content: "Message \(i)"),
                        to: session)
                }
            }
        }

        // Should have created 10 sessions
        let sessions = await sessionStore.sessions
        #expect(sessions.count == 10)

        // Each should have one message
        for session in sessions {
            #expect(session.messages.count == 1)
        }
    }
}
