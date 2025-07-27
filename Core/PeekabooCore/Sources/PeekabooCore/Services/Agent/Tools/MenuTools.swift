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
                    "path": .string(
                        description: "Menu path (e.g., 'File > New' or 'Edit > Copy')",
                        required: true
                    ),
                    "app": .string(
                        description: "Optional: Application name (defaults to frontmost app)",
                        required: false
                    )
                ],
                required: ["path"]
            ),
            handler: { params, context in
                let menuPath = try params.string("path")
                let appName = params.string("app")
                
                // Parse menu path
                let pathComponents = menuPath
                    .split(separator: ">")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                
                guard !pathComponents.isEmpty else {
                    throw PeekabooError.invalidInput("Invalid menu path format. Use 'Menu > Submenu > Item'")
                }
                
                // Ensure app is focused if specified
                if let appName = appName {
                    let apps = try await context.application.listApplications()
                    if let app = apps.findApp(byName: appName) {
                        try await context.application.activateApplication(
                            bundleID: app.bundleIdentifier
                        )
                        // Small delay to ensure activation
                        try await Task.sleep(nanoseconds: TimeInterval.mediumDelay.nanoseconds)
                    }
                }
                
                // Click the menu item
                try await context.menu.clickMenuItem(path: pathComponents)
                
                return .success(
                    "Successfully clicked menu item: \(menuPath)",
                    metadata: "menuPath", menuPath,
                    "app", appName ?? "frontmost app"
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
                    "app": .string(
                        description: "Optional: Application name (defaults to frontmost app)",
                        required: false
                    ),
                    "menu": .string(
                        description: "Optional: Specific menu to expand (e.g., 'File', 'Edit')",
                        required: false
                    )
                ],
                required: []
            ),
            handler: { params, context in
                let appName = params.string("app")
                let specificMenu = params.string("menu")
                
                // Get the target app
                let targetApp: String
                if let appName = appName {
                    // Ensure app is running
                    let apps = try await context.application.listApplications()
                    guard let app = apps.findApp(byName: appName) else {
                        throw PeekabooError.appNotFound(appName)
                    }
                    targetApp = app.name
                } else {
                    // Use frontmost app
                    let focusInfo = try await context.uiAutomation.getFocusedElement()
                    targetApp = focusInfo.app
                }
                
                // Get menu structure
                let menuStructure = try await context.menu.getMenuStructure(
                    for: targetApp,
                    menuName: specificMenu
                )
                
                // Format output
                var output = "Menu structure for \(targetApp):\n\n"
                
                for menu in menuStructure.menus {
                    output += formatMenu(menu, indent: 0)
                    output += "\n"
                }
                
                return .success(
                    output.trimmingCharacters(in: .whitespacesAndNewlines),
                    metadata: "app", targetApp,
                    "menuCount", String(menuStructure.menus.count)
                )
            }
        )
    }
}

// MARK: - Helper Functions

private func formatMenu(_ menu: MenuStructure, indent: Int) -> String {
    let indentStr = String(repeating: "  ", count: indent)
    var output = "\(indentStr)\(menu.title)"
    
    if menu.enabled == false {
        output += " (disabled)"
    }
    
    if let shortcut = menu.keyboardShortcut, !shortcut.isEmpty {
        output += " [\(shortcut)]"
    }
    
    output += "\n"
    
    // Format submenu items
    for item in menu.items {
        output += formatMenu(item, indent: indent + 1)
    }
    
    return output
}