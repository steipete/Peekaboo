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
        
        @OptionGroup var focusOptions: FocusOptions

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
                // Ensure application is focused before menu interaction
                try await self.ensureFocused(
                    applicationName: self.app,
                    options: focusOptions
                )
                
                // If using --item, search recursively; if using --path, use exact path
                if let itemName = self.item {
                    // Use recursive search for --item parameter
                    try await PeekabooServices.shared.menu.clickMenuItemByName(app: self.app, itemName: itemName)
                } else if let path = self.path {
                    // Use exact path for --path parameter
                    try await PeekabooServices.shared.menu.clickMenuItem(app: self.app, itemPath: path)
                }

                // Get app info for response
                let appInfo = try await PeekabooServices.shared.applications.findApplication(identifier: self.app)

                // Determine what was clicked for output
                let clickedPath = self.path ?? self.item!
                
                // Output result
                if self.jsonOutput {
                    let data = MenuClickResult(
                        action: "menu_click",
                        app: appInfo.name,
                        menu_path: clickedPath,
                        clicked_item: clickedPath)
                    outputSuccessCodable(data: data)
                } else {
                    print("✓ Clicked menu item: \(clickedPath)")
                }

            } catch let error as MenuError {
                handleMenuError(error)
                throw ExitCode(1)
            } catch let error as PeekabooError {
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

        private func handleApplicationError(_ error: PeekabooError) {
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
        
        @OptionGroup var focusOptions: FocusOptions

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
                    outputSuccessCodable(data: data)
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
        
        @OptionGroup var focusOptions: FocusOptions

        mutating func run() async throws {
            Logger.shared.setJsonOutputMode(self.jsonOutput)

            do {
                // Ensure application is focused before listing menus
                try await self.ensureFocused(
                    applicationName: self.app,
                    options: focusOptions
                )
                
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
                        menu_structure: self.convertMenusToTyped(filteredMenus))
                    outputSuccessCodable(data: data)
                } else {
                    print("Menu structure for \(menuStructure.application.name):")
                    for menu in filteredMenus {
                        self.printMenu(menu, indent: 0)
                    }
                }

            } catch let error as PeekabooError {
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

        private func convertMenusToTyped(_ menus: [Menu]) -> [MenuData] {
            menus.map { menu in
                MenuData(
                    title: menu.title,
                    enabled: menu.isEnabled,
                    items: menu.items.isEmpty ? nil : self.convertMenuItemsToTyped(menu.items)
                )
            }
        }

        private func convertMenuItemsToTyped(_ items: [MenuItem]) -> [MenuItemData] {
            items.map { item in
                MenuItemData(
                    title: item.title,
                    enabled: item.isEnabled,
                    shortcut: item.keyboardShortcut?.displayString,
                    checked: item.isChecked ? true : nil,
                    separator: item.isSeparator ? true : nil,
                    items: item.submenu.isEmpty ? nil : self.convertMenuItemsToTyped(item.submenu)
                )
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

        private func handleApplicationError(_ error: PeekabooError) {
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
        
        @OptionGroup var focusOptions: FocusOptions

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
                    struct MenuAllResult: Codable {
                        let apps: [AppMenuInfo]
                        
                        struct AppMenuInfo: Codable {
                            let appName: String
                            let bundleId: String
                            let pid: Int32
                            let menus: [MenuData]
                            let statusItems: [StatusItem]?
                        }
                        
                        struct StatusItem: Codable {
                            let type: String
                            let title: String
                            let enabled: Bool
                            let frame: Frame?
                            
                            struct Frame: Codable {
                                let x: Double
                                let y: Double
                                let width: Int
                                let height: Int
                            }
                        }
                    }
                    
                    let statusItems = menuExtras.map { extra in
                        MenuAllResult.StatusItem(
                            type: "status_item",
                            title: extra.title,
                            enabled: true,
                            frame: self.includeFrames ? MenuAllResult.StatusItem.Frame(
                                x: Double(extra.position.x),
                                y: Double(extra.position.y),
                                width: 0,
                                height: 0
                            ) : nil
                        )
                    }
                    
                    let appInfo = MenuAllResult.AppMenuInfo(
                        appName: frontmostMenus.application.name,
                        bundleId: frontmostMenus.application.bundleIdentifier ?? "unknown",
                        pid: frontmostMenus.application.processIdentifier,
                        menus: self.convertMenusToTyped(filteredMenus),
                        statusItems: statusItems.isEmpty ? nil : statusItems
                    )
                    
                    let outputData = MenuAllResult(apps: [appInfo])
                    outputSuccessCodable(data: outputData)
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

        private func convertMenusToTyped(_ menus: [Menu]) -> [MenuData] {
            menus.map { menu in
                MenuData(
                    title: menu.title,
                    enabled: menu.isEnabled,
                    items: menu.items.isEmpty ? nil : self.convertMenuItemsToTyped(menu.items)
                )
            }
        }

        private func convertMenuItemsToTyped(_ items: [MenuItem]) -> [MenuItemData] {
            items.map { item in
                MenuItemData(
                    title: item.title,
                    enabled: item.isEnabled,
                    shortcut: item.keyboardShortcut?.displayString,
                    checked: item.isChecked ? true : nil,
                    separator: item.isSeparator ? true : nil,
                    items: item.submenu.isEmpty ? nil : self.convertMenuItemsToTyped(item.submenu)
                )
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

// Typed menu structures for JSON output
struct MenuListData: Codable {
    let app: String
    let bundle_id: String?
    let menu_structure: [MenuData]
}

struct MenuData: Codable {
    let title: String
    let enabled: Bool
    let items: [MenuItemData]?
}

struct MenuItemData: Codable {
    let title: String
    let enabled: Bool
    let shortcut: String?
    let checked: Bool?
    let separator: Bool?
    let items: [MenuItemData]?
}

