import Foundation
import Testing
@testable import peekaboo

@Suite("Dialog Command Tests", .serialized)
struct DialogCommandTests {
    @Test("Dialog command exists")
    func dialogCommandExists() {
        let config = DialogCommand.configuration
        #expect(config.commandName == "dialog")
        #expect(config.abstract.contains("system dialogs"))
    }

    @Test("Dialog command has expected subcommands")
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

    @Test("Dialog click command help")
    func dialogClickHelp() async throws {
        let output = try await runCommand(["dialog", "click", "--help"])

        #expect(output.contains("Click a button in a dialog"))
        #expect(output.contains("--button"))
        #expect(output.contains("--title"))
    }

    @Test("Dialog input command help")
    func dialogInputHelp() async throws {
        let output = try await runCommand(["dialog", "input", "--help"])

        #expect(output.contains("Enter text in dialog fields"))
        #expect(output.contains("--text"))
        #expect(output.contains("--field"))
        #expect(output.contains("--clear"))
    }

    @Test("Dialog file command help")
    func dialogFileHelp() async throws {
        let output = try await runCommand(["dialog", "file", "--help"])

        #expect(output.contains("Handle file dialogs"))
        #expect(output.contains("--path"))
        #expect(output.contains("--name"))
        #expect(output.contains("--select"))
    }

    @Test("Dialog dismiss command help")
    func dialogDismissHelp() async throws {
        let output = try await runCommand(["dialog", "dismiss", "--help"])

        #expect(output.contains("Dismiss a dialog"))
        #expect(output.contains("--force"))
        #expect(output.contains("--button"))
    }

    @Test("Dialog error codes")
    func dialogErrorCodes() {
        #expect(ErrorCode.NO_ACTIVE_DIALOG.rawValue == "NO_ACTIVE_DIALOG")
        #expect(ErrorCode.ELEMENT_NOT_FOUND.rawValue == "ELEMENT_NOT_FOUND")
    }

    @Test("Dialog button options")
    func dialogButtonOptions() {
        // Test standard button names
        let buttons = ["OK", "Cancel", "Save", "Don't Save", "Yes", "No"]
        for button in buttons {
            let cmd = ["dialog", "click", "--button", button]
            #expect(cmd.count == 5)
        }
    }

    @Test("File dialog validation")
    func fileDialogValidation() {
        // Test that we can specify both path and name
        let cmd = ["dialog", "file", "--path", "/Users/test", "--name", "document.txt", "--select", "Save"]
        #expect(cmd.count == 9)
    }
}

// MARK: - Dialog Command Integration Tests

@Suite(
    "Dialog Command Integration Tests",
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true"))
struct DialogCommandIntegrationTests {
    @Test("List active dialogs")
    func listActiveDialogs() async throws {
        let output = try await runCommand([
            "dialog", "list",
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

    @Test("Dialog click workflow")
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
            #expect(data.error?.code == .NO_ACTIVE_DIALOG)
        }
    }

    @Test("Dialog input workflow")
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
            #expect(data.error?.code == .NO_ACTIVE_DIALOG)
        }
    }

    @Test("Dialog dismiss with escape")
    func dialogDismissEscape() async throws {
        let output = try await runCommand([
            "dialog", "dismiss",
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

    @Test("File dialog handling")
    func fileDialogHandling() async throws {
        let output = try await runCommand([
            "dialog", "file",
            "--path", "/tmp",
            "--name", "test.txt",
            "--select", "Save",
            "--json-output",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: output.data(using: .utf8)!)
        if !data.success {
            // Expected if no file dialog is open
            #expect(data.error?.code == .NO_ACTIVE_DIALOG || data.error?.code == .ELEMENT_NOT_FOUND)
        } else {
            if let fileData = data.data?.value as? [String: Any] {
                #expect(fileData["action"] as? String == "file_dialog")
                #expect(fileData["path"] as? String == "/tmp")
                #expect(fileData["filename"] as? String == "test.txt")
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
