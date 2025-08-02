import Foundation
import MCP
import os.log

/// MCP tool for interacting with system dialogs and alerts
public struct DialogTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "DialogTool")

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
        Peekaboo MCP 3.0.0-beta.2 using anthropic/claude-opus-4-20250514, ollama/llava:latest
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "action": SchemaBuilder.string(
                    description: "Action to perform: 'list' to discover dialogs, 'click' to interact with buttons, 'input' for text entry, 'file' for file selection, 'dismiss' to close dialogs",
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

    public init() {}

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        guard let action = arguments.getString("action") else {
            return ToolResponse.error("Missing required parameter: action")
        }

        let button = arguments.getString("button")
        let text = arguments.getString("text")
        let field = arguments.getString("field")
        let clear = arguments.getBool("clear") ?? false
        let path = arguments.getString("path")
        let select = arguments.getString("select")
        let window = arguments.getString("window")
        let name = arguments.getString("name")
        let force = arguments.getBool("force") ?? false
        let index = arguments.getInt("index")

        let dialogService = PeekabooServices.shared.dialogs

        do {
            let startTime = Date()

            switch action {
            case "list":
                return try await self.handleList(
                    service: dialogService,
                    window: window,
                    startTime: startTime)

            case "click":
                guard let button else {
                    return ToolResponse.error("Click action requires 'button' parameter")
                }
                return try await self.handleClick(
                    service: dialogService,
                    button: button,
                    window: window,
                    startTime: startTime)

            case "input":
                guard let text else {
                    return ToolResponse.error("Input action requires 'text' parameter")
                }
                return try await self.handleInput(
                    service: dialogService,
                    text: text,
                    field: field,
                    clear: clear,
                    window: window,
                    startTime: startTime)

            case "file":
                return try await self.handleFile(
                    service: dialogService,
                    path: path,
                    select: select,
                    window: window,
                    startTime: startTime)

            case "dismiss":
                return try await self.handleDismiss(
                    service: dialogService,
                    force: force,
                    window: window,
                    startTime: startTime)

            default:
                return ToolResponse
                    .error("Unknown action: \(action). Supported actions: list, click, input, file, dismiss")
            }

        } catch {
            self.logger.error("Dialog operation execution failed: \(error)")
            return ToolResponse.error("Failed to \(action) dialog: \(error.localizedDescription)")
        }
    }

    // MARK: - Action Handlers

    private func handleList(
        service: DialogServiceProtocol,
        window: String?,
        startTime: Date) async throws -> ToolResponse
    {
        let elements = try await service.listDialogElements(windowTitle: window)
        let executionTime = Date().timeIntervalSince(startTime)

        var content = "✅ Dialog Elements Found in \(String(format: "%.2f", executionTime))s:\n\n"

        // Dialog info
        content += "📋 **Dialog**: \(elements.dialogInfo.title)\n"
        content += "   Role: \(elements.dialogInfo.role)\n"
        if let subrole = elements.dialogInfo.subrole {
            content += "   Subrole: \(subrole)\n"
        }
        content += "   File Dialog: \(elements.dialogInfo.isFileDialog ? "Yes" : "No")\n"
        content += "   Bounds: \(Int(elements.dialogInfo.bounds.origin.x)), \(Int(elements.dialogInfo.bounds.origin.y)), \(Int(elements.dialogInfo.bounds.size.width)) × \(Int(elements.dialogInfo.bounds.size.height))\n\n"

        // Buttons
        if !elements.buttons.isEmpty {
            content += "🔘 **Buttons** (\(elements.buttons.count)):\n"
            for button in elements.buttons {
                let status = button.isEnabled ? "enabled" : "disabled"
                let defaultMark = button.isDefault ? " (default)" : ""
                content += "   • \(button.title) (\(status))\(defaultMark)\n"
            }
            content += "\n"
        }

        // Text fields
        if !elements.textFields.isEmpty {
            content += "📝 **Text Fields** (\(elements.textFields.count)):\n"
            for textField in elements.textFields {
                let title = textField.title ?? "Field \(textField.index)"
                let value = textField.value ?? ""
                let placeholder = textField.placeholder.map { " (placeholder: \($0))" } ?? ""
                let status = textField.isEnabled ? "enabled" : "disabled"
                content += "   • \(title): '\(value)' (\(status))\(placeholder)\n"
            }
            content += "\n"
        }

        // Static texts
        if !elements.staticTexts.isEmpty {
            content += "📄 **Static Text** (\(elements.staticTexts.count)):\n"
            for staticText in elements.staticTexts {
                content += "   • \(staticText)\n"
            }
            content += "\n"
        }

        // Other elements
        if !elements.otherElements.isEmpty {
            content += "🔧 **Other Elements** (\(elements.otherElements.count)):\n"
            for element in elements.otherElements {
                let title = element.title ?? "Untitled"
                let value = element.value.map { " = '\($0)'" } ?? ""
                content += "   • \(element.role): \(title)\(value)\n"
            }
        }

        return ToolResponse(
            content: [.text(content)],
            meta: .object([
                "dialog_title": .string(elements.dialogInfo.title),
                "dialog_role": .string(elements.dialogInfo.role),
                "is_file_dialog": .bool(elements.dialogInfo.isFileDialog),
                "button_count": .double(Double(elements.buttons.count)),
                "text_field_count": .double(Double(elements.textFields.count)),
                "static_text_count": .double(Double(elements.staticTexts.count)),
                "other_element_count": .double(Double(elements.otherElements.count)),
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleClick(
        service: DialogServiceProtocol,
        button: String,
        window: String?,
        startTime: Date) async throws -> ToolResponse
    {
        let result = try await service.clickButton(buttonText: button, windowTitle: window)
        let executionTime = Date().timeIntervalSince(startTime)

        if result.success {
            return ToolResponse(
                content: [.text("✅ Clicked button '\(button)' in \(String(format: "%.2f", executionTime))s")],
                meta: .object([
                    "button_text": .string(button),
                    "action": .string(result.action.rawValue),
                    "success": .bool(result.success),
                    "execution_time": .double(executionTime),
                    "details": .object(result.details.mapValues { .string($0) }),
                ]))
        } else {
            return ToolResponse
                .error("Failed to click button '\(button)': \(result.details["error"] ?? "Unknown error")")
        }
    }

    private func handleInput(
        service: DialogServiceProtocol,
        text: String,
        field: String?,
        clear: Bool,
        window: String?,
        startTime: Date) async throws -> ToolResponse
    {
        let result = try await service.enterText(
            text: text,
            fieldIdentifier: field,
            clearExisting: clear,
            windowTitle: window)
        let executionTime = Date().timeIntervalSince(startTime)

        if result.success {
            let fieldDesc = field ?? "field"
            let clearDesc = clear ? " (cleared first)" : ""
            return ToolResponse(
                content: [
                    .text(
                        "✅ Entered text '\(text)' into \(fieldDesc)\(clearDesc) in \(String(format: "%.2f", executionTime))s"),
                ],
                meta: .object([
                    "text": .string(text),
                    "field": .string(field ?? ""),
                    "clear": .bool(clear),
                    "action": .string(result.action.rawValue),
                    "success": .bool(result.success),
                    "execution_time": .double(executionTime),
                    "details": .object(result.details.mapValues { .string($0) }),
                ]))
        } else {
            return ToolResponse.error("Failed to enter text: \(result.details["error"] ?? "Unknown error")")
        }
    }

    private func handleFile(
        service: DialogServiceProtocol,
        path: String?,
        select: String?,
        window: String?,
        startTime: Date) async throws -> ToolResponse
    {
        // For file dialogs, we need to determine what to do
        // If path is provided, use it directly
        // If select is provided, it could be multiple paths (comma-separated)
        let targetPath = path ?? select

        guard let targetPath else {
            return ToolResponse.error("File action requires either 'path' or 'select' parameter")
        }

        // Extract filename from path for save dialogs
        let url = URL(fileURLWithPath: targetPath)
        let filename = url.lastPathComponent
        let directoryPath = url.deletingLastPathComponent().path

        let result = try await service.handleFileDialog(
            path: directoryPath,
            filename: filename,
            actionButton: "Save" // Default action button
        )
        let executionTime = Date().timeIntervalSince(startTime)

        if result.success {
            return ToolResponse(
                content: [.text("✅ Selected file '\(targetPath)' in \(String(format: "%.2f", executionTime))s")],
                meta: .object([
                    "path": .string(targetPath),
                    "filename": .string(filename),
                    "directory": .string(directoryPath),
                    "action": .string(result.action.rawValue),
                    "success": .bool(result.success),
                    "execution_time": .double(executionTime),
                    "details": .object(result.details.mapValues { .string($0) }),
                ]))
        } else {
            return ToolResponse.error("Failed to select file: \(result.details["error"] ?? "Unknown error")")
        }
    }

    private func handleDismiss(
        service: DialogServiceProtocol,
        force: Bool,
        window: String?,
        startTime: Date) async throws -> ToolResponse
    {
        let result = try await service.dismissDialog(force: force, windowTitle: window)
        let executionTime = Date().timeIntervalSince(startTime)

        if result.success {
            let method = force ? "force (Escape key)" : "normal"
            return ToolResponse(
                content: [.text("✅ Dismissed dialog using \(method) in \(String(format: "%.2f", executionTime))s")],
                meta: .object([
                    "force": .bool(force),
                    "action": .string(result.action.rawValue),
                    "success": .bool(result.success),
                    "execution_time": .double(executionTime),
                    "details": .object(result.details.mapValues { .string($0) }),
                ]))
        } else {
            return ToolResponse.error("Failed to dismiss dialog: \(result.details["error"] ?? "Unknown error")")
        }
    }
}
