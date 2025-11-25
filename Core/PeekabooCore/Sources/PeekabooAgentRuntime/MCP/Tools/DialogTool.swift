import Foundation
import MCP
import os.log
import PeekabooAutomation
import TachikomaMCP

/// MCP tool for interacting with system dialogs and alerts
public struct DialogTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "DialogTool")
    private let context: MCPToolContext

    public let name = "dialog"

    public var description: String {
        """
        Interact with system dialogs and alerts.

        Actions:
        - click: Click buttons in dialogs
        - input: Input text into dialog fields
        - file: Select files in file dialogs
        - dismiss: Dismiss dialogs
        - list: List open dialogs

        Handles save/open dialogs, alerts, and other system prompts.

        Examples:
        - Click OK button: { "action": "click", "button": "OK" }
        - Input text: { "action": "input", "text": "Hello", "field": "Name" }
        - Select file: { "action": "file", "path": "/Users/user/document.txt" }
        - Dismiss dialog: { "action": "dismiss", "force": true }
        Peekaboo MCP 3.0.0-beta1 using openai/gpt-5.1, anthropic/claude-sonnet-4.5
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "action": SchemaBuilder.string(
                    description: """
                    Action to perform:
                    - list: discover dialogs
                    - click: press buttons
                    - input: enter text
                    - file: select files
                    - dismiss: close dialogs
                    """,
                    enum: ["list", "click", "input", "file", "dismiss"]),
                "button": SchemaBuilder.string(
                    description: "Button text to click (for click action)"),
                "text": SchemaBuilder.string(
                    description: "Text to input (for input action)"),
                "field": SchemaBuilder.string(
                    description: "Field name/index to target (for input action)"),
                "clear": SchemaBuilder.boolean(
                    description: "Clear field before input (default: false)",
                    default: false),
                "path": SchemaBuilder.string(
                    description: "File path to select (for file action)"),
                "select": SchemaBuilder.string(
                    description: "Multiple file paths to select (for file action)"),
                "window": SchemaBuilder.string(
                    description: "Window title or index to target"),
                "name": SchemaBuilder.string(
                    description: "Dialog name to target"),
                "force": SchemaBuilder.boolean(
                    description: "Force dismiss (for dismiss action)",
                    default: false),
                "index": SchemaBuilder.number(
                    description: "Dialog index when multiple dialogs are open"),
            ],
            required: ["action"])
    }

    public init(context: MCPToolContext = .shared) {
        self.context = context
    }

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        guard let actionName = arguments.getString("action") else {
            return ToolResponse.error("Missing required parameter: action")
        }

        guard let action = DialogAction(rawValue: actionName) else {
            return ToolResponse.error(
                "Unknown action: \(actionName). Supported actions: \(DialogAction.supportedList)")
        }

        let inputs = DialogInputs(arguments: arguments)
        let dialogService = self.context.dialogs
        let startTime = Date()

        do {
            return try await self.perform(
                action: action,
                inputs: inputs,
                service: dialogService,
                startTime: startTime)
        } catch let error as DialogInputError {
            return ToolResponse.error(error.message)
        } catch {
            self.logger.error("Dialog operation execution failed: \(error)")
            return ToolResponse.error("Failed to \(action.description) dialog: \(error.localizedDescription)")
        }
    }

    // MARK: - Action Handlers

    private func perform(
        action: DialogAction,
        inputs: DialogInputs,
        service: any DialogServiceProtocol,
        startTime: Date) async throws -> ToolResponse
    {
        switch action {
        case .list:
            return try await self.handleList(service: service, window: inputs.window, startTime: startTime)
        case .click:
            let button = try inputs.requireButton()
            return try await self.handleClick(
                service: service,
                button: button,
                window: inputs.window,
                startTime: startTime)
        case .input:
            let text = try inputs.requireText()
            return try await self.handleInput(
                service: service,
                request: inputs.makeInputRequest(with: text),
                startTime: startTime)
        case .file:
            let selection = try inputs.requireFileSelection()
            return try await self.handleFile(service: service, selection: selection, startTime: startTime)
        case .dismiss:
            return try await self.handleDismiss(
                service: service,
                request: inputs.makeDismissRequest(),
                startTime: startTime)
        }
    }

    private func handleList(
        service: any DialogServiceProtocol,
        window: String?,
        startTime: Date) async throws -> ToolResponse
    {
        let elements = try await service.listDialogElements(windowTitle: window)
        let executionTime = Date().timeIntervalSince(startTime)
        return DialogListFormatter(elements: elements, executionTime: executionTime).response()
    }

    private func handleClick(
        service: any DialogServiceProtocol,
        button: String,
        window: String?,
        startTime: Date) async throws -> ToolResponse
    {
        let result = try await service.clickButton(buttonText: button, windowTitle: window)
        let executionTime = Date().timeIntervalSince(startTime)

        if result.success {
            let summary =
                "\(AgentDisplayTokens.Status.success) Clicked button '\(button)' in " +
                "\(Self.formattedDuration(executionTime))s"
            let summaryMeta = ToolEventSummary(
                targetApp: window,
                actionDescription: "Dialog Button",
                notes: button)
            return self.successResponse(
                message: summary,
                meta: [
                    "button_text": .string(button),
                    "action": .string(result.action.rawValue),
                    "success": .bool(result.success),
                    "execution_time": .double(executionTime),
                    "details": .object(result.details.mapValues { .string($0) }),
                ],
                summary: summaryMeta)
        } else {
            return ToolResponse
                .error("Failed to click button '\(button)': \(result.details["error"] ?? "Unknown error")")
        }
    }

    private func handleInput(
        service: any DialogServiceProtocol,
        request: DialogInputRequest,
        startTime: Date) async throws -> ToolResponse
    {
        let result = try await service.enterText(
            text: request.text,
            fieldIdentifier: request.field,
            clearExisting: request.clear,
            windowTitle: request.window)
        let executionTime = Date().timeIntervalSince(startTime)

        if result.success {
            let fieldDesc = request.field ?? "field"
            let clearSuffix = request.clear ? " (cleared first)" : ""
            let message =
                "\(AgentDisplayTokens.Status.success) Entered text '\(request.text)' into \(fieldDesc)\(clearSuffix) " +
                "in \(Self.formattedDuration(executionTime))s"
            let summaryMeta = ToolEventSummary(
                targetApp: request.window,
                actionDescription: "Dialog Input",
                notes: fieldDesc)
            return self.successResponse(
                message: message,
                meta: [
                    "text": .string(request.text),
                    "field": .string(request.field ?? ""),
                    "clear": .bool(request.clear),
                    "action": .string(result.action.rawValue),
                    "success": .bool(result.success),
                    "execution_time": .double(executionTime),
                    "details": .object(result.details.mapValues { .string($0) }),
                ],
                summary: summaryMeta)
        } else {
            return ToolResponse.error("Failed to enter text: \(result.details["error"] ?? "Unknown error")")
        }
    }

    private func handleFile(
        service: any DialogServiceProtocol,
        selection: DialogFileSelection,
        startTime: Date) async throws -> ToolResponse
    {
        let result = try await service.handleFileDialog(
            path: selection.directory,
            filename: selection.filename,
            actionButton: "Save")
        let executionTime = Date().timeIntervalSince(startTime)

        if result.success {
            let summary =
                "\(AgentDisplayTokens.Status.success) Selected file '\(selection.path)' " +
                "in \(Self.formattedDuration(executionTime))s"
            let summaryMeta = ToolEventSummary(
                actionDescription: "Dialog File",
                notes: selection.filename)
            return self.successResponse(
                message: summary,
                meta: [
                    "path": .string(selection.path),
                    "filename": .string(selection.filename),
                    "directory": .string(selection.directory),
                    "action": .string(result.action.rawValue),
                    "success": .bool(result.success),
                    "execution_time": .double(executionTime),
                    "details": .object(result.details.mapValues { .string($0) }),
                ],
                summary: summaryMeta)
        } else {
            return ToolResponse.error("Failed to select file: \(result.details["error"] ?? "Unknown error")")
        }
    }

    private func handleDismiss(
        service: any DialogServiceProtocol,
        request: DialogDismissRequest,
        startTime: Date) async throws -> ToolResponse
    {
        let result = try await service.dismissDialog(force: request.force, windowTitle: request.window)
        let executionTime = Date().timeIntervalSince(startTime)

        if result.success {
            let method = request.force ? "force (Escape key)" : "normal"
            let summary =
                "\(AgentDisplayTokens.Status.success) Dismissed dialog using \(method) in " +
                "\(Self.formattedDuration(executionTime))s"
            let summaryMeta = ToolEventSummary(
                targetApp: request.window,
                actionDescription: "Dialog Dismiss",
                notes: method)
            return self.successResponse(
                message: summary,
                meta: [
                    "force": .bool(request.force),
                    "action": .string(result.action.rawValue),
                    "success": .bool(result.success),
                    "execution_time": .double(executionTime),
                    "details": .object(result.details.mapValues { .string($0) }),
                ],
                summary: summaryMeta)
        } else {
            return ToolResponse.error("Failed to dismiss dialog: \(result.details["error"] ?? "Unknown error")")
        }
    }

    private func successResponse(message: String, meta: [String: Value], summary: ToolEventSummary) -> ToolResponse {
        ToolResponse(content: [.text(message)], meta: ToolEventSummary.merge(summary: summary, into: .object(meta)))
    }

    static func formattedDuration(_ duration: TimeInterval) -> String {
        String(format: "%.2f", duration)
    }
}

// MARK: - Dialog Inputs & Actions

private enum DialogAction: String, CaseIterable {
    case list
    case click
    case input
    case file
    case dismiss

    var description: String { self.rawValue }

    static var supportedList: String {
        allCases.map(\.rawValue).joined(separator: ", ")
    }
}

private struct DialogInputs {
    let button: String?
    let text: String?
    let field: String?
    let clear: Bool
    let path: String?
    let select: String?
    let window: String?
    let force: Bool

    init(arguments: ToolArguments) {
        self.button = arguments.getString("button")
        self.text = arguments.getString("text")
        self.field = arguments.getString("field")
        self.clear = arguments.getBool("clear") ?? false
        self.path = arguments.getString("path")
        self.select = arguments.getString("select")
        self.window = arguments.getString("window")
        self.force = arguments.getBool("force") ?? false
    }

    func requireButton() throws -> String {
        guard let button else {
            throw DialogInputError.missing("Click action requires 'button' parameter")
        }
        return button
    }

    func requireText() throws -> String {
        guard let text else {
            throw DialogInputError.missing("Input action requires 'text' parameter")
        }
        return text
    }

    func requireFileSelection() throws -> DialogFileSelection {
        let target = self.path ?? self.select
        guard let target else {
            throw DialogInputError.missing("File action requires either 'path' or 'select' parameter")
        }
        let url = URL(fileURLWithPath: target)
        return DialogFileSelection(
            path: target,
            directory: url.deletingLastPathComponent().path,
            filename: url.lastPathComponent)
    }

    func makeInputRequest(with text: String) -> DialogInputRequest {
        DialogInputRequest(text: text, field: self.field, clear: self.clear, window: self.window)
    }

    func makeDismissRequest() -> DialogDismissRequest {
        DialogDismissRequest(force: self.force, window: self.window)
    }
}

private enum DialogInputError: Error {
    case missing(String)

    var message: String {
        switch self {
        case let .missing(details):
            details
        }
    }
}

private struct DialogInputRequest {
    let text: String
    let field: String?
    let clear: Bool
    let window: String?
}

private struct DialogFileSelection {
    let path: String
    let directory: String
    let filename: String
}

private struct DialogDismissRequest {
    let force: Bool
    let window: String?
}

// MARK: - Dialog List Formatting

private struct DialogListFormatter {
    let elements: DialogElements
    let executionTime: TimeInterval

    func response() -> ToolResponse {
        let summary = ToolEventSummary(
            targetApp: self.elements.dialogInfo.title,
            actionDescription: "List Dialog",
            notes: self.elements.dialogInfo.title)
        return ToolResponse(
            content: [.text(self.renderContent())],
            meta: ToolEventSummary.merge(summary: summary, into: .object(self.metaDictionary())))
    }

    private func renderContent() -> String {
        var sections: [String] = []
        sections.append(self.dialogSection())
        if !self.elements.buttons.isEmpty { sections.append(self.buttonSection()) }
        if !self.elements.textFields.isEmpty { sections.append(self.textFieldSection()) }
        if !self.elements.staticTexts.isEmpty { sections.append(self.staticTextSection()) }
        if !self.elements.otherElements.isEmpty { sections.append(self.otherElementsSection()) }
        return sections.joined(separator: "\n")
    }

    private func dialogSection() -> String {
        var lines: [String] = []
        lines.append(
            "\(AgentDisplayTokens.Status.success) Dialog Elements Found in " +
                "\(DialogTool.formattedDuration(self.executionTime))s:\n")
        lines.append("[menu] **Dialog**: \(self.elements.dialogInfo.title)")
        lines.append("   Role: \(self.elements.dialogInfo.role)")
        if let subrole = elements.dialogInfo.subrole {
            lines.append("   Subrole: \(subrole)")
        }
        lines.append("   File Dialog: \(self.elements.dialogInfo.isFileDialog ? "Yes" : "No")")
        let bounds = self.elements.dialogInfo.bounds
        lines.append(
            "   Bounds: \(Int(bounds.origin.x)), \(Int(bounds.origin.y)), " +
                "\(Int(bounds.size.width)) × \(Int(bounds.size.height))\n")
        return lines.joined(separator: "\n")
    }

    private func buttonSection() -> String {
        var lines = ["[tap] **Buttons** (\(elements.buttons.count)):"]
        for button in self.elements.buttons {
            let status = button.isEnabled ? "enabled" : "disabled"
            let defaultMark = button.isDefault ? " (default)" : ""
            lines.append("   • \(button.title) (\(status))\(defaultMark)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func textFieldSection() -> String {
        var lines = ["📝 **Text Fields** (\(elements.textFields.count)):"]
        for textField in self.elements.textFields {
            let title = textField.title ?? "Field \(textField.index)"
            let value = textField.value ?? ""
            let placeholder = textField.placeholder.map { " (placeholder: \($0))" } ?? ""
            let status = textField.isEnabled ? "enabled" : "disabled"
            lines.append("   • \(title): '\(value)' (\(status))\(placeholder)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func staticTextSection() -> String {
        var lines = ["📄 **Static Text** (\(elements.staticTexts.count)):"]
        self.elements.staticTexts.forEach { lines.append("   • \($0)") }
        return lines.joined(separator: "\n") + "\n"
    }

    private func otherElementsSection() -> String {
        var lines = ["**Other Elements** (\(elements.otherElements.count)):"]
        for element in self.elements.otherElements {
            let title = element.title ?? "Untitled"
            let value = element.value.map { " = '\($0)'" } ?? ""
            lines.append("   • \(element.role): \(title)\(value)")
        }
        return lines.joined(separator: "\n")
    }

    private func metaDictionary() -> [String: Value] {
        [
            "dialog_title": .string(self.elements.dialogInfo.title),
            "dialog_role": .string(self.elements.dialogInfo.role),
            "is_file_dialog": .bool(self.elements.dialogInfo.isFileDialog),
            "button_count": .double(Double(self.elements.buttons.count)),
            "text_field_count": .double(Double(self.elements.textFields.count)),
            "static_text_count": .double(Double(self.elements.staticTexts.count)),
            "other_element_count": .double(Double(self.elements.otherElements.count)),
            "execution_time": .double(self.executionTime),
        ]
    }
}
