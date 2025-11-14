import Foundation
import MCP
import os.log
import TachikomaMCP
import PeekabooAutomation

/// MCP tool for pressing keyboard shortcuts and key combinations
public struct HotkeyTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "HotkeyTool")
    private let context: MCPToolContext

    public let name = "hotkey"

    public var description: String {
        """
        Presses keyboard shortcuts and key combinations.
        Simulates pressing multiple keys simultaneously like Cmd+C or Ctrl+Shift+T.
        Keys are pressed in order and released in reverse order.
        Peekaboo MCP 3.0.0-beta.2 using openai/gpt-5, anthropic/claude-sonnet-4.5
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "keys": SchemaBuilder.string(
                    description: """
                    Comma-separated list of keys to press (e.g., 'cmd,c' for copy,
                    'cmd,shift,t' for reopen tab). Supported keys: cmd, shift,
                    alt/option, ctrl, fn, a-z, 0-9, space, return, tab, escape,
                    delete, arrow_up, arrow_down, arrow_left, arrow_right, f1-f12.
                    """),
                "hold_duration": SchemaBuilder.number(
                    description: "Optional. Delay between key press and release in milliseconds. Default: 50.",
                    minimum: 0,
                    default: 50),
            ],
            required: ["keys"])
    }

    public init(context: MCPToolContext = .shared) {
        self.context = context
    }

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        // Extract required keys parameter
        guard let keys = arguments.getString("keys") else {
            return ToolResponse.error("Missing required parameter: keys")
        }

        // Validate keys is not empty
        guard !keys.trimmingCharacters(in: .whitespaces).isEmpty else {
            return ToolResponse.error("Keys parameter cannot be empty")
        }

        // Extract optional hold_duration parameter
        let holdDuration = arguments.getNumber("hold_duration") ?? 50

        // Validate hold_duration
        guard holdDuration >= 0 else {
            return ToolResponse.error("hold_duration must be non-negative")
        }

        // Convert to integer milliseconds
        let holdDurationMs = Int(holdDuration)
        guard holdDurationMs <= 10000 else { // Max 10 seconds
            return ToolResponse.error("hold_duration cannot exceed 10000ms (10 seconds)")
        }

        do {
            let startTime = Date()

            // Execute hotkey using PeekabooServices
            let hotkeyService = self.context.automation
            try await hotkeyService.hotkey(keys: keys, holdDuration: holdDurationMs)

            let executionTime = Date().timeIntervalSince(startTime)

            // Format keys for display
            let keyArray = keys.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let formattedKeys = keyArray.joined(separator: "+")

            let durationText = String(format: "%.2f", executionTime)
            let message = "\(AgentDisplayTokens.Status.success) Pressed \(formattedKeys) " +
                "(held for \(holdDurationMs)ms) in \(durationText)s"

            return ToolResponse(
                content: [.text(message)],
                meta: .object([
                    "keys": .string(keys),
                    "hold_duration": .double(Double(holdDurationMs)),
                    "execution_time": .double(executionTime),
                    "formatted_keys": .string(formattedKeys),
                ]))

        } catch {
            self.logger.error("Hotkey execution failed: \(error)")
            return ToolResponse.error("Failed to press hotkey combination '\(keys)': \(error.localizedDescription)")
        }
    }
}
