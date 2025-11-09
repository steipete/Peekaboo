import ApplicationServices
@preconcurrency import ArgumentParser
import AXorcist
import Foundation
import PeekabooCore

/// Interact with system dialogs and alerts
@MainActor
struct DialogCommand: @MainActor MainActorAsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dialog",
        abstract: "Interact with system dialogs and alerts",
        discussion: """

        EXAMPLES:
          # Click a button in a dialog
          peekaboo dialog click --button "OK"
          peekaboo dialog click --button "Don't Save"

          # Type in a dialog text field
          peekaboo dialog input --text "password123" --field "Password"

          # Handle file dialogs
          peekaboo dialog file --path "/Users/me/Documents/file.txt"
          peekaboo dialog file --name "report.pdf" --select "Save"

          # Dismiss dialogs
          peekaboo dialog dismiss
          peekaboo dialog dismiss --force  # Press Escape
        """,
        subcommands: [
            ClickSubcommand.self,
            InputSubcommand.self,
            FileSubcommand.self,
            DismissSubcommand.self,
            ListSubcommand.self,
        ]
    )

    // MARK: - Click Dialog Button

    @MainActor
struct ClickSubcommand: @MainActor MainActorAsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "click",
            abstract: "Click a button in a dialog using DialogService"
        )

        @Option(help: "Button text to click (e.g., 'OK', 'Cancel', 'Save')")
        var button: String

    @Option(help: "Specific window/sheet title to target")
    var window: String?

        @OptionGroup var runtimeOptions: CommandRuntimeOptions

        @RuntimeStorage private var runtime: CommandRuntime?

        private var services: PeekabooServices {
            self.runtime?.services ?? PeekabooServices.shared
        }

        private var logger: Logger {
            self.runtime?.logger ?? Logger.shared
        }

        var outputLogger: Logger { self.logger }

        var jsonOutput: Bool {
            self.runtimeOptions.jsonOutput
        }

        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                // Click the button using the service
                let result = try await self.services.dialogs.clickButton(
                    buttonText: self.button,
                    windowTitle: self.window
                )

                // Output result
                if self.jsonOutput {
                    struct DialogClickResult: Codable {
                        let action: String
                        let button: String
                        let window: String
                    }

                    let outputData = DialogClickResult(
                        action: "dialog_click",
                        button: result.details["button"] ?? self.button,
                        window: result.details["window"] ?? "Dialog"
                    )
                    outputSuccessCodable(data: outputData, logger: self.outputLogger)
                } else {
                    print("✓ Clicked '\(result.details["button"] ?? self.button)' button")
                }

            } catch let error as DialogError {
                handleDialogServiceError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Input Text in Dialog

    @MainActor
struct InputSubcommand: @MainActor MainActorAsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "input",
            abstract: "Enter text in a dialog field using DialogService"
        )

        @Option(help: "Text to enter")
        var text: String

        @Option(help: "Field label or placeholder to target")
        var field: String?

        @Option(help: "Field index (0-based) if multiple fields")
        var index: Int?

        @Flag(help: "Clear existing text first")
        var clear = false

        @OptionGroup var runtimeOptions: CommandRuntimeOptions

        @RuntimeStorage private var runtime: CommandRuntime?

        private var services: PeekabooServices {
            self.runtime?.services ?? PeekabooServices.shared
        }

        private var logger: Logger {
            self.runtime?.logger ?? Logger.shared
        }

        var outputLogger: Logger { self.logger }

        var jsonOutput: Bool {
            self.runtimeOptions.jsonOutput
        }

        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                // Determine field identifier (index or label)
                let fieldIdentifier = self.field ?? self.index.map { String($0) }

                // Enter text using the service
                let result = try await self.services.dialogs.enterText(
                    text: self.text,
                    fieldIdentifier: fieldIdentifier,
                    clearExisting: self.clear,
                    windowTitle: nil
                )

                // Output result
                if self.jsonOutput {
                    struct DialogInputResult: Codable {
                        let action: String
                        let field: String
                        let textLength: String
                        let cleared: String
                    }

                    let outputData = DialogInputResult(
                        action: "dialog_input",
                        field: result.details["field"] ?? "Text Field",
                        textLength: result.details["text_length"] ?? String(self.text.count),
                        cleared: result.details["cleared"] ?? String(self.clear)
                    )
                    outputSuccessCodable(data: outputData, logger: self.outputLogger)
                } else {
                    print("✓ Entered text in '\(result.details["field"] ?? "field")'")
                }

            } catch let error as DialogError {
                handleDialogServiceError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Handle File Dialog

    @MainActor
struct FileSubcommand: @MainActor MainActorAsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "file",
            abstract: "Handle file save/open dialogs using DialogService"
        )

        @Option(help: "Full file path to navigate to")
        var path: String?

        @Option(help: "File name to enter (for save dialogs)")
        var name: String?

        @Option(help: "Button to click after entering path/name")
        var select: String = "Save"

        @OptionGroup var runtimeOptions: CommandRuntimeOptions

        @RuntimeStorage private var runtime: CommandRuntime?

        private var services: PeekabooServices {
            self.runtime?.services ?? PeekabooServices.shared
        }

        private var logger: Logger {
            self.runtime?.logger ?? Logger.shared
        }

        var outputLogger: Logger { self.logger }

        var jsonOutput: Bool {
            self.runtimeOptions.jsonOutput
        }

        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                // Handle file dialog using the service
                let result = try await self.services.dialogs.handleFileDialog(
                    path: self.path,
                    filename: self.name,
                    actionButton: self.select
                )

                // Output result
                if self.jsonOutput {
                    struct FileDialogResult: Codable {
                        let action: String
                        let path: String?
                        let name: String?
                        let buttonClicked: String
                    }

                    let outputData = FileDialogResult(
                        action: "file_dialog",
                        path: result.details["path"],
                        name: result.details["filename"],
                        buttonClicked: result.details["button_clicked"] ?? self.select
                    )
                    outputSuccessCodable(data: outputData, logger: self.outputLogger)
                } else {
                    print("✓ Handled file dialog")
                    if let p = result.details["path"] { print("  Path: \(p)") }
                    if let n = result.details["filename"] { print("  Name: \(n)") }
                    print("  Action: \(result.details["button_clicked"] ?? self.select)")
                }

            } catch let error as DialogError {
                handleDialogServiceError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Dismiss Dialog

    @MainActor
struct DismissSubcommand: @MainActor MainActorAsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "dismiss",
            abstract: "Dismiss a dialog using DialogService"
        )

        @Flag(help: "Force dismiss with Escape key")
        var force = false

        @Option(help: "Specific window/sheet title to target")
        var window: String?

        @OptionGroup var runtimeOptions: CommandRuntimeOptions

        @RuntimeStorage private var runtime: CommandRuntime?

        private var services: PeekabooServices {
            self.runtime?.services ?? PeekabooServices.shared
        }

        private var logger: Logger {
            self.runtime?.logger ?? Logger.shared
        }

        var outputLogger: Logger { self.logger }

        var jsonOutput: Bool {
            self.runtimeOptions.jsonOutput
        }

        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                // Dismiss dialog using the service
                let result = try await self.services.dialogs.dismissDialog(
                    force: self.force,
                    windowTitle: self.window
                )

                // Output result
                if self.jsonOutput {
                    struct DialogDismissResult: Codable {
                        let action: String
                        let method: String
                        let button: String?
                    }

                    let outputData = DialogDismissResult(
                        action: "dialog_dismiss",
                        method: result.details["method"] ?? "unknown",
                        button: result.details["button"]
                    )
                    outputSuccessCodable(data: outputData, logger: self.outputLogger)
                } else {
                    if result.details["method"] == "escape" {
                        print("✓ Dismissed dialog with Escape")
                    } else if let button = result.details["button"] {
                        print("✓ Dismissed dialog by clicking '\(button)'")
                    } else {
                        print("✓ Dismissed dialog")
                    }
                }

            } catch let error as DialogError {
                handleDialogServiceError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - List Dialog Elements

    @MainActor
struct ListSubcommand: @MainActor MainActorAsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List elements in current dialog using DialogService"
        )

        @OptionGroup var runtimeOptions: CommandRuntimeOptions

        @RuntimeStorage private var runtime: CommandRuntime?

        private var services: PeekabooServices {
            self.runtime?.services ?? PeekabooServices.shared
        }

        private var logger: Logger {
            self.runtime?.logger ?? Logger.shared
        }

        var outputLogger: Logger { self.logger }

        var jsonOutput: Bool {
            self.runtimeOptions.jsonOutput
        }

        @MainActor
        /// Describe the active dialog by enumerating buttons, text fields, and static text.
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                // List dialog elements using the service
                let elements = try await self.services.dialogs.listDialogElements(windowTitle: nil)

                // Output result
                if self.jsonOutput {
struct DialogListResult: Codable {
                        let title: String
                        let role: String
                        let buttons: [String]
                        let textFields: [TextField]
                        let textElements: [String]

                        struct TextField: Codable {
                            let title: String
                            let value: String
                            let placeholder: String
                        }
                    }

                    let textFields = elements.textFields.map { field in
                        DialogListResult.TextField(
                            title: field.title ?? "",
                            value: field.value ?? "",
                            placeholder: field.placeholder ?? ""
                        )
                    }

                    let outputData = DialogListResult(
                        title: elements.dialogInfo.title,
                        role: elements.dialogInfo.role,
                        buttons: elements.buttons.map(\.title),
                        textFields: textFields,
                        textElements: elements.staticTexts
                    )
                    outputSuccessCodable(data: outputData, logger: self.outputLogger)
                } else {
                    print("Dialog: \(elements.dialogInfo.title)")

                    if !elements.buttons.isEmpty {
                        print("\nButtons:")
                        elements.buttons.forEach { print("  • \($0.title)") }
                    }

                    if !elements.textFields.isEmpty {
                        print("\nText Fields:")
                        for field in elements.textFields {
                            let title = field.title ?? "Untitled"
                            let placeholder = field.placeholder ?? ""
                            print("  • \(title) [\(placeholder)]")
                        }
                    }

                    if !elements.staticTexts.isEmpty {
                        print("\nText:")
                        elements.staticTexts.forEach { print("  \($0)") }
                    }
                }

            } catch let error as DialogError {
                handleDialogServiceError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
                throw ExitCode(1)
            }
        }
    }
}

@MainActor
extension DialogCommand.ClickSubcommand: AsyncRuntimeCommand {}

@MainActor
extension DialogCommand.InputSubcommand: AsyncRuntimeCommand {}

@MainActor
extension DialogCommand.FileSubcommand: AsyncRuntimeCommand {}

@MainActor
extension DialogCommand.DismissSubcommand: AsyncRuntimeCommand {}

@MainActor
extension DialogCommand.ListSubcommand: AsyncRuntimeCommand {}

// MARK: - Error Handling

private func handleDialogServiceError(_ error: DialogError, jsonOutput: Bool, logger: Logger) {
    let errorCode: ErrorCode = switch error {
    case .noActiveDialog:
        .NO_ACTIVE_DIALOG
    case .dialogNotFound:
        .ELEMENT_NOT_FOUND
    case .noFileDialog:
        .ELEMENT_NOT_FOUND
    case .buttonNotFound:
        .ELEMENT_NOT_FOUND
    case .fieldNotFound:
        .ELEMENT_NOT_FOUND
    case .invalidFieldIndex:
        .INVALID_INPUT
    case .noTextFields:
        .ELEMENT_NOT_FOUND
    case .noDismissButton:
        .ELEMENT_NOT_FOUND
    }

    if jsonOutput {
        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: errorCode
            )
        )
        outputJSON(response, logger: logger)
    } else {
        fputs("❌ \(error.localizedDescription)\n", stderr)
    }
}
