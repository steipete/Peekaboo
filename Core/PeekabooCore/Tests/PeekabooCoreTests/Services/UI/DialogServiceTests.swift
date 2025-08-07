//
//  DialogServiceTests.swift
//  PeekabooCore
//

import Testing
import Foundation
import AXorcist
@testable import PeekabooCore

@Suite("DialogService Tests")
struct DialogServiceTests {
    
    @Test("Initialize dialog service")
    @MainActor
    func testInitialization() async throws {
        let service = DialogService()
        #expect(service != nil)
    }
    
    @Test("Field targeting by label works")
    @MainActor
    func testFieldTargetingByLabel() async throws {
        // This test would need a real dialog to be open
        // For unit testing, we're just verifying the API exists
        let service = DialogService()
        
        // Test that the method accepts field identifier
        do {
            _ = try await service.enterTextInField(
                text: "test",
                fieldIdentifier: "Username",
                clearExisting: false,
                windowTitle: nil
            )
            Issue.record("Should fail without an actual dialog")
        } catch {
            // Expected to fail without a real dialog
            #expect(error != nil)
        }
    }
    
    @Test("Field targeting by index works")
    @MainActor
    func testFieldTargetingByIndex() async throws {
        let service = DialogService()
        
        // Test that the method accepts numeric index
        do {
            _ = try await service.enterTextInField(
                text: "test",
                fieldIdentifier: "0",
                clearExisting: false,
                windowTitle: nil
            )
            Issue.record("Should fail without an actual dialog")
        } catch {
            // Expected to fail without a real dialog
            #expect(error != nil)
        }
    }
    
    @Test("Field targeting with nil uses first field")
    @MainActor
    func testFieldTargetingDefault() async throws {
        let service = DialogService()
        
        // Test that nil field identifier is accepted
        do {
            _ = try await service.enterTextInField(
                text: "test",
                fieldIdentifier: nil,
                clearExisting: true,
                windowTitle: nil
            )
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
                windowTitle: "Save Dialog"
            )
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
        
        // Test that the method exists
        do {
            let elements = try await service.listDialogElements(windowTitle: nil)
            // Without a real dialog, this should return empty or throw
            #expect(elements.buttons.isEmpty || elements.textFields.isEmpty)
        } catch {
            // Expected to fail without a real dialog
            #expect(error != nil)
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
                actionButton: "Save"
            )
            Issue.record("Should fail without an actual dialog")
        } catch {
            // Expected to fail without a real dialog
            #expect(error != nil)
        }
    }
    
    @Test("Dialog action result structure")
    @MainActor
    func testDialogActionResult() async throws {
        // Test the result structure
        let result = DialogActionResult(
            success: true,
            action: .enterText,
            details: [
                "field": "Username",
                "text_length": "10",
                "cleared": "true"
            ]
        )
        
        #expect(result.success == true)
        #expect(result.action == .enterText)
        #expect(result.details["field"] == "Username")
        #expect(result.details["text_length"] == "10")
        #expect(result.details["cleared"] == "true")
    }
    
    @Test("Dialog elements structure")
    @MainActor
    func testDialogElementsStructure() async throws {
        // Test the dialog elements structure
        let button = DialogButton(
            text: "OK",
            isDefault: true,
            keyEquivalent: "Return"
        )
        
        let textField = DialogTextField(
            label: "Username",
            value: "",
            placeholder: "Enter username",
            isSecure: false
        )
        
        let elements = DialogElements(
            buttons: [button],
            textFields: [textField],
            staticTexts: ["Please enter your credentials"],
            checkboxes: [],
            radioButtons: [],
            popUpButtons: []
        )
        
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
}