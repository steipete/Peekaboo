import Foundation
import Testing
@testable import peekaboo

@Suite("Dialog Command V2 Tests", .serialized)
struct DialogCommandV2Tests {
    @Test("Dialog V2 command exists")
    func dialogCommandV2Exists() {
        let config = DialogCommandV2.configuration
        #expect(config.commandName == "dialog-v2")
        #expect(config.abstract.contains("PeekabooCore services"))
    }

    @Test("Dialog V2 command has expected subcommands")
    func dialogV2Subcommands() {
        let subcommands = DialogCommandV2.configuration.subcommands
        #expect(subcommands.count == 5)

        let subcommandNames = subcommands.map(\.configuration.commandName)
        #expect(subcommandNames.contains("click"))
        #expect(subcommandNames.contains("input"))
        #expect(subcommandNames.contains("file"))
        #expect(subcommandNames.contains("dismiss"))
        #expect(subcommandNames.contains("list"))
    }

    @Test("Dialog V2 click command help")
    func dialogV2ClickHelp() async throws {
        let output = try await runCommand(["dialog-v2", "click", "--help"])

        #expect(output.contains("Click a button in a dialog"))
        #expect(output.contains("--button"))
        #expect(output.contains("--window"))
        #expect(output.contains("DialogService"))
    }

    @Test("Dialog V2 input command help")
    func dialogV2InputHelp() async throws {
        let output = try await runCommand(["dialog-v2", "input", "--help"])

        #expect(output.contains("Enter text in a dialog field"))
        #expect(output.contains("--text"))
        #expect(output.contains("--field"))
        #expect(output.contains("--clear"))
        #expect(output.contains("DialogService"))
    }

    @Test("Dialog V2 file command help")
    func dialogV2FileHelp() async throws {
        let output = try await runCommand(["dialog-v2", "file", "--help"])

        #expect(output.contains("Handle file dialogs"))
        #expect(output.contains("--path"))
        #expect(output.contains("--name"))
        #expect(output.contains("--select"))
        #expect(output.contains("DialogService"))
    }

    @Test("Dialog V2 dismiss command help")
    func dialogV2DismissHelp() async throws {
        let output = try await runCommand(["dialog-v2", "dismiss", "--help"])

        #expect(output.contains("Dismiss a dialog"))
        #expect(output.contains("--force"))
        #expect(output.contains("--window"))
        #expect(output.contains("DialogService"))
    }

    @Test("Dialog V2 list command help")
    func dialogV2ListHelp() async throws {
        let output = try await runCommand(["dialog-v2", "list", "--help"])

        #expect(output.contains("List elements in current dialog"))
        #expect(output.contains("DialogService"))
    }

    @Test("Dialog V2 error handling")
    func dialogV2ErrorHandling() {
        // Test that DialogError enum values are properly mapped
        #expect(DialogError.noActiveDialog.localizedDescription.contains("No active dialog"))
        #expect(DialogError.noFileDialog.localizedDescription.contains("No file dialog"))
        #expect(DialogError.buttonNotFound("OK").localizedDescription.contains("Button 'OK' not found"))
        #expect(DialogError.fieldNotFound("Password").localizedDescription.contains("Field 'Password' not found"))
        #expect(DialogError.invalidFieldIndex(3).localizedDescription.contains("Invalid field index: 3"))
        #expect(DialogError.noTextFields.localizedDescription.contains("No text fields"))
        #expect(DialogError.noDismissButton.localizedDescription.contains("No dismiss button"))
    }

    @Test("Dialog V2 service integration")
    func dialogV2ServiceIntegration() {
        // Verify that PeekabooServices includes the dialog service
        let services = PeekabooServices.shared
        let _ = services.dialogs // This should compile without errors
    }
}

// MARK: - Dialog Command V2 Integration Tests

@Suite(
    "Dialog Command V2 Integration Tests",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true"))
struct DialogCommandV2IntegrationTests {
    @Test("List active dialogs with V2")
    func listActiveDialogsV2() async throws {
        let output = try await runCommand([
            "dialog-v2", "list",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        // May or may not have active dialogs
        if data.success {
            if let dialogData = data.data?.value as? [String: Any] {
                #expect(dialogData["title"] != nil)
                #expect(dialogData["buttons"] != nil)
            }
        } else {
            #expect(data.error?.code == .NO_ACTIVE_DIALOG)
        }
    }

    @Test("Dialog V2 click workflow")
    func dialogV2ClickWorkflow() async throws {
        // This would click a button if a dialog is present
        let output = try await runCommand([
            "dialog-v2", "click",
            "--button", "OK",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        if !data.success {
            // Expected if no dialog is open
            #expect(data.error?.code == .NO_ACTIVE_DIALOG)
        }
    }

    @Test("Dialog V2 input workflow")
    func dialogV2InputWorkflow() async throws {
        let output = try await runCommand([
            "dialog-v2", "input",
            "--text", "Test input",
            "--field", "Name",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        if !data.success {
            // Expected if no dialog is open
            #expect(data.error?.code == .NO_ACTIVE_DIALOG)
        }
    }

    @Test("Dialog V2 dismiss with escape")
    func dialogV2DismissEscape() async throws {
        let output = try await runCommand([
            "dialog-v2", "dismiss",
            "--force",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        if data.success {
            if let dismissData = data.data?.value as? [String: Any] {
                #expect(dismissData["method"] as? String == "escape")
            }
        }
    }

    @Test("File dialog V2 handling")
    func fileDialogV2Handling() async throws {
        let output = try await runCommand([
            "dialog-v2", "file",
            "--path", "/tmp",
            "--name", "test.txt",
            "--select", "Save",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        if !data.success {
            // Expected if no file dialog is open
            #expect(data.error?.code == .NO_ACTIVE_DIALOG || data.error?.code == .NO_FILE_DIALOG)
        } else {
            if let fileData = data.data?.value as? [String: Any] {
                #expect(fileData["action"] as? String == "file_dialog")
                #expect(fileData["path"] as? String == "/tmp")
                #expect(fileData["name"] as? String == "test.txt")
            }
        }
    }
}

// MARK: - Test Helpers

private func runCommand(_ args: [String]) async throws -> String {
    let output = try await runPeekabooCommand(args)
    return output
}

private func runPeekabooCommand(_ args: [String]) async throws -> String {
    // This is a placeholder - in real tests, this would execute the actual CLI
    // For unit tests, we're mainly testing command structure and validation
    ""
}