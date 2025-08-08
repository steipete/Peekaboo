import Foundation
import Testing
@testable import PeekabooCore

@Suite("SessionManager Tests")
struct SessionManagerTests {
    let sessionManager = SessionManager()

    @Test("Create and retrieve session")
    func createAndRetrieveSession() async throws {
        // Create a session
        let sessionId = try await sessionManager.createSession()
        #expect(!sessionId.isEmpty)
        #expect(sessionId.contains("-")) // Should have timestamp-suffix format

        // Verify it shows up in the list
        let sessions = try await sessionManager.listSessions()
        #expect(sessions.contains { $0.id == sessionId })

        // Clean up
        try await self.sessionManager.cleanSession(sessionId: sessionId)
    }

    @Test("Store and retrieve detection result")
    func storeAndRetrieveDetectionResult() async throws {
        // Create a session
        let sessionId = try await sessionManager.createSession()

        // Create a mock detection result
        let element = DetectedElement(
            id: "B1",
            type: .button,
            label: "Test Button",
            bounds: CGRect(x: 100, y: 100, width: 100, height: 50))

        let elements = DetectedElements(buttons: [element])
        let metadata = DetectionMetadata(
            detectionTime: 0.5,
            elementCount: 1,
            method: "test")

        let result = ElementDetectionResult(
            sessionId: sessionId,
            screenshotPath: "/tmp/test.png",
            elements: elements,
            metadata: metadata)

        // Store the result
        try await sessionManager.storeDetectionResult(sessionId: sessionId, result: result)

        // Retrieve it
        let retrieved = try await sessionManager.getDetectionResult(sessionId: sessionId)
        #expect(retrieved != nil)
        #expect(retrieved?.elements.buttons.count == 1)
        #expect(retrieved?.elements.buttons.first?.id == "B1")
        #expect(retrieved?.elements.buttons.first?.label == "Test Button")

        // Clean up
        try await self.sessionManager.cleanSession(sessionId: sessionId)
    }

    @Test("Find elements by query")
    func findElementsByQuery() async throws {
        // Create a session
        let sessionId = try await sessionManager.createSession()

        // Create mock detection elements
        let element1 = DetectedElement(
            id: "B1",
            type: .button,
            label: "Save Document",
            bounds: CGRect(x: 100, y: 100, width: 100, height: 50))

        let element2 = DetectedElement(
            id: "B2",
            type: .button,
            label: "Cancel Operation",
            bounds: CGRect(x: 210, y: 100, width: 100, height: 50))

        let elements = DetectedElements(buttons: [element1, element2])
        let metadata = DetectionMetadata(
            detectionTime: 0.5,
            elementCount: 2,
            method: "test")

        let result = ElementDetectionResult(
            sessionId: sessionId,
            screenshotPath: "/tmp/test.png",
            elements: elements,
            metadata: metadata)

        // Store the detection result which will create the UI map
        try await sessionManager.storeDetectionResult(sessionId: sessionId, result: result)

        // Now find elements by query
        let foundElements = try await sessionManager.findElements(sessionId: sessionId, matching: "save")
        #expect(foundElements.count == 1)
        #expect(foundElements.first?.label?.lowercased().contains("save") == true)

        // Find by partial match
        let cancelElements = try await sessionManager.findElements(sessionId: sessionId, matching: "cancel")
        #expect(cancelElements.count == 1)
        #expect(cancelElements.first?.label?.lowercased().contains("cancel") == true)

        // Clean up
        try await self.sessionManager.cleanSession(sessionId: sessionId)
    }

    @Test("Get most recent session")
    func testGetMostRecentSession() async throws {
        // Create two sessions with a delay
        let session1 = try await sessionManager.createSession()
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        let session2 = try await sessionManager.createSession()

        // The most recent should be session2
        let mostRecent = await sessionManager.getMostRecentSession()
        #expect(mostRecent == session2)

        // Clean up
        try await self.sessionManager.cleanSession(sessionId: session1)
        try await self.sessionManager.cleanSession(sessionId: session2)
    }

    @Test("Session cleanup")
    func sessionCleanup() async throws {
        // Create multiple sessions
        let session1 = try await sessionManager.createSession()
        let session2 = try await sessionManager.createSession()
        let session3 = try await sessionManager.createSession()

        // Clean all sessions
        let cleanedCount = try await sessionManager.cleanAllSessions()
        #expect(cleanedCount >= 3)

        // Verify they're gone
        let sessions = try await sessionManager.listSessions()
        #expect(!sessions.contains { $0.id == session1 })
        #expect(!sessions.contains { $0.id == session2 })
        #expect(!sessions.contains { $0.id == session3 })
    }
}
