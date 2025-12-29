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
        Peekaboo MCP 3.0.0-beta3 using openai/gpt-5.1, anthropic/claude-sonnet-4.5
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
                "snapshot": SchemaBuilder.string(
                    description: "Optional. Snapshot ID from see command. Uses latest snapshot if not specified"),
                "duration": SchemaBuilder.number(
                    description: "Optional. Duration in milliseconds (default: 500)",
                    default: 500),
                "steps": SchemaBuilder.number(
                    description: "Optional. Number of intermediate steps (default: 10)",
                    default: 10),
                "profile": SchemaBuilder.string(
                    description: "Optional. Movement profile. Use 'linear' (default) or 'human'.",
                    enum: ["linear", "human"],
                    default: "linear"),
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
            let fromPoint = try await self.resolveLocation(
                target: request.fromTarget,
                snapshotId: request.snapshotId,
                parameterName: "from")
            let toPoint = try await self.resolveLocation(
                target: request.toTarget,
                snapshotId: request.snapshotId,
                parameterName: "to")

            guard fromPoint.point != toPoint.point else {
                return ToolResponse.error("Start and end points must be different")
            }

            try await self.focusTargetAppIfNeeded(request: request)
            self.logSpaceIntentIfNeeded(request: request)

            let distance = hypot(toPoint.point.x - fromPoint.point.x, toPoint.point.y - fromPoint.point.y)
            let movement = request.profile.resolveParameters(
                smooth: true,
                durationOverride: request.durationOverride,
                stepsOverride: request.stepsOverride,
                defaultDuration: 500,
                defaultSteps: 20,
                distance: distance)

            try await self.context.automation.drag(
                from: fromPoint.point,
                to: toPoint.point,
                duration: movement.duration,
                steps: movement.steps,
                modifiers: request.modifiers,
                profile: movement.profile)

            let executionTime = Date().timeIntervalSince(startTime)
            return self.buildResponse(
                from: fromPoint,
                to: toPoint,
                movement: movement,
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
        snapshotId: String?,
        parameterName: String) async throws -> DragPointDescription
    {
        switch target {
        case let .coordinates(raw):
            let point = try self.parseCoordinates(raw, parameterName: parameterName)
            return DragPointDescription(point: point, description: "(\(Int(point.x)), \(Int(point.y)))")
        case let .element(query):
            guard let snapshot = await self.getSnapshot(id: snapshotId) else {
                throw CoordinateParseError(message: "No active snapshot. Run 'see' command first to capture UI state.")
            }
            if let element = await snapshot.getElement(byId: query) {
                return DragPointDescription(
                    point: element.centerPoint,
                    description: "element \(query) (\(element.humanDescription))",
                    targetApp: snapshot.applicationName,
                    windowTitle: snapshot.windowTitle,
                    elementRole: element.summaryRole,
                    elementLabel: element.summaryLabel)
            }

            let elements = await snapshot.uiElements
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
            return DragPointDescription(
                point: element.centerPoint,
                description: element.humanDescription,
                targetApp: snapshot.applicationName,
                windowTitle: snapshot.windowTitle,
                elementRole: element.summaryRole,
                elementLabel: element.summaryLabel)
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

    private func getSnapshot(id: String?) async -> UISnapshot? {
        await UISnapshotManager.shared.getSnapshot(id: id)
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
        movement: MovementParameters,
        executionTime: TimeInterval,
        request: DragRequest) -> ToolResponse
    {
        let deltaX = to.point.x - from.point.x
        let deltaY = to.point.y - from.point.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)

        var message = """
        \(AgentDisplayTokens.Status.success) Performed drag and drop from \(from.description) to \(to.description)
        """
        message += " using \(movement.profileName) profile"
        if let modifiers = request.modifiers, !modifiers.isEmpty {
            message += " with modifiers (\(modifiers))"
        }
        message += " over \(movement.duration)ms with \(movement.steps) steps"
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
            "duration": .double(Double(movement.duration)),
            "steps": .double(Double(movement.steps)),
            "profile": .string(movement.profileName),
            "distance": .double(distance),
            "execution_time": .double(executionTime),
        ]

        if let modifiers = request.modifiers {
            metaData["modifiers"] = .string(modifiers)
        }

        if let toApp = request.targetApp {
            metaData["target_app"] = .string(toApp)
        }

        let summary = ToolEventSummary(
            targetApp: request.targetApp ?? to.targetApp ?? from.targetApp,
            windowTitle: to.windowTitle ?? from.windowTitle,
            elementRole: to.elementRole ?? from.elementRole,
            elementLabel: to.elementLabel ?? from.elementLabel,
            actionDescription: "Drag",
            coordinates: ToolEventSummary.Coordinates(
                x: Double(to.point.x),
                y: Double(to.point.y)),
            pointerProfile: movement.profileName,
            pointerDistance: Double(distance),
            pointerDirection: pointerDirection(from: from.point, to: to.point),
            pointerDurationMs: Double(movement.duration),
            notes: "from \(from.description) to \(to.description)")

        let metaValue = ToolEventSummary.merge(summary: summary, into: .object(metaData))

        return ToolResponse(content: [.text(message)], meta: metaValue)
    }

    private struct CoordinateParseError: Swift.Error {
        let message: String
    }
}

// MARK: - Supporting Types

private struct DragRequest {
    let fromTarget: DragLocationInput
    let toTarget: DragLocationInput
    let snapshotId: String?
    let targetApp: String?
    let durationOverride: Int?
    let stepsOverride: Int?
    let modifiers: String?
    let autoFocus: Bool
    let bringToCurrentSpace: Bool
    let spaceSwitch: Bool
    let profile: MovementProfileOption

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

        let profileName = (arguments.getString("profile") ?? "linear").lowercased()
        guard let profile = MovementProfileOption(rawValue: profileName) else {
            throw DragToolError("Invalid profile '\(profileName)'. Use 'linear' or 'human'.")
        }

        let durationProvided = arguments.getValue(for: "duration") != nil
        let stepsProvided = arguments.getValue(for: "steps") != nil
        let durationOverride = durationProvided ? arguments.getNumber("duration").map(Int.init) : nil
        let stepsOverride = stepsProvided ? arguments.getNumber("steps").map(Int.init) : nil

        if let override = durationOverride {
            guard override > 0 else {
                throw DragToolError("Duration must be greater than 0.")
            }
            guard override <= 30000 else {
                throw DragToolError("Duration must be 30 seconds or less to prevent excessive delays.")
            }
        }

        if let override = stepsOverride {
            guard override > 0 else {
                throw DragToolError("Steps must be greater than 0.")
            }
            guard override <= 100 else {
                throw DragToolError("Steps must be 100 or less to prevent excessive processing.")
            }
        }

        self.fromTarget = fromTarget
        self.toTarget = toTarget
        self.snapshotId = arguments.getString("snapshot")
        self.targetApp = arguments.getString("to_app")
        self.durationOverride = durationOverride
        self.stepsOverride = stepsOverride
        self.modifiers = arguments.getString("modifiers")
        self.autoFocus = arguments.getBool("auto_focus") ?? true
        self.bringToCurrentSpace = arguments.getBool("bring_to_current_space") ?? false
        self.spaceSwitch = arguments.getBool("space_switch") ?? false
        self.profile = profile
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
    let targetApp: String?
    let windowTitle: String?
    let elementRole: String?
    let elementLabel: String?

    init(
        point: CGPoint,
        description: String,
        targetApp: String? = nil,
        windowTitle: String? = nil,
        elementRole: String? = nil,
        elementLabel: String? = nil)
    {
        self.point = point
        self.description = description
        self.targetApp = targetApp
        self.windowTitle = windowTitle
        self.elementRole = elementRole
        self.elementLabel = elementLabel
    }
}

extension UIElement {
    fileprivate var centerPoint: CGPoint {
        CGPoint(x: self.frame.midX, y: self.frame.midY)
    }

    fileprivate var humanDescription: String {
        "\(self.role): \(self.title ?? self.label ?? "untitled")"
    }
}
