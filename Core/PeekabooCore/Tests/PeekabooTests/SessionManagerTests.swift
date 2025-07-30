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

        // Store some UI elements
        let uiElement1 = UIElement(
            id: "B1",
            elementId: "element_0",
            role: "AXButton",
            title: "Save",
            label: "Save Document",
            frame: CGRect(x: 100, y: 100, width: 100, height: 50),
            isActionable: true)

        let uiElement2 = UIElement(
            id: "B2",
            elementId: "element_1",
            role: "AXButton",
            title: "Cancel",
            label: "Cancel Operation",
            frame: CGRect(x: 210, y: 100, width: 100, height: 50),
            isActionable: true)

        // Create a temporary test image file
        let testImagePath = "/tmp/test.png"
        let testImageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        try testImageData.write(to: URL(fileURLWithPath: testImagePath))

        // Store screenshot with UI map
        try await self.sessionManager.storeScreenshot(
            sessionId: sessionId,
            screenshotPath: testImagePath,
            applicationName: "TestApp",
            windowTitle: "Test Window",
            windowBounds: nil)

        // We need to directly store the UI elements since storeScreenshot doesn't build a UI map
        // This would normally be done by the enhanced detectElements method
        let sessionPath = URL(fileURLWithPath: sessionManager.getSessionStoragePath())
            .appendingPathComponent(sessionId)
        let sessionFile = sessionPath.appendingPathComponent("map.json")

        // Ensure the session directory exists
        try FileManager.default.createDirectory(at: sessionPath, withIntermediateDirectories: true)

        var sessionData = UIAutomationSession()
        sessionData.uiMap = ["B1": uiElement1, "B2": uiElement2]
        sessionData.applicationName = "TestApp"
        sessionData.windowTitle = "Test Window"
        sessionData.lastUpdateTime = Date()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(sessionData)
        try jsonData.write(to: sessionFile, options: .atomic)

        // Find elements by query
        let foundElements = try await sessionManager.findElements(sessionId: sessionId, matching: "save")
        #expect(foundElements.count == 1)
        #expect(foundElements.first?.id == "B1")

        // Find by partial match
        let cancelElements = try await sessionManager.findElements(sessionId: sessionId, matching: "cancel")
        #expect(cancelElements.count == 1)
        #expect(cancelElements.first?.id == "B2")

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
