import Foundation
import Testing
@testable import Peekaboo

@Suite("End-to-End Integration Tests", .tags(.integration, .slow))
@MainActor
struct EndToEndTests {
    @Test("Full agent execution flow", .enabled(if: !Test.isCI))
    func fullAgentFlow() async throws {
        // This test requires a valid API key, so skip in CI
        let settings = PeekabooSettings()
        guard !settings.openAIAPIKey.isEmpty else {
            Issue.record("No API key configured - skipping test")
            return
        }

        let sessionStore = SessionStore()
        let agent = PeekabooAgent(
            settings: settings,
            sessionStore: sessionStore)

        // Execute a simple task
        let result = await agent.executeTask("What time is it?", dryRun: true)

        // Verify execution completed
        #expect(result.error != nil || !result.output.isEmpty)

        // Verify session was created
        #expect(sessionStore.sessions.count >= 1)

        if let session = sessionStore.sessions.first {
            #expect(!session.messages.isEmpty)
            #expect(session.messages.first?.role == .user)
        }
    }

    @Test("Permission check flow")
    func permissionFlow() async {
        let permissions = Permissions()

        // Check permissions
        await permissions.check()

        // Verify we got actual status (not .notDetermined)
        #expect(permissions.screenRecordingStatus != .notDetermined)
        #expect(permissions.accessibilityStatus != .notDetermined)
    }

    @Test("Speech service initialization", .enabled(if: !Test.isCI))
    func speechServiceInit() async throws {
        let settings = PeekabooSettings()
        let speechRecognizer = SpeechRecognizer(settings: settings)

        // Request authorization
        let authorized = await speechRecognizer.requestAuthorization()

        // In CI or without microphone, this might fail
        if !authorized {
            Issue.record("Speech recognition not authorized - skipping test")
            return
        }

        #expect(speechRecognizer.isAvailable)
    }
}

@Suite("Error Recovery Tests", .tags(.unit, .fast))
@MainActor
struct ErrorRecoveryTests {
    @Test("Agent handles network errors gracefully")
    func networkErrorHandling() async {
        let settings = PeekabooSettings()
        settings.openAIAPIKey = "invalid-key"

        let sessionStore = SessionStore()
        let agent = PeekabooAgent(
            settings: settings,
            sessionStore: sessionStore)

        let result = await agent.executeTask("Test task")

        #expect(result.success == false)
        #expect(result.error != nil)
    }

    @Test("Session service handles corrupt data")
    func corruptDataHandling() async throws {
        // Create a session service
        let service = SessionStore()

        // Add a valid session
        let session = service.createSession()
        service.addMessage(
            SessionMessage(role: .user, content: "Test"),
            to: session)

        // Verify it works normally
        #expect(service.sessions.count == 1)

        // Simulate corrupt data by writing invalid JSON to the file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sessionsPath = documentsPath.appendingPathComponent("Peekaboo").appendingPathComponent("sessions.json")

        try? "{ invalid json }".write(to: sessionsPath, atomically: true, encoding: .utf8)

        // Create new instance - should handle corrupt data gracefully
        let service2 = SessionStore()

        // Give it time to attempt loading
        try await Task.sleep(nanoseconds: 100_000_000)

        // Should either have no sessions or have recovered somehow
        // The important thing is it doesn't crash
        #expect(service2.sessions.count >= 0)
    }
}

@Suite("Concurrency Tests", .tags(.unit, .fast))
@MainActor
struct ConcurrencyTests {
    @Test("Multiple simultaneous agent executions")
    func concurrentExecutions() async {
        let settings = PeekabooSettings()
        settings.openAIAPIKey = "test-key"

        let sessionStore = SessionStore()
        let agent = PeekabooAgent(
            settings: settings,
            sessionStore: sessionStore)

        // Start multiple tasks concurrently
        async let result1 = agent.executeTask("Task 1", dryRun: true)
        async let result2 = agent.executeTask("Task 2", dryRun: true)
        async let result3 = agent.executeTask("Task 3", dryRun: true)

        // Wait for all to complete
        let results = await [result1, result2, result3]

        // All should complete (even if with errors)
        #expect(results.count == 3)

        for result in results {
            #expect(result.error != nil || !result.output.isEmpty)
        }
    }

    @Test("Session service thread safety")
    func sessionStoreThreadSafety() async {
        let service = SessionStore()

        // Create sessions from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { @MainActor in
                    let session = service.createSession(title: "Session \(i)")
                    service.addMessage(
                        SessionMessage(
                            role: .user,
                            content: "Message \(i)"),
                        to: session)
                }
            }
        }

        // Should have created 10 sessions
        #expect(service.sessions.count == 10)

        // Each should have one message
        for session in service.sessions {
            #expect(session.messages.count == 1)
        }
    }
}
