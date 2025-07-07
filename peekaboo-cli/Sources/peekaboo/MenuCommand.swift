import ApplicationServices
import ArgumentParser
import AXorcist
import Foundation

struct MenuCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "menu",
        abstract: "Interact with application menu bar",
        discussion: """
        Provides access to application menu bar items and system menu extras.

        EXAMPLES:
          # Click a simple menu item
          peekaboo menu click --app Safari --item "New Window"

          # Navigate nested menus with path
          peekaboo menu click --app TextEdit --path "Format > Font > Show Fonts"

          # Click system menu extras (WiFi, Bluetooth, etc.)
          peekaboo menu click-extra --title "WiFi"

          # List all menu items for an app
          peekaboo menu list --app Finder
        """,
        subcommands: [
            ClickSubcommand.self,
            ClickExtraSubcommand.self,
            ListSubcommand.self
        ]
    )

    // MARK: - Click Menu Item

    struct ClickSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "click",
            abstract: "Click a menu item"
        )

        @Option(help: "Target application by name, bundle ID, or 'PID:12345'")
        var app: String

        @Option(help: "Menu item to click (for simple, non-nested items)")
        var item: String?

        @Option(help: "Menu path for nested items (e.g., 'File > Export > PDF')")
        var path: String?

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        mutating func run() async throws {
            // Validate inputs
            guard item != nil || path != nil else {
                throw ValidationError("Must specify either --item or --path")
            }

            guard item == nil || path == nil else {
                throw ValidationError("Cannot specify both --item and --path")
            }

            do {
                // Find target application
                let (app, _) = try await findApplication(identifier: app)

                // Get menu bar
                guard let menuBar = app.menuBar() else {
                    throw PeekabooMenuError.menuBarNotFound
                }

                // Parse menu path
                let menuPath = path ?? item!
                let pathComponents = menuPath.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }

                // Navigate menu hierarchy
                var currentElement: Element = menuBar
                var clickedItemTitle: String?

                for (index, component) in pathComponents.enumerated() {
                    // Get children of current menu
                    let children = currentElement.children() ?? []

                    // Find matching menu item
                    guard let menuItem = children.first(where: { element in
                        element.title() == component ||
                            element.attributedTitle()?.string == component
                    }) else {
                        throw PeekabooMenuError.menuItemNotFound(component)
                    }

                    // If this is the last component, click it
                    if index == pathComponents.count - 1 {
                        clickedItemTitle = menuItem.title() ?? component
                        try menuItem.performAction(.press)
                    } else {
                        // Otherwise, open the submenu
                        try menuItem.performAction(.press)

                        // Wait for submenu to appear
                        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

                        // Get the submenu
                        guard let submenu = menuItem.children()?.first else {
                            throw PeekabooMenuError.submenuNotFound(component)
                        }

                        currentElement = submenu
                    }
                }

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "menu_click",
                            "app": app.title() ?? self.app,
                            "menu_path": menuPath,
                            "clicked_item": clickedItemTitle ?? menuPath
                        ])
                    )
                    outputJSON(response)
                } else {
                    print("✓ Clicked menu item: \(menuPath)")
                }

            } catch let error as ApplicationError {
                handleApplicationError(error, jsonOutput: jsonOutput)
            } catch let error as PeekabooMenuError {
                handleMenuError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
            }
        }
    }

    // MARK: - Click System Menu Extra

    struct ClickExtraSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "click-extra",
            abstract: "Click a system menu extra (status bar item)"
        )

        @Option(help: "Title of the menu extra (e.g., 'WiFi', 'Bluetooth')")
        var title: String

        @Option(help: "Menu item to click after opening the extra")
        var item: String?

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        mutating func run() async throws {
            do {
                // Get system-wide element
                let systemWide = Element.systemWide()

                // Find menu bar
                guard let menuBar = systemWide.menuBar() else {
                    throw PeekabooMenuError.menuBarNotFound
                }

                // Find menu extras (they're typically in a specific group)
                let menuBarItems = menuBar.children() ?? []

                // Menu extras are usually in the last group
                guard let menuExtrasGroup = menuBarItems.last(where: { $0.role() == "AXGroup" }) else {
                    throw PeekabooMenuError.menuExtraNotFound(title)
                }

                // Find the specific menu extra
                let extras = menuExtrasGroup.children() ?? []
                guard let menuExtra = extras.first(where: { element in
                    element.title() == title ||
                        element.help() == title ||
                        element.descriptionText()?.contains(title) == true
                }) else {
                    throw PeekabooMenuError.menuExtraNotFound(title)
                }

                // Click the menu extra
                try menuExtra.performAction(.press)

                // If an item was specified, click it
                if let itemToClick = item {
                    // Wait for menu to appear
                    try await Task.sleep(nanoseconds: 200_000_000) // 200ms

                    // Find and click the item
                    if let menu = menuExtra.children()?.first {
                        let menuItems = menu.children() ?? []
                        guard let targetItem = menuItems.first(where: { $0.title() == itemToClick }) else {
                            throw PeekabooMenuError.menuItemNotFound(itemToClick)
                        }
                        try targetItem.performAction(.press)
                    }
                }

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "menu_extra_click",
                            "menu_extra": title,
                            "clicked_item": item ?? title
                        ])
                    )
                    outputJSON(response)
                } else {
                    if let clickedItem = item {
                        print("✓ Clicked '\(clickedItem)' in \(title) menu")
                    } else {
                        print("✓ Clicked menu extra: \(title)")
                    }
                }

            } catch let error as PeekabooMenuError {
                handleMenuError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
            }
        }
    }

    // MARK: - List Menu Items

    struct ListSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all menu items for an application"
        )

        @Option(help: "Target application by name, bundle ID, or 'PID:12345'")
        var app: String

        @Flag(help: "Include disabled menu items")
        var includeDisabled = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @MainActor
        mutating func run() async throws {
            do {
                // Find target application
                let (app, _) = try await findApplication(identifier: app)

                // Get menu bar
                guard let menuBar = app.menuBar() else {
                    throw PeekabooMenuError.menuBarNotFound
                }

                // Collect all menu items
                var menuStructure: [[String: Any]] = []

                let topLevelMenus = menuBar.children() ?? []
                for menu in topLevelMenus {
                    if let menuData = collectMenuItems(from: menu, includeDisabled: includeDisabled) {
                        menuStructure.append(menuData)
                    }
                }

                // Output result
                if jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "app": app.title() ?? self.app,
                            "menu_structure": menuStructure
                        ])
                    )
                    outputJSON(response)
                } else {
                    print("Menu structure for \(app.title() ?? self.app):")
                    for menu in menuStructure {
                        printMenu(menu, indent: 0)
                    }
                }

            } catch let error as ApplicationError {
                handleApplicationError(error, jsonOutput: jsonOutput)
            } catch let error as PeekabooMenuError {
                handleMenuError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: jsonOutput)
            }
        }

        @MainActor
        private func collectMenuItems(from element: Element, includeDisabled: Bool) -> [String: Any]? {
            guard let title = element.title() ?? element.attributedTitle()?.string else {
                return nil
            }

            var menuData: [String: Any] = ["title": title]

            // Check if enabled
            let isEnabled = element.isEnabled() ?? true
            if !includeDisabled && !isEnabled {
                return nil
            }

            menuData["enabled"] = isEnabled

            // Get keyboard shortcut if available
            if let shortcut = element.keyboardShortcut() {
                menuData["shortcut"] = shortcut
            }

            // Get children (submenu items)
            if let children = element.children() {
                var items: [[String: Any]] = []
                for child in children {
                    if child.role() == "AXMenuItem",
                       let childData = collectMenuItems(from: child, includeDisabled: includeDisabled) {
                        items.append(childData)
                    }
                }
                if !items.isEmpty {
                    menuData["items"] = items
                }
            }

            return menuData
        }

        private func printMenu(_ menu: [String: Any], indent: Int) {
            let spacing = String(repeating: "  ", count: indent)

            if let title = menu["title"] as? String {
                let enabled = menu["enabled"] as? Bool ?? true
                let shortcut = menu["shortcut"] as? String ?? ""

                var line = "\(spacing)\(title)"
                if !enabled {
                    line += " (disabled)"
                }
                if !shortcut.isEmpty {
                    line += " [\(shortcut)]"
                }
                print(line)

                if let items = menu["items"] as? [[String: Any]] {
                    for item in items {
                        printMenu(item, indent: indent + 1)
                    }
                }
            }
        }
    }
}

// MARK: - Menu Errors

enum PeekabooMenuError: LocalizedError {
    case menuBarNotFound
    case menuItemNotFound(String)
    case submenuNotFound(String)
    case menuExtraNotFound(String)

    var errorDescription: String? {
        switch self {
        case .menuBarNotFound:
            "Menu bar not found for application"
        case let .menuItemNotFound(item):
            "Menu item '\(item)' not found"
        case let .submenuNotFound(menu):
            "Submenu '\(menu)' not found"
        case let .menuExtraNotFound(extra):
            "Menu extra '\(extra)' not found in system menu bar"
        }
    }

    var errorCode: String {
        switch self {
        case .menuBarNotFound:
            "MENU_BAR_NOT_FOUND"
        case .menuItemNotFound:
            "MENU_ITEM_NOT_FOUND"
        case .submenuNotFound:
            "SUBMENU_NOT_FOUND"
        case .menuExtraNotFound:
            "MENU_EXTRA_NOT_FOUND"
        }
    }
}

// MARK: - Error Handling

private func handleMenuError(_ error: PeekabooMenuError, jsonOutput: Bool) {
    if jsonOutput {
        let response = JSONResponse(
            success: false,
            error: ErrorInfo(
                message: error.localizedDescription,
                code: ErrorCode(rawValue: error.errorCode) ?? .UNKNOWN_ERROR
            )
        )
        outputJSON(response)
    } else {
        print("❌ \(error.localizedDescription)")
    }
}

// MARK: - Element Extensions

private extension Element {
    @MainActor
    func attributedTitle() -> NSAttributedString? {
        // Try to get attributed title for menu items with special formatting
        if let attrTitle = value() as? NSAttributedString {
            return attrTitle
        }
        return nil
    }

    @MainActor
    func keyboardShortcut() -> String? {
        // Try to get keyboard shortcut from various attributes
        if let cmdChar = attribute(Attribute<String>("AXMenuItemCmdChar")),
           let modifiers = attribute(Attribute<Int>("AXMenuItemCmdModifiers")) {
            return formatKeyboardShortcut(cmdChar: cmdChar, modifiers: modifiers)
        }
        return nil
    }

    private func formatKeyboardShortcut(cmdChar: String, modifiers: Int) -> String {
        var parts: [String] = []

        if modifiers & (1 << 0) != 0 { parts.append("⌘") } // Command
        if modifiers & (1 << 1) != 0 { parts.append("⇧") } // Shift
        if modifiers & (1 << 2) != 0 { parts.append("⌥") } // Option
        if modifiers & (1 << 3) != 0 { parts.append("⌃") } // Control

        parts.append(cmdChar.uppercased())
        return parts.joined()
    }
}
