import Foundation
@testable import peekaboo
import Testing

#if os(macOS) && swift(>=5.9)
@available(macOS 14.0, *)
@Suite("SessionCache Tests")
struct SessionCacheTests {
    let testSessionId: String
    let sessionCache: SessionCache

    init() async throws {
        testSessionId = UUID().uuidString
        sessionCache = SessionCache(sessionId: testSessionId)

        // Clean up any existing session
        try? await sessionCache.clear()
    }

    @Test("Session ID is correctly initialized")
    func sessionInitialization() async throws {
        #expect(await sessionCache.sessionId == testSessionId)
    }

    @Test("Save and load session data preserves all fields")
    func saveAndLoadSessionData() async throws {
        // Create test data
        let testData = SessionCache.SessionData(
            screenshot: "/tmp/test.png",
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
                )
            ],
            lastUpdateTime: Date(),
            applicationName: "TestApp",
            windowTitle: "Test Window"
        )

        // Save data
        try await sessionCache.save(testData)

        // Load data
        let loadedData = try #require(await sessionCache.load())
        #expect(loadedData.screenshot == "/tmp/test.png")
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
        let emptyCache = SessionCache(sessionId: "non-existent-\(UUID().uuidString)")
        let data = await emptyCache.load()
        #expect(data == nil)
    }

    @Test("Find elements matching query returns correct results")
    func findElementsMatching() async throws {
        // Create test data with multiple elements
        let testData = SessionCache.SessionData(
            screenshot: "/tmp/test.png",
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
                )
            ],
            lastUpdateTime: Date(),
            applicationName: "TestApp",
            windowTitle: "Test Window"
        )

        try await sessionCache.save(testData)

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
        #expect(noMatchElements.count == 0)
    }

    @Test("Get element by ID returns correct element")
    func getElementById() async throws {
        let testData = SessionCache.SessionData(
            screenshot: "/tmp/test.png",
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
                )
            ],
            lastUpdateTime: Date(),
            applicationName: nil,
            windowTitle: nil
        )

        try await sessionCache.save(testData)

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
            screenshot: "/tmp/test.png",
            uiMap: [:],
            lastUpdateTime: Date(),
            applicationName: nil,
            windowTitle: nil
        )

        try await sessionCache.save(testData)

        // Verify data exists
        let loadedData = await sessionCache.load()
        #expect(loadedData != nil)

        // Clear session
        try await sessionCache.clear()

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
        ("AXGroup", "G")
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

    @Test("Atomic save operations preserve data integrity")
    func atomicSaveOperations() async throws {
        // This test verifies atomic save operations work correctly
        // by saving multiple times rapidly

        let testData = SessionCache.SessionData(
            screenshot: "/tmp/test.png",
            uiMap: [:],
            lastUpdateTime: Date(),
            applicationName: "AtomicTest",
            windowTitle: "Atomic Window"
        )

        // Save multiple times rapidly
        for i in 0..<5 {
            var modifiedData = testData
            modifiedData.windowTitle = "Atomic Window \(i)"
            try await sessionCache.save(modifiedData)
        }

        // Verify final state
        let finalData = await sessionCache.load()
        #expect(finalData != nil)
        #expect(finalData?.windowTitle == "Atomic Window 4")
    }
}
#endif
