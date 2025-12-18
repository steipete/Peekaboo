//
//  DialogServiceTests.swift
//  PeekabooCore
//

import AXorcist
import Foundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@Suite("DialogService Tests")
struct DialogServiceTests {
    @Test("Initialize dialog service")
    @MainActor
    func initialization() async throws {
        let service = DialogService()
        #expect(service != nil)
    }

    @Test("Field targeting by label works")
    @MainActor
    func fieldTargetingByLabel() async throws {
        // This test would need a real dialog to be open
        // For unit testing, we're just verifying the API exists
        let service = DialogService()

        // Test that the method accepts field identifier
        do {
            _ = try await service.enterTextInField(
                text: "test",
                fieldIdentifier: "Username",
                clearExisting: false,
                windowTitle: nil)
            Issue.record("Should fail without an actual dialog")
        } catch {
            // Expected to fail without a real dialog
            #expect(error != nil)
        }
    }

    @Test("Field targeting by index works")
    @MainActor
    func fieldTargetingByIndex() async throws {
        let service = DialogService()

        // Test that the method accepts numeric index
        do {
            _ = try await service.enterTextInField(
                text: "test",
                fieldIdentifier: "0",
                clearExisting: false,
                windowTitle: nil)
            Issue.record("Should fail without an actual dialog")
        } catch {
            // Expected to fail without a real dialog
            #expect(error != nil)
        }
    }

    @Test("Field targeting with nil uses first field")
    @MainActor
    func fieldTargetingDefault() async throws {
        let service = DialogService()

        // Test that nil field identifier is accepted
        do {
            _ = try await service.enterTextInField(
                text: "test",
                fieldIdentifier: nil,
                clearExisting: true,
                windowTitle: nil)
            Issue.record("Should fail without an actual dialog")
        } catch {
            // Expected to fail without a real dialog
            #expect(error != nil)
        }
    }

    @Test("Click button in dialog")
    @MainActor
    func testClickButton() async throws {
        let service = DialogService()

        // Test that the method exists and accepts parameters
        do {
            _ = try await service.clickButton(
                buttonText: "OK",
                windowTitle: "Save Dialog")
            Issue.record("Should fail without an actual dialog")
        } catch {
            // Expected to fail without a real dialog
            #expect(error != nil)
        }
    }

    @Test("List dialog elements")
    @MainActor
    func testListDialogElements() async throws {
        let service = DialogService()

        await #expect(throws: DialogError.self) {
            _ = try await service.listDialogElements(windowTitle: nil)
        }
    }

    @Test("Handle file dialog")
    @MainActor
    func testHandleFileDialog() async throws {
        let service = DialogService()

        // Test that the method exists and accepts parameters
        do {
            _ = try await service.handleFileDialog(
                path: "/Users/test",
                filename: "test.txt",
                actionButton: "Save",
                ensureExpanded: false)
            Issue.record("Should fail without an actual dialog")
        } catch {
            // Expected to fail without a real dialog
            #expect(error != nil)
        }
    }

    @Test("Dialog action result structure")
    @MainActor
    func dialogActionResult() async throws {
        // Test the result structure
        let result = DialogActionResult(
            success: true,
            action: .enterText,
            details: [
                "field": "Username",
                "text_length": "10",
                "cleared": "true",
            ])

        #expect(result.success == true)
        #expect(result.action == .enterText)
        #expect(result.details["field"] == "Username")
        #expect(result.details["text_length"] == "10")
        #expect(result.details["cleared"] == "true")
    }

    @Test("Dialog elements structure")
    @MainActor
    func dialogElementsStructure() async throws {
        // Test the dialog elements structure
        let button = DialogButton(
            text: "OK",
            isDefault: true,
            keyEquivalent: "Return")

        let textField = DialogTextField(
            label: "Username",
            value: "",
            placeholder: "Enter username",
            isSecure: false)

        let elements = DialogElements(
            buttons: [button],
            textFields: [textField],
            staticTexts: ["Please enter your credentials"],
            checkboxes: [],
            radioButtons: [],
            popUpButtons: [])

        #expect(elements.buttons.count == 1)
        #expect(elements.buttons[0].text == "OK")
        #expect(elements.buttons[0].isDefault == true)

        #expect(elements.textFields.count == 1)
        #expect(elements.textFields[0].label == "Username")
        #expect(elements.textFields[0].placeholder == "Enter username")
        #expect(elements.textFields[0].isSecure == false)

        #expect(elements.staticTexts.count == 1)
        #expect(elements.staticTexts[0] == "Please enter your credentials")
    }

    @Test("Character typing delegates through handler")
    @MainActor
    func typeCharacterUsesHandler() async throws {
        let service = DialogService()
        var captured: String?
        DialogService.typeCharacterHandler = { captured = $0 }
        defer { DialogService.typeCharacterHandler = { text in try InputDriver.type(text, delayPerCharacter: 0) } }

        try service.typeCharacter("Z")
        #expect(captured == "Z")
    }

    @Test("typeCharacter called repeatedly uses handler each time")
    @MainActor
    func typeCharacterMultipleCalls() async throws {
        let service = DialogService()
        var calls: [String] = []
        DialogService.typeCharacterHandler = { calls.append($0) }
        defer { DialogService.typeCharacterHandler = { text in try InputDriver.type(text, delayPerCharacter: 0) } }

        try service.typeCharacter("A")
        try service.typeCharacter("b")
        try service.typeCharacter("1")

        #expect(calls == ["A", "b", "1"])
    }
}
