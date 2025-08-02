import Foundation
import MCP
import os.log

/// MCP tool for performing drag and drop operations between UI elements or coordinates
public struct DragTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "DragTool")

    public let name = "drag"

    public var description: String {
        """
        Perform drag and drop operations between UI elements or coordinates.
        Supports element queries, specific IDs, or raw coordinates for both start and end points.
        Includes focus options for handling windows in different spaces.
        Peekaboo MCP 3.0.0-beta.2 using anthropic/claude-opus-4-20250514, ollama/llava:latest
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

    public init() {}

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        // Validate that at least one 'from' and one 'to' parameter is specified
        let fromElement = arguments.getString("from")
        let fromCoords = arguments.getString("from_coords")
        let toElement = arguments.getString("to")
        let toCoords = arguments.getString("to_coords")

        guard fromElement != nil || fromCoords != nil else {
            return ToolResponse.error("Must specify either 'from' or 'from_coords' for the start point")
        }

        guard toElement != nil || toCoords != nil else {
            return ToolResponse.error("Must specify either 'to' or 'to_coords' for the end point")
        }

        // Parse optional parameters
        let sessionId = arguments.getString("session")
        let toApp = arguments.getString("to_app")
        let duration = Int(arguments.getNumber("duration") ?? 500)
        let steps = Int(arguments.getNumber("steps") ?? 10)
        let modifiers = arguments.getString("modifiers")
        let autoFocus = arguments.getBool("auto_focus") ?? true
        let bringToCurrentSpace = arguments.getBool("bring_to_current_space") ?? false
        let spaceSwitch = arguments.getBool("space_switch") ?? false

        // Validate duration and steps
        guard duration > 0 else {
            return ToolResponse.error("Duration must be greater than 0")
        }

        guard duration <= 30000 else {
            return ToolResponse.error("Duration must be 30 seconds or less to prevent excessive delays")
        }

        guard steps > 0 else {
            return ToolResponse.error("Steps must be greater than 0")
        }

        guard steps <= 100 else {
            return ToolResponse.error("Steps must be 100 or less to prevent excessive processing")
        }

        do {
            let startTime = Date()

            // Determine start location
            let (fromPoint, fromDescription) = try await resolveLocation(
                elementQuery: fromElement,
                coordinateString: fromCoords,
                sessionId: sessionId,
                parameterName: "from")

            // Determine end location
            let (toPoint, toDescription) = try await resolveLocation(
                elementQuery: toElement,
                coordinateString: toCoords,
                sessionId: sessionId,
                parameterName: "to")

            // Validate that from and to are different
            guard fromPoint != toPoint else {
                return ToolResponse.error("Start and end points must be different")
            }

            // Handle app focus if specified
            if let toApp, autoFocus {
                do {
                    let windowService = PeekabooServices.shared.windows
                    try await windowService.focusWindow(target: .application(toApp))
                    // Small delay to allow app to come to front
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                } catch {
                    self.logger.warning("Failed to focus target app '\(toApp)': \(error)")
                    // Continue with drag operation even if focus fails
                }
            }

            // Handle space management if needed
            if bringToCurrentSpace || spaceSwitch {
                // For now, log the intention - space management would need additional implementation
                self.logger
                    .info(
                        "Space management requested (bring_to_current_space: \(bringToCurrentSpace), space_switch: \(spaceSwitch))")
            }

            // Perform the drag operation
            let automation = PeekabooServices.shared.automation
            try await automation.drag(
                from: fromPoint,
                to: toPoint,
                duration: duration,
                steps: steps,
                modifiers: modifiers)

            let executionTime = Date().timeIntervalSince(startTime)

            // Calculate distance for the response
            let deltaX = toPoint.x - fromPoint.x
            let deltaY = toPoint.y - fromPoint.y
            let distance = sqrt(deltaX * deltaX + deltaY * deltaY)

            // Build response message
            var message = "✅ Performed drag and drop from \(fromDescription) to \(toDescription)"
            if let modifiers, !modifiers.isEmpty {
                message += " with modifiers (\(modifiers))"
            }
            message += " over \(duration)ms with \(steps) steps"
            message += " (distance: \(String(format: "%.1f", distance))px)"
            message += " in \(String(format: "%.2f", executionTime))s"

            var metaData: [String: Value] = [
                "from": .object([
                    "x": .double(Double(fromPoint.x)),
                    "y": .double(Double(fromPoint.y)),
                    "description": .string(fromDescription),
                ]),
                "to": .object([
                    "x": .double(Double(toPoint.x)),
                    "y": .double(Double(toPoint.y)),
                    "description": .string(toDescription),
                ]),
                "duration": .double(Double(duration)),
                "steps": .double(Double(steps)),
                "distance": .double(distance),
                "execution_time": .double(executionTime),
            ]

            if let modifiers {
                metaData["modifiers"] = .string(modifiers)
            }

            if let toApp {
                metaData["target_app"] = .string(toApp)
            }

            return ToolResponse(
                content: [.text(message)],
                meta: .object(metaData))

        } catch let coordinateError as CoordinateParseError {
            return ToolResponse.error(coordinateError.message)
        } catch {
            self.logger.error("Drag execution failed: \(error)")
            return ToolResponse.error("Failed to perform drag operation: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private struct CoordinateParseError: Swift.Error {
        let message: String
    }

    /// Resolve location from either element query or coordinate string
    private func resolveLocation(
        elementQuery: String?,
        coordinateString: String?,
        sessionId: String?,
        parameterName: String) async throws -> (CGPoint, String)
    {
        if let coords = coordinateString {
            // Parse coordinates
            let point = try parseCoordinates(coords, parameterName: parameterName)
            let description = "(\(Int(point.x)), \(Int(point.y)))"
            return (point, description)

        } else if let query = elementQuery {
            // Try to find element by ID first, then by text search
            guard let session = await getSession(id: sessionId) else {
                throw CoordinateParseError(message: "No active session. Run 'see' command first to capture UI state.")
            }

            // Check if it's an element ID (like B1, T2, etc.)
            if let element = await session.getElement(byId: query) {
                let point = CGPoint(x: element.frame.midX, y: element.frame.midY)
                let description = "element \(query) (\(element.role): \(element.title ?? element.label ?? "untitled"))"
                return (point, description)
            }

            // Search by text
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

            // Use first actionable match, or first match if none are actionable
            let element = matches.first { $0.isActionable } ?? matches.first!
            let point = CGPoint(x: element.frame.midX, y: element.frame.midY)
            let description = "\(element.role): \(element.title ?? element.label ?? "untitled")"
            return (point, description)

        } else {
            throw CoordinateParseError(message: "No location specified for \(parameterName)")
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
}
