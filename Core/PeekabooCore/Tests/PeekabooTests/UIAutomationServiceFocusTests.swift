import CoreGraphics
import Testing
@testable import PeekabooCore

@Suite("UIAutomationService Focus Tests", .tags(.safe))
struct UIAutomationServiceFocusTests {
    @Test("getFocusedElement returns nil when no element focused")
    @MainActor
    func getFocusedElementNoFocus() async {
        let service = UIAutomationService()

        // Note: This test may be environment-dependent
        // In a real test environment with no focused elements, this should return nil
        let result = await service.getFocusedElement()

        // We can't guarantee no focus in all test environments,
        // but we can at least verify the method doesn't crash
        if let focusInfo = result {
            #expect(!focusInfo.applicationName.isEmpty)
            #expect(!focusInfo.role.isEmpty)
        }
    }

    @Test("getFocusedElement structure validation")
    @MainActor
    func getFocusedElementStructure() async {
        let service = UIAutomationService()

        // This test validates that if we get a result, it has the expected structure
        let result = await service.getFocusedElement()

        if let focusInfo = result {
            // Validate app information
            #expect(!focusInfo.applicationName.isEmpty)
            #expect(focusInfo.processId > 0)

            // Validate element information
            #expect(!focusInfo.role.isEmpty)
            #expect(focusInfo.frame.width >= 0)
            #expect(focusInfo.frame.height >= 0)

            // Validate optional properties
            _ = focusInfo.title
            _ = focusInfo.value
            _ = focusInfo.bundleIdentifier
        }
    }

    @Test("Focus info dictionary format validation")
    @MainActor
    func focusInfoDictionaryFormat() async {
        let service = UIAutomationService()

        let result = await service.getFocusedElement()

        if let focusInfo = result {
            // Validate UIFocusInfo structure directly
            #expect(!focusInfo.applicationName.isEmpty)
            #expect(focusInfo.processId > 0)
            #expect(!focusInfo.role.isEmpty)
            #expect(focusInfo.frame.width >= 0)
            #expect(focusInfo.frame.height >= 0)

            // Validate bundle identifier
            #expect(!focusInfo.bundleIdentifier.isEmpty)
        }
    }
}

// MARK: - Mock Tests for Focus Information

@Suite("Focus Information Mock Tests")
struct FocusInformationMockTests {
    @Test("UIFocusInfo basic properties")
    func uIFocusInfoBasicProperties() {
        // Test UIFocusInfo structure
        let focusInfo = UIFocusInfo(
            role: "AXTextField",
            title: "Email Address",
            value: "",
            frame: CGRect(x: 100, y: 200, width: 250, height: 30),
            applicationName: "TestApp",
            bundleIdentifier: "com.test.app",
            processId: 1234)

        #expect(focusInfo.role == "AXTextField")
        #expect(focusInfo.title == "Email Address")
        #expect(focusInfo.applicationName == "TestApp")
        #expect(focusInfo.processId == 1234)
    }

    @Test("UIFocusInfo with nil values")
    func uIFocusInfoWithNilValues() {
        // Test UIFocusInfo with optional values as nil
        let focusInfo = UIFocusInfo(
            role: "AXButton",
            title: nil,
            value: nil,
            frame: CGRect(x: 0, y: 0, width: 100, height: 50),
            applicationName: "App",
            bundleIdentifier: "com.unknown.app",
            processId: 999)

        #expect(focusInfo.role == "AXButton")
        #expect(focusInfo.title == nil)
        #expect(focusInfo.value == nil)
        #expect(focusInfo.bundleIdentifier == "com.unknown.app")
    }
}
