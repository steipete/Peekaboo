// Example of how MenuCommand would be refactored with new AXorcist APIs

import ArgumentParser
import Foundation
import ApplicationServices
import AXorcist

struct MenuCommandRefactored: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "menu",
        abstract: "Interact with application menu bar"
    )
}

// MARK: - Click Subcommand (Refactored)

extension MenuCommandRefactored {
    struct ClickSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "click",
            abstract: "Click a menu item using the menu path"
        )
        
        @Option var app: String
        @Option var path: String? 
        @Option var item: String?
        @Flag var jsonOutput = false
        
        @MainActor
        mutating func run() async throws {
            guard item != nil || path != nil else {
                throw ValidationError("Must specify either --path or --item")
            }
            
            do {
                // Find application
                let runningApp = try ApplicationFinder.findApplication(identifier: app)
                let axApp = AXUIElementCreateApplication(runningApp.processIdentifier)
                let appElement = Element(axApp)
                
                // NEW: Use menuBar() extension
                guard let menuBar = appElement.menuBar() else {
                    throw MenuError.menuBarNotFound
                }
                
                // NEW: Use MenuNavigator
                let navigator = menuBar.menuNavigator()
                
                if let menuPath = path {
                    // NEW: Use navigate() method for paths
                    if let menuItem = try await navigator.navigate(path: menuPath) {
                        // NEW: Check actionability before clicking
                        let actionability = menuItem.checkActionability()
                        if !actionability.isActionable {
                            throw MenuError.menuItemNotClickable(
                                menuPath, 
                                actionability.issues.first?.description ?? "Unknown issue"
                            )
                        }
                        
                        try await menuItem.performAction(.press)
                        
                        if jsonOutput {
                            outputSuccessJSON(clicked: menuPath)
                        } else {
                            print("✓ Clicked menu item: \(menuPath)")
                        }
                    }
                } else if let menuItemTitle = item {
                    // Direct item click - search all menus
                    var clicked = false
                    
                    for menu in navigator.allMenus() {
                        try await menu.open()
                        
                        if let item = menu.item(titled: menuItemTitle) {
                            try await item.performAction(.press)
                            clicked = true
                            break
                        }
                        
                        try await menu.close()
                    }
                    
                    if !clicked {
                        throw MenuError.menuItemNotFound(menuItemTitle)
                    }
                    
                    if jsonOutput {
                        outputSuccessJSON(clicked: menuItemTitle)
                    } else {
                        print("✓ Clicked menu item: \(menuItemTitle)")
                    }
                }
                
            } catch let error as MenuError {
                handleMenuError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
            }
        }
    }
}

// MARK: - List Subcommand (Refactored)

extension MenuCommandRefactored {
    struct ListSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all menu items for an application"
        )
        
        @Option var app: String
        @Flag var includeDisabled = false
        @Flag var jsonOutput = false
        
        @MainActor
        mutating func run() async throws {
            do {
                let runningApp = try ApplicationFinder.findApplication(identifier: app)
                let axApp = AXUIElementCreateApplication(runningApp.processIdentifier)
                let appElement = Element(axApp)
                
                // NEW: Use menuBar() and MenuNavigator
                guard let menuBar = appElement.menuBar() else {
                    throw MenuError.menuBarNotFound
                }
                
                let navigator = menuBar.menuNavigator()
                var menuStructure: [[String: Any]] = []
                
                for menuController in navigator.allMenus() {
                    let menuTitle = menuController.menu.title() ?? "Unknown"
                    
                    // Open menu
                    try await menuController.open()
                    
                    // NEW: Use allItems() method
                    let items = menuController.allItems(includeDisabled: includeDisabled)
                    
                    let menuData: [String: Any] = [
                        "title": menuTitle,
                        "items": items.map { item in
                            var itemData: [String: Any] = [
                                "title": item.title,
                                "enabled": item.isEnabled
                            ]
                            
                            if let shortcut = item.keyboardShortcut {
                                itemData["shortcut"] = shortcut
                            }
                            
                            if item.hasSubmenu {
                                itemData["hasSubmenu"] = true
                            }
                            
                            return itemData
                        }
                    ]
                    
                    menuStructure.append(menuData)
                    
                    // Close menu
                    try await menuController.close()
                }
                
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "app": runningApp.localizedName ?? app,
                            "menu_structure": menuStructure
                        ])
                    )
                    outputJSON(response)
                } else {
                    print("Menu structure for \(runningApp.localizedName ?? app):")
                    for menu in menuStructure {
                        print("\n\(menu["title"] ?? "Unknown"):")
                        if let items = menu["items"] as? [[String: Any]] {
                            for item in items {
                                let enabled = item["enabled"] as? Bool ?? false
                                let enabledStr = enabled ? "✓" : "✗"
                                let shortcut = item["shortcut"] as? String ?? ""
                                print("  \(enabledStr) \(item["title"] ?? "Unknown") \(shortcut)")
                            }
                        }
                    }
                }
                
            } catch let error as MenuError {
                handleMenuError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
            }
        }
    }
}

// MARK: - Additional Error Types

enum MenuError: LocalizedError {
    case menuBarNotFound
    case menuItemNotClickable(String, String)
    
    var errorDescription: String? {
        switch self {
        case .menuBarNotFound:
            return "Menu bar not found for application"
        case .menuItemNotClickable(let item, let reason):
            return "Menu item '\(item)' is not clickable: \(reason)"
        }
    }
}