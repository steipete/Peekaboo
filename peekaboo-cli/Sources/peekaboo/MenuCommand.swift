import AppKit
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
            ListSubcommand.self,
            ListAllSubcommand.self,
        ])

    // MARK: - Click Menu Item

    struct ClickSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "click",
            abstract: "Click a menu item")

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
            guard self.item != nil || self.path != nil else {
                throw ValidationError("Must specify either --item or --path")
            }

            guard self.item == nil || self.path == nil else {
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
                let menuPath = self.path ?? self.item!
                let pathComponents = menuPath.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }

                // Navigate menu hierarchy
                var currentElement: Element = menuBar
                var clickedItemTitle: String?

                for (index, component) in pathComponents.enumerated() {
                    // Get children of current menu
                    let children = currentElement.children() ?? []

                    // Find matching menu item
                    guard let menuItem = children.first(where: { element in
                        if let title = element.title(), title == component {
                            return true
                        }
                        // Try to get attributed title for menu items with special formatting
                        if let attrTitle = element.value() as? NSAttributedString,
                           attrTitle.string == component
                        {
                            return true
                        }
                        return false
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
                if self.jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "menu_click",
                            "app": app.title() ?? self.app,
                            "menu_path": menuPath,
                            "clicked_item": clickedItemTitle ?? menuPath,
                        ]))
                    outputJSON(response)
                } else {
                    print("✓ Clicked menu item: \(menuPath)")
                }

            } catch let error as ApplicationError {
                handleApplicationError(error, jsonOutput: jsonOutput)
            } catch let error as PeekabooMenuError {
                handleMenuError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
            }
        }
    }

    // MARK: - Click System Menu Extra

    struct ClickExtraSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "click-extra",
            abstract: "Click a system menu extra (status bar item)")

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
                    throw PeekabooMenuError.menuExtraNotFound(self.title)
                }

                // Find the specific menu extra
                let extras = menuExtrasGroup.children() ?? []
                guard let menuExtra = extras.first(where: { element in
                    element.title() == title ||
                        element.help() == title ||
                        element.descriptionText()?.contains(title) == true
                }) else {
                    throw PeekabooMenuError.menuExtraNotFound(self.title)
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
                if self.jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "action": "menu_extra_click",
                            "menu_extra": title,
                            "clicked_item": item ?? self.title,
                        ]))
                    outputJSON(response)
                } else {
                    if let clickedItem = item {
                        print("✓ Clicked '\(clickedItem)' in \(self.title) menu")
                    } else {
                        print("✓ Clicked menu extra: \(self.title)")
                    }
                }

            } catch let error as PeekabooMenuError {
                handleMenuError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
            }
        }
    }

    // MARK: - List Menu Items

    struct ListSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all menu items for an application")

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
                if self.jsonOutput {
                    let response = JSONResponse(
                        success: true,
                        data: AnyCodable([
                            "app": app.title() ?? self.app,
                            "menu_structure": menuStructure,
                        ]))
                    outputJSON(response)
                } else {
                    print("Menu structure for \(app.title() ?? self.app):")
                    for menu in menuStructure {
                        self.printMenu(menu, indent: 0)
                    }
                }

            } catch let error as ApplicationError {
                handleApplicationError(error, jsonOutput: jsonOutput)
            } catch let error as PeekabooMenuError {
                handleMenuError(error, jsonOutput: jsonOutput)
            } catch {
                handleGenericError(error, jsonOutput: self.jsonOutput)
            }
        }

        @MainActor
        private func collectMenuItems(from element: Element, includeDisabled: Bool, depth: Int = 0) -> [String: Any]? {
            // Limit depth to prevent infinite recursion
            guard depth < 10 else { return nil }

            guard let title = element.title() ?? attributedTitle(for: element)?.string else {
                return nil
            }

            var menuData: [String: Any] = ["title": title]

            // Check if enabled
            let isEnabled = element.isEnabled() ?? true
            if !includeDisabled, !isEnabled {
                return nil
            }

            menuData["enabled"] = isEnabled

            // Get keyboard shortcut if available
            if let shortcut = keyboardShortcut(for: element) {
                menuData["shortcut"] = shortcut
            }

            // Get children (submenu items) - this is the key!
            // When menu bar items have children, those are the actual menu items
            if let children = element.children() {
                var items: [[String: Any]] = []

                // For menu bar items, the first child is often the menu itself
                for child in children {
                    let childRole = child.role() ?? ""

                    if childRole == AXRoleNames.kAXMenuRole {
                        // This is a menu, get its children (the actual menu items)
                        if let menuChildren = child.children() {
                            for menuItem in menuChildren {
                                if let itemData = collectMenuItems(
                                    from: menuItem,
                                    includeDisabled: includeDisabled,
                                    depth: depth + 1)
                                {
                                    items.append(itemData)
                                }
                            }
                        }
                    } else if childRole == AXRoleNames.kAXMenuItemRole {
                        // Direct menu item
                        if let childData = collectMenuItems(
                            from: child,
                            includeDisabled: includeDisabled,
                            depth: depth + 1)
                        {
                            items.append(childData)
                        }
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
                        self.printMenu(item, indent: indent + 1)
                    }
                }
            }
        }

        @MainActor
        private func attributedTitle(for element: Element) -> NSAttributedString? {
            // Try to get attributed title for menu items with special formatting
            if let attrTitle = element.value() as? NSAttributedString {
                return attrTitle
            }
            return nil
        }

        @MainActor
        private func keyboardShortcut(for element: Element) -> String? {
            // Try to get keyboard shortcut from various attributes
            if let cmdChar = element.attribute(Attribute<String>("AXMenuItemCmdChar")),
               let modifiers = element.attribute(Attribute<Int>("AXMenuItemCmdModifiers"))
            {
                return self.formatKeyboardShortcut(cmdChar: cmdChar, modifiers: modifiers)
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

    // MARK: - Menu Extraction Helpers

    @MainActor
    private static func extractFullMenu(from menuBarItem: Element) -> [String: Any]? {
        guard let title = menuBarItem.title() else { return nil }

        var menuData: [String: Any] = [:]
        menuData["title"] = title
        menuData["role"] = menuBarItem.role() ?? ""
        menuData["enabled"] = menuBarItem.isEnabled() ?? true

        // Extract all menu items without clicking
        if let children = menuBarItem.children() {
            for child in children {
                if child.role() == AXRoleNames.kAXMenuRole {
                    // This is the actual menu, extract its items
                    if let menuItems = extractMenuItems(from: child) {
                        menuData["items"] = menuItems
                    }
                }
            }
        }

        return menuData
    }

    @MainActor
    private static func extractMenuItems(from menu: Element) -> [[String: Any]]? {
        guard let children = menu.children() else { return nil }

        var items: [[String: Any]] = []
        for child in children {
            if child.role() == AXRoleNames.kAXMenuItemRole {
                var itemData: [String: Any] = [:]
                itemData["title"] = child.title() ?? ""
                itemData["enabled"] = child.isEnabled() ?? true

                // Get keyboard shortcut
                if let cmdChar = child.attribute(Attribute<String>("AXMenuItemCmdChar")),
                   let modifiers = child.attribute(Attribute<Int>("AXMenuItemCmdModifiers"))
                {
                    itemData["shortcut"] = self.formatKeyboardShortcut(cmdChar: cmdChar, modifiers: modifiers)
                }

                // Check for submenu
                if let submenuChildren = child.children(), !submenuChildren.isEmpty {
                    for submenuChild in submenuChildren {
                        if submenuChild.role() == AXRoleNames.kAXMenuRole {
                            if let submenuItems = extractMenuItems(from: submenuChild) {
                                itemData["items"] = submenuItems
                            }
                        }
                    }
                }

                items.append(itemData)
            }
        }

        return items.isEmpty ? nil : items
    }

    private static func formatKeyboardShortcut(cmdChar: String, modifiers: Int) -> String {
        var parts: [String] = []

        if modifiers & (1 << 0) != 0 { parts.append("⌘") }
        if modifiers & (1 << 1) != 0 { parts.append("⇧") }
        if modifiers & (1 << 2) != 0 { parts.append("⌥") }
        if modifiers & (1 << 3) != 0 { parts.append("⌃") }

        parts.append(cmdChar.uppercased())
        return parts.joined()
    }

    // MARK: - List All Menu Bar Items

    struct ListAllSubcommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list-all",
            abstract: "List all menu bar items system-wide (including status items)")

        @Flag(help: "Include disabled menu items")
        var includeDisabled = false

        @Flag(help: "Output in JSON format")
        var jsonOutput = false

        @Flag(help: "Include item frames (pixel positions)")
        var includeFrames = false

        @MainActor
        mutating func run() async throws {
            var allAppMenus: [[String: Any]] = []
            var processedApps = Set<String>()

            // Only get the frontmost application's menus (others are not accessible)
            if let frontApp = NSWorkspace.shared.frontmostApplication,
               let bundleId = frontApp.bundleIdentifier
            {
                let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
                let element = Element(appElement)

                // Get the app's menu bar
                if let menuBar = element.menuBar() {
                    var appData: [String: Any] = [:]
                    appData["app_name"] = frontApp.localizedName ?? "Unknown"
                    appData["bundle_id"] = bundleId
                    appData["pid"] = frontApp.processIdentifier

                    var menus: [[String: Any]] = []

                    // Process all menu bar items
                    if let menuBarItems = menuBar.children() {
                        for menuBarItem in menuBarItems {
                            let role = menuBarItem.role() ?? ""

                            if role == AXRoleNames.kAXMenuBarItemRole {
                                // Extract the full menu structure
                                if let menuData = MenuCommand.extractFullMenu(from: menuBarItem) {
                                    menus.append(menuData)
                                }
                            }
                        }
                    }

                    // Try to find menu extras (status items)
                    // They're usually in the last group of the menu bar
                    if let menuBarChildren = menuBar.children(),
                       let lastGroup = menuBarChildren.last(where: { $0.role() == "AXGroup" })
                    {
                        if let extras = lastGroup.children() {
                            for extra in extras {
                                var itemData: [String: Any] = [:]

                                itemData["type"] = "status_item"
                                itemData["role"] = extra.role() ?? "Unknown"
                                itemData["title"] = extra.title() ?? extra.help() ?? extra
                                    .descriptionText() ?? "Untitled"
                                itemData["enabled"] = extra.isEnabled() ?? true

                                if self.includeFrames {
                                    if let position = extra.position(),
                                       let size = extra.size()
                                    {
                                        itemData["frame"] = [
                                            "x": position.x,
                                            "y": position.y,
                                            "width": size.width,
                                            "height": size.height,
                                        ]
                                    }
                                }

                                menus.append(itemData)
                            }
                        }
                    }

                    if !menus.isEmpty {
                        appData["menus"] = menus
                        allAppMenus.append(appData)
                    }
                }
            }

            // Output results
            if self.jsonOutput {
                let response = JSONResponse(
                    success: true,
                    data: AnyCodable([
                        "apps": allAppMenus,
                    ]))
                outputJSON(response)
            } else {
                for appData in allAppMenus {
                    if let appName = appData["app_name"] as? String {
                        print("\n=== \(appName) ===")
                        if let menus = appData["menus"] as? [[String: Any]] {
                            for menu in menus {
                                self.printFullMenu(menu, indent: 0)
                            }
                        }
                    }
                }
            }
        }

        private func printFullMenu(_ menu: [String: Any], indent: Int) {
            let spacing = String(repeating: "  ", count: indent)

            if let title = menu["title"] as? String {
                let enabled = menu["enabled"] as? Bool ?? true
                let shortcut = menu["shortcut"] as? String

                var line = "\(spacing)\(title)"
                if !enabled {
                    line += " (disabled)"
                }
                if let s = shortcut {
                    line += " [\(s)]"
                }

                print(line)

                // Print submenu items
                if let items = menu["items"] as? [[String: Any]] {
                    for item in items {
                        self.printFullMenu(item, indent: indent + 1)
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
                code: ErrorCode(rawValue: error.errorCode) ?? .UNKNOWN_ERROR))
        outputJSON(response)
    } else {
        print("❌ \(error.localizedDescription)")
    }
}
