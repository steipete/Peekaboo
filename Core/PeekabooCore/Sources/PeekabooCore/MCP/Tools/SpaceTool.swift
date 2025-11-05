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
        Peekaboo MCP 3.0.0-beta.2 using anthropic/claude-opus-4-20250514, ollama/llava:latest
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
        guard let action = arguments.getString("action") else {
            return ToolResponse.error("Missing required parameter: action")
        }

        let to = arguments.getNumber("to")
        let appName = arguments.getString("app")
        let windowTitle = arguments.getString("window_title")
        let windowIndex = arguments.getInt("window_index")
        let toCurrent = arguments.getBool("to_current") ?? false
        let follow = arguments.getBool("follow") ?? false
        let detailed = arguments.getBool("detailed") ?? false

        let spaceService = SpaceManagementService()

        do {
            let startTime = Date()

            switch action {
            case "list":
                return try await self.handleList(
                    service: spaceService,
                    detailed: detailed,
                    startTime: startTime)

            case "switch":
                guard let spaceNumber = to else {
                    return ToolResponse.error("Switch action requires 'to' parameter (space number)")
                }
                return try await self.handleSwitch(
                    service: spaceService,
                    spaceNumber: Int(spaceNumber),
                    startTime: startTime)

            case "move-window":
                guard let appName else {
                    return ToolResponse.error("Move-window action requires 'app' parameter")
                }

                if toCurrent, to != nil {
                    return ToolResponse.error("Cannot specify both 'to_current' and 'to' parameters")
                }

                if !toCurrent, to == nil {
                    return ToolResponse
                        .error("Move-window action requires either 'to' (space number) or 'to_current' parameter")
                }

                return try await self.handleMoveWindow(
                    service: spaceService,
                    appName: appName,
                    windowTitle: windowTitle,
                    windowIndex: windowIndex,
                    targetSpaceNumber: to != nil ? Int(to!) : nil,
                    toCurrent: toCurrent,
                    follow: follow,
                    startTime: startTime)

            default:
                return ToolResponse.error("Unknown action: \(action). Supported actions: list, switch, move-window")
            }

        } catch {
            self.logger.error("Space operation execution failed: \(error)")
            return ToolResponse.error("Failed to \(action): \(error.localizedDescription)")
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
                    output += "  • Owner PIDs: \(space.ownerPIDs.map(String.init).joined(separator: ", "))\n"
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

        return ToolResponse(
            content: [
                .text(
                    "\(AgentDisplayTokens.Status.success) Switched to Space \(spaceNumber) in \(String(format: "%.2f", executionTime))s"),
            ],
            meta: .object([
                "space_number": .double(Double(spaceNumber)),
                "space_id": .double(Double(targetSpace.id)),
                "execution_time": .double(executionTime),
            ]))
    }

    @MainActor
    private func handleMoveWindow(
        service: SpaceManagementService,
        appName: String,
        windowTitle: String?,
        windowIndex: Int?,
        targetSpaceNumber: Int?,
        toCurrent: Bool,
        follow: Bool,
        startTime: Date) async throws -> ToolResponse
    {
        let windowService = PeekabooServices.shared.windows

        // Find the target window
        let windowTarget = try createWindowTarget(app: appName, title: windowTitle, index: windowIndex)
        let windows = try await windowService.listWindows(target: windowTarget)

        guard let windowInfo = windows.first else {
            return ToolResponse.error("No matching window found for app '\(appName)'")
        }

        let windowID = UInt32(windowInfo.windowID)

        if toCurrent {
            // Move to current space
            try service.moveWindowToCurrentSpace(windowID: windowID)

            let executionTime = Date().timeIntervalSince(startTime)

            return ToolResponse(
                content: [
                    .text(
                        "\(AgentDisplayTokens.Status.success) Moved window '\(windowInfo.title)' to current Space in \(String(format: "%.2f", executionTime))s"),
                ],
                meta: .object([
                    "window_title": .string(windowInfo.title),
                    "window_id": .double(Double(windowInfo.windowID)),
                    "moved_to_current": .bool(true),
                    "execution_time": .double(executionTime),
                ]))
        } else {
            // Move to specific space
            guard let targetSpaceNumber else {
                return ToolResponse.error("Internal error: targetSpaceNumber is nil")
            }

            let spaces = service.getAllSpaces()

            guard targetSpaceNumber > 0, targetSpaceNumber <= spaces.count else {
                return ToolResponse.error("Invalid space number. Available spaces: 1-\(spaces.count)")
            }

            let targetSpace = spaces[targetSpaceNumber - 1]

            try service.moveWindowToSpace(windowID: windowID, spaceID: targetSpace.id)

            // If follow is true, switch to the target space
            if follow {
                try await service.switchToSpace(targetSpace.id)
            }

            let executionTime = Date().timeIntervalSince(startTime)
            let followText = follow ? " and switched to Space \(targetSpaceNumber)" : ""

            return ToolResponse(
                content: [
                    .text(
                        "\(AgentDisplayTokens.Status.success) Moved window '\(windowInfo.title)' to Space \(targetSpaceNumber)\(followText) in \(String(format: "%.2f", executionTime))s"),
                ],
                meta: .object([
                    "window_title": .string(windowInfo.title),
                    "window_id": .double(Double(windowInfo.windowID)),
                    "target_space_number": .double(Double(targetSpaceNumber)),
                    "target_space_id": .double(Double(targetSpace.id)),
                    "followed": .bool(follow),
                    "execution_time": .double(executionTime),
                ]))
        }
    }

    // MARK: - Helper Methods

    private func createWindowTarget(app: String, title: String?, index: Int?) throws -> WindowTarget {
        if let title {
            return .applicationAndTitle(app: app, title: title)
        }

        if let index {
            return .index(app: app, index: index)
        }

        return .application(app)
    }
}
