import Foundation
import TachikomaMCP
import MCP
import os.log

/// MCP tool for scrolling UI elements or at current mouse position
public struct ScrollTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "ScrollTool")

    public let name = "scroll"

    public var description: String {
        """
        Scrolls the mouse wheel in any direction.
        Can target specific elements or scroll at current mouse position.
        Supports smooth scrolling and configurable speed.
        Peekaboo MCP 3.0.0-beta.2 using anthropic/claude-opus-4-20250514, ollama/llava:latest
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "direction": SchemaBuilder.string(
                    description: "Scroll direction: up (content moves up), down (content moves down), left, or right.",
                    enum: ["up", "down", "left", "right"]),
                "on": SchemaBuilder.string(
                    description: "Optional. Element ID to scroll on (from see command). If not specified, scrolls at current mouse position."),
                "session": SchemaBuilder.string(
                    description: "Optional. Session ID from see command. Uses latest session if not specified."),
                "amount": SchemaBuilder.number(
                    description: "Optional. Number of scroll ticks/lines. Default: 3.",
                    default: 3),
                "delay": SchemaBuilder.number(
                    description: "Optional. Delay between scroll ticks in milliseconds. Default: 2.",
                    default: 2),
                "smooth": SchemaBuilder.boolean(
                    description: "Optional. Use smooth scrolling with smaller increments.",
                    default: false),
            ],
            required: ["direction"])
    }

    public init() {}

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        // Parse required parameters
        guard let directionString = arguments.getString("direction") else {
            return ToolResponse.error("Direction is required")
        }

        guard let direction = parseScrollDirection(directionString) else {
            return ToolResponse.error("Invalid direction. Must be one of: up, down, left, right")
        }

        // Parse optional parameters
        let elementId = arguments.getString("on")
        let sessionId = arguments.getString("session")
        let amount = Int(arguments.getNumber("amount") ?? 3)
        let delay = Int(arguments.getNumber("delay") ?? 2)
        let smooth = arguments.getBool("smooth") ?? false

        // Validate amount
        guard amount > 0 else {
            return ToolResponse.error("Amount must be greater than 0")
        }

        guard amount <= 50 else {
            return ToolResponse.error("Amount must be 50 or less to prevent excessive scrolling")
        }

        do {
            let startTime = Date()
            let automation = PeekabooServices.shared.automation

            // Determine target for scrolling
            var targetDescription = "at current mouse position"

            if let elementId {
                // Find element from session and scroll on it
                guard let session = await getSession(id: sessionId) else {
                    return ToolResponse.error("No active session. Run 'see' command first to capture UI state.")
                }

                guard let element = await session.getElement(byId: elementId) else {
                    return ToolResponse
                        .error(
                            "Element '\(elementId)' not found in current session. Run 'see' command to update UI state.")
                }

                targetDescription = "on \(element.role): \(element.title ?? element.label ?? "untitled")"

                // Use element ID as target for the scroll service
                try await automation.scroll(
                    direction: direction,
                    amount: amount,
                    target: elementId,
                    smooth: smooth,
                    delay: delay,
                    sessionId: sessionId)
            } else {
                // Scroll at current mouse position
                try await automation.scroll(
                    direction: direction,
                    amount: amount,
                    target: nil,
                    smooth: smooth,
                    delay: delay,
                    sessionId: sessionId)
            }

            let executionTime = Date().timeIntervalSince(startTime)

            // Build response message
            let scrollDescription = smooth ? "smooth scroll" : "scroll"
            let message = "✅ Performed \(scrollDescription) \(direction) (\(amount) ticks) \(targetDescription) in \(String(format: "%.2f", executionTime))s"

            return ToolResponse.text(message)

        } catch {
            self.logger.error("Scroll execution failed: \(error)")
            return ToolResponse.error("Failed to perform scroll: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func parseScrollDirection(_ direction: String) -> ScrollDirection? {
        switch direction.lowercased() {
        case "up":
            .up
        case "down":
            .down
        case "left":
            .left
        case "right":
            .right
        default:
            nil
        }
    }

    private func getSession(id: String?) async -> UISession? {
        if let sessionId = id {
            return await UISessionManager.shared.getSession(id: sessionId)
        }

        // Get most recent session
        // For now, return nil - in a real implementation we'd track the most recent session
        return nil
    }
}
