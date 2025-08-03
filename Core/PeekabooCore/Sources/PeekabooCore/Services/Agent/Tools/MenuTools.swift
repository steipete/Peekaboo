import AXorcist
import CoreGraphics
import Foundation
import Tachikoma

// MARK: - Tool Definitions

@available(macOS 14.0, *)
public struct MenuToolDefinitions {
    public static let menuClick = UnifiedToolDefinition(
        name: "menu_click",
        commandName: "menu-click",
        abstract: "Click a menu item in the menu bar",
        discussion: """
            Clicks a menu item in an application's menu bar using the menu path.
            Menu paths use ">" to separate menu levels.

            EXAMPLES:
              peekaboo menu-click "File > New"
              peekaboo menu-click "Edit > Copy" --app Safari
              peekaboo menu-click "Window > Minimize"
        """,
        category: .menu,
        parameters: [
            ParameterDefinition(
                name: "path",
                type: .string,
                description: "Menu path (e.g., 'File > New' or 'Edit > Copy')",
                required: true,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .argument)),
            ParameterDefinition(
                name: "app",
                type: .string,
                description: "Application name (defaults to frontmost app)",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
        ],
        examples: [
            #"{"path": "File > New"}"#,
            #"{"path": "Edit > Copy", "app": "Safari"}"#,
        ],
        agentGuidance: """
            AGENT TIPS:
            - Use plain ellipsis "..." instead of Unicode "…"
            - If app not specified, uses frontmost application
            - Menu paths are case-sensitive
            - Use 'list_menus' first to discover available menu items
            - Some menu items may be disabled depending on context
        """)

    public static let listMenus = UnifiedToolDefinition(
        name: "list_menus",
        commandName: "list-menus",
        abstract: "List available menu items",
        discussion: """
            Lists all available menu items for an application, showing the
            complete menu structure including submenus and keyboard shortcuts.

            EXAMPLES:
              peekaboo list-menus                    # List menus for frontmost app
              peekaboo list-menus --app Safari        # List Safari menus
              peekaboo list-menus --menu File         # Show only File menu
        """,
        category: .menu,
        parameters: [
            ParameterDefinition(
                name: "app",
                type: .string,
                description: "Application name (defaults to frontmost app)",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "menu",
                type: .string,
                description: "Specific menu to expand (e.g., 'File', 'Edit')",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
        ],
        examples: [
            #"{}"#,
            #"{"app": "Safari"}"#,
            #"{"app": "TextEdit", "menu": "File"}"#,
        ],
        agentGuidance: """
            AGENT TIPS:
            - Shows keyboard shortcuts when available
            - Disabled items are marked in the output
            - Use this before menu_click to find exact menu paths
            - Menu structure may change based on app state
        """)
}

// MARK: - Menu Tools

/// Menu interaction tools for clicking menu items and listing menus
@available(macOS 14.0, *)
extension PeekabooAgentService {
    /// Create the menu click tool
    func createMenuClickTool() -> Tool<PeekabooServices> {
        let definition = MenuToolDefinitions.menuClick

        return createTool(
            name: definition.name,
            description: definition.agentDescription,
            parameters: definition.toAgentParameters(),
            execute: { params, context in
                let menuPath = try params.string("path")
                let appName = params.string("app", default: nil)

                // Parse menu path
                let pathComponents = menuPath
                    .split(separator: ">")
                    .map { $0.trimmingCharacters(in: .whitespaces) }

                guard !pathComponents.isEmpty else {
                    throw PeekabooError.invalidInput("Invalid menu path format. Use 'Menu > Submenu > Item'")
                }

                // Ensure app is focused if specified
                if let appName {
                    let appsOutput = try await context.applications.listApplications()
                    if let app = appsOutput.data.applications
                        .first(where: { $0.name.lowercased() == appName.lowercased() })
                    {
                        try await context.applications.activateApplication(
                            identifier: app.bundleIdentifier ?? app.name)
                        // Small delay to ensure activation
                        try await Task.sleep(nanoseconds: TimeInterval.mediumDelay.nanoseconds)
                    }
                }

                // Click the menu item using menu service
                let targetApp: String
                if let appName {
                    targetApp = appName
                } else {
                    // Get frontmost app
                    let appsOutput = try await context.applications.listApplications()
                    guard let frontmost = appsOutput.data.applications.first(where: { $0.isActive }) else {
                        throw PeekabooError.operationError(message: "No active application found")
                    }
                    targetApp = frontmost.name
                }

                let startTime = Date()
                try await context.menu.clickMenuItem(app: targetApp, itemPath: menuPath ?? "")
                _ = Date().timeIntervalSince(startTime)

                return ToolOutput.success("Clicked \(targetApp) > \(menuPath ?? "")")
            })
    }

    /// Create the list menus tool
    func createListMenusTool() -> Tool<PeekabooServices> {
        let definition = MenuToolDefinitions.listMenus

        return createTool(
            name: definition.name,
            description: definition.agentDescription,
            parameters: definition.toAgentParameters(),
            execute: { params, context in
                let appName = params.string("app", default: nil)
                let specificMenu = params.string("menu", default: nil)

                let startTime = Date()

                // Get app name for context
                let targetApp: String
                if let appName {
                    targetApp = appName
                } else {
                    let frontmostApp = try await context.applications.getFrontmostApplication()
                    targetApp = frontmostApp.name
                }

                // Get menu structure
                let menuStructure: MenuStructure = if let appName {
                    // Get menus for specific app
                    try await context.menu.listMenus(for: appName)
                } else {
                    // Get menus for frontmost app
                    try await context.menu.listFrontmostMenus()
                }

                _ = Date().timeIntervalSince(startTime)

                // Count total menu items
                var totalItems = 0
                var expandedMenuItems = 0

                for menu in menuStructure.menus {
                    totalItems += countMenuItems(menu)
                    if let specificMenu, menu.title.lowercased() == specificMenu.lowercased() {
                        expandedMenuItems = countMenuItems(menu)
                    }
                }

                // Format output
                var output = ""

                // If specific menu requested, filter
                if let specificMenu {
                    if let targetMenu = menuStructure.menus
                        .first(where: { $0.title.lowercased() == specificMenu.lowercased() })
                    {
                        output = formatMenu(targetMenu, indent: 0)
                    } else {
                        output = "Menu '\(specificMenu)' not found"
                    }
                } else {
                    // Show all menus
                    output = "Menu structure:\n\n"
                    for menu in menuStructure.menus {
                        output += formatMenu(menu, indent: 0)
                        output += "\n"
                    }
                }

                // Create summary
                var summary = "Listed \(totalItems) menu items in \(targetApp)"
                if let specificMenu, expandedMenuItems > 0 {
                    summary += " (expanded '\(specificMenu)' menu with \(expandedMenuItems) items)"
                }

                return ToolOutput.success(output.trimmingCharacters(in: .whitespacesAndNewlines))
            })
    }
}

// MARK: - Helper Functions

private func countMenuItems(_ menu: Menu) -> Int {
    var count = menu.items.count
    for item in menu.items {
        count += countMenuItemsRecursive(item)
    }
    return count
}

private func countMenuItemsRecursive(_ item: MenuItem) -> Int {
    var count = 0
    for subitem in item.submenu {
        count += 1 + countMenuItemsRecursive(subitem)
    }
    return count
}

private func formatMenu(_ menu: Menu, indent: Int) -> String {
    let indentStr = String(repeating: "  ", count: indent)
    var output = "\(indentStr)\(menu.title)"

    if !menu.isEnabled {
        output += " (disabled)"
    }

    output += "\n"

    // Format menu items
    for item in menu.items {
        output += formatMenuItem(item, indent: indent + 1)
    }

    return output
}

private func formatMenuItem(_ item: MenuItem, indent: Int) -> String {
    let indentStr = String(repeating: "  ", count: indent)
    var output = "\(indentStr)\(item.title)"

    if !item.isEnabled {
        output += " (disabled)"
    }

    if let shortcut = item.keyboardShortcut {
        output += " [\(shortcut.displayString)]"
    }

    output += "\n"

    // Format submenu items
    for subitem in item.submenu {
        output += formatMenuItem(subitem, indent: indent + 1)
    }

    return output
}
