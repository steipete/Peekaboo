import Foundation
import TachikomaMCP
import MCP

/// MCP tool for interacting with application menu bars
public struct MenuTool: MCPTool {
    public let name = "menu"

    public var description: String {
        """
        Interact with application menu bars - list available menus and menu items for an application, or click on a specific menu item using path notation.

        Actions:
        - list: Discover all available menus and menu items for an application
        - list-all: List all menus across all applications (for debugging)
        - click: Click on a specific menu item using path notation
        - click-extra: Click on a system menu extra (menu bar items)

        Target applications by name (e.g., "Safari"), bundle ID (e.g., "com.apple.Safari"),
        or process ID (e.g., "PID:663"). Fuzzy matching is supported for application names.

        Examples:
        - List Chrome menus: { "action": "list", "app": "Google Chrome" }
        - Save document: { "action": "click", "app": "TextEdit", "path": "File > Save" }
        - Copy selection: { "action": "click", "app": "Safari", "path": "Edit > Copy" }
        Peekaboo MCP 3.0.0-beta.2 using anthropic/claude-opus-4-20250514, ollama/llava:latest
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "action": SchemaBuilder.string(
                    description: "Action to perform: 'list' to discover menus, 'click' to interact with menu items, 'click-extra' for system menu extras, 'list-all' for all menus",
                    enum: ["list", "click", "click-extra", "list-all"]),
                "app": SchemaBuilder.string(
                    description: "Target application name, bundle ID, or process ID (required for list and click actions)"),
                "path": SchemaBuilder.string(
                    description: "Menu path for nested items (e.g., 'File > Save As...' or 'Edit > Copy')"),
                "item": SchemaBuilder.string(
                    description: "Simple menu item to click (for non-nested items)"),
                "title": SchemaBuilder.string(
                    description: "Title of system menu extra (for click-extra action)"),
            ],
            required: ["action"])
    }

    public init() {}

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        guard let action = arguments.getString("action") else {
            return ToolResponse.error("Missing required parameter: action")
        }

        switch action {
        case "list":
            return try await self.handleListAction(arguments: arguments)
        case "list-all":
            return try await self.handleListAllAction()
        case "click":
            return try await self.handleClickAction(arguments: arguments)
        case "click-extra":
            return try await self.handleClickExtraAction(arguments: arguments)
        default:
            return ToolResponse.error("Invalid action: \(action). Must be one of: list, click, click-extra, list-all")
        }
    }

    // MARK: - Action Handlers

    private func handleListAction(arguments: ToolArguments) async throws -> ToolResponse {
        guard let app = arguments.getString("app") else {
            return ToolResponse.error("Missing required parameter: app (required for list action)")
        }

        do {
            let menuStructure = try await PeekabooServices.shared.menu.listMenus(for: app)
            let formattedOutput = self.formatMenuStructure(menuStructure)

            return ToolResponse.text(
                formattedOutput,
                meta: .object([
                    "app": .string(menuStructure.application.name),
                    "total_menus": .int(menuStructure.menus.count),
                    "total_items": .int(menuStructure.totalItems),
                ]))
        } catch {
            return ToolResponse.error("Failed to list menus for app '\(app)': \(error.localizedDescription)")
        }
    }

    private func handleListAllAction() async throws -> ToolResponse {
        // This is a debugging feature - we'll list menus for all running applications
        do {
            let apps = try await PeekabooServices.shared.applications.listApplications()
            var allMenus: [(app: String, menuCount: Int, itemCount: Int)] = []

            for app in apps.data.applications {
                do {
                    let menuStructure = try await PeekabooServices.shared.menu.listMenus(for: app.name)
                    allMenus.append((
                        app: app.name,
                        menuCount: menuStructure.menus.count,
                        itemCount: menuStructure.totalItems))
                } catch {
                    // Skip apps that don't have accessible menus
                    continue
                }
            }

            if allMenus.isEmpty {
                return ToolResponse.text("No applications with accessible menus found.")
            }

            var output = "📋 All Application Menus\n\n"
            for menuInfo in allMenus.sorted(by: { $0.app < $1.app }) {
                output += "• \(menuInfo.app): \(menuInfo.menuCount) menus, \(menuInfo.itemCount) items\n"
            }

            return ToolResponse.text(
                output,
                meta: .object([
                    "total_apps": .int(allMenus.count),
                    "apps": .array(allMenus.map { .string($0.app) }),
                ]))
        } catch {
            return ToolResponse.error("Failed to list all menus: \(error.localizedDescription)")
        }
    }

    private func handleClickAction(arguments: ToolArguments) async throws -> ToolResponse {
        guard let app = arguments.getString("app") else {
            return ToolResponse.error("Missing required parameter: app (required for click action)")
        }

        // Try path first, then item
        if let path = arguments.getString("path") {
            do {
                try await PeekabooServices.shared.menu.clickMenuItem(app: app, itemPath: path)
                return ToolResponse.text("✅ Successfully clicked menu item: \(path)")
            } catch {
                return ToolResponse
                    .error("Failed to click menu item '\(path)' in app '\(app)': \(error.localizedDescription)")
            }
        } else if let item = arguments.getString("item") {
            do {
                try await PeekabooServices.shared.menu.clickMenuItemByName(app: app, itemName: item)
                return ToolResponse.text("✅ Successfully clicked menu item: \(item)")
            } catch {
                return ToolResponse
                    .error("Failed to click menu item '\(item)' in app '\(app)': \(error.localizedDescription)")
            }
        } else {
            return ToolResponse
                .error("Missing required parameter: either 'path' or 'item' must be provided for click action")
        }
    }

    private func handleClickExtraAction(arguments: ToolArguments) async throws -> ToolResponse {
        guard let title = arguments.getString("title") else {
            return ToolResponse.error("Missing required parameter: title (required for click-extra action)")
        }

        do {
            try await PeekabooServices.shared.menu.clickMenuExtra(title: title)
            return ToolResponse.text("✅ Successfully clicked system menu extra: \(title)")
        } catch {
            return ToolResponse.error("Failed to click system menu extra '\(title)': \(error.localizedDescription)")
        }
    }

    // MARK: - Formatting Helpers

    private func formatMenuStructure(_ structure: MenuStructure) -> String {
        var output = "📋 Menu Structure for \(structure.application.name)\n\n"

        for menu in structure.menus {
            output += self.formatMenu(menu, indent: 0)
        }

        output += "\n📊 Summary: \(structure.menus.count) menus, \(structure.totalItems) total items"

        return output
    }

    private func formatMenu(_ menu: Menu, indent: Int) -> String {
        let indentStr = String(repeating: "  ", count: indent)
        var output = "\(indentStr)📁 \(menu.title)"

        if !menu.isEnabled {
            output += " (disabled)"
        }

        output += "\n"

        for item in menu.items {
            output += self.formatMenuItem(item, indent: indent + 1)
        }

        return output
    }

    private func formatMenuItem(_ item: MenuItem, indent: Int) -> String {
        let indentStr = String(repeating: "  ", count: indent)
        var output = ""

        if item.isSeparator {
            output += "\(indentStr)┈┈┈┈┈┈┈┈┈┈\n"
            return output
        }

        let icon = item.submenu.isEmpty ? "•" : "📂"
        output += "\(indentStr)\(icon) \(item.title)"

        // Add keyboard shortcut if available
        if let shortcut = item.keyboardShortcut {
            output += " (\(shortcut.displayString))"
        }

        // Add state indicators
        var indicators: [String] = []
        if !item.isEnabled { indicators.append("disabled") }
        if item.isChecked { indicators.append("checked") }

        if !indicators.isEmpty {
            output += " [\(indicators.joined(separator: ", "))]"
        }

        output += "\n"

        // Add submenu items
        for subitem in item.submenu {
            output += self.formatMenuItem(subitem, indent: indent + 1)
        }

        return output
    }
}
