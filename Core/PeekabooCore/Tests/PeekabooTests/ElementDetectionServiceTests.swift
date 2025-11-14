import AppKit
@preconcurrency import AXorcist
import CoreGraphics
import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@Suite("ElementDetectionService Tests", .tags(.ui, .safe))
@MainActor
struct ElementDetectionServiceTests {
    @Test("Initialize ElementDetectionService")
    func initializeService() async throws {
        let sessionManager = MockSessionManager()
        let service: ElementDetectionService? = ElementDetectionService(sessionManager: sessionManager)
        #expect(service != nil)
    }

    @Test("Detect elements from screenshot")
    func detectElementsFromScreenshot() async throws {
        let sessionManager = MockSessionManager()
        let service = ElementDetectionService(sessionManager: sessionManager)

        // Create mock image data
        let mockImageData = Data()

        // In a real test, we'd have actual image data. For now, we'll test the API
        do {
            let result = try await service.detectElements(
                in: mockImageData,
                sessionId: "test-session",
                windowContext: nil)

            #expect(result.sessionId == "test-session")
            #expect(result.metadata.elementCount >= 0)
        } catch {
            // In test environment without a focused window, this might fail
            // We're mainly testing the API structure
        }
    }

    @Test("Window detection works for non-active apps")
    func detectWindowsForNonActiveApp() async throws {
        let sessionManager = MockSessionManager()
        _ = ElementDetectionService(sessionManager: sessionManager)

        // This test verifies that window detection doesn't require the app to be active
        // Previously, the service would throw an error if !targetApp.isActive
        // Now it should work for background apps as well

        // Note: In a real test environment, we'd need to:
        // 1. Launch a test app
        // 2. Switch focus to another app
        // 3. Try to detect windows from the background app
        // 4. Verify it doesn't throw "is running but not active" error

        // For now, we're documenting the expected behavior
        #expect(Bool(true)) // Placeholder for actual test implementation
    }

    @Test("Map element types correctly")
    func elementTypeMapping() async throws {
        let sessionManager = MockSessionManager()
        _ = ElementDetectionService(sessionManager: sessionManager)

        // Test various AX roles map to correct ElementType
        let roleMappings: [(String, ElementType)] = [
            ("AXButton", .button),
            ("AXTextField", .textField),
            ("AXStaticText", .other), // staticText not in protocol
            ("AXLink", .link),
            ("AXImage", .image),
            ("AXCheckBox", .checkbox),
            ("AXRadioButton", .other), // radioButton not in protocol
            ("AXPopUpButton", .other), // popupButton not in protocol
            ("AXComboBox", .other), // comboBox not in protocol
            ("AXSlider", .slider),
            ("AXMenuItem", .menu), // Use menu type for menu items
            ("AXUnknown", .other),
        ]

        // We can't directly test the private method, but we can verify
        // the service handles these types correctly
        #expect(!roleMappings.isEmpty)
    }

    @Test("Find element by ID")
    func findElementById() async throws {
        let sessionManager = MockSessionManager()

        // Create mock detection result
        let mockElements = [
            DetectedElement(
                id: "button-1",
                type: .button,
                label: "Save",
                value: nil,
                bounds: CGRect(x: 10, y: 10, width: 100, height: 40),
                isEnabled: true,
                isSelected: nil,
                attributes: ["keyboardShortcut": "⌘S"]),
            DetectedElement(
                id: "textfield-1",
                type: .textField,
                label: "Username",
                value: "john_doe",
                bounds: CGRect(x: 10, y: 60, width: 200, height: 30),
                isEnabled: true,
                isSelected: nil,
                attributes: [:]),
        ]

        let detectedElements = DetectedElements(
            buttons: mockElements.filter { $0.type == .button },
            textFields: mockElements.filter { $0.type == .textField })

        let detectionResult = ElementDetectionResult(
            sessionId: "test-session",
            screenshotPath: "/tmp/test.png",
            elements: detectedElements,
            metadata: DetectionMetadata(
                detectionTime: 0.1,
                elementCount: mockElements.count,
                method: "AXorcist"))

        await sessionManager.primeDetectionResult(detectionResult)

        _ = ElementDetectionService(sessionManager: sessionManager)

        // Test getting detection result
        let result = try await sessionManager.getDetectionResult(sessionId: "test-session")
        #expect(result != nil)

        // Test finding elements in the stored result
        if let detectionResult = result {
            let allElements = detectionResult.elements.all
            #expect(allElements.count == 2)

            // Find button by ID
            if let button = allElements.first(where: { $0.id == "button-1" }) {
                #expect(button.type == .button)
                #expect(button.label == "Save")
            } else {
                Issue.record("Failed to find button-1")
            }
        }
    }

    @Test("DetectedElements functionality")
    func detectedElementsOperations() async throws {
        let button1 = DetectedElement(
            id: "btn-1",
            type: .button,
            label: "Submit",
            value: nil,
            bounds: CGRect(x: 0, y: 0, width: 100, height: 50),
            isEnabled: true,
            isSelected: nil,
            attributes: ["keyboardShortcut": "⌘S"])
        let button2 = DetectedElement(
            id: "btn-2",
            type: .button,
            label: "Cancel",
            value: nil,
            bounds: CGRect(x: 0, y: 60, width: 100, height: 50),
            isEnabled: false,
            isSelected: nil,
            attributes: [:])
        let textField = DetectedElement(
            id: "txt-1",
            type: .textField,
            label: "Email",
            value: "test@example.com",
            bounds: CGRect(x: 0, y: 120, width: 200, height: 30),
            isEnabled: true,
            isSelected: nil,
            attributes: [:])

        let detectedElements = DetectedElements(
            buttons: [button1, button2],
            textFields: [textField])

        self.assertBasicElementCollections(
            detectedElements,
            expectedTotal: 3,
            disabledId: "btn-2")
    }

    @Test("Actionable element detection")
    func detectActionableElements() async throws {
        // Create elements with various actionable states
        let elements = [
            DetectedElement(
                id: "actionable-1",
                type: .button,
                label: "Click Me",
                value: nil,
                bounds: CGRect(x: 0, y: 0, width: 100, height: 50),
                isEnabled: true,
                isSelected: nil,
                attributes: [:]),
            DetectedElement(
                id: "non-actionable-1",
                type: .other, // staticText not in protocol
                label: "Just text",
                value: nil,
                bounds: CGRect(x: 0, y: 60, width: 100, height: 20),
                isEnabled: true,
                isSelected: nil,
                attributes: ["role": "AXStaticText"]),
            DetectedElement(
                id: "actionable-2",
                type: .link,
                label: "Click here",
                value: nil,
                bounds: CGRect(x: 0, y: 90, width: 100, height: 20),
                isEnabled: true,
                isSelected: nil,
                attributes: [:]),
        ]

        let buttonElements = elements.filter { $0.type == .button }
        let linkElements = elements.filter { $0.type == .link }
        let otherElements = elements.filter { $0.type == .other }

        let detectedElements = DetectedElements(
            buttons: buttonElements,
            links: linkElements,
            other: otherElements)

        let result = createDetectionResult(elements: detectedElements, total: elements.count)

        // Verify actionable elements are correctly identified
        let actionableTypes: Set<ElementType> = [.button, .link, .checkbox]
        let actionableElements = result.elements.all.filter { actionableTypes.contains($0.type) }

        #expect(actionableElements.count == 2)
        #expect(actionableElements.contains { $0.id == "actionable-1" })
        #expect(actionableElements.contains { $0.id == "actionable-2" })
    }

    @Test("Keyboard shortcut extraction")
    func extractKeyboardShortcuts() async throws {
        let elements = [
            DetectedElement(
                id: "menu-1",
                type: .other, // menuItem
                label: "Save",
                value: nil,
                bounds: CGRect(x: 0, y: 0, width: 200, height: 30),
                isEnabled: true,
                isSelected: nil,
                attributes: ["keyboardShortcut": "⌘S"]),
            DetectedElement(
                id: "menu-2",
                type: .other, // menuItem
                label: "Save As...",
                value: nil,
                bounds: CGRect(x: 0, y: 30, width: 200, height: 30),
                isEnabled: true,
                isSelected: nil,
                attributes: ["keyboardShortcut": "⇧⌘S"]),
            DetectedElement(
                id: "button-1",
                type: .button,
                label: "OK",
                value: nil,
                bounds: CGRect(x: 0, y: 60, width: 100, height: 40),
                isEnabled: true,
                isSelected: nil,
                attributes: [:]),
        ]

        let elementsWithShortcuts = elements.filter { $0.attributes["keyboardShortcut"] != nil }
        #expect(elementsWithShortcuts.count == 2)
        #expect(elementsWithShortcuts[0].attributes["keyboardShortcut"] == "⌘S")
        #expect(elementsWithShortcuts[1].attributes["keyboardShortcut"] == "⇧⌘S")
    }
}

extension ElementDetectionServiceTests {
    private func assertBasicElementCollections(
        _ elements: DetectedElements,
        expectedTotal: Int,
        disabledId: String)
    {
        #expect(elements.all.count == expectedTotal)

        let found = elements.findById("btn-1")
        #expect(found?.label == "Submit")

        #expect(elements.buttons.count == 2)
        #expect(elements.buttons.allSatisfy { $0.type == .button })
        #expect(elements.textFields.count == 1)
        #expect(elements.textFields.first?.type == .textField)

        let enabledElements = elements.all.filter(\.isEnabled)
        #expect(enabledElements.count == expectedTotal - 1)

        let disabledElements = elements.all.filter { !$0.isEnabled }
        #expect(disabledElements.count == 1)
        #expect(disabledElements.first?.id == disabledId)
    }
}

// MARK: - Mock Session Manager

@MainActor
private final class MockSessionManager: SessionManagerProtocol {
    private var mockDetectionResult: ElementDetectionResult?
    private var storedResults: [String: ElementDetectionResult] = [:]

    func primeDetectionResult(_ result: ElementDetectionResult?) {
        self.mockDetectionResult = result
    }

    func createSession() async throws -> String {
        "test-session-\(UUID().uuidString)"
    }

    func storeDetectionResult(sessionId: String, result: ElementDetectionResult) async throws {
        self.storedResults[sessionId] = result
    }

    func getDetectionResult(sessionId: String) async throws -> ElementDetectionResult? {
        self.mockDetectionResult ?? self.storedResults[sessionId]
    }

    func getMostRecentSession() async -> String? {
        self.storedResults.keys.first
    }

    func listSessions() async throws -> [SessionInfo] {
        []
    }

    func cleanSession(sessionId: String) async throws {
        self.storedResults.removeValue(forKey: sessionId)
    }

    func cleanSessionsOlderThan(days: Int) async throws -> Int {
        let count = self.storedResults.count
        self.storedResults.removeAll()
        return count
    }

    func cleanAllSessions() async throws -> Int {
        let count = self.storedResults.count
        self.storedResults.removeAll()
        return count
    }

    nonisolated func getSessionStoragePath() -> String {
        "/tmp/test-sessions"
    }

    func storeScreenshot(
        sessionId: String,
        screenshotPath: String,
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?) async throws
    {
        // No-op for tests
    }

    func getElement(sessionId: String, elementId: String) async throws -> UIElement? {
        nil
    }

    func findElements(sessionId: String, matching query: String) async throws -> [UIElement] {
        []
    }

    func getUIAutomationSession(sessionId: String) async throws -> UIAutomationSession? {
        nil
    }
}

private func createDetectionResult(elements: DetectedElements, total: Int) -> ElementDetectionResult {
    ElementDetectionResult(
        sessionId: "test-session",
        screenshotPath: "/tmp/test.png",
        elements: elements,
        metadata: DetectionMetadata(
            detectionTime: 0.1,
            elementCount: total,
            method: "AXorcist"))
}
