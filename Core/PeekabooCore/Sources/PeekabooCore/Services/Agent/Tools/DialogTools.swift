import AXorcist
import CoreGraphics
import Foundation
import Tachikoma

// MARK: - Tool Definitions

@available(macOS 14.0, *)
public struct DialogToolDefinitions {
    public static let dialogClick = UnifiedToolDefinition(
        name: "dialog_click",
        commandName: "dialog-click",
        abstract: "Click a button in a dialog, sheet, or alert",
        discussion: """
            Clicks a button in any open dialog, sheet, or alert window by matching
            the button label text.

            EXAMPLES:
              peekaboo dialog-click OK
              peekaboo dialog-click Save --app TextEdit
              peekaboo dialog-click "Don't Save"
        """,
        category: .menu,
        parameters: [
            ParameterDefinition(
                name: "button",
                type: .string,
                description: "Button label to click (e.g., 'OK', 'Cancel', 'Save')",
                required: true,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .argument)),
            ParameterDefinition(
                name: "app",
                type: .string,
                description: "Application name (defaults to frontmost app)",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
        ],
        examples: [
            #"{"button": "OK"}"#,
            #"{"button": "Save", "app": "TextEdit"}"#,
            #"{"button": "Don't Save"}"#,
        ],
        agentGuidance: """
            AGENT TIPS:
            - Button labels are case-sensitive
            - Common buttons: OK, Cancel, Save, Don't Save, Continue
            - Works with alerts, sheets, and modal dialogs
            - If multiple dialogs are open, clicks in the frontmost one
            - Some buttons may have keyboard shortcuts (shown in parentheses)
        """)

    public static let dialogInput = UnifiedToolDefinition(
        name: "dialog_input",
        commandName: "dialog-input",
        abstract: "Enter text into a field in a dialog or sheet",
        discussion: """
            Types text into the currently focused text field in a dialog,
            sheet, or form. Can optionally clear the field first.

            EXAMPLES:
              peekaboo dialog-input "My Document Name"
              peekaboo dialog-input "password123" --no-clear
              peekaboo dialog-input "new-file.txt" --app Finder
        """,
        category: .menu,
        parameters: [
            ParameterDefinition(
                name: "text",
                type: .string,
                description: "Text to enter",
                required: true,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .argument)),
            ParameterDefinition(
                name: "field",
                type: .string,
                description: "Field label or placeholder text (not yet implemented)",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "app",
                type: .string,
                description: "Application name (defaults to frontmost app)",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "no-clear",
                type: .boolean,
                description: "Don't clear the field before typing",
                required: false,
                defaultValue: "false",
                options: nil,
                cliOptions: CLIOptions(argumentType: .flag, longName: "no-clear")),
        ],
        examples: [
            #"{"text": "My Document"}"#,
            #"{"text": "password123", "clear_first": false}"#,
            #"{"text": "report.pdf", "app": "Preview"}"#,
        ],
        agentGuidance: """
            AGENT TIPS:
            - By default, clears the field first (Cmd+A, Delete)
            - Use clear_first: false to append to existing text
            - Field must be focused before using this command
            - For password fields, the text won't be visible
            - Tab between fields or click to focus specific fields first
        """)
}

// MARK: - Dialog Tools

/// Dialog interaction tools for clicking buttons and entering text in dialogs
@available(macOS 14.0, *)
extension PeekabooAgentService {
    /// Create the dialog click tool
    func createDialogClickTool() -> Tool<PeekabooServices> {
        let definition = DialogToolDefinitions.dialogClick

        return createTool(
            name: definition.name,
            description: definition.agentDescription,
            parameters: definition.toAgentParameters(),
            execute: { params, context in
                let buttonLabel = try params.string("button")
                let appName = params.string("app", default: nil)

                // Get the frontmost app if not specified
                let targetApp: String
                if let appName = appName {
                    targetApp = appName
                } else {
                    let frontmostApp = try await context.applications.getFrontmostApplication()
                    targetApp = frontmostApp.name
                }

                let startTime = Date()
                _ = try await context.dialogs.clickButton(
                    buttonText: buttonLabel,
                    windowTitle: appName)
                _ = Date().timeIntervalSince(startTime)

                return ToolOutput.success("Clicked '\(buttonLabel)' in dialog - \(targetApp)")
            })
    }

    /// Create the dialog input tool
    func createDialogInputTool() -> Tool<PeekabooServices> {
        let definition = DialogToolDefinitions.dialogInput

        return createTool(
            name: definition.name,
            description: definition.agentDescription,
            parameters: definition.toAgentParameters(),
            execute: { params, context in
                let text = try params.string("text")
                let fieldLabel = params.string("field", default: nil)
                let appName = params.string("app", default: nil)
                let clearFirst = params.bool("clear_first", default: true)

                // For now, this is a simplified implementation
                // Field-specific targeting is not yet supported
                if fieldLabel != nil {
                    throw PeekabooError.serviceUnavailable("Field-specific text entry not yet implemented")
                }

                // Get the frontmost app if not specified
                let targetApp: String
                if let appName = appName {
                    targetApp = appName
                } else {
                    let frontmostApp = try await context.applications.getFrontmostApplication()
                    targetApp = frontmostApp.name
                }

                let startTime = Date()

                // Clear if requested
                if clearFirst {
                    try await context.automation.hotkey(keys: "cmd,a", holdDuration: 0)
                    try await Task.sleep(nanoseconds: TimeInterval.shortDelay.nanoseconds)
                    try await context.automation.hotkey(keys: "delete", holdDuration: 0)
                    try await Task.sleep(nanoseconds: TimeInterval.shortDelay.nanoseconds)
                }

                // Type the text
                try await context.automation.type(
                    text: text ?? "",
                    target: nil as String?,
                    clearExisting: false,
                    typingDelay: 0,
                    sessionId: nil as String?)

                _ = Date().timeIntervalSince(startTime)

                var output = "Entered \"\(text ?? "")\""
                if let fieldLabel = fieldLabel {
                    output += " in '\(fieldLabel)' field"
                }
                output += " - \(targetApp) dialog"

                return ToolOutput.success(output)
            })
    }
}
