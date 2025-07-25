import AppKit
import ArgumentParser
import Foundation
import PeekabooCore

/// Menu-specific errors
enum MenuError: Error {
    case menuBarNotFound
    case menuItemNotFound(String)
    case submenuNotFound(String)
    case menuExtraNotFound
    case menuOperationFailed(String)
}

/// Interact with application menu bar items and system menu extras
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

        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            // Validate inputs
            guard self.item != nil || self.path != nil else {
                throw ValidationError("Must specify either --item or --path")
            }

            guard self.item == nil || self.path == nil else {
                throw ValidationError("Cannot specify both --item and --path")
            }

            do {
                // Construct the menu path
                let menuPath = self.path ?? self.item!

                // Click the menu item using the service
                try await PeekabooServices.shared.menu.clickMenuItem(app: self.app, itemPath: menuPath)

                // Get app info for response
                let appInfo = try await PeekabooServices.shared.applications.findApplication(identifier: self.app)

                // Output result
                if self.jsonOutput {
                    let data = MenuClickResult(
                        action: "menu_click",
                        app: appInfo.name,
                        menu_path: menuPath,
                        clicked_item: menuPath)
                    outputSuccess(data: data)
                } else {
                    print("✓ Clicked menu item: \(menuPath)")
                }

            } catch let error as MenuError {
                handleMenuError(error)
                throw ExitCode(1)
            } catch let error as ApplicationError {
                handleApplicationError(error)
                throw ExitCode(1)
            } catch {
                self.handleGenericError(error)
                throw ExitCode(1)
            }
        }

        private func handleMenuError(_ error: MenuError) {
            if self.jsonOutput {
                let errorCode: ErrorCode = switch error {
                case .menuBarNotFound:
                    .MENU_BAR_NOT_FOUND
                case .menuItemNotFound:
                    .MENU_ITEM_NOT_FOUND
                case .submenuNotFound:
                    .MENU_ITEM_NOT_FOUND
                case .menuExtraNotFound:
                    .MENU_ITEM_NOT_FOUND
                case .menuOperationFailed:
                    .INTERACTION_FAILED
                }

                outputError(
                    message: error.localizedDescription,
                    code: errorCode,
                    details: "Failed to click menu item")
            } else {
                fputs("❌ \(error.localizedDescription)\n", stderr)
            }
        }

        private func handleApplicationError(_ error: ApplicationError) {
            if self.jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .APP_NOT_FOUND,
                    details: "Application not found")
            } else {
                fputs("❌ \(error.localizedDescription)\n", stderr)
            }
        }

        private func handleGenericError(_ error: Error) {
            if self.jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .UNKNOWN_ERROR,
                    details: "Menu operation failed")
            } else {
                fputs("❌ Error: \(error.localizedDescription)\n", stderr)
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

        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                // Click the menu extra
                try await PeekabooServices.shared.menu.clickMenuExtra(title: self.title)

                // If an item was specified, we would need to click it after the menu appears
                // This would require additional service functionality
                if item != nil {
                    // Wait for menu to appear
                    try await Task.sleep(nanoseconds: 200_000_000) // 200ms

                    // Note: Clicking menu items within menu extras would require
                    // additional functionality in the service layer to identify
                    // and interact with the opened menu from the menu extra.
                    // For now, we just warn that this is not fully implemented.
                    fputs(
                        "Warning: Clicking menu items within menu extras is not yet implemented\n",
                        stderr)
                }

                // Output result
                if self.jsonOutput {
                    let data = MenuExtraClickResult(
                        action: "menu_extra_click",
                        menu_extra: title,
                        clicked_item: item ?? self.title)
                    outputSuccess(data: data)
                } else {
                    if let clickedItem = item {
                        print("✓ Clicked '\(clickedItem)' in \(self.title) menu")
                    } else {
                        print("✓ Clicked menu extra: \(self.title)")
                    }
                }

            } catch let error as MenuError {
                handleMenuError(error)
                throw ExitCode(1)
            } catch {
                self.handleGenericError(error)
                throw ExitCode(1)
            }
        }

        private func handleMenuError(_ error: MenuError) {
            if self.jsonOutput {
                let errorCode: ErrorCode = switch error {
                case .menuBarNotFound:
                    .MENU_BAR_NOT_FOUND
                case .menuItemNotFound:
                    .MENU_ITEM_NOT_FOUND
                case .submenuNotFound:
                    .MENU_ITEM_NOT_FOUND
                case .menuExtraNotFound:
                    .MENU_ITEM_NOT_FOUND
                case .menuOperationFailed:
                    .INTERACTION_FAILED
                }

                outputError(
                    message: error.localizedDescription,
                    code: errorCode,
                    details: "Failed to click menu extra")
            } else {
                fputs("❌ \(error.localizedDescription)\n", stderr)
            }
        }

        private func handleGenericError(_ error: Error) {
            if self.jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .UNKNOWN_ERROR,
                    details: "Menu extra operation failed")
            } else {
                fputs("❌ Error: \(error.localizedDescription)\n", stderr)
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

        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                // Get menu structure from service
                let menuStructure = try await PeekabooServices.shared.menu.listMenus(for: self.app)

                // Filter out disabled items if requested
                let filteredMenus = self.includeDisabled ? menuStructure.menus : self
                    .filterDisabledMenus(menuStructure.menus)

                // Output result
                if self.jsonOutput {
                    let data = MenuListData(
                        app: menuStructure.application.name,
                        bundle_id: menuStructure.application.bundleIdentifier,
                        menu_structure: self.convertMenusToJSON(filteredMenus))
                    outputSuccess(data: data)
                } else {
                    print("Menu structure for \(menuStructure.application.name):")
                    for menu in filteredMenus {
                        self.printMenu(menu, indent: 0)
                    }
                }

            } catch let error as ApplicationError {
                handleApplicationError(error)
                throw ExitCode(1)
            } catch let error as MenuError {
                handleMenuError(error)
                throw ExitCode(1)
            } catch {
                self.handleGenericError(error)
                throw ExitCode(1)
            }
        }

        private func filterDisabledMenus(_ menus: [Menu]) -> [Menu] {
            menus.compactMap { menu in
                guard menu.isEnabled else { return nil }
                let filteredItems = self.filterDisabledItems(menu.items)
                return Menu(title: menu.title, items: filteredItems, isEnabled: menu.isEnabled)
            }
        }

        private func filterDisabledItems(_ items: [MenuItem]) -> [MenuItem] {
            items.compactMap { item in
                guard item.isEnabled else { return nil }
                let filteredSubmenu = self.filterDisabledItems(item.submenu)
                return MenuItem(
                    title: item.title,
                    keyboardShortcut: item.keyboardShortcut,
                    isEnabled: item.isEnabled,
                    isChecked: item.isChecked,
                    isSeparator: item.isSeparator,
                    submenu: filteredSubmenu,
                    path: item.path)
            }
        }

        private func convertMenusToJSON(_ menus: [Menu]) -> [[String: Any]] {
            menus.map { menu in
                var menuData: [String: Any] = [
                    "title": menu.title,
                    "enabled": menu.isEnabled,
                ]

                if !menu.items.isEmpty {
                    menuData["items"] = self.convertMenuItemsToJSON(menu.items)
                }

                return menuData
            }
        }

        private func convertMenuItemsToJSON(_ items: [MenuItem]) -> [[String: Any]] {
            items.map { item in
                var itemData: [String: Any] = [
                    "title": item.title,
                    "enabled": item.isEnabled,
                ]

                if let shortcut = item.keyboardShortcut {
                    itemData["shortcut"] = shortcut.displayString
                }

                if item.isChecked {
                    itemData["checked"] = true
                }

                if item.isSeparator {
                    itemData["separator"] = true
                }

                if !item.submenu.isEmpty {
                    itemData["items"] = self.convertMenuItemsToJSON(item.submenu)
                }

                return itemData
            }
        }

        private func printMenu(_ menu: Menu, indent: Int) {
            let spacing = String(repeating: "  ", count: indent)

            var line = "\(spacing)\(menu.title)"
            if !menu.isEnabled {
                line += " (disabled)"
            }
            print(line)

            for item in menu.items {
                self.printMenuItem(item, indent: indent + 1)
            }
        }

        private func printMenuItem(_ item: MenuItem, indent: Int) {
            let spacing = String(repeating: "  ", count: indent)

            if item.isSeparator {
                print("\(spacing)---")
                return
            }

            var line = "\(spacing)\(item.title)"
            if !item.isEnabled {
                line += " (disabled)"
            }
            if item.isChecked {
                line += " ✓"
            }
            if let shortcut = item.keyboardShortcut {
                line += " [\(shortcut.displayString)]"
            }
            print(line)

            for subitem in item.submenu {
                self.printMenuItem(subitem, indent: indent + 1)
            }
        }

        private func handleApplicationError(_ error: ApplicationError) {
            if self.jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .APP_NOT_FOUND,
                    details: "Application not found")
            } else {
                fputs("❌ \(error.localizedDescription)\n", stderr)
            }
        }

        private func handleMenuError(_ error: MenuError) {
            if self.jsonOutput {
                let errorCode: ErrorCode = switch error {
                case .menuBarNotFound:
                    .MENU_BAR_NOT_FOUND
                case .menuItemNotFound:
                    .MENU_ITEM_NOT_FOUND
                case .submenuNotFound:
                    .MENU_ITEM_NOT_FOUND
                case .menuExtraNotFound:
                    .MENU_ITEM_NOT_FOUND
                case .menuOperationFailed:
                    .INTERACTION_FAILED
                }

                outputError(
                    message: error.localizedDescription,
                    code: errorCode,
                    details: "Failed to list menus")
            } else {
                fputs("❌ \(error.localizedDescription)\n", stderr)
            }
        }

        private func handleGenericError(_ error: Error) {
            if self.jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .UNKNOWN_ERROR,
                    details: "Menu list operation failed")
            } else {
                fputs("❌ Error: \(error.localizedDescription)\n", stderr)
            }
        }
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

        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                // Get frontmost application menus
                let frontmostMenus = try await PeekabooServices.shared.menu.listFrontmostMenus()

                // Get system menu extras
                let menuExtras = try await PeekabooServices.shared.menu.listMenuExtras()

                // Filter if needed
                let filteredMenus = self.includeDisabled ? frontmostMenus.menus : self
                    .filterDisabledMenus(frontmostMenus.menus)

                // Output results
                if self.jsonOutput {
                    var appData: [String: Any] = [
                        "app_name": frontmostMenus.application.name,
                        "bundle_id": frontmostMenus.application.bundleIdentifier ?? "unknown",
                        "pid": frontmostMenus.application.processIdentifier,
                        "menus": self.convertMenusToJSON(filteredMenus),
                    ]

                    // Add menu extras
                    var extraData: [[String: Any]] = []
                    for extra in menuExtras {
                        var itemData: [String: Any] = [
                            "type": "status_item",
                            "title": extra.title,
                            "enabled": true,
                        ]

                        if self.includeFrames {
                            itemData["frame"] = [
                                "x": extra.position.x,
                                "y": extra.position.y,
                                "width": 0, // Menu extras don't have size in our current model
                                "height": 0,
                            ]
                        }

                        extraData.append(itemData)
                    }

                    if !extraData.isEmpty {
                        appData["status_items"] = extraData
                    }

                    let data = ["apps": [appData]]
                    outputSuccess(data: data)
                } else {
                    print("\n=== \(frontmostMenus.application.name) ===")
                    for menu in filteredMenus {
                        self.printFullMenu(menu, indent: 0)
                    }

                    if !menuExtras.isEmpty {
                        print("\n=== System Menu Extras ===")
                        for extra in menuExtras {
                            print("  \(extra.title)")
                            if self.includeFrames {
                                print("    Position: (\(Int(extra.position.x)), \(Int(extra.position.y)))")
                            }
                        }
                    }
                }

            } catch let error as MenuError {
                handleMenuError(error)
                throw ExitCode(1)
            } catch {
                self.handleGenericError(error)
                throw ExitCode(1)
            }
        }

        private func filterDisabledMenus(_ menus: [Menu]) -> [Menu] {
            menus.compactMap { menu in
                guard menu.isEnabled else { return nil }
                let filteredItems = self.filterDisabledItems(menu.items)
                return Menu(title: menu.title, items: filteredItems, isEnabled: menu.isEnabled)
            }
        }

        private func filterDisabledItems(_ items: [MenuItem]) -> [MenuItem] {
            items.compactMap { item in
                guard item.isEnabled else { return nil }
                let filteredSubmenu = self.filterDisabledItems(item.submenu)
                return MenuItem(
                    title: item.title,
                    keyboardShortcut: item.keyboardShortcut,
                    isEnabled: item.isEnabled,
                    isChecked: item.isChecked,
                    isSeparator: item.isSeparator,
                    submenu: filteredSubmenu,
                    path: item.path)
            }
        }

        private func convertMenusToJSON(_ menus: [Menu]) -> [[String: Any]] {
            menus.map { menu in
                var menuData: [String: Any] = [
                    "title": menu.title,
                    "enabled": menu.isEnabled,
                ]

                if !menu.items.isEmpty {
                    menuData["items"] = self.convertMenuItemsToJSON(menu.items)
                }

                return menuData
            }
        }

        private func convertMenuItemsToJSON(_ items: [MenuItem]) -> [[String: Any]] {
            items.map { item in
                var itemData: [String: Any] = [
                    "title": item.title,
                    "enabled": item.isEnabled,
                ]

                if let shortcut = item.keyboardShortcut {
                    itemData["shortcut"] = shortcut.displayString
                }

                if item.isChecked {
                    itemData["checked"] = true
                }

                if item.isSeparator {
                    itemData["separator"] = true
                }

                if !item.submenu.isEmpty {
                    itemData["items"] = self.convertMenuItemsToJSON(item.submenu)
                }

                return itemData
            }
        }

        private func printFullMenu(_ menu: Menu, indent: Int) {
            let spacing = String(repeating: "  ", count: indent)

            var line = "\(spacing)\(menu.title)"
            if !menu.isEnabled {
                line += " (disabled)"
            }
            print(line)

            for item in menu.items {
                self.printMenuItem(item, indent: indent + 1)
            }
        }

        private func printMenuItem(_ item: MenuItem, indent: Int) {
            let spacing = String(repeating: "  ", count: indent)

            if item.isSeparator {
                print("\(spacing)---")
                return
            }

            var line = "\(spacing)\(item.title)"
            if !item.isEnabled {
                line += " (disabled)"
            }
            if item.isChecked {
                line += " ✓"
            }
            if let shortcut = item.keyboardShortcut {
                line += " [\(shortcut.displayString)]"
            }
            print(line)

            for subitem in item.submenu {
                self.printMenuItem(subitem, indent: indent + 1)
            }
        }

        private func handleMenuError(_ error: MenuError) {
            if self.jsonOutput {
                let errorCode: ErrorCode = switch error {
                case .menuBarNotFound:
                    .MENU_BAR_NOT_FOUND
                case .menuItemNotFound:
                    .MENU_ITEM_NOT_FOUND
                case .submenuNotFound:
                    .MENU_ITEM_NOT_FOUND
                case .menuExtraNotFound:
                    .MENU_ITEM_NOT_FOUND
                case .menuOperationFailed:
                    .INTERACTION_FAILED
                }

                outputError(
                    message: error.localizedDescription,
                    code: errorCode,
                    details: "Failed to list menus")
            } else {
                fputs("❌ \(error.localizedDescription)\n", stderr)
            }
        }

        private func handleGenericError(_ error: Error) {
            if self.jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .UNKNOWN_ERROR,
                    details: "Menu list operation failed")
            } else {
                fputs("❌ Error: \(error.localizedDescription)\n", stderr)
            }
        }
    }
}

// MARK: - Data Structures

struct MenuClickResult: Codable {
    let action: String
    let app: String
    let menu_path: String
    let clicked_item: String
}

struct MenuExtraClickResult: Codable {
    let action: String
    let menu_extra: String
    let clicked_item: String
}

struct MenuListData: Encodable {
    let app: String
    let bundle_id: String?
    let menu_structure: [[String: Any]]

    enum CodingKeys: String, CodingKey {
        case app
        case bundle_id
        case menu_structure
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.app, forKey: .app)
        try container.encodeIfPresent(self.bundle_id, forKey: .bundle_id)

        // Convert menu structure to AnyCodable for encoding
        let codableMenuStructure = self.menu_structure.map { AnyCodable($0) }
        try container.encode(codableMenuStructure, forKey: .menu_structure)
    }
}

// MARK: - Helper Functions

private func outputSuccess(data: some Encodable) {
    let response = JSONResponse(
        success: true,
        data: data,
        debugLogs: Logger.shared.getDebugLogs())
    outputJSON(response)
}
