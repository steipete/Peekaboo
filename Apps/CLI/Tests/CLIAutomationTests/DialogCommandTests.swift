import Foundation
import PeekabooCore
import PeekabooFoundation
import Testing
@testable import PeekabooCLI

private struct DialogTextFieldPayload: Codable, Sendable {
    let title: String?
    let value: String?
    let placeholder: String?
}

private struct DialogListPayload: Codable, Sendable {
    let title: String
    let role: String
    let buttons: [String]
    let textFields: [DialogTextFieldPayload]
    let textElements: [String]
}

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
        let config = DialogCommand.commandDescription
        #expect(config.commandName == "dialog")
        #expect(config.abstract.contains("Interact with system dialogs and alerts"))
    }

    @Test("Dialog  command has expected subcommands")
    func dialogSubcommands() {
        let subcommands = DialogCommand.commandDescription.subcommands
        #expect(subcommands.count == 5)

        var subcommandNames: [String] = []
        subcommandNames.reserveCapacity(subcommands.count)
        for descriptor in subcommands {
            guard let name = descriptor.commandDescription.commandName else { continue }
            subcommandNames.append(name)
        }
        #expect(subcommandNames.contains("click"))
        #expect(subcommandNames.contains("input"))
        #expect(subcommandNames.contains("file"))
        #expect(subcommandNames.contains("dismiss"))
        #expect(subcommandNames.contains("list"))
    }

    @Test("Dialog  click command help")
    func dialogClickHelp() async throws {
        let result = try await runCommand(["dialog", "click", "--help"])
        #expect(result.status == 0)
        let output = result.output

        #expect(output.contains("Click a button in a dialog using DialogService"))
        #expect(output.contains("--button"))
        #expect(output.contains("--window-title"))
        #expect(output.contains("--json"))
    }

    @Test("Dialog  input command help")
    func dialogInputHelp() async throws {
        let result = try await runCommand(["dialog", "input", "--help"])
        #expect(result.status == 0)
        let output = result.output

        #expect(output.contains("Enter text in a dialog field using DialogService"))
        #expect(output.contains("--text"))
        #expect(output.contains("--field"))
        #expect(output.contains("--index"))
        #expect(output.contains("--clear"))
    }

    @Test("Dialog  file command help")
    func dialogFileHelp() async throws {
        let result = try await runCommand(["dialog", "file", "--help"])
        #expect(result.status == 0)
        let output = result.output

        #expect(output.contains("Handle file save/open dialogs using DialogService"))
        #expect(output.contains("--path"))
        #expect(output.contains("--name"))
        #expect(output.contains("--select"))
    }

    @Test("Dialog  dismiss command help")
    func dialogDismissHelp() async throws {
        let result = try await runCommand(["dialog", "dismiss", "--help"])
        #expect(result.status == 0)
        let output = result.output

        #expect(output.contains("Dismiss a dialog using DialogService"))
        #expect(output.contains("--force"))
        #expect(output.contains("--window-title"))
    }

    @Test("dialog dismiss uses force flag")
    func dialogDismissForce() async throws {
        let dialogService = StubDialogService()
        dialogService.dialogElements = DialogElements(
            dialogInfo: DialogInfo(
                title: "Open",
                role: "AXWindow",
                subrole: "AXDialog",
                isFileDialog: false,
                bounds: .init(x: 0, y: 0, width: 400, height: 300)
            ),
            buttons: [],
            textFields: [],
            staticTexts: []
        )
        dialogService.dismissResult = DialogActionResult(
            success: true,
            action: .dismiss,
            details: ["method": "escape"]
        )

        let services = self.makeTestServices(dialogs: dialogService)
        let (output, status) = try await self.runCommand(
            ["dialog", "dismiss", "--force", "--json"],
            services: services
        )

        #expect(status == 0)
        struct Payload: Codable {
            let success: Bool
            let data: DialogDismissResult
        }
        struct DialogDismissResult: Codable {
            let method: String
        }

        let response = try JSONDecoder().decode(Payload.self, from: Data(output.utf8))
        #expect(response.success == true)
        #expect(response.data.method == "escape")
    }

    @Test("Dialog  list command help")
    func dialogListHelp() async throws {
        let result = try await runCommand(["dialog", "list", "--help"])
        #expect(result.status == 0)
        let output = result.output

        #expect(output.contains("List elements in current dialog using DialogService"))
        #expect(output.contains("--json"))
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
        let services = self.makeTestServices()
        _ = services.dialogs // This should compile without errors
    }

    @Test("dialog list surfaces stubbed elements in JSON")
    func dialogListWithStubData() async throws {
        let elements = DialogElements(
            dialogInfo: DialogInfo(
                title: "Open",
                role: "AXWindow",
                subrole: "AXDialog",
                isFileDialog: true,
                bounds: .init(x: 0, y: 0, width: 400, height: 300)
            ),
            buttons: [
                DialogButton(title: "New Document"),
                DialogButton(title: "Open"),
            ],
            textFields: [
                DialogTextField(title: "Name", value: "", placeholder: "File name", index: 0, isEnabled: true),
            ],
            staticTexts: ["Choose a document to open"]
        )
        let dialogService = StubDialogService(elements: elements)
        let services = self.makeTestServices(dialogs: dialogService)

        let (output, status) = try await self.runCommand(
            ["dialog", "list", "--json"],
            services: services
        )
        #expect(status == 0)

        let data = try #require(output.data(using: .utf8))
        let response = try JSONDecoder().decode(CodableJSONResponse<DialogListPayload>.self, from: data)
        #expect(response.data.title == "Open")
        #expect(response.data.buttons.contains("New Document"))
        #expect(response.data.textFields.first?.placeholder == "File name")
    }

    @Test("dialog click emits JSON success when stub succeeds")
    func dialogClickJSON() async throws {
        let dialogService = await MainActor.run { StubDialogService() }
        dialogService.dialogElements = DialogElements(
            dialogInfo: DialogInfo(
                title: "Open",
                role: "AXWindow",
                subrole: "AXDialog",
                isFileDialog: true,
                bounds: .init(x: 0, y: 0, width: 400, height: 300)
            ),
            buttons: [
                DialogButton(title: "New Document"),
            ],
            textFields: [],
            staticTexts: []
        )
        dialogService.clickButtonResult = DialogActionResult(
            success: true,
            action: .clickButton,
            details: ["button": "New Document", "window": "Open"]
        )
        let services = self.makeTestServices(dialogs: dialogService)

        let (output, status) = try await self.runCommand(
            ["dialog", "click", "--button", "New Document", "--json"],
            services: services
        )
        #expect(status == 0)

        let data = try #require(output.data(using: .utf8))
        struct DialogClickPayload: Codable {
            let action: String
            let button: String
            let window: String
        }

        let response = try JSONDecoder().decode(CodableJSONResponse<DialogClickPayload>.self, from: data)
        #expect(response.success == true)
        #expect(response.data.button == "New Document")
        #expect(dialogService.recordedButtonClicks.count == 1)
        #expect(dialogService.recordedButtonClicks.first?.button == "New Document")
    }

    @Test("dialog input maps noActiveDialog to NO_ACTIVE_DIALOG")
    func dialogInputMapsNoActiveDialog() async throws {
        let services = self.makeTestServices(dialogs: StubDialogService(elements: nil))
        let result = try await InProcessCommandRunner.run(
            ["dialog", "input", "--text", "Hello", "--json"],
            services: services
        )
        let output = result.stdout.isEmpty ? result.stderr : result.stdout

        let data = try #require(output.data(using: .utf8))
        let response = try JSONDecoder().decode(JSONResponse.self, from: data)
        #expect(response.success == false)
        #expect(response.error?.code == "NO_ACTIVE_DIALOG")
    }

    @Test("dialog input maps fieldNotFound to ELEMENT_NOT_FOUND")
    func dialogInputMapsFieldNotFound() async throws {
        let elements = DialogElements(
            dialogInfo: DialogInfo(
                title: "Save",
                role: "AXWindow",
                subrole: "AXDialog",
                isFileDialog: true,
                bounds: .init(x: 0, y: 0, width: 400, height: 300)
            ),
            buttons: [],
            textFields: [],
            staticTexts: []
        )
        let dialogService = StubDialogService(elements: elements)
        let services = self.makeTestServices(dialogs: dialogService)

        let result = try await InProcessCommandRunner.run(
            ["dialog", "input", "--text", "Hello", "--field", "Filename", "--json"],
            services: services
        )
        let output = result.stdout.isEmpty ? result.stderr : result.stdout

        let data = try #require(output.data(using: .utf8))
        let response = try JSONDecoder().decode(JSONResponse.self, from: data)
        #expect(response.success == false)
        #expect(response.error?.code == "ELEMENT_NOT_FOUND")
    }

    @Test("dialog file maps noFileDialog to ELEMENT_NOT_FOUND")
    func dialogFileMapsNoFileDialog() async throws {
        let elements = DialogElements(
            dialogInfo: DialogInfo(
                title: "Preferences",
                role: "AXWindow",
                subrole: "AXDialog",
                isFileDialog: false,
                bounds: .init(x: 0, y: 0, width: 400, height: 300)
            ),
            buttons: [],
            textFields: [],
            staticTexts: []
        )
        let dialogService = StubDialogService(elements: elements)
        let services = self.makeTestServices(dialogs: dialogService)

        let result = try await InProcessCommandRunner.run(
            ["dialog", "file", "--path", "/tmp", "--name", "test.txt", "--select", "Save", "--json"],
            services: services
        )
        let output = result.stdout.isEmpty ? result.stderr : result.stdout

        let data = try #require(output.data(using: .utf8))
        let response = try JSONDecoder().decode(JSONResponse.self, from: data)
        #expect(response.success == false)
        #expect(response.error?.code == "ELEMENT_NOT_FOUND")
    }

    @Test("dialog maps invalidFieldIndex to INVALID_INPUT")
    func dialogMapsInvalidFieldIndex() async throws {
        @MainActor
        struct InvalidIndexDialogService: DialogServiceProtocol {
            func findActiveDialog(
                windowTitle: String?,
                appName: String?
            ) async throws -> DialogInfo { throw DialogError.noActiveDialog }
            func clickButton(
                buttonText: String,
                windowTitle: String?,
                appName: String?
            ) async throws -> DialogActionResult { throw DialogError.noActiveDialog }
            func enterText(
                text: String,
                fieldIdentifier: String?,
                clearExisting: Bool,
                windowTitle: String?,
                appName: String?
            ) async throws -> DialogActionResult {
                throw DialogError.invalidFieldIndex
            }

            func handleFileDialog(
                path: String?,
                filename: String?,
                actionButton: String?,
                ensureExpanded: Bool,
                appName: String?
            ) async throws -> DialogActionResult { throw DialogError.noActiveDialog }
            func dismissDialog(
                force: Bool,
                windowTitle: String?,
                appName: String?
            ) async throws -> DialogActionResult { throw DialogError.noActiveDialog }
            func listDialogElements(
                windowTitle: String?,
                appName: String?
            ) async throws -> DialogElements { throw DialogError.noActiveDialog }
        }

        let services = self.makeTestServices(dialogs: InvalidIndexDialogService())
        let result = try await InProcessCommandRunner.run(
            ["dialog", "input", "--text", "Hello", "--index", "5", "--json"],
            services: services
        )
        let output = result.stdout.isEmpty ? result.stderr : result.stdout

        let data = try #require(output.data(using: .utf8))
        let response = try JSONDecoder().decode(JSONResponse.self, from: data)
        #expect(response.success == false)
        #expect(response.error?.code == "INVALID_INPUT")
    }

    private struct CommandFailure: Error {
        let status: Int32
        let stderr: String
    }

    private func runCommand(_ args: [String]) async throws -> (output: String, status: Int32) {
        let services = self.makeTestServices()
        return try await self.runCommand(args, services: services)
    }

    private func runCommand(
        _ args: [String],
        services: PeekabooServices
    ) async throws -> (output: String, status: Int32) {
        let result = try await InProcessCommandRunner.run(args, services: services)
        let output = result.stdout.isEmpty ? result.stderr : result.stdout
        if result.exitStatus != 0 {
            throw CommandFailure(status: result.exitStatus, stderr: output)
        }
        return (output, result.exitStatus)
    }

    @MainActor
    private func makeTestServices(
        dialogs: any DialogServiceProtocol = StubDialogService()
    ) -> PeekabooServices {
        TestServicesFactory.makePeekabooServices(dialogs: dialogs)
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
        let output = try await runAutomationCommand([
            "dialog", "list",
            "--json",
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
            from: Data(output.utf8)
        ) {
            if response.success {
                #expect(!response.data.title.isEmpty)
                #expect(!response.data.buttons.isEmpty)
            }
        } else {
            // Otherwise it's an error response
            let errorResponse = try JSONDecoder().decode(JSONResponse.self, from: Data(output.utf8))
            #expect(errorResponse.error?.code == "NO_ACTIVE_DIALOG")
        }
    }

    @Test("Dialog  click workflow")
    func dialogClickWorkflow() async throws {
        // This would click a button if a dialog is present
        let output = try await runAutomationCommand([
            "dialog", "click",
            "--button", "OK",
            "--json",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: Data(output.utf8))
        if !data.success {
            // Expected if no dialog is open
            #expect(data.error?.code == "NO_ACTIVE_DIALOG")
        }
    }

    @Test("Dialog  input workflow")
    func dialogInputWorkflow() async throws {
        let output = try await runAutomationCommand([
            "dialog", "input",
            "--text", "Test input",
            "--field", "Name",
            "--json",
        ])

        let data = try JSONDecoder().decode(JSONResponse.self, from: Data(output.utf8))
        if !data.success {
            // Expected if no dialog is open
            #expect(data.error?.code == "NO_ACTIVE_DIALOG")
        }
    }

    @Test("Dialog  dismiss with escape")
    func dialogDismissEscape() async throws {
        let output = try await runAutomationCommand([
            "dialog", "dismiss",
            "--force",
            "--json",
        ])

        struct DialogDismissResult: Codable {
            let action: String
            let method: String
            let button: String?
        }

        if let response = try? JSONDecoder().decode(
            CodableJSONResponse<DialogDismissResult>.self,
            from: Data(output.utf8)
        ) {
            if response.success {
                #expect(response.data.method == "escape")
            }
        }
    }

    @Test("File dialog  handling")
    func fileDialogHandling() async throws {
        let output = try await runAutomationCommand([
            "dialog", "file",
            "--path", "/tmp",
            "--name", "test.txt",
            "--select", "Save",
            "--json",
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
            from: Data(output.utf8)
        ) {
            if response.success {
                #expect(response.data.action == "file_dialog")
                #expect(response.data.path == "/tmp")
                #expect(response.data.name == "test.txt")
            }
        } else {
            // Otherwise it's an error response
            let errorResponse = try JSONDecoder().decode(JSONResponse.self, from: Data(output.utf8))
            #expect(
                errorResponse.error?.code == "NO_ACTIVE_DIALOG" ||
                    errorResponse.error?.code == "ELEMENT_NOT_FOUND"
            )
        }
    }
}

// MARK: - Test Helpers

private func runAutomationCommand(
    _ args: [String],
    allowedExitStatuses: Set<Int32> = [0, 1, 64]
) async throws -> String {
    let result = try await InProcessCommandRunner.runShared(
        args,
        allowedExitCodes: allowedExitStatuses
    )
    return result.combinedOutput
}
#endif
