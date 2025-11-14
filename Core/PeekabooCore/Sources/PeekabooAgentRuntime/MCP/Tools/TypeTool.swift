import Foundation
import MCP
import PeekabooAutomation
import PeekabooFoundation
import os.log
import TachikomaMCP

/// MCP tool for typing text
public struct TypeTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "TypeTool")
    private let context: MCPToolContext

    public let name = "type"

    public var description: String {
        """
        Types text into UI elements or at current focus.
        Supports special keys ({return}, {tab}, etc.) and configurable typing speed.
        Can target specific elements or type at current keyboard focus.
        Peekaboo MCP 3.0.0-beta.2 using openai/gpt-5
        and anthropic/claude-sonnet-4.5
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "text": SchemaBuilder.string(
                    description: "The text to type. If not specified, can use special key flags instead."),
                "on": SchemaBuilder.string(
                    description: "Optional. Element ID to type into (from see command). " +
                        "If not specified, types at current focus."),
                "session": SchemaBuilder.string(
                    description: "Optional. Session ID from see command. Uses latest session if not specified."),
                "delay": SchemaBuilder.number(
                    description: "Optional. Delay between keystrokes in milliseconds. Default: 5.",
                    default: 5),
                "clear": SchemaBuilder.boolean(
                    description: "Optional. Clear the field before typing (Cmd+A, Delete).",
                    default: false),
                "press_return": SchemaBuilder.boolean(
                    description: "Optional. Press return/enter after typing.",
                    default: false),
                "tab": SchemaBuilder.number(
                    description: "Optional. Press tab N times."),
                "escape": SchemaBuilder.boolean(
                    description: "Optional. Press escape key.",
                    default: false),
                "delete": SchemaBuilder.boolean(
                    description: "Optional. Press delete/backspace key.",
                    default: false),
            ],
            required: [])
    }

    public init(context: MCPToolContext = .shared) {
        self.context = context
    }

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        do {
            let request = try self.parseRequest(arguments: arguments)
            return try await self.performType(request: request)
        } catch let error as TypeToolValidationError {
            return ToolResponse.error(error.message)
        } catch {
            self.logger.error("Type execution failed: \(error)")
            return ToolResponse.error("Failed to type text: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func getSession(id: String?) async -> UISession? {
        if let sessionId = id {
            return await UISessionManager.shared.getSession(id: sessionId)
        }

        // Get most recent session
        // For now, return nil - in a real implementation we'd track the most recent session
        return nil
    }

    private func parseRequest(arguments: ToolArguments) throws -> TypeRequest {
        let request = TypeRequest(
            text: arguments.getString("text"),
            elementId: arguments.getString("on"),
            sessionId: arguments.getString("session"),
            delay: Int(arguments.getNumber("delay") ?? 5),
            clearField: arguments.getBool("clear") ?? false,
            pressReturn: arguments.getBool("press_return") ?? false,
            tabCount: arguments.getNumber("tab").map { Int($0) },
            pressEscape: arguments.getBool("escape") ?? false,
            pressDelete: arguments.getBool("delete") ?? false)

        guard request.hasActions else {
            throw TypeToolValidationError("Must specify text to type or special key actions")
        }

        return request
    }

    @MainActor
    private func performType(request: TypeRequest) async throws -> ToolResponse {
        let automation = self.context.automation
        let startTime = Date()

        try await self.focusIfNeeded(request: request, automation: automation)
        try await self.clearIfNeeded(request: request, automation: automation)
        try await self.typeTextIfNeeded(request: request, automation: automation)
        try await self.pressSpecialKeysIfNeeded(request: request, automation: automation)

        let executionTime = Date().timeIntervalSince(startTime)
        let message = self.buildSummary(request: request, executionTime: executionTime)

        return ToolResponse(
            content: [.text(message)],
            meta: .object([
                "execution_time": .double(executionTime),
                "characters_typed": request.text != nil ? .double(Double(request.text!.count)) : .null,
            ]))
    }

    @MainActor
    private func focusIfNeeded(request: TypeRequest, automation: any UIAutomationServiceProtocol) async throws {
        guard let elementId = request.elementId else { return }
        guard let session = await self.getSession(id: request.sessionId) else {
            throw TypeToolValidationError("No active session. Run 'see' command first to capture UI state.")
        }

        guard let element = await session.getElement(byId: elementId) else {
            throw TypeToolValidationError(
                "Element '\(elementId)' not found in current session. Run 'see' command to update UI state.")
        }

        let clickLocation = CGPoint(x: element.frame.midX, y: element.frame.midY)
        try await automation.click(
            target: .coordinates(clickLocation),
            clickType: .single,
            sessionId: request.sessionId)
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    @MainActor
    private func clearIfNeeded(request: TypeRequest, automation: any UIAutomationServiceProtocol) async throws {
        guard request.clearField else { return }
        try await automation.hotkey(keys: "cmd,a", holdDuration: 50)
        try await Task.sleep(nanoseconds: 50_000_000)
        try await automation.hotkey(keys: "delete", holdDuration: 50)
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    @MainActor
    private func typeTextIfNeeded(request: TypeRequest, automation: any UIAutomationServiceProtocol) async throws {
        guard let text = request.text else { return }
        try await automation.type(
            text: text,
            target: nil,
            clearExisting: false,
            typingDelay: request.delay,
            sessionId: request.sessionId)
    }

    @MainActor
    private func pressSpecialKeysIfNeeded(
        request: TypeRequest,
        automation: any UIAutomationServiceProtocol) async throws
    {
        if let tabCount = request.tabCount {
            for index in 0..<tabCount {
                try await automation.hotkey(keys: "tab", holdDuration: 50)
                if index < tabCount - 1 {
                    try await Task.sleep(nanoseconds: UInt64(request.delay) * 1_000_000)
                }
            }
        }

        if request.pressEscape {
            try await automation.hotkey(keys: "escape", holdDuration: 50)
        }

        if request.pressDelete {
            try await automation.hotkey(keys: "delete", holdDuration: 50)
        }

        if request.pressReturn {
            try await automation.hotkey(keys: "return", holdDuration: 50)
        }
    }

    private func buildSummary(request: TypeRequest, executionTime: TimeInterval) -> String {
        var actions: [String] = []

        if request.clearField {
            actions.append("Cleared field")
        }

        if let text = request.text {
            let displayText = text.count > 50 ? String(text.prefix(50)) + "..." : text
            actions.append("Typed: \"\(displayText)\"")
        }

        if let tabCount = request.tabCount {
            actions.append("Pressed Tab \(tabCount) time\(tabCount == 1 ? "" : "s")")
        }

        if request.pressEscape {
            actions.append("Pressed Escape")
        }

        if request.pressDelete {
            actions.append("Pressed Delete")
        }

        if request.pressReturn {
            actions.append("Pressed Return")
        }

        let duration = String(format: "%.2f", executionTime) + "s"
        let summary = actions.isEmpty ? "Performed no actions" : actions.joined(separator: ", ")
        return "\(AgentDisplayTokens.Status.success) \(summary) in \(duration)"
    }
}

private struct TypeRequest {
    let text: String?
    let elementId: String?
    let sessionId: String?
    let delay: Int
    let clearField: Bool
    let pressReturn: Bool
    let tabCount: Int?
    let pressEscape: Bool
    let pressDelete: Bool

    var hasActions: Bool {
        self.text != nil || self.tabCount != nil || self.pressEscape || self.pressDelete || self.pressReturn
    }
}

private struct TypeToolValidationError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}
