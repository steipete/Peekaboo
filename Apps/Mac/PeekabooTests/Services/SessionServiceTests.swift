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
    mutating func `Creating a new session assigns unique ID`() {
        self.setup()
        defer { tearDown() }
        let session = self.store.createSession(title: "Test Session", modelName: "test-model")

        #expect(!session.id.isEmpty)
        #expect(session.title == "Test Session")
        #expect(session.messages.isEmpty)
        #expect(session.startTime <= Date())
        #expect(session.summary.isEmpty)
    }

    @Test
    mutating func `Adding messages to session updates the session`() throws {
        self.setup()
        defer { tearDown() }
        var session = self.store.createSession(title: "Test", modelName: "test-model")
        let message = ConversationMessage(
            role: .user,
            content: "Test message")

        self.store.addMessage(message, to: session)
        session = try #require(self.store.sessions.first)

        // Verify the session was updated
        let sessions = self.store.sessions
        #expect(sessions.count == 1)

        if let updatedSession = sessions.first {
            #expect(updatedSession.messages.count == 1)
            #expect(updatedSession.messages.first?.content == "Test message")
        }
    }

    @Test
    mutating func `Multiple sessions can be managed independently`() throws {
        self.setup()
        defer { tearDown() }
        var session1 = self.store.createSession(title: "Session 1", modelName: "test-model")
        let session2 = self.store.createSession(title: "Session 2", modelName: "test-model")

        #expect(session1.id != session2.id)
        #expect(self.store.sessions.count == 2)

        // Add message to first session
        self.store.addMessage(
            ConversationMessage(role: .user, content: "Message 1"),
            to: session1)
        session1 = try #require(self.store.sessions.first { $0.id == session1.id })

        // Verify only first session has the message
        let sessions = self.store.sessions
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
        let session1 = self.store.createSession(title: "1", modelName: "m")
        try? await Task.sleep(for: .milliseconds(10))
        let session2 = self.store.createSession(title: "2", modelName: "m")
        try? await Task.sleep(for: .milliseconds(10))
        let session3 = self.store.createSession(title: "3", modelName: "m")

        let sessions = self.store.sessions
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
    func `Sessions persist across store instances`() throws {
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

    @Test
    func `failed load keeps the unreadable session file`() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storageURL = directory.appendingPathComponent("sessions.json")
        let original = Data("{ invalid json }".utf8)
        try original.write(to: storageURL)

        let store = SessionStore(storageURL: storageURL)
        store.saveSessions()
        store.saveSessions()

        let preserved = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil)
            .filter { url in
                (try? Data(contentsOf: url)) == original
            }
        let preservedURL = try #require(preserved.first)
        #expect(preserved.count == 1)
        #expect(preservedURL.lastPathComponent != "sessions.json")
        #expect(store.sessions.isEmpty)
        let created = store.createSession(title: "Recovered", modelName: "test")
        store.saveSessions()
        let reloaded = SessionStore(storageURL: storageURL)
        #expect(reloaded.sessions.count == 1)
        #expect(reloaded.sessions.first?.id == created.id)
        #expect(reloaded.sessions.first?.title == "Recovered")
        let reread = try Data(contentsOf: preservedURL)
        #expect(reread == original)
    }

    @Test
    func `an existing session file still loads`() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storageURL = directory.appendingPathComponent("sessions.json")
        let stored = """
        [
          {
            "id" : "session_existing",
            "title" : "Existing chat",
            "messages" : [
              {
                "id" : "11111111-1111-1111-1111-111111111111",
                "role" : "user",
                "content" : "hello from before",
                "timestamp" : "2026-08-01T12:00:00Z",
                "toolCalls" : []
              }
            ],
            "startTime" : "2026-08-01T12:00:00Z",
            "summary" : "Kept",
            "modelName" : "gpt"
          }
        ]
        """
        try stored.write(to: storageURL, atomically: true, encoding: .utf8)

        let store = SessionStore(storageURL: storageURL)
        #expect(!store.sessionPersistenceBlocked)
        #expect(store.sessions.count == 1)
        #expect(store.sessions.first?.title == "Existing chat")
        #expect(store.sessions.first?.summary == "Kept")
        #expect(store.sessions.first?.messages.first?.content == "hello from before")
        store.saveSessions()

        let reloaded = SessionStore(storageURL: storageURL)
        #expect(reloaded.sessions.first?.messages.first?.content == "hello from before")
        #expect(reloaded.sessions.first?.title == "Existing chat")
    }

    @Test
    func `a blocked save retries after the sessions directory is writable`() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storageURL = directory.appendingPathComponent("sessions.json")
        let original = Data("{ invalid json }".utf8)
        try original.write(to: storageURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }

        let store = SessionStore(storageURL: storageURL)
        #expect(store.sessionPersistenceBlocked)
        #expect(store.sessionPersistenceNotice == SessionStore.sessionPersistenceBlockedNotice)
        store.saveSessions()
        #expect(try Data(contentsOf: storageURL) == original)
        #expect(store.sessions.isEmpty)

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        let created = store.createSession(title: "Recovered", modelName: "test")
        store.saveSessions()
        #expect(!store.sessionPersistenceBlocked)
        #expect(store.sessionPersistenceNotice == nil)

        let preserved = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil)
            .filter { url in
                (try? Data(contentsOf: url)) == original
            }
        let preservedURL = try #require(preserved.first)
        #expect(preservedURL.lastPathComponent != "sessions.json")

        let reloaded = SessionStore(storageURL: storageURL)
        #expect(reloaded.sessions.count == 1)
        #expect(reloaded.sessions.first?.id == created.id)
        #expect(reloaded.sessions.first?.title == "Recovered")
        #expect(!reloaded.sessionPersistenceBlocked)
        #expect(try Data(contentsOf: preservedURL) == original)
    }

    @Test
    func `retrying a failed save does not restore deleted sessions`() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storageURL = directory.appendingPathComponent("sessions.json")
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }

        let store = SessionStore(storageURL: storageURL)
        let kept = store.createSession(title: "Kept", modelName: "test")
        let deleted = store.createSession(title: "Deleted", modelName: "test")
        store.saveSessions()
        let saved = try Data(contentsOf: storageURL)
        #expect(SessionStore(storageURL: storageURL).sessions.count == 2)

        store.sessions.removeAll { $0.id == deleted.id }
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
        store.saveSessions()
        #expect(store.sessionPersistenceBlocked)
        #expect(store.sessionPersistenceNotice == SessionStore.sessionSaveFailedNotice)
        #expect(try Data(contentsOf: storageURL) == saved)
        #expect(store.sessions.map(\.id) == [kept.id])

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        store.saveSessions()
        #expect(store.sessions.map(\.id) == [kept.id])
        #expect(!store.sessionPersistenceBlocked)
        #expect(store.sessionPersistenceNotice == nil)

        let reloaded = SessionStore(storageURL: storageURL)
        #expect(reloaded.sessions.map(\.id) == [kept.id])
        #expect(!reloaded.sessionPersistenceBlocked)
        #expect(reloaded.sessionPersistenceNotice == nil)
    }

    @Test
    func `a failed atomic save stays visible until a later save finishes`() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storageURL = directory.appendingPathComponent("sessions.json")
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }

        let store = SessionStore(storageURL: storageURL)
        let session = store.createSession(title: "Kept", modelName: "test")
        store.addMessage(
            ConversationMessage(role: .user, content: "before"),
            to: session)
        store.saveSessions()
        let saved = try Data(contentsOf: storageURL)
        #expect(String(data: saved, encoding: .utf8)?.contains("before") == true)

        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
        store.addMessage(
            ConversationMessage(role: .user, content: "after"),
            to: session)
        store.saveSessions()
        #expect(store.sessionPersistenceBlocked)
        #expect(store.sessionPersistenceNotice == SessionStore.sessionSaveFailedNotice)
        let duringFailure = try Data(contentsOf: storageURL)
        #expect(duringFailure == saved)
        #expect(String(data: duringFailure, encoding: .utf8)?.contains("after") != true)

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        store.saveSessions()
        #expect(!store.sessionPersistenceBlocked)
        #expect(store.sessionPersistenceNotice == nil)

        let reloaded = SessionStore(storageURL: storageURL)
        let message = reloaded.sessions.first?.messages.map(\.content) ?? []
        #expect(message.contains("before"))
        #expect(message.contains("after"))
        #expect(!reloaded.sessionPersistenceBlocked)
    }
}
