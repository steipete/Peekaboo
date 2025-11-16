import Foundation
import MCP
import os.log
import PeekabooAutomation
import PeekabooFoundation
import TachikomaMCP

/// MCP tool for clicking UI elements
public struct ClickTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "ClickTool")
    private let context: MCPToolContext

    public let name = "click"

    public var description: String {
        """
        Clicks on UI elements or coordinates.
        Supports element queries, specific IDs from see command, or raw coordinates.
        Includes smart waiting for elements to become actionable.
        Peekaboo MCP 3.0.0-beta.2 using openai/gpt-5.1, anthropic/claude-sonnet-4.5
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "query": SchemaBuilder.string(
                    description: """
                    Optional. Element text or query to click. Will search for matching elements.
                    """),
                "on": SchemaBuilder.string(
                    description: """
                    Optional. Element ID to click (e.g., B1, T2) from see command output.
                    """),
                "coords": SchemaBuilder.string(
                    description: """
                    Optional. Click at specific coordinates in format 'x,y' (e.g., '100,200').
                    """),
                "session": SchemaBuilder.string(
                    description: """
                    Optional. Session ID from see command. Uses latest session if not specified.
                    """),
                "wait_for": SchemaBuilder.number(
                    description: """
                    Optional. Maximum milliseconds to wait for element to become actionable. Default: 5000.
                    """,
                    default: 5000),
                "double": SchemaBuilder.boolean(
                    description: "Optional. Double-click instead of single click.",
                    default: false),
                "right": SchemaBuilder.boolean(
                    description: "Optional. Right-click (secondary click) instead of left-click.",
                    default: false),
            ],
            required: [])
    }

    public init(context: MCPToolContext = .shared) {
        self.context = context
    }

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        let request: ClickRequest
        do {
            request = try ClickRequest(arguments: arguments)
        } catch let error as ClickToolError {
            return ToolResponse.error(error.message)
        }

        let startTime = Date()

        do {
            let resolution = try await self.resolveClickTarget(for: request)
            try await self.performClick(
                at: resolution.location,
                sessionId: request.sessionId,
                intent: request.intent)

            let executionTime = Date().timeIntervalSince(startTime)
            return self.buildResponse(
                intent: request.intent,
                resolution: resolution,
                executionTime: executionTime)
        } catch let error as ClickToolError {
            return ToolResponse.error(error.message)
        } catch {
            self.logger.error("Click execution failed: \(error.localizedDescription)")
            return ToolResponse.error("Failed to perform click: \(error.localizedDescription)")
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

    private func resolveClickTarget(for request: ClickRequest) async throws -> ClickResolution {
        switch request.target {
        case let .coordinates(raw):
            let point = try self.parseCoordinates(raw)
            return ClickResolution(location: point, elementDescription: nil)
        case let .elementId(identifier):
            let session = try await self.requireSession(id: request.sessionId)
            let element = try await self.requireElement(id: identifier, session: session)
            return ClickResolution(
                location: element.centerPoint,
                elementDescription: element.humanDescription,
                targetApp: session.applicationName,
                windowTitle: session.windowTitle,
                elementRole: element.humanRole,
                elementLabel: element.displayLabel)
        case let .query(text):
            let session = try await self.requireSession(id: request.sessionId)
            let element = try await self.findElement(matching: text, session: session)
            return ClickResolution(
                location: element.centerPoint,
                elementDescription: element.humanDescription,
                targetApp: session.applicationName,
                windowTitle: session.windowTitle,
                elementRole: element.humanRole,
                elementLabel: element.displayLabel)
        }
    }

    private func performClick(at location: CGPoint, sessionId: String?, intent: ClickIntent) async throws {
        try await self.context.automation.click(
            target: .coordinates(location),
            clickType: intent.automationType,
            sessionId: sessionId)
    }

    private func buildResponse(
        intent: ClickIntent,
        resolution: ClickResolution,
        executionTime: TimeInterval) -> ToolResponse
    {
        var message = "\(AgentDisplayTokens.Status.success) \(intent.displayVerb)"
        if let element = resolution.elementDescription {
            message += " on \(element)"
        }
        message += " at (\(Int(resolution.location.x)), \(Int(resolution.location.y)))"
        message += " in \(String(format: "%.2f", executionTime))s"

        let metaDict: [String: Value] = [
            "click_location": .object([
                "x": .double(Double(resolution.location.x)),
                "y": .double(Double(resolution.location.y)),
            ]),
            "execution_time": .double(executionTime),
            "clicked_element": resolution.elementDescription.map(Value.string) ?? .null,
        ]

        let summary = ToolEventSummary(
            targetApp: resolution.targetApp,
            windowTitle: resolution.windowTitle,
            elementRole: resolution.elementRole,
            elementLabel: resolution.elementLabel,
            actionDescription: intent.displayVerb,
            coordinates: ToolEventSummary.Coordinates(
                x: Double(resolution.location.x),
                y: Double(resolution.location.y)))

        let metaValue = ToolEventSummary.merge(summary: summary, into: .object(metaDict))

        return ToolResponse(
            content: [.text(message)],
            meta: metaValue)
    }

    private func parseCoordinates(_ raw: String) throws -> CGPoint {
        let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let x = Double(parts[0]),
              let y = Double(parts[1])
        else {
            throw ClickToolError("Invalid coordinates format. Use 'x,y' (e.g., '100,200').")
        }
        return CGPoint(x: x, y: y)
    }

    private func requireSession(id: String?) async throws -> UISession {
        guard let session = await self.getSession(id: id) else {
            throw ClickToolError("No active session. Run 'see' command first to capture UI state.")
        }
        return session
    }

    private func requireElement(id: String, session: UISession) async throws -> UIElement {
        guard let element = await session.getElement(byId: id) else {
            throw ClickToolError(
                "Element '\(id)' not found in current session. Run 'see' command to update UI state.")
        }
        return element
    }

    private func findElement(matching query: String, session: UISession) async throws -> UIElement {
        let searchText = query.lowercased()
        let elements = await session.uiElements
        let matches = elements.filter { element in
            element.title?.lowercased().contains(searchText) ?? false ||
                element.label?.lowercased().contains(searchText) ?? false ||
                element.value?.lowercased().contains(searchText) ?? false
        }

        guard !matches.isEmpty else {
            throw ClickToolError("No elements found matching query: '\(query)'")
        }

        return matches.first { $0.isActionable } ?? matches[0]
    }
}

// MARK: - Supporting Types

private struct ClickRequest {
    let target: ClickRequestTarget
    let sessionId: String?
    let intent: ClickIntent

    init(arguments: ToolArguments) throws {
        if let coords = arguments.getString("coords") {
            self.target = .coordinates(coords)
        } else if let elementId = arguments.getString("on") {
            self.target = .elementId(elementId)
        } else if let query = arguments.getString("query") {
            self.target = .query(query)
        } else {
            throw ClickToolError("Must specify either 'query', 'on', or 'coords'.")
        }

        self.sessionId = arguments.getString("session")
        let isDouble = arguments.getBool("double") ?? false
        let isRight = arguments.getBool("right") ?? false
        self.intent = ClickIntent(double: isDouble, right: isRight)
    }
}

private enum ClickRequestTarget {
    case coordinates(String)
    case elementId(String)
    case query(String)
}

private struct ClickResolution {
    let location: CGPoint
    let elementDescription: String?
    let targetApp: String?
    let windowTitle: String?
    let elementRole: String?
    let elementLabel: String?

    init(
        location: CGPoint,
        elementDescription: String?,
        targetApp: String? = nil,
        windowTitle: String? = nil,
        elementRole: String? = nil,
        elementLabel: String? = nil)
    {
        self.location = location
        self.elementDescription = elementDescription
        self.targetApp = targetApp
        self.windowTitle = windowTitle
        self.elementRole = elementRole
        self.elementLabel = elementLabel
    }
}

private struct ClickIntent {
    let automationType: ClickType
    let displayVerb: String

    init(double: Bool, right: Bool) {
        if right {
            self.automationType = .right
            self.displayVerb = "Right-clicked"
        } else if double {
            self.automationType = .double
            self.displayVerb = "Double-clicked"
        } else {
            self.automationType = .single
            self.displayVerb = "Clicked"
        }
    }
}

private struct ClickToolError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

extension UIElement {
    fileprivate var centerPoint: CGPoint {
        CGPoint(x: self.frame.midX, y: self.frame.midY)
    }

    fileprivate var humanDescription: String {
        "\(self.role): \(self.title ?? self.label ?? "untitled")"
    }

    fileprivate var humanRole: String? {
        self.roleDescription ?? self.role
    }

    fileprivate var displayLabel: String? {
        self.title ?? self.label ?? self.value
    }
}
