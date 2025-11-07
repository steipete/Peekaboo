import Foundation
import MCP
import os.log
import PeekabooFoundation
import TachikomaMCP

/// MCP tool for manipulating application windows
public struct WindowTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "WindowTool")

    public let name = "window"

    public var description: String {
        """
        Manipulate application windows - close, minimize, maximize, move, resize, and focus.

        Actions:
        - close: Close a window
        - minimize: Minimize a window
        - maximize: Maximize a window
        - move: Move a window to specific coordinates (requires x, y)
        - resize: Resize a window to specific dimensions (requires width, height)
        - set-bounds: Set both position and size (requires x, y, width, height)
        - focus: Bring a window to the foreground

        Target windows by application name and optionally by window title or index.
        Supports partial title matching for convenience.

        Examples:
        - Close Safari window: { "action": "close", "app": "Safari" }
        - Move window: { "action": "move", "app": "TextEdit", "x": 100, "y": 100 }
        - Resize window: { "action": "resize", "app": "Terminal", "width": 800, "height": 600 }
        Peekaboo MCP 3.0.0-beta.2 using openai/gpt-5, anthropic/claude-sonnet-4.5
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "action": SchemaBuilder.string(
                    description: "The action to perform on the window",
                    enum: ["close", "minimize", "maximize", "move", "resize", "set-bounds", "focus"]),
                "app": SchemaBuilder.string(
                    description: "Target application name, bundle ID, or process ID"),
                "title": SchemaBuilder.string(
                    description: "Window title to target (partial matching supported)"),
                "index": SchemaBuilder.number(
                    description: "Window index (0-based) for multi-window applications"),
                "x": SchemaBuilder.number(
                    description: "X coordinate for move or set-bounds action"),
                "y": SchemaBuilder.number(
                    description: "Y coordinate for move or set-bounds action"),
                "width": SchemaBuilder.number(
                    description: "Width for resize or set-bounds action"),
                "height": SchemaBuilder.number(
                    description: "Height for resize or set-bounds action"),
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
        let title = arguments.getString("title")
        let index = arguments.getInt("index")
        let x = arguments.getNumber("x")
        let y = arguments.getNumber("y")
        let width = arguments.getNumber("width")
        let height = arguments.getNumber("height")

        let windowService = PeekabooServices.shared.windows

        do {
            let startTime = Date()

            switch action {
            case "close":
                return try await self.handleClose(
                    service: windowService,
                    app: app,
                    title: title,
                    index: index,
                    startTime: startTime)

            case "minimize":
                return try await self.handleMinimize(
                    service: windowService,
                    app: app,
                    title: title,
                    index: index,
                    startTime: startTime)

            case "maximize":
                return try await self.handleMaximize(
                    service: windowService,
                    app: app,
                    title: title,
                    index: index,
                    startTime: startTime)

            case "move":
                guard let x, let y else {
                    return ToolResponse.error("Move action requires both 'x' and 'y' coordinates")
                }
                return try await self.handleMove(
                    service: windowService,
                    app: app,
                    title: title,
                    index: index,
                    x: x,
                    y: y,
                    startTime: startTime)

            case "resize":
                guard let width, let height else {
                    return ToolResponse.error("Resize action requires both 'width' and 'height' dimensions")
                }
                return try await self.handleResize(
                    service: windowService,
                    app: app,
                    title: title,
                    index: index,
                    width: width,
                    height: height,
                    startTime: startTime)

            case "set-bounds":
                guard let x, let y, let width, let height else {
                    return ToolResponse.error("Set-bounds action requires 'x', 'y', 'width', and 'height' parameters")
                }
                return try await self.handleSetBounds(
                    service: windowService,
                    app: app,
                    title: title,
                    index: index,
                    x: x,
                    y: y,
                    width: width,
                    height: height,
                    startTime: startTime)

            case "focus":
                return try await self.handleFocus(
                    service: windowService,
                    app: app,
                    title: title,
                    index: index,
                    startTime: startTime)

            default:
                return ToolResponse
                    .error(
                        "Unknown action: \(action). Supported actions: close, minimize, maximize, move, resize, set-bounds, focus")
            }

        } catch {
            self.logger.error("Window operation execution failed: \(error)")
            return ToolResponse.error("Failed to \(action) window: \(error.localizedDescription)")
        }
    }

    // MARK: - Action Handlers

    private func handleClose(
        service: any WindowManagementServiceProtocol,
        app: String?,
        title: String?,
        index: Int?,
        startTime: Date) async throws -> ToolResponse
    {
        let target = try createWindowTarget(app: app, title: title, index: index)

        // Get window info before closing for better reporting
        let windows = try await service.listWindows(target: target)
        guard let windowInfo = windows.first else {
            return ToolResponse.error("No matching window found to close")
        }

        try await service.closeWindow(target: target)

        let executionTime = Date().timeIntervalSince(startTime)

        return ToolResponse(
            content: [
                .text(
                    "\(AgentDisplayTokens.Status.success) Closed window '\(windowInfo.title)' in \(String(format: "%.2f", executionTime))s"),
            ],
            meta: .object([
                "window_title": .string(windowInfo.title),
                "window_id": .double(Double(windowInfo.windowID)),
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleMinimize(
        service: any WindowManagementServiceProtocol,
        app: String?,
        title: String?,
        index: Int?,
        startTime: Date) async throws -> ToolResponse
    {
        let target = try createWindowTarget(app: app, title: title, index: index)

        // Get window info before minimizing
        let windows = try await service.listWindows(target: target)
        guard let windowInfo = windows.first else {
            return ToolResponse.error("No matching window found to minimize")
        }

        try await service.minimizeWindow(target: target)

        let executionTime = Date().timeIntervalSince(startTime)

        return ToolResponse(
            content: [
                .text(
                    "\(AgentDisplayTokens.Status.success) Minimized window '\(windowInfo.title)' in \(String(format: "%.2f", executionTime))s"),
            ],
            meta: .object([
                "window_title": .string(windowInfo.title),
                "window_id": .double(Double(windowInfo.windowID)),
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleMaximize(
        service: any WindowManagementServiceProtocol,
        app: String?,
        title: String?,
        index: Int?,
        startTime: Date) async throws -> ToolResponse
    {
        let target = try createWindowTarget(app: app, title: title, index: index)

        // Get window info before maximizing
        let windows = try await service.listWindows(target: target)
        guard let windowInfo = windows.first else {
            return ToolResponse.error("No matching window found to maximize")
        }

        try await service.maximizeWindow(target: target)

        let executionTime = Date().timeIntervalSince(startTime)

        return ToolResponse(
            content: [
                .text(
                    "\(AgentDisplayTokens.Status.success) Maximized window '\(windowInfo.title)' in \(String(format: "%.2f", executionTime))s"),
            ],
            meta: .object([
                "window_title": .string(windowInfo.title),
                "window_id": .double(Double(windowInfo.windowID)),
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleMove(
        service: any WindowManagementServiceProtocol,
        app: String?,
        title: String?,
        index: Int?,
        x: Double,
        y: Double,
        startTime: Date) async throws -> ToolResponse
    {
        let target = try createWindowTarget(app: app, title: title, index: index)
        let position = CGPoint(x: x, y: y)

        // Get window info before moving
        let windows = try await service.listWindows(target: target)
        guard let windowInfo = windows.first else {
            return ToolResponse.error("No matching window found to move")
        }

        try await service.moveWindow(target: target, to: position)

        let executionTime = Date().timeIntervalSince(startTime)

        return ToolResponse(
            content: [
                .text(
                    "\(AgentDisplayTokens.Status.success) Moved window '\(windowInfo.title)' to (\(Int(x)), \(Int(y))) in \(String(format: "%.2f", executionTime))s"),
            ],
            meta: .object([
                "window_title": .string(windowInfo.title),
                "window_id": .double(Double(windowInfo.windowID)),
                "new_x": .double(x),
                "new_y": .double(y),
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleResize(
        service: any WindowManagementServiceProtocol,
        app: String?,
        title: String?,
        index: Int?,
        width: Double,
        height: Double,
        startTime: Date) async throws -> ToolResponse
    {
        let target = try createWindowTarget(app: app, title: title, index: index)
        let size = CGSize(width: width, height: height)

        // Get window info before resizing
        let windows = try await service.listWindows(target: target)
        guard let windowInfo = windows.first else {
            return ToolResponse.error("No matching window found to resize")
        }

        try await service.resizeWindow(target: target, to: size)

        let executionTime = Date().timeIntervalSince(startTime)

        return ToolResponse(
            content: [
                .text(
                    "\(AgentDisplayTokens.Status.success) Resized window '\(windowInfo.title)' to \(Int(width)) × \(Int(height)) in \(String(format: "%.2f", executionTime))s"),
            ],
            meta: .object([
                "window_title": .string(windowInfo.title),
                "window_id": .double(Double(windowInfo.windowID)),
                "new_width": .double(width),
                "new_height": .double(height),
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleSetBounds(
        service: any WindowManagementServiceProtocol,
        app: String?,
        title: String?,
        index: Int?,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        startTime: Date) async throws -> ToolResponse
    {
        let target = try createWindowTarget(app: app, title: title, index: index)
        let bounds = CGRect(x: x, y: y, width: width, height: height)

        // Get window info before setting bounds
        let windows = try await service.listWindows(target: target)
        guard let windowInfo = windows.first else {
            return ToolResponse.error("No matching window found to set bounds")
        }

        try await service.setWindowBounds(target: target, bounds: bounds)

        let executionTime = Date().timeIntervalSince(startTime)

        return ToolResponse(
            content: [
                .text(
                    "\(AgentDisplayTokens.Status.success) Set bounds for window '\(windowInfo.title)' to (\(Int(x)), \(Int(y)), \(Int(width)) × \(Int(height))) in \(String(format: "%.2f", executionTime))s"),
            ],
            meta: .object([
                "window_title": .string(windowInfo.title),
                "window_id": .double(Double(windowInfo.windowID)),
                "new_x": .double(x),
                "new_y": .double(y),
                "new_width": .double(width),
                "new_height": .double(height),
                "execution_time": .double(executionTime),
            ]))
    }

    private func handleFocus(
        service: any WindowManagementServiceProtocol,
        app: String?,
        title: String?,
        index: Int?,
        startTime: Date) async throws -> ToolResponse
    {
        let target = try createWindowTarget(app: app, title: title, index: index)

        // Get window info before focusing
        let windows = try await service.listWindows(target: target)
        guard let windowInfo = windows.first else {
            return ToolResponse.error("No matching window found to focus")
        }

        try await service.focusWindow(target: target)

        let executionTime = Date().timeIntervalSince(startTime)

        return ToolResponse(
            content: [
                .text(
                    "\(AgentDisplayTokens.Status.success) Focused window '\(windowInfo.title)' in \(String(format: "%.2f", executionTime))s"),
            ],
            meta: .object([
                "window_title": .string(windowInfo.title),
                "window_id": .double(Double(windowInfo.windowID)),
                "execution_time": .double(executionTime),
            ]))
    }

    // MARK: - Helper Methods

    private func createWindowTarget(app: String?, title: String?, index: Int?) throws -> WindowTarget {
        if let app, let title {
            return .applicationAndTitle(app: app, title: title)
        }

        if let app, let index {
            return .index(app: app, index: index)
        }

        if let app {
            return .application(app)
        }

        if let title {
            return .title(title)
        }

        throw PeekabooError.invalidInput("Must specify at least 'app' or 'title' parameter to target a window")
    }
}
