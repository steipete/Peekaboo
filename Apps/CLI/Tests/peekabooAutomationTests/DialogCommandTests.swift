import Foundation
import PeekabooCore
import PeekabooFoundation
import Testing
@testable import PeekabooCLI

#if !PEEKABOO_SKIP_AUTOMATION
@Suite(
    "Dialog Command  Tests",
    .serialized,
    .tags(.automation),
    .enabled(if: CLITestEnvironment.runAutomationRead)
)
struct DialogCommandTests {
    @Test("Dialog  command exists")
    func dialogCommandExists() {
        let config = DialogCommand.configuration
        #expect(config.commandName == "dialog")
        #expect(config.abstract.contains("Interact with system dialogs and alerts"))
    }

    @Test("Dialog  command has expected subcommands")
    func dialogSubcommands() {
        let subcommands = DialogCommand.configuration.subcommands
        #expect(subcommands.count == 5)

        let subcommandNames = subcommands.map { $0.configuration.commandName }
        #expect(subcommandNames.contains("click"))
        #expect(subcommandNames.contains("input"))
        #expect(subcommandNames.contains("file"))
        #expect(subcommandNames.contains("dismiss"))
        #expect(subcommandNames.contains("list"))
    }

    @Test("Dialog  click command help")
    func dialogClickHelp() async throws {
        let output = try await runCommand(["dialog", "click", "--help"])

        #expect(output.contains("OVERVIEW: Click a button in a dialog using DialogService"))
        #expect(output.contains("--button"))
        #expect(output.contains("--window"))
        #expect(output.contains("--json-output"))
    }

    @Test("Dialog  input command help")
    func dialogInputHelp() async throws {
        let output = try await runCommand(["dialog", "input", "--help"])

        #expect(output.contains("OVERVIEW: Enter text in a dialog field using DialogService"))
        #expect(output.contains("--text"))
        #expect(output.contains("--field"))
        #expect(output.contains("--index"))
        #expect(output.contains("--clear"))
    }

    @Test("Dialog  file command help")
    func dialogFileHelp() async throws {
        let output = try await runCommand(["dialog", "file", "--help"])

        #expect(output.contains("OVERVIEW: Handle file save/open dialogs using DialogService"))
        #expect(output.contains("--path"))
        #expect(output.contains("--name"))
        #expect(output.contains("--select"))
    }

    @Test("Dialog  dismiss command help")
    func dialogDismissHelp() async throws {
        let output = try await runCommand(["dialog", "dismiss", "--help"])

        #expect(output.contains("OVERVIEW: Dismiss a dialog using DialogService"))
        #expect(output.contains("--force"))
        #expect(output.contains("--window"))
    }

    @Test("Dialog  list command help")
    func dialogListHelp() async throws {
        let output = try await runCommand(["dialog", "list", "--help"])

        #expect(output.contains("OVERVIEW: List elements in current dialog using DialogService"))
        #expect(output.contains("--json-output"))
    }

    @Test("Dialog  error handling")
    func dialogErrorHandling() {
        // Test that DialogError enum values are properly mapped
        let errorCases: [(PeekabooError, StandardErrorCode, String)] = [
            (.elementNotFound("OK"), .elementNotFound, "Element not found: OK"),
            (.invalidInput("Field index 5 out of range"), .invalidInput, "Invalid input: Field index 5 out of range"),
            (
                .operationError(message: "No text fields found in dialog."),
                .unknownError,
                "No text fields found in dialog."
            ),
        ]

        for (error, code, message) in errorCases {
            #expect(error.code == code)
            #expect(error.errorDescription == message)
        }
    }

    @Test("Dialog  service integration")
    @MainActor
    func dialogServiceIntegration() {
        // Verify that PeekabooServices includes the dialog service
        let services = PeekabooServices.shared
        _ = services.dialogs // This should compile without errors
    }
}

// MARK: - Dialog Command  Integration Tests

@Suite(
    "Dialog Command  Integration Tests",
    .serialized,
    .tags(.automation),
    .enabled(if: CLITestEnvironment.runAutomationActions)
)
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
        if let response = try? JSONDecoder().decode(
            CodableJSONResponse<DialogListResult>.self,
            from: output.data(using: .utf8)!
        ) {
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

        if let response = try? JSONDecoder().decode(
            CodableJSONResponse<DialogDismissResult>.self,
            from: output.data(using: .utf8)!
        ) {
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
        if let response = try? JSONDecoder().decode(
            CodableJSONResponse<FileDialogResult>.self,
            from: output.data(using: .utf8)!
        ) {
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
    let projectRoot = dialogProjectRoot()
    let binaryURL = try ensurePeekabooBinary(at: projectRoot)

    let process = Process()
    process.executableURL = binaryURL
    process.currentDirectoryURL = projectRoot
    process.arguments = args

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    // Allow command-line validation failures
    let allowedStatuses: Set<Int32> = [0, 1, 64]
    guard allowedStatuses.contains(process.terminationStatus) else {
        throw CommandError(status: process.terminationStatus, output: output)
    }

    return output
}

private func dialogProjectRoot() -> URL {
    let thisFile = URL(fileURLWithPath: #filePath)
    return thisFile
        .deletingLastPathComponent() // DialogCommandTests.swift
        .deletingLastPathComponent() // peekabooTests
        .deletingLastPathComponent() // Tests
}

private func ensurePeekabooBinary(at root: URL) throws -> URL {
    let binaryURL = root.appendingPathComponent(".build/debug/peekaboo")
    if FileManager.default.isExecutableFile(atPath: binaryURL.path) {
        return binaryURL
    }

    let buildProcess = Process()
    buildProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    buildProcess.currentDirectoryURL = root
    buildProcess.arguments = ["build", "--product", "peekaboo"]

    let buildPipe = Pipe()
    buildProcess.standardOutput = buildPipe
    buildProcess.standardError = buildPipe

    try buildProcess.run()
    buildProcess.waitUntilExit()

    guard buildProcess.terminationStatus == 0 else {
        let buildOutput = String(data: buildPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        throw CommandError(status: buildProcess.terminationStatus, output: buildOutput)
    }

    return binaryURL
}

private struct CommandError: Error, CustomStringConvertible {
    let status: Int32
    let output: String

    var description: String {
        "Command failed with exit code \(self.status). Output: \(self.output)"
    }
}
#endif
