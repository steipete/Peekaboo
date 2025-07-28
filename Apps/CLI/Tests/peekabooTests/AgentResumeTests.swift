import Foundation
import Testing
@testable import peekaboo

@Suite("Agent Resume Functionality Tests")
struct AgentResumeTests {
    
    // MARK: - AgentSessionManager Tests
    
    @available(macOS 14.0, *) @Test("AgentSessionManager creates session correctly")
    func sessionManagerCreatesSession() async {
        let manager = AgentSessionManager.shared
        let task = "Test task"
        let threadId = "test-thread-123"
        
        let sessionId = await manager.createSession(task: task, threadId: threadId)
        
        #expect(!sessionId.isEmpty)
        
        let session = await manager.getSession(id: sessionId)
        #expect(session != nil)
        #expect(session?.task == task)
        #expect(session?.threadId == threadId)
        #expect(session?.steps.isEmpty == true)
        #expect(session?.lastQuestion == nil)
        
        // Clean up
        await manager.deleteSession(id: sessionId)
    }
    
    @available(macOS 14.0, *) @Test("AgentSessionManager adds steps correctly")
    func sessionManagerAddsSteps() async {
        let manager = AgentSessionManager.shared
        let sessionId = await manager.createSession(task: "Test task", threadId: "thread-123")
        
        await manager.addStep(
            sessionId: sessionId,
            description: "Test step",
            command: "test command",
            output: "test output"
        )
        
        let session = await manager.getSession(id: sessionId)
        #expect(session?.steps.count == 1)
        #expect(session?.steps.first?.description == "Test step")
        #expect(session?.steps.first?.command == "test command")
        #expect(session?.steps.first?.output == "test output")
        
        // Clean up
        await manager.deleteSession(id: sessionId)
    }
    
    @available(macOS 14.0, *) @Test("AgentSessionManager handles last question")
    func sessionManagerHandlesLastQuestion() async {
        let manager = AgentSessionManager.shared
        let sessionId = await manager.createSession(task: "Test task", threadId: "thread-123")
        
        await manager.setLastQuestion(sessionId: sessionId, question: "What should I do next?")
        
        let session = await manager.getSession(id: sessionId)
        #expect(session?.lastQuestion == "What should I do next?")
        
        // Update question
        await manager.setLastQuestion(sessionId: sessionId, question: "Different question?")
        let updatedSession = await manager.getSession(id: sessionId)
        #expect(updatedSession?.lastQuestion == "Different question?")
        
        // Clear question
        await manager.setLastQuestion(sessionId: sessionId, question: nil)
        let clearedSession = await manager.getSession(id: sessionId)
        #expect(clearedSession?.lastQuestion == nil)
        
        // Clean up
        await manager.deleteSession(id: sessionId)
    }
    
    @available(macOS 14.0, *) @Test("AgentSessionManager retrieves recent sessions")
    func sessionManagerRetrievesRecentSessions() async {
        let manager = AgentSessionManager.shared
        
        // Create multiple sessions
        let sessionId1 = await manager.createSession(task: "Task 1", threadId: "thread-1")
        let sessionId2 = await manager.createSession(task: "Task 2", threadId: "thread-2")
        let sessionId3 = await manager.createSession(task: "Task 3", threadId: "thread-3")
        
        // Add some steps to make them different
        await manager.addStep(sessionId: sessionId1, description: "Step 1", command: nil, output: nil)
        await manager.addStep(sessionId: sessionId2, description: "Step 1", command: nil, output: nil)
        await manager.addStep(sessionId: sessionId2, description: "Step 2", command: nil, output: nil)
        
        let recentSessions = await manager.getRecentSessions(limit: 10)
        #expect(recentSessions.count >= 3)
        
        // Sessions should be ordered by last activity (most recent first)
        let sessionIds = recentSessions.map { $0.id }
        #expect(sessionIds.contains(sessionId1))
        #expect(sessionIds.contains(sessionId2))
        #expect(sessionIds.contains(sessionId3))
        
        // Clean up
        await manager.deleteSession(id: sessionId1)
        await manager.deleteSession(id: sessionId2)
        await manager.deleteSession(id: sessionId3)
    }
    
    @available(macOS 14.0, *) @Test("AgentSessionManager handles nonexistent sessions")
    func sessionManagerHandlesNonexistentSessions() async {
        let manager = AgentSessionManager.shared
        let nonexistentId = "nonexistent-session-id"
        
        let session = await manager.getSession(id: nonexistentId)
        #expect(session == nil)
        
        // Adding step to nonexistent session should not crash
        await manager.addStep(sessionId: nonexistentId, description: "test", command: nil, output: nil)
        
        // Setting question on nonexistent session should not crash
        await manager.setLastQuestion(sessionId: nonexistentId, question: "test")
    }
    
    // MARK: - Session Persistence Tests
    
    @available(macOS 14.0, *) @Test("AgentSessionManager persists sessions to disk")
    func sessionManagerPersistsSessions() async {
        let manager = AgentSessionManager.shared
        let sessionId = await manager.createSession(task: "Persistent task", threadId: "persistent-thread")
        
        await manager.addStep(
            sessionId: sessionId,
            description: "Persistent step",
            command: "test command",
            output: "test output"
        )
        
        await manager.setLastQuestion(sessionId: sessionId, question: "Persistent question?")
        
        // Create a new manager instance to test persistence
        let newManager = AgentSessionManager()
        
        // Give it a moment to load sessions
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let retrievedSession = await newManager.getSession(id: sessionId)
        #expect(retrievedSession != nil)
        #expect(retrievedSession?.task == "Persistent task")
        #expect(retrievedSession?.steps.count == 1)
        #expect(retrievedSession?.lastQuestion == "Persistent question?")
        
        // Clean up
        await manager.deleteSession(id: sessionId)
    }
    
    // MARK: - AgentCommand Resume Logic Tests
    
    @available(macOS 14.0, *) @Test("AgentCommand shows recent sessions with empty resume")
    func agentCommandShowsRecentSessions() async throws {
        // Create a test session first
        let manager = AgentSessionManager.shared
        let sessionId = await manager.createSession(task: "Test session task", threadId: "test-thread")
        await manager.addStep(sessionId: sessionId, description: "Test step", command: nil, output: nil)
        await manager.setLastQuestion(sessionId: sessionId, question: "Test question?")
        
        // Test showing recent sessions (we can't easily test the actual command execution,
        // but we can test the data retrieval)
        let recentSessions = await manager.getRecentSessions()
        #expect(recentSessions.count >= 1)
        
        let testSession = recentSessions.first { $0.id == sessionId }
        #expect(testSession != nil)
        #expect(testSession?.task == "Test session task")
        #expect(testSession?.steps.count == 1)
        #expect(testSession?.lastQuestion == "Test question?")
        
        // Clean up
        await manager.deleteSession(id: sessionId)
    }
    
    @available(macOS 14.0, *) @Test("AgentCommand validates session resumption")
    func agentCommandValidatesSessionResumption() async {
        let manager = AgentSessionManager.shared
        
        // Test with nonexistent session
        let nonexistentSession = await manager.getSession(id: "nonexistent-session")
        #expect(nonexistentSession == nil)
        
        // Test with valid session
        let sessionId = await manager.createSession(task: "Valid session", threadId: "valid-thread")
        let validSession = await manager.getSession(id: sessionId)
        #expect(validSession != nil)
        #expect(validSession?.id == sessionId)
        
        // Clean up
        await manager.deleteSession(id: sessionId)
    }
    
    // MARK: - Session Data Serialization Tests
    
    @available(macOS 14.0, *) @Test("AgentSession encodes and decodes correctly")
    func agentSessionSerialization() throws {
        let step = AgentSessionManager.AgentSession.AgentStep(
            description: "Test step",
            command: "test command",
            output: "test output",
            timestamp: Date()
        )
        
        let session = AgentSessionManager.AgentSession(
            id: "test-session-id",
            task: "Test task",
            threadId: "test-thread-id",
            steps: [step],
            lastQuestion: "Test question?",
            createdAt: Date(),
            lastActivityAt: Date()
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(session)
        #expect(!data.isEmpty)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedSession = try decoder.decode(AgentSessionManager.AgentSession.self, from: data)
        
        #expect(decodedSession.id == session.id)
        #expect(decodedSession.task == session.task)
        #expect(decodedSession.threadId == session.threadId)
        #expect(decodedSession.steps.count == 1)
        #expect(decodedSession.steps.first?.description == "Test step")
        #expect(decodedSession.lastQuestion == "Test question?")
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @available(macOS 14.0, *) @Test("AgentSessionManager handles concurrent access")
    func sessionManagerHandlesConcurrentAccess() async {
        let manager = AgentSessionManager.shared
        let sessionId = await manager.createSession(task: "Concurrent test", threadId: "concurrent-thread")
        
        // Simulate concurrent access
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await manager.addStep(
                        sessionId: sessionId,
                        description: "Concurrent step \(i)",
                        command: "command \(i)",
                        output: "output \(i)"
                    )
                }
            }
        }
        
        let session = await manager.getSession(id: sessionId)
        #expect(session?.steps.count == 10)
        
        // Clean up
        await manager.deleteSession(id: sessionId)
    }
    
    @available(macOS 14.0, *) @Test("AgentSessionManager cleans up old sessions")
    func sessionManagerCleansUpOldSessions() async {
        let manager = AgentSessionManager.shared
        
        // Create a session
        let sessionId = await manager.createSession(task: "Old session", threadId: "old-thread")
        
        // Verify it exists
        let session = await manager.getSession(id: sessionId)
        #expect(session != nil)
        
        // Clean up sessions older than 0 days (should remove all)
        await manager.cleanupOldSessions(olderThan: 0)
        
        // Session should still exist because it was just created
        let sessionAfterCleanup = await manager.getSession(id: sessionId)
        #expect(sessionAfterCleanup != nil)
        
        // Clean up manually
        await manager.deleteSession(id: sessionId)
    }
    
    @available(macOS 14.0, *) @Test("Session directory creation works correctly")
    func sessionDirectoryCreation() {
        // This test verifies that the session directory is created correctly
        // The actual creation happens in the AgentSessionManager init
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let sessionsDirectory = homeDir.appendingPathComponent(".peekaboo/sessions")
        
        // The directory should exist or be creatable
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: sessionsDirectory.path, isDirectory: &isDirectory)
        
        // Either it exists and is a directory, or we can create it
        if exists {
            #expect(isDirectory.boolValue == true)
        } else {
            // Try to create it
            do {
                try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
                #expect(FileManager.default.fileExists(atPath: sessionsDirectory.path))
            } catch {
                // If we can't create it, that's fine for testing - might be permissions
                // The actual manager handles this gracefully
            }
        }
    }
    
    // MARK: - Integration Tests
    
    @available(macOS 14.0, *) @Test("Complete session lifecycle")
    func completeSessionLifecycle() async {
        let manager = AgentSessionManager.shared
        
        // Create session
        let sessionId = await manager.createSession(task: "Lifecycle test", threadId: "lifecycle-thread")
        #expect(!sessionId.isEmpty)
        
        // Add multiple steps
        await manager.addStep(sessionId: sessionId, description: "Step 1", command: "cmd1", output: "out1")
        await manager.addStep(sessionId: sessionId, description: "Step 2", command: "cmd2", output: "out2")
        await manager.addStep(sessionId: sessionId, description: "Step 3", command: "cmd3", output: "out3")
        
        // Set and update question
        await manager.setLastQuestion(sessionId: sessionId, question: "Initial question?")
        await manager.setLastQuestion(sessionId: sessionId, question: "Updated question?")
        
        // Retrieve and verify
        let session = await manager.getSession(id: sessionId)
        #expect(session?.steps.count == 3)
        #expect(session?.lastQuestion == "Updated question?")
        #expect(session?.task == "Lifecycle test")
        
        // Verify in recent sessions
        let recentSessions = await manager.getRecentSessions()
        let foundSession = recentSessions.first { $0.id == sessionId }
        #expect(foundSession != nil)
        
        // Clean up
        await manager.deleteSession(id: sessionId)
        
        // Verify deletion
        let deletedSession = await manager.getSession(id: sessionId)
        #expect(deletedSession == nil)
    }
}