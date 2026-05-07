import Foundation
import PeekabooCore

enum MenuOutputSupport {
    static func filterDisabledMenus(_ menus: [Menu]) -> [Menu] {
        menus.compactMap { menu in
            guard menu.isEnabled else { return nil }
            let filteredItems = Self.filterDisabledItems(menu.items)
            return Menu(title: menu.title, items: filteredItems, isEnabled: menu.isEnabled)
        }
    }

    private static func filterDisabledItems(_ items: [MenuItem]) -> [MenuItem] {
        items.compactMap { item in
            guard item.isEnabled else { return nil }
            let filteredSubmenu = Self.filterDisabledItems(item.submenu)
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

    static func convertMenusToTyped(_ menus: [Menu]) -> [MenuData] {
        menus.map { menu in
            MenuData(
                title: menu.title,
                bundle_id: menu.bundleIdentifier,
                owner_name: menu.ownerName,
                enabled: menu.isEnabled,
                items: menu.items.isEmpty ? nil : Self.convertMenuItemsToTyped(menu.items)
            )
        }
    }

    private static func convertMenuItemsToTyped(_ items: [MenuItem]) -> [MenuItemData] {
        items.map { item in
            MenuItemData(
                title: item.title,
                bundle_id: item.bundleIdentifier,
                owner_name: item.ownerName,
                enabled: item.isEnabled,
                shortcut: item.keyboardShortcut?.displayString,
                checked: item.isChecked ? true : nil,
                separator: item.isSeparator ? true : nil,
                items: item.submenu.isEmpty ? nil : Self.convertMenuItemsToTyped(item.submenu)
            )
        }
    }

    static func printMenu(_ menu: Menu, indent: Int) {
        let spacing = String(repeating: "  ", count: indent)

        var line = "\(spacing)\(menu.title)"
        if !menu.isEnabled {
            line += " (disabled)"
        }
        print(line)

        for item in menu.items {
            Self.printMenuItem(item, indent: indent + 1)
        }
    }

    private static func printMenuItem(_ item: MenuItem, indent: Int) {
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
            Self.printMenuItem(subitem, indent: indent + 1)
        }
    }
}
