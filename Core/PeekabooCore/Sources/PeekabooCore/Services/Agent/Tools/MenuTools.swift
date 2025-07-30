import AXorcist
import CoreGraphics
import Foundation

// MARK: - Menu Tools

/// Menu interaction tools for clicking menu items and listing menus
@available(macOS 14.0, *)
extension PeekabooAgentService {
    /// Create the menu click tool
    func createMenuClickTool() -> Tool<PeekabooServices> {
        createTool(
            name: "menu_click",
            description: "Click a menu item in the menu bar",
            parameters: .object(
                properties: [
                    "path": ParameterSchema.string(
                        description: "Menu path (e.g., 'File > New' or 'Edit > Copy')"),
                    "app": ParameterSchema.string(
                        description: "Optional: Application name (defaults to frontmost app)"),
                ],
                required: ["path"]),
            handler: { params, context in
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
                try await context.menu.clickMenuItem(app: targetApp, itemPath: menuPath)
                let duration = Date().timeIntervalSince(startTime)

                return .success(
                    "Clicked \(targetApp) > \(menuPath)",
                    metadata: [
                        "menuPath": menuPath,
                        "app": targetApp,
                        "duration": String(format: "%.2fs", duration),
                    ])
            })
    }

    /// Create the list menus tool
    func createListMenusTool() -> Tool<PeekabooServices> {
        createTool(
            name: "list_menus",
            description: "List all available menu items for an application",
            parameters: .object(
                properties: [
                    "app": ParameterSchema.string(
                        description: "Optional: Application name (defaults to frontmost app)"),
                    "menu": ParameterSchema.string(
                        description: "Optional: Specific menu to expand (e.g., 'File', 'Edit')"),
                ],
                required: []),
            handler: { params, context in
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

                let duration = Date().timeIntervalSince(startTime)

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

                return .success(
                    output.trimmingCharacters(in: .whitespacesAndNewlines),
                    metadata: [
                        "app": targetApp,
                        "menuCount": String(menuStructure.menus.count),
                        "totalItems": String(totalItems),
                        "duration": String(format: "%.2fs", duration),
                        "summary": summary,
                    ])
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
