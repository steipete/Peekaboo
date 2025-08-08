import Foundation
import Testing
@testable import Peekaboo
@testable import PeekabooCore

@Suite("SessionStore Tests", .tags(.services, .unit))
@MainActor
struct SessionStoreTests {
    var store: SessionStore!
    var testStorageURL: URL!

    mutating func setup() {
        // Create isolated storage for each test
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        testStorageURL = testDir.appendingPathComponent("test_sessions.json")
        store = SessionStore(storageURL: testStorageURL)
    }

    mutating func tearDown() {
        // Clean up test storage
        if let url = testStorageURL {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
    }

    @Test("Creating a new session assigns unique ID")
    mutating func testCreateSession() async {
        setup()
        defer { tearDown() }
        let session = await store.createSession(title: "Test Session", modelName: "test-model")

        #expect(!session.id.isEmpty)
        #expect(session.title == "Test Session")
        #expect(session.messages.isEmpty)
        #expect(session.startTime <= Date())
        #expect(session.summary.isEmpty)
    }

    @Test("Adding messages to session updates the session")
    mutating func testAddMessage() async {
        setup()
        defer { tearDown() }
        var session = await store.createSession(title: "Test", modelName: "test-model")
        let message = ConversationMessage(
            role: .user,
            content: "Test message")

        await store.addMessage(message, to: session)
        session = await store.sessions.first!

        // Verify the session was updated
        let sessions = await store.sessions
        #expect(sessions.count == 1)

        if let updatedSession = sessions.first {
            #expect(updatedSession.messages.count == 1)
            #expect(updatedSession.messages.first?.content == "Test message")
        }
    }

    @Test("Multiple sessions can be managed independently")
    mutating func multipleSessions() async {
        setup()
        defer { tearDown() }
        var session1 = await store.createSession(title: "Session 1", modelName: "test-model")
        let session2 = await store.createSession(title: "Session 2", modelName: "test-model")

        #expect(session1.id != session2.id)
        #expect(await store.sessions.count == 2)

        // Add message to first session
        await store.addMessage(
            ConversationMessage(role: .user, content: "Message 1"),
            to: session1)
        session1 = await store.sessions.first { $0.id == session1.id }!


        // Verify only first session has the message
        let sessions = await store.sessions
        let updatedSession1 = sessions.first { $0.id == session1.id }
        let updatedSession2 = sessions.first { $0.id == session2.id }

        #expect(updatedSession1?.messages.count == 1)
        #expect(updatedSession2?.messages.isEmpty == true)
    }

    @Test("Sessions are sorted by start time (newest first)")
    mutating func sessionSorting() async {
        setup()
        defer { tearDown() }
        // Create sessions with specific times
        let session1 = await store.createSession(title: "1", modelName: "m")
        try? await Task.sleep(for: .milliseconds(10))
        let session2 = await store.createSession(title: "2", modelName: "m")
        try? await Task.sleep(for: .milliseconds(10))
        let session3 = await store.createSession(title: "3", modelName: "m")

        let sessions = await store.sessions
        #expect(sessions.count == 3)

        // Verify order (newest first)
        #expect(sessions[0].id == session3.id)
        #expect(sessions[1].id == session2.id)
        #expect(sessions[2].id == session1.id)
    }
}

@Suite("SessionStore Persistence Tests", .tags(.services, .integration))
@MainActor
struct SessionStorePersistenceTests {
    @Test("Sessions persist across store instances")
    func sessionPersistence() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storageURL = directory.appendingPathComponent("test_sessions.json")
        
        var sessionId: String!
        let messageContent = "Test persistence message"

        // Create and populate session in first instance
        do {
            let store1 = SessionStore(storageURL: storageURL)
            let session = await store1.createSession(title: "Persistent Session", modelName: "p-model")
            sessionId = session.id

            await store1.addMessage(
                ConversationMessage(role: .user, content: messageContent),
                to: session)
            
            // Force save
            await store1.saveSessions()
            
            let sessions = await store1.sessions
            #expect(sessions.count == 1)
        }

        // Create new instance with same storage URL and verify data is loaded
        let store2 = SessionStore(storageURL: storageURL)

        let sessions = await store2.sessions
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
