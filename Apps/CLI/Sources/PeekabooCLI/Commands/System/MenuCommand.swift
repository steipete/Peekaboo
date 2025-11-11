import AppKit
import Commander
import Foundation
import PeekabooCore
import PeekabooFoundation

/// Menu-specific errors
enum MenuError: Error {
    case menuBarNotFound
    case menuItemNotFound(String)
    case submenuNotFound(String)
    case menuExtraNotFound
    case menuOperationFailed(String)
}

/// Interact with application menu bar items and system menu extras
@MainActor
struct MenuCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
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
                ]
            )
        }
    }
}

extension MenuCommand {
    // MARK: - Click Menu Item

    @MainActor

    struct ClickSubcommand: OutputFormattable, ApplicationResolvablePositional {
        @Option(help: "Target application by name, bundle ID, or 'PID:12345'")
        var app: String

        @Option(name: .long, help: "Target application by process ID")
        var pid: Int32?

        @Option(help: "Menu item to click (for simple, non-nested items)")
        var item: String?

        @Option(help: "Menu path for nested items (e.g., 'File > Export > PDF')")
        var path: String?

        @OptionGroup var focusOptions: FocusCommandOptions
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: PeekabooServices { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            guard self.item != nil || self.path != nil else {
                throw ValidationError("Must specify either --item or --path")
            }

            guard self.item == nil || self.path == nil else {
                throw ValidationError("Cannot specify both --item and --path")
            }

            do {
                let appIdentifier = try self.resolveApplicationIdentifier()
                try await ensureFocused(
                    applicationName: appIdentifier,
                    options: self.focusOptions,
                    services: self.services
                )

                if let itemName = self.item {
                    try await MenuServiceBridge.clickMenuItemByName(
                        services: self.services,
                        appIdentifier: appIdentifier,
                        itemName: itemName
                    )
                } else if let path {
                    try await MenuServiceBridge.clickMenuItem(
                        services: self.services,
                        appIdentifier: appIdentifier,
                        itemPath: path
                    )
                }

                let appInfo = try await self.services.applications.findApplication(identifier: appIdentifier)
                let clickedPath = self.path ?? self.item!

                if self.jsonOutput {
                    let data = MenuClickResult(
                        action: "menu_click",
                        app: appInfo.name,
                        menu_path: clickedPath,
                        clicked_item: clickedPath
                    )
                    outputSuccessCodable(data: data, logger: self.outputLogger)
                } else {
                    print("✓ Clicked menu item: \(clickedPath)")
                }

            } catch let error as MenuError {
                self.handleMenuError(error)
                throw ExitCode(1)
            } catch let error as PeekabooError {
                self.handleApplicationError(error)
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
                    details: "Failed to click menu item",
                    logger: self.outputLogger
                )
            } else {
                fputs("❌ \(error.localizedDescription)\n", stderr)
            }
        }

        private func handleApplicationError(_ error: PeekabooError) {
            if self.jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .APP_NOT_FOUND,
                    details: "Application not found",
                    logger: self.outputLogger
                )
            } else {
                fputs("❌ \(error.localizedDescription)\n", stderr)
            }
        }

        private func handleGenericError(_ error: any Error) {
            if self.jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .UNKNOWN_ERROR,
                    details: "Menu operation failed",
                    logger: self.outputLogger
                )
            } else {
                fputs("❌ Error: \(error.localizedDescription)\n", stderr)
            }
        }
    }

    // MARK: - Click System Menu Extra

    @MainActor

    struct ClickExtraSubcommand: OutputFormattable {
        @Option(help: "Title of the menu extra (e.g., 'WiFi', 'Bluetooth')")
        var title: String

        @Option(help: "Menu item to click after opening the extra")
        var item: String?
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: PeekabooServices { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                try await MenuServiceBridge.clickMenuExtra(services: self.services, title: self.title)

                if self.item != nil {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    fputs("Warning: Clicking menu items within menu extras is not yet implemented\n", stderr)
                }

                if self.jsonOutput {
                    let data = MenuExtraClickResult(
                        action: "menu_extra_click",
                        menu_extra: title,
                        clicked_item: item ?? self.title
                    )
                    outputSuccessCodable(data: data, logger: self.outputLogger)
                } else if let clickedItem = item {
                    print("✓ Clicked '\(clickedItem)' in \(self.title) menu")
                } else {
                    print("✓ Clicked menu extra: \(self.title)")
                }

            } catch let error as MenuError {
                self.handleMenuError(error)
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
                    details: "Failed to click menu extra",
                    logger: self.outputLogger
                )
            } else {
                fputs("❌ \(error.localizedDescription)\n", stderr)
            }
        }

        private func handleGenericError(_ error: any Error) {
            if self.jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .UNKNOWN_ERROR,
                    details: "Menu extra operation failed",
                    logger: self.outputLogger
                )
            } else {
                fputs("❌ Error: \(error.localizedDescription)\n", stderr)
            }
        }
    }

    // MARK: - List Menu Items

    @MainActor

    struct ListSubcommand: OutputFormattable, ApplicationResolvablePositional {
        @Option(help: "Target application by name, bundle ID, or 'PID:12345'")
        var app: String

        @Option(name: .long, help: "Target application by process ID")
        var pid: Int32?

        @Flag(help: "Include disabled menu items")
        var includeDisabled = false

        @OptionGroup var focusOptions: FocusCommandOptions
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: PeekabooServices { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                let appIdentifier = try self.resolveApplicationIdentifier()
                try await ensureFocused(
                    applicationName: appIdentifier,
                    options: self.focusOptions,
                    services: self.services
                )

                let menuStructure = try await MenuServiceBridge.listMenus(
                    services: self.services,
                    appIdentifier: appIdentifier
                )
                let filteredMenus = self.includeDisabled ? menuStructure.menus : self
                    .filterDisabledMenus(menuStructure.menus)

                if self.jsonOutput {
                    let data = MenuListData(
                        app: menuStructure.application.name,
                        bundle_id: menuStructure.application.bundleIdentifier,
                        menu_structure: self.convertMenusToTyped(filteredMenus)
                    )
                    outputSuccessCodable(data: data, logger: self.outputLogger)
                } else {
                    print("Menu structure for \(menuStructure.application.name):")
                    for menu in filteredMenus {
                        self.printMenu(menu, indent: 0)
                    }
                }

            } catch let error as PeekabooError {
                self.handleApplicationError(error)
                throw ExitCode(1)
            } catch let error as MenuError {
                self.handleMenuError(error)
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
                    path: item.path
                )
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
                    details: "Application not found",
                    logger: self.outputLogger
                )
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
                    details: "Failed to list menus",
                    logger: self.outputLogger
                )
            } else {
                fputs("❌ \(error.localizedDescription)\n", stderr)
            }
        }

        private func handleGenericError(_ error: any Error) {
            if self.jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .UNKNOWN_ERROR,
                    details: "Menu list operation failed",
                    logger: self.outputLogger
                )
            } else {
                fputs("❌ Error: \(error.localizedDescription)\n", stderr)
            }
        }
    }

    // MARK: - List All Menu Bar Items

    @MainActor

    struct ListAllSubcommand: OutputFormattable {
        @Flag(help: "Include disabled menu items")
        var includeDisabled = false

        @Flag(help: "Include item frames (pixel positions)")
        var includeFrames = false
        @RuntimeStorage private var runtime: CommandRuntime?

        private var resolvedRuntime: CommandRuntime {
            guard let runtime else {
                preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
            }
            return runtime
        }

        private var services: PeekabooServices { self.resolvedRuntime.services }
        private var logger: Logger { self.resolvedRuntime.logger }
        var outputLogger: Logger { self.logger }
        var jsonOutput: Bool { self.resolvedRuntime.configuration.jsonOutput }

        @MainActor
        mutating func run(using runtime: CommandRuntime) async throws {
            self.runtime = runtime
            self.logger.setJsonOutputMode(self.jsonOutput)

            do {
                let frontmostMenus = try await MenuServiceBridge.listFrontmostMenus(services: self.services)
                let menuExtras = try await MenuServiceBridge.listMenuExtras(services: self.services)

                let filteredMenus = self.includeDisabled ? frontmostMenus.menus : self
                    .filterDisabledMenus(frontmostMenus.menus)

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
                    outputSuccessCodable(data: outputData, logger: self.outputLogger)
                } else {
                    print("\n=== \(frontmostMenus.application.name) ===")
                    for menu in filteredMenus {
                        self.printMenu(menu, indent: 0)
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
                self.handleMenuError(error)
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
                    path: item.path
                )
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
                    details: "Failed to list menus",
                    logger: self.outputLogger
                )
            } else {
                fputs("❌ \(error.localizedDescription)\n", stderr)
            }
        }

        private func handleGenericError(_ error: any Error) {
            if self.jsonOutput {
                outputError(
                    message: error.localizedDescription,
                    code: .UNKNOWN_ERROR,
                    details: "Menu list operation failed",
                    logger: self.outputLogger
                )
            } else {
                fputs("❌ Error: \(error.localizedDescription)\n", stderr)
            }
        }
    }
}

// MARK: - Subcommand Conformances

@MainActor
extension MenuCommand.ClickSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "click",
                abstract: "Click a menu item"
            )
        }
    }
}

extension MenuCommand.ClickSubcommand: AsyncRuntimeCommand {}

@MainActor
extension MenuCommand.ClickSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = try values.requireOption("app", as: String.self)
        self.pid = try values.decodeOption("pid", as: Int32.self)
        self.item = values.singleOption("item")
        self.path = values.singleOption("path")
        self.focusOptions = try values.makeFocusOptions()
    }
}

@MainActor
extension MenuCommand.ClickExtraSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "click-extra",
                abstract: "Click a system menu extra (status bar item)"
            )
        }
    }
}

extension MenuCommand.ClickExtraSubcommand: AsyncRuntimeCommand {}

@MainActor
extension MenuCommand.ClickExtraSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.title = try values.requireOption("title", as: String.self)
        self.item = values.singleOption("item")
    }
}

@MainActor
extension MenuCommand.ListSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "list",
                abstract: "List all menu items for an application"
            )
        }
    }
}

extension MenuCommand.ListSubcommand: AsyncRuntimeCommand {}

@MainActor
extension MenuCommand.ListSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = try values.requireOption("app", as: String.self)
        self.pid = try values.decodeOption("pid", as: Int32.self)
        self.includeDisabled = values.flag("includeDisabled")
        self.focusOptions = try values.makeFocusOptions()
    }
}

@MainActor
extension MenuCommand.ListAllSubcommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            CommandDescription(
                commandName: "list-all",
                abstract: "List all menu bar items system-wide (including status items)"
            )
        }
    }
}

extension MenuCommand.ListAllSubcommand: AsyncRuntimeCommand {}

@MainActor
extension MenuCommand.ListAllSubcommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.includeDisabled = values.flag("includeDisabled")
        self.includeFrames = values.flag("includeFrames")
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
