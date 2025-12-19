import AXorcist
import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Interact with system dialogs and alerts
@MainActor
struct DialogCommand: ParsableCommand {
    static let commandDescription = CommandDescription(
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
          peekaboo dialog file --path "/Users/me/Documents" --name "report.pdf" --select "Save"
          peekaboo dialog file --app TextEdit --window-title "Untitled" --path "/tmp" --name "poem.rtf" --select default

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
        ],
        showHelpOnEmptyInvocation: true
    )

    // MARK: - Click Dialog Button

    @MainActor

    struct ClickSubcommand {
        @Option(help: "Button text to click (e.g., 'OK', 'Cancel', 'Save')")
        var button: String

        @OptionGroup var target: InteractionTargetOptions
        @OptionGroup var focusOptions: FocusCommandOptions
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try self.target.validate()
                try await ensureFocused(
                    snapshotId: nil,
                    target: self.target,
                    options: self.focusOptions,
                    services: self.services
                )

                let resolvedWindowTitle = try await self.target.resolveWindowTitleOptional(services: self.services)
                let appHint = try await DialogCommand.resolveDialogAppHint(target: self.target, services: self.services)

                // Click the button using the service
                let result = try await self.services.dialogs.clickButton(
                    buttonText: self.button,
                    windowTitle: resolvedWindowTitle,
                    appName: appHint
                )

                // Output result
                if self.jsonOutput {
                    struct DialogClickResult: Codable {
                        let action: String
                        let button: String
                        let buttonIdentifier: String?
                        let window: String

                        enum CodingKeys: String, CodingKey {
                            case action
                            case button
                            case buttonIdentifier = "button_identifier"
                            case window
                        }
                    }

                    let outputData = DialogClickResult(
                        action: "dialog_click",
                        button: result.details["button"] ?? self.button,
                        buttonIdentifier: result.details["button_identifier"],
                        window: result.details["window"] ?? "Dialog"
                    )
                    outputSuccessCodable(data: outputData, logger: self.outputLogger)
                } else {
                    print("✓ Clicked '\(result.details["button"] ?? self.button)' button")
                }
                AutomationEventLogger.log(
                    .dialog,
                    "action=click button='\(result.details["button"] ?? self.button)' "
                        + "window='\(result.details["window"] ?? resolvedWindowTitle ?? "unknown")' "
                        + "app='\(appHint ?? "unknown")'"
                )

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
    struct InputSubcommand {
        static let commandDescription = CommandDescription(
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

        @OptionGroup var target: InteractionTargetOptions
        @OptionGroup var focusOptions: FocusCommandOptions
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try self.target.validate()
                try await ensureFocused(
                    snapshotId: nil,
                    target: self.target,
                    options: self.focusOptions,
                    services: self.services
                )

                let resolvedWindowTitle = try await self.target.resolveWindowTitleOptional(services: self.services)
                let appHint = try await DialogCommand.resolveDialogAppHint(target: self.target, services: self.services)

                // Determine field identifier (index or label)
                let fieldIdentifier = self.field ?? self.index.map { String($0) }

                // Enter text using the service
                let result = try await self.services.dialogs.enterText(
                    text: self.text,
                    fieldIdentifier: fieldIdentifier,
                    clearExisting: self.clear,
                    windowTitle: resolvedWindowTitle,
                    appName: appHint
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
                let fieldDescription = result.details["field"]
                    ?? self.field
                    ?? self.index.map { "index \($0)" }
                    ?? "field"
                let textLength = result.details["text_length"] ?? String(self.text.count)
                let clearedValue = result.details["cleared"] ?? String(self.clear)
                AutomationEventLogger.log(
                    .dialog,
                    "action=input field='\(fieldDescription)' chars=\(textLength) "
                        + "cleared=\(clearedValue) app='\(appHint ?? "unknown")'"
                )

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
    struct FileSubcommand {
        static let commandDescription = CommandDescription(
            commandName: "file",
            abstract: "Handle file save/open dialogs using DialogService"
        )

        @Option(help: "Full file path to navigate to")
        var path: String?

        @Option(help: "File name to enter (for save dialogs)")
        var name: String?

        @Option(help: "Button to click after entering path/name. Omit (or pass 'default') to click the OKButton.")
        var select: String?

        @Flag(name: .long, help: "Ensure file dialogs are expanded (Show Details) before setting --path")
        var ensureExpanded = false

        @OptionGroup var target: InteractionTargetOptions
        @OptionGroup var focusOptions: FocusCommandOptions
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try self.target.validate()
                try await ensureFocused(
                    snapshotId: nil,
                    target: self.target,
                    options: self.focusOptions,
                    services: self.services
                )

                let appHint = try await DialogCommand.resolveDialogAppHint(target: self.target, services: self.services)

                // Handle file dialog using the service
                let result = try await self.services.dialogs.handleFileDialog(
                    path: self.path,
                    filename: self.name,
                    actionButton: self.select,
                    ensureExpanded: self.ensureExpanded,
                    appName: appHint
                )

                // Output result
                if self.jsonOutput {
                    struct FileDialogResult: Codable {
                        let action: String
                        let dialogIdentifier: String?
                        let foundVia: String?
                        let path: String?
                        let pathNavigationMethod: String?
                        let name: String?
                        let buttonClicked: String
                        let buttonIdentifier: String?
                        let savedPath: String?
                        let savedPathVerified: Bool
                        let savedPathFoundVia: String?
                        let savedPathMatchesExpected: Bool?
                        let savedPathExpected: String?
                        let savedPathMatchesExpectedDirectory: Bool?
                        let savedPathExpectedDirectory: String?
                        let savedPathDirectory: String?
                        let overwriteConfirmed: Bool?
                        let ensureExpanded: Bool?

                        enum CodingKeys: String, CodingKey {
                            case action
                            case dialogIdentifier = "dialog_identifier"
                            case foundVia = "found_via"
                            case path
                            case pathNavigationMethod = "path_navigation_method"
                            case name
                            case buttonClicked
                            case buttonIdentifier = "button_identifier"
                            case savedPath
                            case savedPathVerified
                            case savedPathFoundVia = "saved_path_found_via"
                            case savedPathMatchesExpected = "saved_path_matches_expected"
                            case savedPathExpected = "saved_path_expected"
                            case savedPathMatchesExpectedDirectory = "saved_path_matches_expected_directory"
                            case savedPathExpectedDirectory = "saved_path_expected_directory"
                            case savedPathDirectory = "saved_path_directory"
                            case overwriteConfirmed = "overwrite_confirmed"
                            case ensureExpanded = "ensure_expanded"
                        }
                    }

                    let savedPathVerified =
                        result.details["saved_path_verified"] == "true" || result.details["saved_path_exists"] == "true"

                    let outputData = FileDialogResult(
                        action: "file_dialog",
                        dialogIdentifier: result.details["dialog_identifier"],
                        foundVia: result.details["found_via"],
                        path: result.details["path"],
                        pathNavigationMethod: result.details["path_navigation_method"],
                        name: result.details["filename"],
                        buttonClicked: result.details["button_clicked"] ?? self.select ?? "default",
                        buttonIdentifier: result.details["button_identifier"],
                        savedPath: result.details["saved_path"],
                        savedPathVerified: savedPathVerified,
                        savedPathFoundVia: result.details["saved_path_found_via"],
                        savedPathMatchesExpected: result.details["saved_path_matches_expected"].map { $0 == "true" },
                        savedPathExpected: result.details["saved_path_expected"],
                        savedPathMatchesExpectedDirectory: result.details["saved_path_matches_expected_directory"]
                            .map { $0 == "true" },
                        savedPathExpectedDirectory: result.details["saved_path_expected_directory"],
                        savedPathDirectory: result.details["saved_path_directory"],
                        overwriteConfirmed: result.details["overwrite_confirmed"].map { $0 == "true" },
                        ensureExpanded: result.details["ensure_expanded"].map { $0 == "true" }
                    )
                    outputSuccessCodable(data: outputData, logger: self.outputLogger)
                } else {
                    print("✓ Handled file dialog")
                    if let p = result.details["path"] { print("  Path: \(p)") }
                    if let n = result.details["filename"] { print("  Name: \(n)") }
                    print("  Action: \(result.details["button_clicked"] ?? self.select ?? "default")")
                    if let savedPath = result.details["saved_path"], result.details["saved_path_exists"] == "true" {
                        print("  Saved: \(savedPath)")
                    }
                }
                let resolvedPath = result.details["path"] ?? self.path ?? "unknown"
                let resolvedName = result.details["filename"] ?? self.name ?? "unknown"
                let buttonClicked = result.details["button_clicked"] ?? self.select ?? "default"
                let savedPath = result.details["saved_path"] ?? "unknown"
                let savedPathVerified = result.details["saved_path_exists"] ?? "unknown"
                AutomationEventLogger.log(
                    .dialog,
                    "action=file path='\(resolvedPath)' name='\(resolvedName)' "
                        + "button='\(buttonClicked)' saved_path='\(savedPath)' "
                        + "saved_path_verified=\(savedPathVerified) app='\(appHint ?? "unknown")'"
                )

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
    struct DismissSubcommand {
        static let commandDescription = CommandDescription(
            commandName: "dismiss",
            abstract: "Dismiss a dialog using DialogService"
        )

        @Flag(help: "Force dismiss with Escape key")
        var force = false

        @OptionGroup var target: InteractionTargetOptions
        @OptionGroup var focusOptions: FocusCommandOptions
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try self.target.validate()
                try await ensureFocused(
                    snapshotId: nil,
                    target: self.target,
                    options: self.focusOptions,
                    services: self.services
                )

                let resolvedWindowTitle = try await self.target.resolveWindowTitleOptional(services: self.services)
                let appHint = try await DialogCommand.resolveDialogAppHint(target: self.target, services: self.services)

                // Dismiss dialog using the service
                let result = try await self.services.dialogs.dismissDialog(
                    force: self.force,
                    windowTitle: resolvedWindowTitle,
                    appName: appHint
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
                let method = result.details["method"] ?? (self.force ? "escape" : "button")
                let dismissedButton = result.details["button"] ?? "none"
                AutomationEventLogger.log(
                    .dialog,
                    "action=dismiss method=\(method) button='\(dismissedButton)' "
                        + "app='\(appHint ?? "unknown")'"
                )

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
    struct ListSubcommand {
        static let commandDescription = CommandDescription(
            commandName: "list",
            abstract: "List elements in current dialog using DialogService"
        )

        @OptionGroup var target: InteractionTargetOptions
        @OptionGroup var focusOptions: FocusCommandOptions
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        /// Describe the active dialog by enumerating buttons, text fields, and static text.
        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try self.target.validate()
                try await ensureFocused(
                    snapshotId: nil,
                    target: self.target,
                    options: self.focusOptions,
                    services: self.services
                )

                let resolvedWindowTitle = try await self.target.resolveWindowTitleOptional(services: self.services)
                let appHint = try await DialogCommand.resolveDialogAppHint(target: self.target, services: self.services)

                // List dialog elements using the service
                let elements = try await self.services.dialogs.listDialogElements(
                    windowTitle: resolvedWindowTitle,
                    appName: appHint
                )

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
                let buttonCount = elements.buttons.count
                let textFieldCount = elements.textFields.count
                AutomationEventLogger.log(
                    .dialog,
                    "action=list title='\(elements.dialogInfo.title)' buttons=\(buttonCount) "
                        + "text_fields=\(textFieldCount) app='\(appHint ?? "unknown")'"
                )

            } catch let error as DialogError {
                handleDialogServiceError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
                throw ExitCode(1)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput, logger: self.outputLogger)
                throw ExitCode(1)
            }
        }
    }

    @MainActor
    private static func resolveDialogAppHint(
        target: InteractionTargetOptions,
        services: any PeekabooServiceProviding
    ) async throws -> String? {
        if let app = target.app, !app.isEmpty, !app.hasPrefix("PID:") {
            return app
        }

        guard let pid = target.pid else {
            return nil
        }

        let apps = try await services.applications.listApplications()
        guard let match = apps.data.applications.first(where: { $0.processIdentifier == pid }) else {
            return nil
        }

        return match.bundleIdentifier ?? match.name
    }
}

@MainActor
extension DialogCommand.InputSubcommand: ParsableCommand {}
extension DialogCommand.InputSubcommand: AsyncRuntimeCommand {}

@MainActor
extension DialogCommand.InputSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.text = try values.requireOption("text", as: String.self)
        self.field = values.singleOption("field")
        self.index = try values.decodeOption("index", as: Int.self)
        self.clear = values.flag("clear")
        try values.fillInteractionTargetOptions(into: &self.target)
        self.focusOptions = try values.makeFocusOptions()
    }
}

@MainActor
extension DialogCommand.FileSubcommand: ParsableCommand {}
extension DialogCommand.FileSubcommand: AsyncRuntimeCommand {}

@MainActor
extension DialogCommand.FileSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.path = values.singleOption("path")
        self.name = values.singleOption("name")
        self.select = values.singleOption("select")
        self.ensureExpanded = values.flag("ensureExpanded")
        try values.fillInteractionTargetOptions(into: &self.target)
        self.focusOptions = try values.makeFocusOptions()
    }
}

@MainActor
extension DialogCommand.DismissSubcommand: ParsableCommand {}
extension DialogCommand.DismissSubcommand: AsyncRuntimeCommand {}

@MainActor
extension DialogCommand.DismissSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.force = values.flag("force")
        try values.fillInteractionTargetOptions(into: &self.target)
        self.focusOptions = try values.makeFocusOptions()
    }
}

@MainActor
extension DialogCommand.ListSubcommand: ParsableCommand {}
extension DialogCommand.ListSubcommand: AsyncRuntimeCommand {}

@MainActor
extension DialogCommand.ListSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        try values.fillInteractionTargetOptions(into: &self.target)
        self.focusOptions = try values.makeFocusOptions()
    }
}

@MainActor
extension DialogCommand.ClickSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "click",
                abstract: "Click a button in a dialog using DialogService"
            )
        }
    }
}

extension DialogCommand.ClickSubcommand: AsyncRuntimeCommand {}

@MainActor
extension DialogCommand.ClickSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.button = try values.requireOption("button", as: String.self)
        try values.fillInteractionTargetOptions(into: &self.target)
        self.focusOptions = try values.makeFocusOptions()
    }
}

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
    case .fileVerificationFailed:
        .FILE_IO_ERROR
    case .fileSavedToUnexpectedDirectory:
        .FILE_IO_ERROR
    }

    if jsonOutput {
        let details: String? = switch error {
        case let .fileVerificationFailed(expectedPath):
            "expected_path=\(expectedPath)"
        case let .fileSavedToUnexpectedDirectory(expectedDirectory, actualDirectory, actualPath):
            "expected_directory=\(expectedDirectory) actual_directory=\(actualDirectory) actual_path=\(actualPath)"
        default:
            nil
        }
        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: errorCode,
                details: details
            )
        )
        outputJSON(response, logger: logger)
    } else {
        fputs("❌ \(error.localizedDescription)\n", stderr)
    }
}
