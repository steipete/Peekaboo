import Foundation
import Testing
@testable import peekaboo
@testable import PeekabooCore

@Suite("Agent Resume Functionality Tests")
struct AgentResumeTests {
    // MARK: - AgentSessionManager Tests

    // TODO: The SessionManager API has changed. These tests need to be rewritten.
    /*
    @available(macOS 14.0, *) @Test("AgentSessionManager creates session correctly")
    func sessionManagerCreatesSession() async {
        let manager = SessionManager()
        let task = "Test task"

        let session = try! await manager.createSession(task: task)

        #expect(!session.id.isEmpty)

        let retrievedSession = try! await manager.getSession(id: session.id)
        #expect(retrievedSession != nil)
        #expect(retrievedSession?.summary == task)
        #expect(retrievedSession?.messages.isEmpty == true)

        // Clean up
        await manager.deleteSession(id: session.id)
    }

    @available(macOS 14.0, *) @Test("AgentSessionManager adds steps correctly")
    func sessionManagerAddsSteps() async {
        let manager = SessionManager()
        let session = try! await manager.createSession(task: "Test task")

        await manager.addMessageToSession(
            sessionId: session.id,
            message: .init(role: .user, content: "Test step")
        )

        let updatedSession = try! await manager.getSession(id: session.id)
        #expect(updatedSession?.messages.count == 1)
        #expect(updatedSession?.messages.first?.content.first?.text == "Test step")

        // Clean up
        await manager.deleteSession(id: session.id)
    }

    @available(macOS 14.0, *) @Test("AgentSessionManager retrieves recent sessions")
    func sessionManagerRetrievesRecentSessions() async {
        let manager = SessionManager()

        // Create multiple sessions
        let session1 = try! await manager.createSession(task: "Task 1")
        let session2 = try! await manager.createSession(task: "Task 2")
        let session3 = try! await manager.createSession(task: "Task 3")

        // Add some steps to make them different
        await manager.addMessageToSession(sessionId: session1.id, message: .init(role: .user, content: "Step 1"))
        await manager.addMessageToSession(sessionId: session2.id, message: .init(role: .user, content: "Step 1"))
        await manager.addMessageToSession(sessionId: session2.id, message: .init(role: .user, content: "Step 2"))

        let recentSessions = try! await manager.listSessions()
        #expect(recentSessions.count >= 3)

        // Sessions should be ordered by last activity (most recent first)
        let sessionIds = recentSessions.map(\.id)
        #expect(sessionIds.contains(session1.id))
        #expect(sessionIds.contains(session2.id))
        #expect(sessionIds.contains(session3.id))

        // Clean up
        await manager.deleteSession(id: session1.id)
        await manager.deleteSession(id: session2.id)
        await manager.deleteSession(id: session3.id)
    }

    @available(macOS 14.0, *) @Test("AgentSessionManager handles nonexistent sessions")
    func sessionManagerHandlesNonexistentSessions() async {
        let manager = SessionManager()
        let nonexistentId = "nonexistent-session-id"

        let session = try! await manager.getSession(id: nonexistentId)
        #expect(session == nil)
    }

    // MARK: - Session Persistence Tests

    @available(macOS 14.0, *) @Test("AgentSessionManager persists sessions to disk")
    func sessionManagerPersistsSessions() async {
        let manager = SessionManager()
        let session = try! await manager.createSession(task: "Persistent task")

        await manager.addMessageToSession(
            sessionId: session.id,
            message: .init(role: .user, content: "Persistent step")
        )

        // Create a new manager instance to test persistence
        let newManager = SessionManager()

        // Give it a moment to load sessions
        try! await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let retrievedSession = try! await newManager.getSession(id: session.id)
        #expect(retrievedSession != nil)
        #expect(retrievedSession?.summary == "Persistent task")
        #expect(retrievedSession?.messages.count == 1)

        // Clean up
        await manager.deleteSession(id: session.id)
    }

    // MARK: - AgentCommand Resume Logic Tests

    @available(macOS 14.0, *) @Test("AgentCommand shows recent sessions with empty resume")
    func agentCommandShowsRecentSessions() async throws {
        // Create a test session first
        let manager = SessionManager()
        let session = try! await manager.createSession(task: "Test session task")
        await manager.addMessageToSession(sessionId: session.id, message: .init(role: .user, content: "Test step"))

        // Test showing recent sessions (we can't easily test the actual command execution,
        // but we can test the data retrieval)
        let recentSessions = try! await manager.listSessions()
        #expect(recentSessions.count >= 1)

        let testSession = recentSessions.first { $0.id == session.id }
        #expect(testSession != nil)
        #expect(testSession?.summary == "Test session task")
        #expect(testSession?.messageCount == 1)

        // Clean up
        await manager.deleteSession(id: session.id)
    }

    @available(macOS 14.0, *) @Test("AgentCommand validates session resumption")
    func agentCommandValidatesSessionResumption() async {
        let manager = SessionManager()

        // Test with nonexistent session
        let nonexistentSession = try! await manager.getSession(id: "nonexistent-session")
        #expect(nonexistentSession == nil)

        // Test with valid session
        let session = try! await manager.createSession(task: "Valid session")
        let validSession = try! await manager.getSession(id: session.id)
        #expect(validSession != nil)
        #expect(validSession?.id == session.id)

        // Clean up
        await manager.deleteSession(id: session.id)
    }
    */
}
