import Foundation
import Testing
@testable import Peekaboo

@Suite("SessionStore Tests", .tags(.services, .unit))
struct SessionStoreTests {
    let store: SessionStore

    init() {
        self.store = SessionStore()
    }

    @Test("Creating a new session assigns unique ID")
    func testCreateSession() {
        let session = self.store.createSession(title: "")

        #expect(!session.id.isEmpty)
        #expect(session.title == "New Session")
        #expect(session.messages.isEmpty)
        #expect(session.startTime <= Date())
        #expect(session.summary.isEmpty)
    }

    @Test("Adding messages to session updates the session")
    func testAddMessage() {
        let session = self.store.createSession(title: "")
        let message = SessionMessage(
            role: .user,
            content: "Test message")

        self.store.addMessage(message, to: session)

        // Verify the session was updated
        let sessions = self.store.sessions
        #expect(sessions.count == 1)

        if let updatedSession = sessions.first {
            #expect(updatedSession.messages.count == 1)
            #expect(updatedSession.messages.first?.content == "Test message")
        }
    }

    @Test("Multiple sessions can be managed independently")
    func multipleSessions() {
        let session1 = self.store.createSession(title: "")
        let session2 = self.store.createSession(title: "")

        #expect(session1.id != session2.id)
        #expect(self.store.sessions.count == 2)

        // Add message to first session
        self.store.addMessage(
            SessionMessage(role: .user, content: "Message 1"),
            to: session1)

        // Verify only first session has the message
        let sessions = self.store.sessions
        let updatedSession1 = sessions.first { $0.id == session1.id }
        let updatedSession2 = sessions.first { $0.id == session2.id }

        #expect(updatedSession1?.messages.count == 1)
        #expect(updatedSession2?.messages.isEmpty == true)
    }

    @Test("Sessions are sorted by start time (newest first)")
    func sessionSorting() {
        // Create sessions with specific times
        let session1 = self.store.createSession(title: "")
        Thread.sleep(forTimeInterval: 0.1)
        let session2 = self.store.createSession(title: "")
        Thread.sleep(forTimeInterval: 0.1)
        let session3 = self.store.createSession(title: "")

        let sessions = self.store.sessions
        #expect(sessions.count == 3)

        // Verify order (newest first)
        #expect(sessions[0].id == session3.id)
        #expect(sessions[1].id == session2.id)
        #expect(sessions[2].id == session1.id)
    }
}

@Suite("SessionStore Persistence Tests", .tags(.services, .integration))
struct SessionStorePersistenceTests {
    @Test("Sessions persist across store instances")
    func sessionPersistence() async throws {
        let sessionId: String
        let messageContent = "Test persistence message"

        // Create and populate session in first instance
        do {
            let store1 = SessionStore()
            let session = store1.createSession()
            sessionId = session.id

            store1.addMessage(
                SessionMessage(role: .user, content: messageContent),
                to: session)

            #expect(store1.sessions.count == 1)
        }

        // Wait a bit to ensure persistence
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Create new instance and verify data is loaded
        let store2 = SessionStore()

        // Give it time to load from persistence
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        #expect(store2.sessions.count == 1)

        if let loadedSession = store2.sessions.first {
            #expect(loadedSession.id == sessionId)
            #expect(loadedSession.messages.count == 1)
            #expect(loadedSession.messages.first?.content == messageContent)
        }
    }
}
