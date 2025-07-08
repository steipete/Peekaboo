import ApplicationServices
import ArgumentParser
import AXorcist
import Foundation
import PeekabooCore

/// Refactored DialogCommand using PeekabooCore services
///
/// This version delegates dialog management to the service layer
/// while maintaining the same command interface and JSON output compatibility.
struct DialogCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dialog",
        abstract: "Interact with system dialogs and alerts using PeekabooCore services",
        discussion: """
        This is a refactored version of the dialog command that uses PeekabooCore services
        instead of direct implementation. It maintains the same interface but delegates
        dialog detection and interaction to the service layer.

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
        ])

    // MARK: - Click Dialog Button

    struct ClickSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "click",
            abstract: "Click a button in a dialog using DialogService")

        @Option(help: "Button text to click (e.g., 'OK', 'Cancel', 'Save')")
        var button: String

        @Option(help: "Specific window/sheet title to target")
        var window: String?

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        private let services = PeekabooServices.shared

        @MainActor
        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(jsonOutput)

            do {
                // Click the button using the service
                let result = try await services.dialogs.clickButton(
                    buttonText: button,
                    windowTitle: window
                )

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: result.success,
                        data: AnyCodable([
                            "action": "dialog_click",
                            "button": result.details["button"] ?? button,
                            "window": result.details["window"] ?? "Dialog",
                        ]))
                    outputJSON(response)
                } else {
                    print("✓ Clicked '\(result.details["button"] ?? button)' button")
                }

            } catch let error as DialogError {
                handleDialogServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Input Text in Dialog

    struct InputSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "input",
            abstract: "Enter text in a dialog field using DialogService")

        @Option(help: "Text to enter")
        var text: String

        @Option(help: "Field label or placeholder to target")
        var field: String?

        @Option(help: "Field index (0-based) if multiple fields")
        var index: Int?

        @Flag(help: "Clear existing text first")
        var clear = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        private let services = PeekabooServices.shared

        @MainActor
        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(jsonOutput)

            do {
                // Determine field identifier (index or label)
                let fieldIdentifier = field ?? index.map { String($0) }

                // Enter text using the service
                let result = try await services.dialogs.enterText(
                    text: text,
                    fieldIdentifier: fieldIdentifier,
                    clearExisting: clear,
                    windowTitle: nil
                )

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: result.success,
                        data: AnyCodable([
                            "action": "dialog_input",
                            "field": result.details["field"] ?? "Text Field",
                            "text_length": result.details["text_length"] ?? String(text.count),
                            "cleared": result.details["cleared"] ?? String(clear),
                        ]))
                    outputJSON(response)
                } else {
                    print("✓ Entered text in '\(result.details["field"] ?? "field")'")
                }

            } catch let error as DialogError {
                handleDialogServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Handle File Dialog

    struct FileSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "file",
            abstract: "Handle file save/open dialogs using DialogService")

        @Option(help: "Full file path to navigate to")
        var path: String?

        @Option(help: "File name to enter (for save dialogs)")
        var name: String?

        @Option(help: "Button to click after entering path/name")
        var select: String = "Save"

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        private let services = PeekabooServices.shared

        @MainActor
        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(jsonOutput)

            do {
                // Handle file dialog using the service
                let result = try await services.dialogs.handleFileDialog(
                    path: path,
                    filename: name,
                    actionButton: select
                )

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: result.success,
                        data: AnyCodable([
                            "action": "file_dialog",
                            "path": result.details["path"],
                            "name": result.details["filename"],
                            "button_clicked": result.details["button_clicked"] ?? select,
                        ]))
                    outputJSON(response)
                } else {
                    print("✓ Handled file dialog")
                    if let p = result.details["path"] { print("  Path: \(p)") }
                    if let n = result.details["filename"] { print("  Name: \(n)") }
                    print("  Action: \(result.details["button_clicked"] ?? select)")
                }

            } catch let error as DialogError {
                handleDialogServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - Dismiss Dialog

    struct DismissSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "dismiss",
            abstract: "Dismiss a dialog using DialogService")

        @Flag(help: "Force dismiss with Escape key")
        var force = false

        @Option(help: "Specific window/sheet title to target")
        var window: String?

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        private let services = PeekabooServices.shared

        @MainActor
        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(jsonOutput)

            do {
                // Dismiss dialog using the service
                let result = try await services.dialogs.dismissDialog(
                    force: force,
                    windowTitle: window
                )

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: result.success,
                        data: AnyCodable([
                            "action": "dialog_dismiss",
                            "method": result.details["method"] ?? "unknown",
                            "button": result.details["button"],
                        ]))
                    outputJSON(response)
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
                handleDialogServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            }
        }
    }

    // MARK: - List Dialog Elements

    struct ListSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List elements in current dialog using DialogService")

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        private let services = PeekabooServices.shared

        @MainActor
        func run() async throws {
            Logger.shared.setJsonOutputMode(jsonOutput)

            do {
                // List dialog elements using the service
                let elements = try await services.dialogs.listDialogElements(windowTitle: nil)

                // Prepare dialog info for output
                var dialogInfo: [String: Any] = [
                    "title": elements.dialogInfo.title,
                    "role": elements.dialogInfo.role,
                ]

                // Add buttons
                dialogInfo["buttons"] = elements.buttons.map { $0.title }

                // Add text fields
                dialogInfo["text_fields"] = elements.textFields.map { field in
                    [
                        "title": field.title ?? "",
                        "value": field.value ?? "",
                        "placeholder": field.placeholder ?? "",
                    ]
                }

                // Add static texts
                dialogInfo["text_elements"] = elements.staticTexts

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable(dialogInfo))
                    outputJSON(response)
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
                handleDialogServiceError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
                throw ExitCode(1)
            }
        }
    }
}

// MARK: - Error Handling

private func handleDialogServiceError(_ error: DialogError, jsonOutput: Bool) {
    let errorCode: String
    switch error {
    case .noActiveDialog:
        errorCode = "NO_ACTIVE_DIALOG"
    case .noFileDialog:
        errorCode = "NO_FILE_DIALOG"
    case .buttonNotFound:
        errorCode = "BUTTON_NOT_FOUND"
    case .fieldNotFound:
        errorCode = "FIELD_NOT_FOUND"
    case .invalidFieldIndex:
        errorCode = "INVALID_FIELD_INDEX"
    case .noTextFields:
        errorCode = "NO_TEXT_FIELDS"
    case .noDismissButton:
        errorCode = "NO_DISMISS_BUTTON"
    }

    if jsonOutput {
        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: ErrorCode(rawValue: errorCode) ?? .UNKNOWN_ERROR))
        outputJSON(response)
    } else {
        fputs("❌ \(error.localizedDescription)\n", stderr)
    }
}

private func handleGenericError(_ error: Error, jsonOutput: Bool) {
    if jsonOutput {
        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: .UNKNOWN_ERROR))
        outputJSON(response)
    } else {
        fputs("❌ Error: \(error.localizedDescription)\n", stderr)
    }
}