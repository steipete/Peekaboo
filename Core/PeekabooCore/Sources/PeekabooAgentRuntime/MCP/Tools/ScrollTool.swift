import Foundation
import MCP
import os.log
import PeekabooAutomation
import PeekabooFoundation
import TachikomaMCP

private typealias ToolScrollDirection = PeekabooFoundation.ScrollDirection

/// MCP tool for scrolling UI elements or at current mouse position
public struct ScrollTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "ScrollTool")
    private let context: MCPToolContext

    public let name = "scroll"

    public var description: String {
        """
        Scrolls the mouse wheel in any direction.
        Can target specific elements or scroll at current mouse position.
        Supports smooth scrolling and configurable speed.
        Peekaboo MCP 3.0.0-beta.2 using openai/gpt-5.1
        and anthropic/claude-sonnet-4.5
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "direction": SchemaBuilder.string(
                    description: "Scroll direction: up (content moves up), down (content moves down), left, or right.",
                    enum: ["up", "down", "left", "right"]),
                "on": SchemaBuilder.string(
                    description: "Optional. Element ID to scroll on (from see command). " +
                        "If not specified, scrolls at current mouse position."),
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

    public init(context: MCPToolContext = .shared) {
        self.context = context
    }

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        do {
            let request = try self.parseRequest(arguments: arguments)
            return try await self.performScroll(request: request)
        } catch let error as ScrollToolValidationError {
            return ToolResponse.error(error.message)
        } catch {
            self.logger.error("Scroll execution failed: \(error)")
            return ToolResponse.error("Failed to perform scroll: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func parseScrollDirection(_ direction: String) -> ToolScrollDirection? {
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

    private func parseRequest(arguments: ToolArguments) throws -> ScrollToolRequest {
        guard let directionString = arguments.getString("direction") else {
            throw ScrollToolValidationError("Direction is required")
        }

        guard let direction = self.parseScrollDirection(directionString) else {
            throw ScrollToolValidationError("Invalid direction. Must be one of: up, down, left, right")
        }

        let amount = Int(arguments.getNumber("amount") ?? 3)
        guard amount > 0 else {
            throw ScrollToolValidationError("Amount must be greater than 0")
        }
        guard amount <= 50 else {
            throw ScrollToolValidationError("Amount must be 50 or less to prevent excessive scrolling")
        }

        return ScrollToolRequest(
            direction: direction,
            elementId: arguments.getString("on"),
            sessionId: arguments.getString("session"),
            amount: amount,
            delay: Int(arguments.getNumber("delay") ?? 2),
            smooth: arguments.getBool("smooth") ?? false)
    }

    @MainActor
    private func performScroll(request: ScrollToolRequest) async throws -> ToolResponse {
        let automation = self.context.automation
        let startTime = Date()

        let target = try await self.resolveTargetDescription(request: request)
        let serviceRequest = ScrollRequest(
            direction: request.direction,
            amount: request.amount,
            target: target.elementId,
            smooth: request.smooth,
            delay: request.delay,
            sessionId: request.sessionId)
        try await automation.scroll(serviceRequest)

        let executionTime = Date().timeIntervalSince(startTime)
        let scrollDescription = request.smooth ? "smooth scroll" : "scroll"
        let duration = String(format: "%.2f", executionTime) + "s"
        let message = "\(AgentDisplayTokens.Status.success) Performed \(scrollDescription) \(request.direction) " +
            "(\(request.amount) ticks) \(target.description) in \(duration)"

        return ToolResponse.text(message)
    }

    @MainActor
    private func resolveTargetDescription(request: ScrollToolRequest) async throws -> ScrollTargetDescription {
        guard let elementId = request.elementId else {
            return ScrollTargetDescription(elementId: nil, description: "at current mouse position")
        }

        guard let session = await self.getSession(id: request.sessionId) else {
            throw ScrollToolValidationError("No active session. Run 'see' command first to capture UI state.")
        }

        guard let element = await session.getElement(byId: elementId) else {
            throw ScrollToolValidationError(
                "Element '\(elementId)' not found in current session. Run 'see' command to update UI state.")
        }

        let label = element.title ?? element.label ?? "untitled"
        let description = "on \(element.role): \(label)"
        return ScrollTargetDescription(elementId: elementId, description: description)
    }
}

private struct ScrollToolRequest {
    let direction: ToolScrollDirection
    let elementId: String?
    let sessionId: String?
    let amount: Int
    let delay: Int
    let smooth: Bool
}

private struct ScrollTargetDescription {
    let elementId: String?
    let description: String
}

private struct ScrollToolValidationError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}
