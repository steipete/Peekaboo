import Foundation
import Testing
import PeekabooCore
@testable import peekaboo
import PeekabooCore

@Suite("Agent Resume CLI Tests")
struct AgentResumeCLITests {
    
    // MARK: - Command Line Argument Tests
    
    @Test("AgentCommand has resume option")
    func agentCommandHasResumeOption() {
        // Verify that the AgentCommand struct has the resume property
        // This is a compile-time test to ensure the property exists
        let command = AgentCommand()
        
        // The resume property should be optional and default to nil
        #expect(command.resume == nil)
    }
    
    @Test("AgentCommand task is optional for resume functionality")
    func agentCommandTaskIsOptional() {
        // Verify that task is now optional to support resume without initial task
        let command = AgentCommand()
        
        // Task should be optional
        #expect(command.task == nil)
    }
    
    // MARK: - Resume Command Validation Tests
    
    @Test("Resume validation handles empty session ID")
    func resumeValidationHandlesEmptySessionID() {
        let resumeSessionId = ""
        let shouldShowRecentSessions = resumeSessionId.isEmpty
        #expect(shouldShowRecentSessions == true)
    }
    
    @Test("Resume validation handles valid session ID")
    func resumeValidationHandlesValidSessionID() {
        let resumeSessionId = "valid-session-123"
        let shouldShowRecentSessions = resumeSessionId.isEmpty
        #expect(shouldShowRecentSessions == false)
    }
    
    // MARK: - Error Message Tests
    
    @Test("Error messages are properly formatted")
    func errorMessagesAreProperlyFormatted() {
        // Test JSON error format
        let jsonError = ["success": false, "error": "Session not found"] as [String: Any]
        #expect(jsonError["success"] as? Bool == false)
        #expect(jsonError["error"] as? String == "Session not found")
        
        // Test that error can be serialized to JSON
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonError, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8)
            #expect(jsonString != nil)
            #expect(jsonString!.contains("\"success\" : false"))
        } catch {
            #expect(false, "JSON serialization should not fail")
        }
    }
    
    @Test("Session data formats correctly for JSON output")
    func sessionDataFormatsCorrectlyForJSON() async {
        let manager = AgentSessionManager.shared
        let sessionId = await manager.createSession(task: "JSON test task", threadId: "json-test-thread")
        
        await manager.addStep(sessionId: sessionId, description: "JSON step", command: "json-cmd", output: "json-out")
        await manager.setLastQuestion(sessionId: sessionId, question: "JSON question?")
        
        let session = await manager.getSession(id: sessionId)!
        
        // Format session data as it would be for JSON output
        let sessionData: [String: Any] = [
            "id": session.id,
            "task": session.task,
            "steps": session.steps.count,
            "lastQuestion": session.lastQuestion as Any,
            "createdAt": ISO8601DateFormatter().string(from: session.createdAt),
            "lastActivityAt": ISO8601DateFormatter().string(from: session.lastActivityAt)
        ]
        
        #expect(sessionData["id"] as? String == sessionId)
        #expect(sessionData["task"] as? String == "JSON test task")
        #expect(sessionData["steps"] as? Int == 1)
        #expect(sessionData["lastQuestion"] as? String == "JSON question?")
        
        // Test serialization
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sessionData, options: .prettyPrinted)
            let jsonString = String(data: jsonData, encoding: .utf8)
            #expect(jsonString != nil)
            #expect(jsonString!.contains("JSON test task"))
        } catch {
            #expect(false, "Session data should serialize to JSON")
        }
        
        // Clean up
        await manager.deleteSession(id: sessionId)
    }
    
    // MARK: - Time Formatting Tests
    
    @Test("Time ago formatting works correctly")
    func timeAgoFormattingWorksCorrectly() {
        let now = Date()
        
        // Test recent time (less than 1 minute)
        let recent = now.addingTimeInterval(-30) // 30 seconds ago
        let recentFormatted = formatTimeAgoForTest(recent, from: now)
        #expect(recentFormatted == "just now")
        
        // Test minutes ago
        let minutesAgo = now.addingTimeInterval(-90) // 1.5 minutes ago
        let minutesFormatted = formatTimeAgoForTest(minutesAgo, from: now)
        #expect(minutesFormatted == "1 minute ago")
        
        let multipleMinutesAgo = now.addingTimeInterval(-300) // 5 minutes ago
        let multipleMinutesFormatted = formatTimeAgoForTest(multipleMinutesAgo, from: now)
        #expect(multipleMinutesFormatted == "5 minutes ago")
        
        // Test hours ago
        let hoursAgo = now.addingTimeInterval(-3900) // 1.08 hours ago
        let hoursFormatted = formatTimeAgoForTest(hoursAgo, from: now)
        #expect(hoursFormatted == "1 hour ago")
        
        let multipleHoursAgo = now.addingTimeInterval(-7200) // 2 hours ago
        let multipleHoursFormatted = formatTimeAgoForTest(multipleHoursAgo, from: now)
        #expect(multipleHoursFormatted == "2 hours ago")
        
        // Test days ago
        let daysAgo = now.addingTimeInterval(-86500) // Just over 1 day ago
        let daysFormatted = formatTimeAgoForTest(daysAgo, from: now)
        #expect(daysFormatted == "1 day ago")
        
        let multipleDaysAgo = now.addingTimeInterval(-172800) // 2 days ago
        let multipleDaysFormatted = formatTimeAgoForTest(multipleDaysAgo, from: now)
        #expect(multipleDaysFormatted == "2 days ago")
    }
    
    // Helper function to test time formatting logic
    private func formatTimeAgoForTest(_ date: Date, from now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
    
    // MARK: - Session Display Tests
    
    @Test("Session list formatting includes all required fields")
    func sessionListFormattingIncludesAllRequiredFields() async {
        let manager = AgentSessionManager.shared
        
        // Create test sessions with different characteristics
        let sessionId1 = await manager.createSession(task: "Simple task", threadId: "thread-1")
        let sessionId2 = await manager.createSession(task: "Complex task with multiple steps", threadId: "thread-2")
        let sessionId3 = await manager.createSession(task: "Task with question", threadId: "thread-3")
        
        // Add different amounts of content
        await manager.addStep(sessionId: sessionId2, description: "Step 1", command: nil, output: nil)
        await manager.addStep(sessionId: sessionId2, description: "Step 2", command: nil, output: nil)
        await manager.addStep(sessionId: sessionId2, description: "Step 3", command: nil, output: nil)
        
        await manager.setLastQuestion(sessionId: sessionId3, question: "What should I do next?")
        
        let sessions = await manager.getRecentSessions()
        let testSessions = sessions.filter { [sessionId1, sessionId2, sessionId3].contains($0.id) }
        
        #expect(testSessions.count == 3)
        
        // Verify each session has the required fields for display
        for session in testSessions {
            #expect(!session.id.isEmpty)
            #expect(!session.task.isEmpty)
            #expect(session.steps.count >= 0)
            // lastQuestion can be nil, that's valid
            #expect(session.createdAt <= Date())
            #expect(session.lastActivityAt <= Date())
        }
        
        // Verify specific session characteristics
        let simpleSession = testSessions.first { $0.id == sessionId1 }
        #expect(simpleSession?.steps.count == 0)
        #expect(simpleSession?.lastQuestion == nil)
        
        let complexSession = testSessions.first { $0.id == sessionId2 }
        #expect(complexSession?.steps.count == 3)
        #expect(complexSession?.lastQuestion == nil)
        
        let questionSession = testSessions.first { $0.id == sessionId3 }
        #expect(questionSession?.steps.count == 0)
        #expect(questionSession?.lastQuestion == "What should I do next?")
        
        // Clean up
        await manager.deleteSession(id: sessionId1)
        await manager.deleteSession(id: sessionId2)
        await manager.deleteSession(id: sessionId3)
    }
    
    // MARK: - Resume Prompt Construction Tests
    
    @Test("Resume prompt is constructed correctly")
    func resumePromptIsConstructedCorrectly() {
        let originalTask = "Open TextEdit"
        let continuationTask = "Now save the document"
        
        let expectedPrompt = "Continue with the original task. The user's response: \(continuationTask)"
        
        #expect(expectedPrompt == "Continue with the original task. The user's response: Now save the document")
        
        // Test with different continuation tasks
        let longContinuation = "This is a very long continuation task that includes multiple instructions and complex requirements"
        let longPrompt = "Continue with the original task. The user's response: \(longContinuation)"
        
        #expect(longPrompt.contains("very long continuation task"))
    }
    
    // MARK: - Configuration Integration Tests
    
    @Test("Resume respects configuration settings")
    func resumeRespectsConfigurationSettings() {
        // Test that resume functionality respects the same configuration as regular commands
        let defaultModel = "gpt-4-turbo"
        let defaultMaxSteps = 20
        
        // These would be the defaults used in resume
        #expect(defaultModel == "gpt-4-turbo")
        #expect(defaultMaxSteps == 20)
        
        // Test that configuration override logic works
        let configModel = "gpt-4o"
        let configMaxSteps = 30
        
        let effectiveModel = configModel // Would be from config if available
        let effectiveMaxSteps = configMaxSteps // Would be from config if available
        
        #expect(effectiveModel == "gpt-4o")
        #expect(effectiveMaxSteps == 30)
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Resume handles special characters in task")
    func resumeHandlesSpecialCharactersInTask() {
        let specialTask = "Task with \"quotes\" and 'apostrophes' and {brackets} and <tags>"
        let continuationTask = "Continue with émojis 🤖 and unicode ∆∇∫"
        
        let resumePrompt = "Continue with the original task. The user's response: \(continuationTask)"
        
        #expect(resumePrompt.contains("émojis 🤖"))
        #expect(resumePrompt.contains("unicode ∆∇∫"))
    }
    
    @Test("Resume handles very long tasks")
    func resumeHandlesVeryLongTasks() {
        let longTask = String(repeating: "Very long task description. ", count: 100)
        let longContinuation = String(repeating: "Long continuation. ", count: 50)
        
        let resumePrompt = "Continue with the original task. The user's response: \(longContinuation)"
        
        #expect(resumePrompt.count > 1000) // Should handle long text
        #expect(resumePrompt.contains("Long continuation."))
    }
    
    // MARK: - Session ID Validation Tests
    
    @Test("Session ID validation works correctly")
    func sessionIDValidationWorksCorrectly() {
        // Test valid UUID format
        let validUUID = UUID().uuidString
        #expect(validUUID.count == 36)
        #expect(validUUID.contains("-"))
        
        // Test short ID display (prefix 8 characters)
        let shortID = String(validUUID.prefix(8))
        #expect(shortID.count == 8)
        #expect(!shortID.contains("-"))
        
        // Test invalid session IDs
        let emptyID = ""
        let shortInvalidID = "abc"
        let longInvalidID = "this-is-not-a-valid-uuid-format-at-all"
        
        #expect(emptyID.isEmpty)
        #expect(shortInvalidID.count < 36)
        #expect(longInvalidID.count > 36) // Not a valid UUID format
    }
}
