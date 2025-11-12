import Foundation
import MCP
import os.log
import TachikomaMCP

/// MCP tool for managing macOS Spaces (virtual desktops)
public struct SpaceTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "SpaceTool")

    public let name = "space"

    public var description: String {
        """
        Manage macOS Spaces (virtual desktops).

        Actions:
        - list: List spaces with detailed information
        - switch: Switch to a specific space
        - move-window: Move windows between spaces

        Supports moving windows with optional follow behavior to switch along with the window.

        Examples:
        - List spaces: { "action": "list" }
        - List with details: { "action": "list", "detailed": true }
        - Switch to space 2: { "action": "switch", "to": 2 }
        - Move window to space 3: { "action": "move-window", "app": "Safari", "to": 3 }
        - Move window to current space: { "action": "move-window", "app": "TextEdit", "to_current": true }
        - Move and follow: { "action": "move-window", "app": "Terminal", "to": 2, "follow": true }
        Peekaboo MCP 3.0.0-beta.2 using openai/gpt-5, anthropic/claude-sonnet-4.5
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "action": SchemaBuilder.string(
                    description: "The action to perform",
                    enum: ["list", "switch", "move-window"]),
                "to": SchemaBuilder.number(
                    description: "Space number to switch to (for switch action)"),
                "app": SchemaBuilder.string(
                    description: "Application name for move-window action"),
                "window_title": SchemaBuilder.string(
                    description: "Window title to move"),
                "window_index": SchemaBuilder.number(
                    description: "Window index for multi-window apps"),
                "to_current": SchemaBuilder.boolean(
                    description: "Move window to current space (for move-window action)",
                    default: false),
                "follow": SchemaBuilder.boolean(
                    description: "Follow the window to the new space (for move-window action)",
                    default: false),
                "detailed": SchemaBuilder.boolean(
                    description: "Show detailed space information (for list action)",
                    default: false),
            ],
            required: ["action"])
    }

    public init() {}

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        let spaceService = SpaceManagementService()
        let parsedAction: SpaceAction

        do {
            parsedAction = try self.parseAction(arguments: arguments)
        } catch let validationError as SpaceActionValidationError {
            return ToolResponse.error(validationError.message)
        }

        do {
            return try await self.perform(action: parsedAction, service: spaceService, startTime: Date())
        } catch {
            self.logger.error("Space operation execution failed: \(error)")
            return ToolResponse.error("Failed to \(parsedAction.description): \(error.localizedDescription)")
        }
    }

    // MARK: - Action Handlers

    @MainActor
    private func handleList(
        service: SpaceManagementService,
        detailed: Bool,
        startTime: Date) async throws -> ToolResponse
    {
        let spaces = service.getAllSpaces()
        let executionTime = Date().timeIntervalSince(startTime)

        if spaces.isEmpty {
            return ToolResponse(
                content: [.text("No Spaces found")],
                meta: .object([
                    "count": .double(0),
                    "execution_time": .double(executionTime),
                ]))
        }

        var output = "Found \(spaces.count) Space(s):\n\n"

        for (index, space) in spaces.enumerated() {
            let spaceNumber = index + 1
            let activeIndicator = space.isActive ? " (Active)" : ""

            output += "Space \(spaceNumber)\(activeIndicator):\n"

            if detailed {
                output += "  • ID: \(space.id)\n"
                output += "  • Type: \(space.type.rawValue)\n"
                if let displayID = space.displayID {
                    output += "  • Display: \(displayID)\n"
                }
                if let name = space.name, !name.isEmpty {
                    output += "  • Name: \(name)\n"
                }
                if !space.ownerPIDs.isEmpty {
                    let owners = space.ownerPIDs.map(String.init).joined(separator: ", ")
                    output += "  • Owner PIDs: \(owners)\n"
                }
            } else {
                output += "  • Type: \(space.type.rawValue)\n"
            }

            output += "\n"
        }

        return ToolResponse(
            content: [.text(output.trimmingCharacters(in: .whitespacesAndNewlines))],
            meta: .object([
                "count": .double(Double(spaces.count)),
                "execution_time": .double(executionTime),
            ]))
    }

    @MainActor
    private func handleSwitch(
        service: SpaceManagementService,
        spaceNumber: Int,
        startTime: Date) async throws -> ToolResponse
    {
        let spaces = service.getAllSpaces()

        guard spaceNumber > 0, spaceNumber <= spaces.count else {
            return ToolResponse.error("Invalid space number. Available spaces: 1-\(spaces.count)")
        }

        let targetSpace = spaces[spaceNumber - 1]

        // Check if already on the target space
        if targetSpace.isActive {
            let executionTime = Date().timeIntervalSince(startTime)
            return ToolResponse(
                content: [.text("Already on Space \(spaceNumber)")],
                meta: .object([
                    "space_number": .double(Double(spaceNumber)),
                    "space_id": .double(Double(targetSpace.id)),
                    "was_already_active": .bool(true),
                    "execution_time": .double(executionTime),
                ]))
        }

        try await service.switchToSpace(targetSpace.id)

        let executionTime = Date().timeIntervalSince(startTime)
        let message = self.successMessage("Switched to Space \(spaceNumber)", duration: executionTime)

        return ToolResponse(
            content: [.text(message)],
            meta: .object([
                "space_number": .double(Double(spaceNumber)),
                "space_id": .double(Double(targetSpace.id)),
                "execution_time": .double(executionTime),
            ]))
    }

    @MainActor
    private func handleMoveWindow(
        service: SpaceManagementService,
        request: MoveWindowRequest,
        startTime: Date) async throws -> ToolResponse
    {
        let windowService = PeekabooServices.shared.windows

        // Find the target window
        let windowTarget = try self.createWindowTarget(
            app: request.appName,
            title: request.windowTitle,
            index: request.windowIndex)
        let windows = try await windowService.listWindows(target: windowTarget)

        guard let windowInfo = windows.first else {
            return ToolResponse.error("No matching window found for app '\(request.appName)'")
        }

        guard let windowID = UInt32(exactly: windowInfo.windowID) else {
            return ToolResponse.error("Window '\(windowInfo.title)' is missing an identifier")
        }

        if request.toCurrent {
            return try self.moveWindowToCurrentSpace(
                service: service,
                windowInfo: windowInfo,
                windowID: windowID,
                startTime: startTime)
        }

        return try await self.moveWindowToSpecificSpace(
            service: service,
            request: request,
            windowInfo: windowInfo,
            windowID: windowID,
            startTime: startTime)
    }

    // MARK: - Helper Methods

    private func perform(
        action: SpaceAction,
        service: SpaceManagementService,
        startTime: Date) async throws -> ToolResponse
    {
        switch action {
        case let .list(detailed):
            try await self.handleList(service: service, detailed: detailed, startTime: startTime)
        case let .switchSpace(spaceNumber):
            try await self.handleSwitch(service: service, spaceNumber: spaceNumber, startTime: startTime)
        case let .moveWindow(request):
            try await self.handleMoveWindow(service: service, request: request, startTime: startTime)
        }
    }

    private func parseAction(arguments: ToolArguments) throws -> SpaceAction {
        guard let actionName = arguments.getString("action") else {
            throw SpaceActionValidationError("Missing required parameter: action")
        }

        switch actionName {
        case "list":
            let detailed = arguments.getBool("detailed") ?? false
            return .list(detailed: detailed)
        case "switch":
            guard let spaceNumber = arguments.getNumber("to").map(Int.init) else {
                throw SpaceActionValidationError("Switch action requires 'to' parameter (space number)")
            }
            return .switchSpace(spaceNumber: spaceNumber)
        case "move-window":
            return try self.parseMoveWindow(arguments: arguments)
        default:
            throw SpaceActionValidationError(
                "Unknown action: \(actionName). Supported actions: list, switch, move-window")
        }
    }

    private func parseMoveWindow(arguments: ToolArguments) throws -> SpaceAction {
        guard let appName = arguments.getString("app") else {
            throw SpaceActionValidationError("Move-window action requires 'app' parameter")
        }

        let toCurrent = arguments.getBool("to_current") ?? false
        let targetSpace = arguments.getNumber("to").map(Int.init)

        if toCurrent, targetSpace != nil {
            throw SpaceActionValidationError("Cannot specify both 'to_current' and 'to' parameters")
        }

        if !toCurrent, targetSpace == nil {
            throw SpaceActionValidationError(
                "Move-window action requires either 'to' (space number) or 'to_current' parameter")
        }

        let request = MoveWindowRequest(
            appName: appName,
            windowTitle: arguments.getString("window_title"),
            windowIndex: arguments.getInt("window_index"),
            targetSpaceNumber: targetSpace,
            toCurrent: toCurrent,
            follow: arguments.getBool("follow") ?? false)

        return .moveWindow(request)
    }

    private func createWindowTarget(app: String, title: String?, index: Int?) throws -> WindowTarget {
        if let title {
            return .applicationAndTitle(app: app, title: title)
        }

        if let index {
            return .index(app: app, index: index)
        }

        return .application(app)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        String(format: "%.2f", duration)
    }

    private func successMessage(_ body: String, duration: TimeInterval) -> String {
        "\(AgentDisplayTokens.Status.success) \(body) in \(self.formatDuration(duration))s"
    }
}

private enum SpaceAction {
    case list(detailed: Bool)
    case switchSpace(spaceNumber: Int)
    case moveWindow(MoveWindowRequest)

    var description: String {
        switch self {
        case .list:
            "list"
        case .switchSpace:
            "switch"
        case .moveWindow:
            "move-window"
        }
    }
}

private struct MoveWindowRequest {
    let appName: String
    let windowTitle: String?
    let windowIndex: Int?
    let targetSpaceNumber: Int?
    let toCurrent: Bool
    let follow: Bool
}

private struct SpaceActionValidationError: Error {
    let message: String

    init(_ message: String) { self.message = message }
}

extension SpaceTool {
    @MainActor
    private func moveWindowToCurrentSpace(
        service: SpaceManagementService,
        windowInfo: ServiceWindowInfo,
        windowID: UInt32,
        startTime: Date) throws -> ToolResponse
    {
        try service.moveWindowToCurrentSpace(windowID: windowID)

        let executionTime = Date().timeIntervalSince(startTime)
        let message = self.successMessage(
            "Moved window '\(windowInfo.title)' to current Space",
            duration: executionTime)

        return ToolResponse(
            content: [.text(message)],
            meta: .object([
                "window_title": .string(windowInfo.title),
                "window_id": .double(Double(windowID)),
                "moved_to_current": .bool(true),
                "execution_time": .double(executionTime),
            ]))
    }

    @MainActor
    private func moveWindowToSpecificSpace(
        service: SpaceManagementService,
        request: MoveWindowRequest,
        windowInfo: ServiceWindowInfo,
        windowID: UInt32,
        startTime: Date) async throws -> ToolResponse
    {
        guard let targetSpaceNumber = request.targetSpaceNumber else {
            return ToolResponse.error("Internal error: targetSpaceNumber is nil")
        }

        let spaces = service.getAllSpaces()
        guard targetSpaceNumber > 0, targetSpaceNumber <= spaces.count else {
            return ToolResponse.error("Invalid space number. Available spaces: 1-\(spaces.count)")
        }

        let targetSpace = spaces[targetSpaceNumber - 1]
        try service.moveWindowToSpace(windowID: windowID, spaceID: targetSpace.id)

        if request.follow {
            try await service.switchToSpace(targetSpace.id)
        }

        let executionTime = Date().timeIntervalSince(startTime)
        let followText = request.follow ? " and switched to Space \(targetSpaceNumber)" : ""
        let body = "Moved window '\(windowInfo.title)' to Space \(targetSpaceNumber)\(followText)"
        let message = self.successMessage(body, duration: executionTime)

        return ToolResponse(
            content: [.text(message)],
            meta: .object([
                "window_title": .string(windowInfo.title),
                "window_id": .double(Double(windowID)),
                "target_space_number": .double(Double(targetSpaceNumber)),
                "target_space_id": .double(Double(targetSpace.id)),
                "followed": .bool(request.follow),
                "execution_time": .double(executionTime),
            ]))
    }
}
