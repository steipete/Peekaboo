import Foundation
import Testing
import PeekabooCore
@testable import peekaboo
import PeekabooCore

@Suite("Dialog Command  Tests", .serialized)
struct DialogCommandTests {
    @Test("Dialog  command exists")
    func dialogCommandExists() {
        let config = DialogCommand.configuration
        #expect(config.commandName == "dialog")
        #expect(config.abstract.contains("PeekabooCore services"))
    }

    @Test("Dialog  command has expected subcommands")
    func dialogSubcommands() {
        let subcommands = DialogCommand.configuration.subcommands
        #expect(subcommands.count == 5)

        let subcommandNames = subcommands.map(\.configuration.commandName)
        #expect(subcommandNames.contains("click"))
        #expect(subcommandNames.contains("input"))
        #expect(subcommandNames.contains("file"))
        #expect(subcommandNames.contains("dismiss"))
        #expect(subcommandNames.contains("list"))
    }

    @Test("Dialog  click command help")
    func dialogClickHelp() async throws {
        let output = try await runCommand(["dialog", "click", "--help"])

        #expect(output.contains("Click a button in a dialog"))
        #expect(output.contains("--button"))
        #expect(output.contains("--window"))
        #expect(output.contains("DialogService"))
    }

    @Test("Dialog  input command help")
    func dialogInputHelp() async throws {
        let output = try await runCommand(["dialog", "input", "--help"])

        #expect(output.contains("Enter text in a dialog field"))
        #expect(output.contains("--text"))
        #expect(output.contains("--field"))
        #expect(output.contains("--clear"))
        #expect(output.contains("DialogService"))
    }

    @Test("Dialog  file command help")
    func dialogFileHelp() async throws {
        let output = try await runCommand(["dialog", "file", "--help"])

        #expect(output.contains("Handle file dialogs"))
        #expect(output.contains("--path"))
        #expect(output.contains("--name"))
        #expect(output.contains("--select"))
        #expect(output.contains("DialogService"))
    }

    @Test("Dialog  dismiss command help")
    func dialogDismissHelp() async throws {
        let output = try await runCommand(["dialog", "dismiss", "--help"])

        #expect(output.contains("Dismiss a dialog"))
        #expect(output.contains("--force"))
        #expect(output.contains("--window"))
        #expect(output.contains("DialogService"))
    }

    @Test("Dialog  list command help")
    func dialogListHelp() async throws {
        let output = try await runCommand(["dialog", "list", "--help"])

        #expect(output.contains("List elements in current dialog"))
        #expect(output.contains("DialogService"))
    }

    @Test("Dialog  error handling")
    func dialogErrorHandling() {
        // Test that DialogError enum values are properly mapped
        #expect(DialogError.noActiveDialog.localizedDescription.contains("No active dialog"))
        #expect(DialogError.noFileDialog.localizedDescription.contains("No file dialog"))
        #expect(DialogError.buttonNotFound("OK").localizedDescription.contains("Button 'OK' not found"))
        #expect(DialogError.fieldNotFound.localizedDescription.contains("Field not found"))
        #expect(DialogError.invalidFieldIndex.localizedDescription.contains("Invalid field index"))
        #expect(DialogError.noTextFields.localizedDescription.contains("No text fields"))
        #expect(DialogError.noDismissButton.localizedDescription.contains("No dismiss button"))
    }

    @Test("Dialog  service integration")
    func dialogServiceIntegration() {
        // Verify that PeekabooServices includes the dialog service
        let services = PeekabooServices.shared
        let _ = services.dialogs // This should compile without errors
    }
}

// MARK: - Dialog Command  Integration Tests

@Suite(
    "Dialog Command  Integration Tests",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true"))
struct DialogCommandIntegrationTests {
    @Test("List active dialogs with ")
    func listActiveDialogs() async throws {
        let output = try await runCommand([
            "dialog", "list",
            "--json-output",
        ])

        struct TextField: Codable {
            let title: String
            let value: String
            let placeholder: String
        }
        
        struct DialogListResult: Codable {
            let title: String
            let role: String
            let buttons: [String]
            let textFields: [TextField]
            let textElements: [String]
        }
        
        // Try to decode as success response first
        if let response = try? JSONDecoder().decode(CodableJSONResponse<DialogListResult>.self, from: output.data(using: .utf8)!) {
            if response.success {
                #expect(!response.data.title.isEmpty)
                #expect(!response.data.buttons.isEmpty)
            }
        } else {
            // Otherwise it's an error response
            let errorResponse = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
            #expect(errorResponse.error?.code == "NO_ACTIVE_DIALOG")
        }
    }

    @Test("Dialog  click workflow")
    func dialogClickWorkflow() async throws {
        // This would click a button if a dialog is present
        let output = try await runCommand([
            "dialog", "click",
            "--button", "OK",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        if !data.success {
            // Expected if no dialog is open
            #expect(data.error?.code == "NO_ACTIVE_DIALOG")
        }
    }

    @Test("Dialog  input workflow")
    func dialogInputWorkflow() async throws {
        let output = try await runCommand([
            "dialog", "input",
            "--text", "Test input",
            "--field", "Name",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        if !data.success {
            // Expected if no dialog is open
            #expect(data.error?.code == "NO_ACTIVE_DIALOG")
        }
    }

    @Test("Dialog  dismiss with escape")
    func dialogDismissEscape() async throws {
        let output = try await runCommand([
            "dialog", "dismiss",
            "--force",
            "--json-output",
        ])

        struct DialogDismissResult: Codable {
            let action: String
            let method: String
            let button: String?
        }
        
        if let response = try? JSONDecoder().decode(CodableJSONResponse<DialogDismissResult>.self, from: output.data(using: .utf8)!) {
            if response.success {
                #expect(response.data.method == "escape")
            }
        }
    }

    @Test("File dialog  handling")
    func fileDialogHandling() async throws {
        let output = try await runCommand([
            "dialog", "file",
            "--path", "/tmp",
            "--name", "test.txt",
            "--select", "Save",
            "--json-output",
        ])

        struct FileDialogResult: Codable {
            let action: String
            let path: String?
            let name: String?
            let buttonClicked: String
        }
        
        // Try to decode as success response first
        if let response = try? JSONDecoder().decode(CodableJSONResponse<FileDialogResult>.self, from: output.data(using: .utf8)!) {
            if response.success {
                #expect(response.data.action == "file_dialog")
                #expect(response.data.path == "/tmp")
                #expect(response.data.name == "test.txt")
            }
        } else {
            // Otherwise it's an error response
            let errorResponse = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
            #expect(errorResponse.error?.code == "NO_ACTIVE_DIALOG" || errorResponse.error?.code == "NO_FILE_DIALOG")
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
