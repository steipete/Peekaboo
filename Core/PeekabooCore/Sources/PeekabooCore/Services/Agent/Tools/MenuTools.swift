import Foundation
import CoreGraphics
import AXorcist

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
                        description: "Menu path (e.g., 'File > New' or 'Edit > Copy')"
                    ),
                    "app": ParameterSchema.string(
                        description: "Optional: Application name (defaults to frontmost app)"
                    )
                ],
                required: ["path"]
            ),
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
                if let appName = appName {
                    let apps = try await context.applications.listApplications()
                    if let app = apps.first(where: { $0.name.lowercased() == appName.lowercased() }) {
                        try await context.applications.activateApplication(
                            identifier: app.bundleIdentifier ?? app.name
                        )
                        // Small delay to ensure activation
                        try await Task.sleep(nanoseconds: TimeInterval.mediumDelay.nanoseconds)
                    }
                }
                
                // Click the menu item using menu service
                let targetApp: String
                if let appName = appName {
                    targetApp = appName
                } else {
                    // Get frontmost app
                    let apps = try await context.applications.listApplications()
                    guard let frontmost = apps.first(where: { $0.isActive }) else {
                        throw PeekabooError.operationError(message: "No active application found")
                    }
                    targetApp = frontmost.name
                }
                
                try await context.menu.clickMenuItem(app: targetApp, itemPath: menuPath)
                
                return .success(
                    "Successfully clicked menu item: \(menuPath)",
                    metadata: [
                        "menuPath": menuPath,
                        "app": appName ?? "frontmost app"
                    ]
                )
            }
        )
    }
    
    /// Create the list menus tool
    func createListMenusTool() -> Tool<PeekabooServices> {
        createTool(
            name: "list_menus",
            description: "List all available menu items for an application",
            parameters: .object(
                properties: [
                    "app": ParameterSchema.string(
                        description: "Optional: Application name (defaults to frontmost app)"
                    ),
                    "menu": ParameterSchema.string(
                        description: "Optional: Specific menu to expand (e.g., 'File', 'Edit')"
                    )
                ],
                required: []
            ),
            handler: { params, context in
                let appName = params.string("app", default: nil)
                let specificMenu = params.string("menu", default: nil)
                
                // Get menu structure
                let menuStructure: MenuStructure
                if let appName = appName {
                    // Get menus for specific app
                    menuStructure = try await context.menu.listMenus(for: appName)
                } else {
                    // Get menus for frontmost app
                    menuStructure = try await context.menu.listFrontmostMenus()
                }
                
                // Format output
                var output = "Menu structure:\n\n"
                
                // If specific menu requested, filter
                if let specificMenu = specificMenu {
                    if let targetMenu = menuStructure.menus.first(where: { $0.title.lowercased() == specificMenu.lowercased() }) {
                        output += formatMenu(targetMenu, indent: 0)
                    } else {
                        output = "Menu '\(specificMenu)' not found"
                    }
                } else {
                    // Show all menus
                    for menu in menuStructure.menus {
                        output += formatMenu(menu, indent: 0)
                        output += "\n"
                    }
                }
                
                return .success(
                    output.trimmingCharacters(in: .whitespacesAndNewlines),
                    metadata: [
                        "app": appName ?? "frontmost app",
                        "menuCount": String(menuStructure.menus.count)
                    ]
                )
            }
        )
    }
}

// MARK: - Helper Functions

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