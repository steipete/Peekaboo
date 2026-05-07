import Commander
import Foundation
import PeekabooCore

extension DialogCommand {
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

        private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var outputLogger: Logger {
            self.logger
        }

        var jsonOutput: Bool {
            self.resolvedRuntime.configuration.jsonOutput
        }

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
                let result = try await self.services.dialogs.dismissDialog(
                    force: self.force,
                    windowTitle: resolvedWindowTitle,
                    appName: appHint
                )

                if self.jsonOutput {
                    let outputData = DialogDismissResult(
                        action: "dialog_dismiss",
                        method: result.details["method"] ?? "unknown",
                        button: result.details["button"]
                    )
                    outputSuccessCodable(data: outputData, logger: self.outputLogger)
                } else if result.details["method"] == "escape" {
                    print("✓ Dismissed dialog with Escape")
                } else if let button = result.details["button"] {
                    print("✓ Dismissed dialog by clicking '\(button)'")
                } else {
                    print("✓ Dismissed dialog")
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

        private var services: any PeekabooServiceProviding {
            self.resolvedRuntime.services
        }

        private var logger: Logger {
            self.resolvedRuntime.logger
        }

        var outputLogger: Logger {
            self.logger
        }

        var jsonOutput: Bool {
            self.resolvedRuntime.configuration.jsonOutput
        }

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
                let elements = try await self.services.dialogs.listDialogElements(
                    windowTitle: resolvedWindowTitle,
                    appName: appHint
                )

                if self.jsonOutput {
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
                AutomationEventLogger.log(
                    .dialog,
                    "action=list title='\(elements.dialogInfo.title)' buttons=\(elements.buttons.count) "
                        + "text_fields=\(elements.textFields.count) app='\(appHint ?? "unknown")'"
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
}

private struct DialogDismissResult: Codable {
    let action: String
    let method: String
    let button: String?
}

private struct DialogListResult: Codable {
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
