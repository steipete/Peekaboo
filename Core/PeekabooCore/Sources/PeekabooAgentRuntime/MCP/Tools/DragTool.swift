import Foundation
import MCP
import os.log
import PeekabooAutomation
import TachikomaMCP

/// MCP tool for performing drag and drop operations between UI elements or coordinates
public struct DragTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "DragTool")
    private let context: MCPToolContext

    public let name = "drag"

    public var description: String {
        """
        Perform drag and drop operations between UI elements or coordinates.
        Supports element queries, specific IDs, or raw coordinates for both start and end points.
        Includes focus options for handling windows in different spaces.
        Peekaboo MCP 3.0.0-beta.2 using openai/gpt-5, anthropic/claude-sonnet-4.5
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "from": SchemaBuilder.string(
                    description: "Optional. Start element ID or query"),
                "from_coords": SchemaBuilder.string(
                    description: "Optional. Start coordinates in format 'x,y' (e.g., '100,200')"),
                "to": SchemaBuilder.string(
                    description: "Optional. End element ID or query"),
                "to_coords": SchemaBuilder.string(
                    description: "Optional. End coordinates in format 'x,y' (e.g., '300,400')"),
                "to_app": SchemaBuilder.string(
                    description: "Optional. Target application name when dragging between apps"),
                "session": SchemaBuilder.string(
                    description: "Optional. Session ID from see command. Uses latest session if not specified"),
                "duration": SchemaBuilder.number(
                    description: "Optional. Duration in milliseconds (default: 500)",
                    default: 500),
                "steps": SchemaBuilder.number(
                    description: "Optional. Number of intermediate steps (default: 10)",
                    default: 10),
                "modifiers": SchemaBuilder.string(
                    description: "Optional. Comma-separated modifiers (cmd, shift, alt, ctrl)"),
                "auto_focus": SchemaBuilder.boolean(
                    description: "Optional. Auto-focus target window (default: true)",
                    default: true),
                "bring_to_current_space": SchemaBuilder.boolean(
                    description: "Optional. Bring window to current space",
                    default: false),
                "space_switch": SchemaBuilder.boolean(
                    description: "Optional. Allow switching spaces",
                    default: false),
            ],
            required: [])
    }

    public init(context: MCPToolContext = .shared) {
        self.context = context
    }

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        let request: DragRequest
        do {
            request = try DragRequest(arguments: arguments)
        } catch let error as DragToolError {
            return ToolResponse.error(error.message)
        }

        do {
            let startTime = Date()
            let (fromPoint, fromDescription) = try await self.resolveLocation(
                target: request.fromTarget,
                sessionId: request.sessionId,
                parameterName: "from")
            let (toPoint, toDescription) = try await self.resolveLocation(
                target: request.toTarget,
                sessionId: request.sessionId,
                parameterName: "to")

            guard fromPoint != toPoint else {
                return ToolResponse.error("Start and end points must be different")
            }

            try await self.focusTargetAppIfNeeded(request: request)
            self.logSpaceIntentIfNeeded(request: request)

            try await self.context.automation.drag(
                from: fromPoint,
                to: toPoint,
                duration: request.duration,
                steps: request.steps,
                modifiers: request.modifiers)

            let executionTime = Date().timeIntervalSince(startTime)
            return self.buildResponse(
                from: DragPointDescription(point: fromPoint, description: fromDescription),
                to: DragPointDescription(point: toPoint, description: toDescription),
                executionTime: executionTime,
                request: request)
        } catch let error as CoordinateParseError {
            return ToolResponse.error(error.message)
        } catch let error as DragToolError {
            return ToolResponse.error(error.message)
        } catch {
            self.logger.error("Drag execution failed: \(error.localizedDescription)")
            return ToolResponse.error("Failed to perform drag operation: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func resolveLocation(
        target: DragLocationInput,
        sessionId: String?,
        parameterName: String) async throws -> (CGPoint, String)
    {
        switch target {
        case let .coordinates(raw):
            let point = try self.parseCoordinates(raw, parameterName: parameterName)
            return (point, "(\(Int(point.x)), \(Int(point.y)))")
        case let .element(query):
            guard let session = await self.getSession(id: sessionId) else {
                throw CoordinateParseError(message: "No active session. Run 'see' command first to capture UI state.")
            }
            if let element = await session.getElement(byId: query) {
                return (element.centerPoint, "element \(query) (\(element.humanDescription))")
            }

            let elements = await session.uiElements
            let matches = elements.filter { element in
                let searchText = query.lowercased()
                return element.title?.lowercased().contains(searchText) ?? false ||
                    element.label?.lowercased().contains(searchText) ?? false ||
                    element.value?.lowercased().contains(searchText) ?? false
            }

            guard !matches.isEmpty else {
                throw CoordinateParseError(message: "No elements found matching '\(query)' for \(parameterName)")
            }

            let element = matches.first { $0.isActionable } ?? matches[0]
            return (element.centerPoint, element.humanDescription)
        }
    }

    private func parseCoordinates(_ coordString: String, parameterName: String) throws -> CGPoint {
        let parts = coordString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        guard parts.count == 2 else {
            throw CoordinateParseError(
                message: "Invalid \(parameterName) coordinates format. Use 'x,y' (e.g., '100,200')")
        }

        guard let x = Double(parts[0]), let y = Double(parts[1]) else {
            throw CoordinateParseError(
                message: "Invalid \(parameterName) coordinates. Both x and y must be valid numbers")
        }

        // Validate coordinates are reasonable (not negative, not extremely large)
        guard x >= 0, y >= 0 else {
            throw CoordinateParseError(
                message: "Invalid \(parameterName) coordinates. Both x and y must be non-negative")
        }

        guard x <= 20000, y <= 20000 else {
            throw CoordinateParseError(
                message: "Invalid \(parameterName) coordinates. Both x and y must be 20000 or less")
        }

        return CGPoint(x: x, y: y)
    }

    private func getSession(id: String?) async -> UISession? {
        if let sessionId = id {
            return await UISessionManager.shared.getSession(id: sessionId)
        }

        // Get most recent session
        // For now, return nil - in a real implementation we'd track the most recent session
        return nil
    }

    private func focusTargetAppIfNeeded(request: DragRequest) async throws {
        guard request.autoFocus, let toApp = request.targetApp else { return }
        do {
            try await self.context.windows.focusWindow(target: .application(toApp))
            try await Task.sleep(nanoseconds: 100_000_000)
        } catch {
            self.logger.warning("Failed to focus target app '\(toApp)': \(error.localizedDescription)")
        }
    }

    private func logSpaceIntentIfNeeded(request: DragRequest) {
        guard request.bringToCurrentSpace || request.spaceSwitch else { return }
        let message = """
        Space management requested (bring_to_current_space: \(request.bringToCurrentSpace), \
        space_switch: \(request.spaceSwitch))
        """
        self.logger.info("\(message)")
    }

    private func buildResponse(
        from: DragPointDescription,
        to: DragPointDescription,
        executionTime: TimeInterval,
        request: DragRequest) -> ToolResponse
    {
        let deltaX = to.point.x - from.point.x
        let deltaY = to.point.y - from.point.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)

        var message = """
        \(AgentDisplayTokens.Status.success) Performed drag and drop from \(from.description) to \(to.description)
        """
        if let modifiers = request.modifiers, !modifiers.isEmpty {
            message += " with modifiers (\(modifiers))"
        }
        message += " over \(request.duration)ms with \(request.steps) steps"
        message += " (distance: \(String(format: "%.1f", distance))px)"
        message += " in \(String(format: "%.2f", executionTime))s"

        var metaData: [String: Value] = [
            "from": .object([
                "x": .double(Double(from.point.x)),
                "y": .double(Double(from.point.y)),
                "description": .string(from.description),
            ]),
            "to": .object([
                "x": .double(Double(to.point.x)),
                "y": .double(Double(to.point.y)),
                "description": .string(to.description),
            ]),
            "duration": .double(Double(request.duration)),
            "steps": .double(Double(request.steps)),
            "distance": .double(distance),
            "execution_time": .double(executionTime),
        ]

        if let modifiers = request.modifiers {
            metaData["modifiers"] = .string(modifiers)
        }

        if let toApp = request.targetApp {
            metaData["target_app"] = .string(toApp)
        }

        return ToolResponse(content: [.text(message)], meta: .object(metaData))
    }

    private struct CoordinateParseError: Swift.Error {
        let message: String
    }
}

// MARK: - Supporting Types

private struct DragRequest {
    let fromTarget: DragLocationInput
    let toTarget: DragLocationInput
    let sessionId: String?
    let targetApp: String?
    let duration: Int
    let steps: Int
    let modifiers: String?
    let autoFocus: Bool
    let bringToCurrentSpace: Bool
    let spaceSwitch: Bool

    init(arguments: ToolArguments) throws {
        let fromElement = arguments.getString("from")
        let fromCoords = arguments.getString("from_coords")
        let toElement = arguments.getString("to")
        let toCoords = arguments.getString("to_coords")

        guard let fromTarget = DragLocationInput(element: fromElement, coordinates: fromCoords) else {
            throw DragToolError("Must specify either 'from' or 'from_coords' for the start point.")
        }
        guard let toTarget = DragLocationInput(element: toElement, coordinates: toCoords) else {
            throw DragToolError("Must specify either 'to' or 'to_coords' for the end point.")
        }

        let durationValue = Int(arguments.getNumber("duration") ?? 500)
        guard durationValue > 0 else {
            throw DragToolError("Duration must be greater than 0.")
        }
        guard durationValue <= 30000 else {
            throw DragToolError("Duration must be 30 seconds or less to prevent excessive delays.")
        }

        let stepsValue = Int(arguments.getNumber("steps") ?? 10)
        guard stepsValue > 0 else {
            throw DragToolError("Steps must be greater than 0.")
        }
        guard stepsValue <= 100 else {
            throw DragToolError("Steps must be 100 or less to prevent excessive processing.")
        }

        self.fromTarget = fromTarget
        self.toTarget = toTarget
        self.sessionId = arguments.getString("session")
        self.targetApp = arguments.getString("to_app")
        self.duration = durationValue
        self.steps = stepsValue
        self.modifiers = arguments.getString("modifiers")
        self.autoFocus = arguments.getBool("auto_focus") ?? true
        self.bringToCurrentSpace = arguments.getBool("bring_to_current_space") ?? false
        self.spaceSwitch = arguments.getBool("space_switch") ?? false
    }
}

private enum DragLocationInput {
    case element(String)
    case coordinates(String)

    init?(element: String?, coordinates: String?) {
        if let coords = coordinates {
            self = .coordinates(coords)
        } else if let element {
            self = .element(element)
        } else {
            return nil
        }
    }
}

private struct DragToolError: Swift.Error {
    let message: String
    init(_ message: String) { self.message = message }
}

private struct DragPointDescription {
    let point: CGPoint
    let description: String
}

extension UIElement {
    fileprivate var centerPoint: CGPoint {
        CGPoint(x: self.frame.midX, y: self.frame.midY)
    }

    fileprivate var humanDescription: String {
        "\(self.role): \(self.title ?? self.label ?? "untitled")"
    }
}
