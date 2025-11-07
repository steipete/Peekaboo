import Foundation
import MCP
import os.log
import TachikomaMCP

/// MCP tool for interacting with the macOS Dock
public struct DockTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "DockTool")

    public let name = "dock"

    public var description: String {
        """
        Interact with the macOS Dock - launch apps, show context menus, hide/show dock.
        Actions: launch, right-click (with menu selection), hide, show, list
        Can list all dock items including persistent and running applications.
        Peekaboo MCP 3.0.0-beta.2 using openai/gpt-5, anthropic/claude-sonnet-4.5
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "action": SchemaBuilder.string(
                    description: "Action to perform on the dock",
                    enum: ["launch", "right-click", "hide", "show", "list"]),
                "app": SchemaBuilder.string(
                    description: "Application name for launch/right-click actions"),
                "select": SchemaBuilder.string(
                    description: "Menu item to select after right-clicking"),
                "include_all": SchemaBuilder.boolean(
                    description: "Include all items when listing (default: false)",
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

        let app = arguments.getString("app")
        let select = arguments.getString("select")
        let includeAll = arguments.getBool("include_all") ?? false

        let dockService = PeekabooServices.shared.dock

        do {
            let startTime = Date()

            switch action {
            case "launch":
                return try await self.handleLaunch(
                    service: dockService,
                    app: app,
                    startTime: startTime)

            case "right-click":
                return try await self.handleRightClick(
                    service: dockService,
                    app: app,
                    menuItem: select,
                    startTime: startTime)

            case "hide":
                return try await self.handleHide(
                    service: dockService,
                    startTime: startTime)

            case "show":
                return try await self.handleShow(
                    service: dockService,
                    startTime: startTime)

            case "list":
                return try await self.handleList(
                    service: dockService,
                    includeAll: includeAll,
                    startTime: startTime)

            default:
                return ToolResponse
                    .error("Unknown action: \(action). Supported actions: launch, right-click, hide, show, list")
            }

        } catch {
            self.logger.error("Dock operation execution failed: \(error)")
            return ToolResponse.error("Failed to \(action) dock: \(error.localizedDescription)")
        }
    }

    // MARK: - Action Handlers

    private func handleLaunch(
        service: any DockServiceProtocol,
        app: String?,
        startTime: Date) async throws -> ToolResponse
    {
        guard let app else {
            return ToolResponse.error("Must specify 'app' for launch action")
        }

        try await service.launchFromDock(appName: app)

        let executionTime = Date().timeIntervalSince(startTime)

        return ToolResponse(
            content: [
                .text(
                    "\(AgentDisplayTokens.Status.success) Launched \(app) from dock in \(String(format: "%.2f", executionTime))s"),
            ],
            meta: .object([
                "app_name": .string(app),
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleRightClick(
        service: any DockServiceProtocol,
        app: String?,
        menuItem: String?,
        startTime: Date) async throws -> ToolResponse
    {
        guard let app else {
            return ToolResponse.error("Must specify 'app' for right-click action")
        }

        try await service.rightClickDockItem(appName: app, menuItem: menuItem)

        let executionTime = Date().timeIntervalSince(startTime)

        var message = "\(AgentDisplayTokens.Status.success) Right-clicked \(app) in dock"
        if let menuItem {
            message += " and selected '\(menuItem)'"
        }
        message += " in \(String(format: "%.2f", executionTime))s"

        return ToolResponse(
            content: [.text(message)],
            meta: .object([
                "app_name": .string(app),
                "menu_item": menuItem != nil ? .string(menuItem!) : .null,
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleHide(
        service: any DockServiceProtocol,
        startTime: Date) async throws -> ToolResponse
    {
        try await service.hideDock()

        let executionTime = Date().timeIntervalSince(startTime)

        return ToolResponse(
            content: [
                .text(
                    "\(AgentDisplayTokens.Status.success) Hidden dock (enabled auto-hide) in \(String(format: "%.2f", executionTime))s"),
            ],
            meta: .object([
                "auto_hide_enabled": .bool(true),
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleShow(
        service: any DockServiceProtocol,
        startTime: Date) async throws -> ToolResponse
    {
        try await service.showDock()

        let executionTime = Date().timeIntervalSince(startTime)

        return ToolResponse(
            content: [
                .text(
                    "\(AgentDisplayTokens.Status.success) Shown dock (disabled auto-hide) in \(String(format: "%.2f", executionTime))s"),
            ],
            meta: .object([
                "auto_hide_enabled": .bool(false),
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleList(
        service: any DockServiceProtocol,
        includeAll: Bool,
        startTime: Date) async throws -> ToolResponse
    {
        let dockItems = try await service.listDockItems(includeAll: includeAll)
        let executionTime = Date().timeIntervalSince(startTime)

        let itemList = dockItems.enumerated().map { index, item in
            var info = "[\(index)] \(item.title) (\(item.itemType.rawValue))"
            if let isRunning = item.isRunning {
                info += isRunning ? " [RUNNING]" : " [NOT RUNNING]"
            }
            if let bundleId = item.bundleIdentifier {
                info += " [\(bundleId)]"
            }
            return info
        }.joined(separator: "\n")

        let filterText = includeAll ? "(including separators/spacers)" : "(applications and folders only)"
        let message = "🚢 Dock Items \(filterText) (\(dockItems.count) total):\n\(itemList)\n\nCompleted in \(String(format: "%.2f", executionTime))s"

        return ToolResponse(
            content: [.text(message)],
            meta: .object([
                "dock_item_count": .double(Double(dockItems.count)),
                "include_all": .bool(includeAll),
                "dock_items": .array(dockItems.map { item in
                    .object([
                        "index": .double(Double(item.index)),
                        "title": .string(item.title),
                        "item_type": .string(item.itemType.rawValue),
                        "is_running": item.isRunning != nil ? .bool(item.isRunning!) : .null,
                        "bundle_identifier": item.bundleIdentifier != nil ? .string(item.bundleIdentifier!) : .null,
                        "position": item.position != nil ? .object([
                            "x": .double(Double(item.position!.x)),
                            "y": .double(Double(item.position!.y)),
                        ]) : .null,
                        "size": item.size != nil ? .object([
                            "width": .double(Double(item.size!.width)),
                            "height": .double(Double(item.size!.height)),
                        ]) : .null,
                    ])
                }),
                "execution_time": .double(executionTime),
            ]))
    }
}
