import Foundation
import MCP
import os.log
import PeekabooAutomation
import TachikomaMCP

/// MCP tool for interacting with system dialogs and alerts.
public struct DialogTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "DialogTool")
    private let context: MCPToolContext

    public let name = "dialog"

    public var description: String {
        """
        Interact with system dialogs and alerts (alerts, sheets, NSSavePanel/NSOpenPanel).

        Actions:
        - list: inspect dialog structure (buttons, text fields, static text)
        - click: press a dialog button
        - input: type into a dialog text field
        - file: drive NSOpenPanel/NSSavePanel dialogs (path/name/select/verify)
        - dismiss: close the active dialog

        Targeting (recommended for determinism):
        - Provide app/pid and optionally window_id/window_title/window_index to focus before interacting.

        Examples:
        - Click OK: { "action": "click", "button": "OK", "app": "TextEdit" }
        - Default action: { "action": "click", "button": "default", "app": "TextEdit" }
        - Input password: { "action": "input", "text": "hunter2", "field": "Password", "clear": true, "app": "Safari" }
        - Save file (OKButton): { "action": "file", "path": "/tmp", "name": "poem.rtf",
          "select": "default", "ensure_expanded": true, "app": "TextEdit" }
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "action": SchemaBuilder.string(
                    description: "Action to perform",
                    enum: DialogToolAction.allCases.map(\.rawValue)),

                // Targeting
                "app": SchemaBuilder.string(description: "Target app name/bundle ID, or 'PID:<n>'."),
                "pid": SchemaBuilder.number(description: "Target process ID (alternative to app)."),
                "window_id": SchemaBuilder.number(description: "Window ID (preferred stable selector)."),
                "window_title": SchemaBuilder.string(description: "Window title (substring match)."),
                "window_index": SchemaBuilder.number(description: "Window index (0-based); requires app/pid."),

                // click
                "button": SchemaBuilder.string(description: "Button text to click. Use 'default' to click OKButton."),

                // input
                "text": SchemaBuilder.string(description: "Text to input (for input action)."),
                "field": SchemaBuilder.string(description: "Field label/placeholder to target (for input action)."),
                "field_index": SchemaBuilder.number(description: "Field index (0-based) to target (for input action)."),
                "clear": SchemaBuilder.boolean(description: "Clear existing text first.", default: false),

                // file
                "path": SchemaBuilder.string(description: "Directory (or full path) to navigate to (for file action)."),
                "name": SchemaBuilder.string(description: "Filename to enter (for save dialogs)."),
                "select": SchemaBuilder.string(
                    description: """
                    Button to click after setting path/name. Omit (or pass 'default') to click OKButton.
                    """),
                "ensure_expanded": SchemaBuilder.boolean(
                    description: "Ensure file dialogs are expanded (Show Details) before applying path navigation.",
                    default: false),

                // dismiss
                "force": SchemaBuilder.boolean(description: "Force dismiss (sends Escape).", default: false),
            ],
            required: ["action"])
    }

    public init(context: MCPToolContext = .shared) {
        self.context = context
    }

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        let startTime = Date()

        do {
            let action = try DialogToolAction(arguments: arguments)
            let inputs = DialogToolInputs(arguments: arguments)

            let target = MCPInteractionTarget(
                app: inputs.app,
                pid: inputs.pid,
                windowTitle: inputs.windowTitle,
                windowIndex: inputs.windowIndex,
                windowId: inputs.windowId)

            if inputs.hasAnyTargeting {
                _ = try await target.focusIfRequested(windows: self.context.windows)
            }

            let resolvedWindowTitle = try await target.resolveWindowTitleIfNeeded(windows: self.context.windows)
            let appHint = target.appIdentifier

            return try await self.perform(
                action: action,
                inputs: inputs,
                windowTitle: resolvedWindowTitle,
                appHint: appHint,
                startTime: startTime)
        } catch let error as MCPInteractionTargetError {
            return ToolResponse.error(error.localizedDescription)
        } catch let error as DialogToolInputError {
            return ToolResponse.error(error.localizedDescription)
        } catch {
            self.logger.error("Dialog execution failed: \(error.localizedDescription)")
            return ToolResponse.error("Dialog failed: \(error.localizedDescription)")
        }
    }

    private func perform(
        action: DialogToolAction,
        inputs: DialogToolInputs,
        windowTitle: String?,
        appHint: String?,
        startTime: Date) async throws -> ToolResponse
    {
        switch action {
        case .list:
            let elements = try await self.context.dialogs.listDialogElements(windowTitle: windowTitle, appName: appHint)
            let executionTime = Date().timeIntervalSince(startTime)
            return self.formatList(
                elements: elements,
                executionTime: executionTime,
                windowTitle: windowTitle,
                appHint: appHint)

        case .click:
            let button = try inputs.requireButton()
            let result = try await self.context.dialogs.clickButton(
                buttonText: button,
                windowTitle: windowTitle,
                appName: appHint)
            return self.formatActionResult(
                context: ActionResultContext(
                    verb: "Clicked",
                    notes: button,
                    windowTitle: windowTitle,
                    appHint: appHint),
                result: result,
                startTime: startTime)

        case .input:
            let request = try inputs.requireInputRequest()
            let result = try await self.context.dialogs.enterText(
                text: request.text,
                fieldIdentifier: request.fieldIdentifier,
                clearExisting: request.clearExisting,
                windowTitle: windowTitle,
                appName: appHint)
            let notes = request.fieldIdentifier ?? "field"
            return self.formatActionResult(
                context: ActionResultContext(
                    verb: "Entered text",
                    notes: notes,
                    windowTitle: windowTitle,
                    appHint: appHint),
                result: result,
                startTime: startTime)

        case .file:
            let request = inputs.fileRequest()
            let actionButton: String?
            if let select = request.select {
                let normalized = select.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                actionButton = normalized == "default" ? nil : select
            } else {
                actionButton = nil
            }

            let result = try await self.context.dialogs.handleFileDialog(
                path: request.path,
                filename: request.name,
                actionButton: actionButton,
                ensureExpanded: request.ensureExpanded,
                appName: appHint)

            let executionTime = Date().timeIntervalSince(startTime)
            let clicked = result.details["button_clicked"] ?? (request.select ?? "default")
            let savedPath = result.details["saved_path"]
            let savedVerified = result.details["saved_path_verified"] == "true" ||
                result.details["saved_path_exists"] == "true"

            var message = "\(AgentDisplayTokens.Status.success) Handled file dialog"
            if let savedPath {
                let verifySuffix = savedVerified ? " (verified)" : ""
                message += ": \(clicked) → \(savedPath)\(verifySuffix)"
            } else {
                message += ": clicked \(clicked)"
            }
            message += " in \(Self.formattedDuration(executionTime))"

            let meta: Value = .object([
                "action": .string(result.action.rawValue),
                "success": .bool(result.success),
                "execution_time": .double(executionTime),
                "details": .object(result.details.mapValues { .string($0) }),
            ])

            let summary = ToolEventSummary(
                targetApp: appHint,
                windowTitle: windowTitle,
                actionDescription: "Dialog File",
                notes: savedPath ?? clicked)

            return ToolResponse(
                content: [.text(message)],
                meta: ToolEventSummary.merge(summary: summary, into: meta))

        case .dismiss:
            let force = inputs.force ?? false
            let result = try await self.context.dialogs.dismissDialog(
                force: force,
                windowTitle: windowTitle,
                appName: appHint)
            let verb = force ? "Dismissed (forced)" : "Dismissed"
            return self.formatActionResult(
                context: ActionResultContext(
                    verb: verb,
                    notes: nil,
                    windowTitle: windowTitle,
                    appHint: appHint),
                result: result,
                startTime: startTime)
        }
    }

    private struct ActionResultContext {
        let verb: String
        let notes: String?
        let windowTitle: String?
        let appHint: String?
    }

    private func formatActionResult(
        context: ActionResultContext,
        result: DialogActionResult,
        startTime: Date) -> ToolResponse
    {
        let executionTime = Date().timeIntervalSince(startTime)
        let message = "\(AgentDisplayTokens.Status.success) \(context.verb) in \(Self.formattedDuration(executionTime))"

        let meta: Value = .object([
            "action": .string(result.action.rawValue),
            "success": .bool(result.success),
            "execution_time": .double(executionTime),
            "details": .object(result.details.mapValues { .string($0) }),
        ])

        let summary = ToolEventSummary(
            targetApp: context.appHint,
            windowTitle: context.windowTitle,
            actionDescription: "Dialog \(context.verb)",
            notes: context.notes)

        return ToolResponse(
            content: [.text(message)],
            meta: ToolEventSummary.merge(summary: summary, into: meta))
    }

    private func formatList(
        elements: DialogElements,
        executionTime: TimeInterval,
        windowTitle: String?,
        appHint: String?) -> ToolResponse
    {
        let dialogTitle = elements.dialogInfo.title
        let buttonTitles = elements.buttons.map(\.title)
        let textFields = elements.textFields.map { field in
            [
                "title": field.title ?? "",
                "value": field.value ?? "",
                "placeholder": field.placeholder ?? "",
            ]
        }
        let staticTexts = elements.staticTexts

        let message = "\(AgentDisplayTokens.Status.success) Dialog '\(dialogTitle)' " +
            "(buttons=\(buttonTitles.count), fields=\(textFields.count), text=\(staticTexts.count)) " +
            "in \(Self.formattedDuration(executionTime))"

        let meta: Value = .object([
            "title": .string(dialogTitle),
            "role": .string(elements.dialogInfo.role),
            "buttons": .array(buttonTitles.map(Value.string)),
            "text_fields": .array(textFields.map { .object($0.mapValues(Value.string)) }),
            "text_elements": .array(staticTexts.map(Value.string)),
            "execution_time": .double(executionTime),
        ])

        let summary = ToolEventSummary(
            targetApp: appHint,
            windowTitle: windowTitle,
            actionDescription: "Dialog List",
            notes: dialogTitle)

        return ToolResponse(
            content: [.text(message)],
            meta: ToolEventSummary.merge(summary: summary, into: meta))
    }

    private static func formattedDuration(_ duration: TimeInterval) -> String {
        String(format: "%.2fs", duration)
    }
}

private enum DialogToolAction: String, CaseIterable {
    case list
    case click
    case input
    case file
    case dismiss

    init(arguments: ToolArguments) throws {
        guard let raw = arguments.getString("action") else {
            throw DialogToolInputError.missing("action")
        }
        guard let value = DialogToolAction(rawValue: raw) else {
            throw DialogToolInputError.invalid("action", raw)
        }
        self = value
    }
}

private enum DialogToolInputError: LocalizedError {
    case missing(String)
    case invalid(String, String)
    case missingForAction(action: DialogToolAction, field: String)

    var errorDescription: String? {
        switch self {
        case let .missing(field):
            "Missing required parameter: \(field)"
        case let .invalid(field, value):
            "Invalid \(field): \(value)"
        case let .missingForAction(action, field):
            "Missing required parameter for \(action.rawValue): \(field)"
        }
    }
}

private struct DialogToolInputs {
    let app: String?
    let pid: Int?
    let windowId: Int?
    let windowTitle: String?
    let windowIndex: Int?

    let button: String?
    let text: String?
    let field: String?
    let fieldIndex: Int?
    let clear: Bool

    let path: String?
    let name: String?
    let select: String?
    let ensureExpanded: Bool

    let force: Bool?

    init(arguments: ToolArguments) {
        self.app = arguments.getString("app")
        self.pid = arguments.getInt("pid")
        self.windowId = arguments.getInt("window_id")
        self.windowTitle = arguments.getString("window_title")
        self.windowIndex = arguments.getInt("window_index")

        self.button = arguments.getString("button")
        self.text = arguments.getString("text")
        self.field = arguments.getString("field")
        self.fieldIndex = arguments.getInt("field_index")
        self.clear = arguments.getBool("clear") ?? false

        self.path = arguments.getString("path")
        self.name = arguments.getString("name")
        self.select = arguments.getString("select")
        self.ensureExpanded = arguments.getBool("ensure_expanded") ?? false

        self.force = arguments.getBool("force")
    }

    var hasAnyTargeting: Bool {
        !(self.app?.isEmpty ?? true) ||
            self.pid != nil ||
            self.windowId != nil ||
            !(self.windowTitle?.isEmpty ?? true) ||
            self.windowIndex != nil
    }

    func requireButton() throws -> String {
        guard let button, !button.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DialogToolInputError.missingForAction(action: .click, field: "button")
        }
        return button
    }

    struct DialogInputRequest {
        let text: String
        let fieldIdentifier: String?
        let clearExisting: Bool
    }

    func requireInputRequest() throws -> DialogInputRequest {
        guard let text, !text.isEmpty else {
            throw DialogToolInputError.missingForAction(action: .input, field: "text")
        }

        let identifier: String? = if let field, !field.isEmpty {
            field
        } else if let fieldIndex {
            String(fieldIndex)
        } else {
            nil
        }

        return DialogInputRequest(text: text, fieldIdentifier: identifier, clearExisting: self.clear)
    }

    struct DialogFileRequest {
        let path: String?
        let name: String?
        let select: String?
        let ensureExpanded: Bool
    }

    func fileRequest() -> DialogFileRequest {
        DialogFileRequest(path: self.path, name: self.name, select: self.select, ensureExpanded: self.ensureExpanded)
    }
}
