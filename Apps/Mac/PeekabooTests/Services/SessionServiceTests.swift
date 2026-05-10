import Foundation
import Testing
@testable import Peekaboo
@testable import PeekabooCore

@Suite(.tags(.services, .unit))
@MainActor
struct SessionStoreTests {
    var store: SessionStore!
    var testStorageURL: URL!

    mutating func setup() {
        // Create isolated storage for each test
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        self.testStorageURL = testDir.appendingPathComponent("test_sessions.json")
        self.store = SessionStore(storageURL: self.testStorageURL)
    }

    mutating func tearDown() {
        // Clean up test storage
        if let url = testStorageURL {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
    }

    @Test
    mutating func `Creating a new session assigns unique ID`() async {
        self.setup()
        defer { tearDown() }
        let session = store.createSession(title: "Test Session", modelName: "test-model")

        #expect(!session.id.isEmpty)
        #expect(session.title == "Test Session")
        #expect(session.messages.isEmpty)
        #expect(session.startTime <= Date())
        #expect(session.summary.isEmpty)
    }

    @Test
    mutating func `Adding messages to session updates the session`() async throws {
        self.setup()
        defer { tearDown() }
        var session = store.createSession(title: "Test", modelName: "test-model")
        let message = ConversationMessage(
            role: .user,
            content: "Test message")

        store.addMessage(message, to: session)
        session = try #require(self.store.sessions.first)

        // Verify the session was updated
        let sessions = store.sessions
        #expect(sessions.count == 1)

        if let updatedSession = sessions.first {
            #expect(updatedSession.messages.count == 1)
            #expect(updatedSession.messages.first?.content == "Test message")
        }
    }

    @Test
    mutating func `Multiple sessions can be managed independently`() async throws {
        self.setup()
        defer { tearDown() }
        var session1 = store.createSession(title: "Session 1", modelName: "test-model")
        let session2 = store.createSession(title: "Session 2", modelName: "test-model")

        #expect(session1.id != session2.id)
        #expect(self.store.sessions.count == 2)

        // Add message to first session
        self.store.addMessage(
            ConversationMessage(role: .user, content: "Message 1"),
            to: session1)
        session1 = try #require(self.store.sessions.first { $0.id == session1.id })

        // Verify only first session has the message
        let sessions = store.sessions
        let updatedSession1 = sessions.first { $0.id == session1.id }
        let updatedSession2 = sessions.first { $0.id == session2.id }

        #expect(updatedSession1?.messages.count == 1)
        #expect(updatedSession2?.messages.isEmpty == true)
    }

    @Test
    mutating func `Sessions are sorted by start time (newest first)`() async {
        self.setup()
        defer { tearDown() }
        // Create sessions with specific times
        let session1 = store.createSession(title: "1", modelName: "m")
        try? await Task.sleep(for: .milliseconds(10))
        let session2 = store.createSession(title: "2", modelName: "m")
        try? await Task.sleep(for: .milliseconds(10))
        let session3 = store.createSession(title: "3", modelName: "m")

        let sessions = store.sessions
        #expect(sessions.count == 3)

        // Verify order (newest first)
        #expect(sessions[0].id == session3.id)
        #expect(sessions[1].id == session2.id)
        #expect(sessions[2].id == session1.id)
    }
}

@Suite(.tags(.services, .integration))
@MainActor
struct SessionStorePersistenceTests {
    @Test
    func `Sessions persist across store instances`() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storageURL = directory.appendingPathComponent("test_sessions.json")

        var sessionId: String!
        let messageContent = "Test persistence message"

        // Create and populate session in first instance
        do {
            let store1 = SessionStore(storageURL: storageURL)
            let session = store1.createSession(title: "Persistent Session", modelName: "p-model")
            sessionId = session.id

            store1.addMessage(
                ConversationMessage(role: .user, content: messageContent),
                to: session)

            // Force save
            store1.saveSessions()

            let sessions = store1.sessions
            #expect(sessions.count == 1)
        }

        // Create new instance with same storage URL and verify data is loaded
        let store2 = SessionStore(storageURL: storageURL)

        let sessions = store2.sessions
        #expect(sessions.count == 1)

        if let loadedSession = sessions.first {
            #expect(loadedSession.id == sessionId)
            #expect(loadedSession.messages.count == 1)
            #expect(loadedSession.messages.first?.content == messageContent)
        }

        // Clean up
        try? FileManager.default.removeItem(at: directory)
    }
}
