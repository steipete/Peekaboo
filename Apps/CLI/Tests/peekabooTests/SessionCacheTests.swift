import Foundation
import Testing
@testable import peekaboo

@Suite("SessionCache Tests", .serialized)
struct SessionCacheTests {
    let testSessionId: String
    let sessionCache: SessionCache

    init() async throws {
        self.testSessionId = UUID().uuidString
        self.sessionCache = try SessionCache(sessionId: self.testSessionId)

        // Clean up any existing session
        try? await self.sessionCache.clear()
    }

    @Test("Session ID is correctly initialized")
    func sessionInitialization() async throws {
        #expect(await self.sessionCache.sessionId == self.testSessionId)
    }

    @Test("Default session ID uses latest session or process ID")
    func defaultSessionUsesLatestOrProcessID() async throws {
        // Clean up any existing sessions to ensure we get PID behavior
        let sessionsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".peekaboo/session")
        try? FileManager.default.removeItem(at: sessionsDir)

        // With no existing sessions and createIfNeeded = true, it should use timestamp-based ID
        let defaultCache = try SessionCache(sessionId: nil, createIfNeeded: true)
        let sessionId = await defaultCache.sessionId
        // Session ID should be timestamp-random format (e.g., 1751889198010-5978)
        #expect(sessionId.matches(of: /^\d{13}-\d{4}$/).count == 1)

        // With no existing sessions and createIfNeeded = false, it should throw
        #expect(throws: Error.self) {
            _ = try SessionCache(sessionId: nil, createIfNeeded: false)
        }

        // Create a new session with a specific ID
        let testSession = try SessionCache(sessionId: "test-session-123")
        let testData = SessionCache.SessionData(
            version: SessionCache.SessionData.currentVersion,
            screenshotPath: nil,
            annotatedPath: nil,
            uiMap: [:],
            lastUpdateTime: Date(),
            applicationName: "Test",
            windowTitle: "Test Window",
            windowBounds: nil,
            menuBar: nil)
        try await testSession.save(testData)

        // Now a new SessionCache with no ID should use the latest session
        let latestCache = try SessionCache(sessionId: nil, createIfNeeded: false)
        #expect(await latestCache.sessionId == "test-session-123")
    }

    @Test("Session cache uses ~/.peekaboo/session/<sessionId>/ directory structure")
    func sessionDirectoryStructure() async throws {
        let cache = try SessionCache(sessionId: "test-12345")
        let paths = await cache.getSessionPaths()

        // Check that paths follow the v3 spec structure
        #expect(paths.raw.contains("/.peekaboo/session/test-12345/raw.png"))
        #expect(paths.annotated.contains("/.peekaboo/session/test-12345/annotated.png"))
        #expect(paths.map.contains("/.peekaboo/session/test-12345/map.json"))
    }

    @Test("Save and load session data preserves all fields")
    func saveAndLoadSessionData() async throws {
        // Create test data
        let testData = SessionCache.SessionData(
            version: SessionCache.SessionData.currentVersion,
            screenshotPath: "/tmp/test.png",
            annotatedPath: nil,
            uiMap: [
                "B1": SessionCache.SessionData.UIElement(
                    id: "B1",
                    elementId: "element_1",
                    role: "AXButton",
                    title: "Save",
                    label: "Save Document",
                    value: nil,
                    frame: CGRect(x: 100, y: 200, width: 80, height: 30),
                    isActionable: true
                ),
            ],
            lastUpdateTime: Date(),
            applicationName: "TestApp",
            windowTitle: "Test Window",
            windowBounds: nil,
            menuBar: nil)

        // Save data
        try await self.sessionCache.save(testData)

        // Load data
        let loadedData = try #require(await self.sessionCache.load())
        #expect(loadedData.screenshotPath == "/tmp/test.png")
        #expect(loadedData.applicationName == "TestApp")
        #expect(loadedData.windowTitle == "Test Window")
        #expect(loadedData.uiMap.count == 1)

        let element = try #require(loadedData.uiMap["B1"])
        #expect(element.role == "AXButton")
        #expect(element.title == "Save")
        #expect(element.label == "Save Document")
        #expect(element.isActionable)
    }

    @Test("Loading non-existent session returns nil")
    func loadNonExistentSession() async throws {
        let emptyCache = try SessionCache(sessionId: "non-existent-\(UUID().uuidString)")
        let data = await emptyCache.load()
        #expect(data == nil)
    }

    @Test("Find elements matching query returns correct results")
    func findElementsMatching() async throws {
        // Create test data with multiple elements
        let testData = SessionCache.SessionData(
            version: SessionCache.SessionData.currentVersion,
            screenshotPath: "/tmp/test.png",
            annotatedPath: nil,
            uiMap: [
                "B1": SessionCache.SessionData.UIElement(
                    id: "B1",
                    elementId: "element_1",
                    role: "AXButton",
                    title: "Save",
                    label: "Save Document",
                    value: nil,
                    frame: CGRect(x: 100, y: 100, width: 80, height: 30),
                    isActionable: true
                ),
                "B2": SessionCache.SessionData.UIElement(
                    id: "B2",
                    elementId: "element_2",
                    role: "AXButton",
                    title: "Cancel",
                    label: "Cancel Operation",
                    value: nil,
                    frame: CGRect(x: 200, y: 100, width: 80, height: 30),
                    isActionable: true
                ),
                "T1": SessionCache.SessionData.UIElement(
                    id: "T1",
                    elementId: "element_3",
                    role: "AXTextField",
                    title: nil,
                    label: "Username",
                    value: "john.doe",
                    frame: CGRect(x: 100, y: 150, width: 200, height: 30),
                    isActionable: true
                ),
                "G1": SessionCache.SessionData.UIElement(
                    id: "G1",
                    elementId: "element_4",
                    role: "AXGroup",
                    title: "Settings",
                    label: nil,
                    value: nil,
                    frame: CGRect(x: 50, y: 50, width: 300, height: 200),
                    isActionable: false
                ),
            ],
            lastUpdateTime: Date(),
            applicationName: "TestApp",
            windowTitle: "Test Window",
            windowBounds: nil,
            menuBar: nil)

        try await self.sessionCache.save(testData)

        // Test finding by title
        let saveElements = await sessionCache.findElements(matching: "save")
        #expect(saveElements.count == 1)
        #expect(saveElements.first?.id == "B1")

        // Test finding by label
        let usernameElements = await sessionCache.findElements(matching: "username")
        #expect(usernameElements.count == 1)
        #expect(usernameElements.first?.id == "T1")

        // Test finding by value
        let johnElements = await sessionCache.findElements(matching: "john")
        #expect(johnElements.count == 1)
        #expect(johnElements.first?.id == "T1")

        // Test finding by role
        let buttonElements = await sessionCache.findElements(matching: "button")
        #expect(buttonElements.count == 2)

        // Test case insensitive search
        let cancelElements = await sessionCache.findElements(matching: "CANCEL")
        #expect(cancelElements.count == 1)
        #expect(cancelElements.first?.id == "B2")

        // Test no matches
        let noMatchElements = await sessionCache.findElements(matching: "nonexistent")
        #expect(noMatchElements.isEmpty)
    }

    @Test("Get element by ID returns correct element")
    func getElementById() async throws {
        let testData = SessionCache.SessionData(
            version: SessionCache.SessionData.currentVersion,
            screenshotPath: "/tmp/test.png",
            annotatedPath: nil,
            uiMap: [
                "B1": SessionCache.SessionData.UIElement(
                    id: "B1",
                    elementId: "element_1",
                    role: "AXButton",
                    title: "OK",
                    label: nil,
                    value: nil,
                    frame: CGRect(x: 100, y: 100, width: 50, height: 30),
                    isActionable: true
                ),
            ],
            lastUpdateTime: Date(),
            applicationName: nil,
            windowTitle: nil,
            windowBounds: nil,
            menuBar: nil)

        try await self.sessionCache.save(testData)

        // Test getting existing element
        let element = await sessionCache.getElement(id: "B1")
        #expect(element != nil)
        #expect(element?.title == "OK")

        // Test getting non-existent element
        let noElement = await sessionCache.getElement(id: "B99")
        #expect(noElement == nil)
    }

    @Test("Clear session removes all data")
    func clearSession() async throws {
        let testData = SessionCache.SessionData(
            version: SessionCache.SessionData.currentVersion,
            screenshotPath: "/tmp/test.png",
            annotatedPath: nil,
            uiMap: [:],
            lastUpdateTime: Date(),
            applicationName: nil,
            windowTitle: nil,
            windowBounds: nil,
            menuBar: nil)

        try await self.sessionCache.save(testData)

        // Verify data exists
        let loadedData = await sessionCache.load()
        #expect(loadedData != nil)

        // Clear session
        try await self.sessionCache.clear()

        // Verify data is gone
        let clearedData = await sessionCache.load()
        #expect(clearedData == nil)
    }

    @Test("Element ID generation returns correct prefixes", arguments: [
        ("AXButton", "B"),
        ("AXTextField", "T"),
        ("AXTextArea", "T"),
        ("AXLink", "L"),
        ("AXMenu", "M"),
        ("AXMenuItem", "M"),
        ("AXCheckBox", "C"),
        ("AXRadioButton", "R"),
        ("AXSlider", "S"),
        ("AXUnknown", "G"),
        ("AXGroup", "G"),
    ])
    func elementIDGeneration(role: String, expectedPrefix: String) {
        #expect(ElementIDGenerator.prefix(for: role) == expectedPrefix)
    }

    @Test("Actionable role detection is correct", arguments: [
        ("AXButton", true),
        ("AXTextField", true),
        ("AXTextArea", true),
        ("AXCheckBox", true),
        ("AXRadioButton", true),
        ("AXPopUpButton", true),
        ("AXLink", true),
        ("AXMenuItem", true),
        ("AXSlider", true),
        ("AXComboBox", true),
        ("AXSegmentedControl", true),
        ("AXGroup", false),
        ("AXStaticText", false),
        ("AXImage", false),
        ("AXUnknown", false)
    ])
    func actionableRoles(role: String, shouldBeActionable: Bool) {
        #expect(ElementIDGenerator.isActionableRole(role) == shouldBeActionable)
    }

    @Test("Update screenshot copies file to session directory")
    func updateScreenshotCopiesFile() async throws {
        // Create a temporary test file
        let tempDir = FileManager.default.temporaryDirectory
        let sourcePath = tempDir.appendingPathComponent("test-source.png").path
        let testData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        try testData.write(to: URL(fileURLWithPath: sourcePath))

        // Update screenshot
        try await self.sessionCache.updateScreenshot(
            path: sourcePath,
            application: "TestApp",
            window: "TestWindow")

        // Verify raw.png was created in session directory
        let paths = await sessionCache.getSessionPaths()
        #expect(FileManager.default.fileExists(atPath: paths.raw))

        // Verify session data is updated
        let data = await sessionCache.load()
        #expect(data?.screenshotPath == paths.raw)
        #expect(data?.applicationName == "TestApp")
        #expect(data?.windowTitle == "TestWindow")

        // Cleanup
        try? FileManager.default.removeItem(atPath: sourcePath)
    }

    @Test("Atomic save operations preserve data integrity")
    func atomicSaveOperations() async throws {
        // This test verifies atomic save operations work correctly
        // by saving multiple times rapidly

        let testData = SessionCache.SessionData(
            version: SessionCache.SessionData.currentVersion,
            screenshotPath: "/tmp/test.png",
            annotatedPath: nil,
            uiMap: [:],
            lastUpdateTime: Date(),
            applicationName: "AtomicTest",
            windowTitle: "Atomic Window")

        // Save multiple times rapidly
        for i in 0..<5 {
            var modifiedData = testData
            modifiedData.windowTitle = "Atomic Window \(i)"
            try await self.sessionCache.save(modifiedData)
        }

        // Verify final state
        let finalData = await sessionCache.load()
        #expect(finalData != nil)
        #expect(finalData?.windowTitle == "Atomic Window 4")
    }
}
