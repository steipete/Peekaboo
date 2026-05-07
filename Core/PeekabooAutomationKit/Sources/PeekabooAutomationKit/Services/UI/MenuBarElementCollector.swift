@preconcurrency import AXorcist
import CoreGraphics
import PeekabooFoundation

/// Converts an application's AX menu bar into Peekaboo detection elements.
@MainActor
struct MenuBarElementCollector {
    func appendMenuBar(
        _ menuBar: Element,
        elements: inout [DetectedElement],
        elementIdMap: inout [String: DetectedElement])
    {
        guard let menus = menuBar.children() else { return }

        for menu in menus {
            let menuId = "menu_\(elements.count)"
            let menuElement = DetectedElement(
                id: menuId,
                type: .menu,
                label: menu.title() ?? "Menu",
                value: nil,
                bounds: menu.frame() ?? .zero,
                isEnabled: menu.isEnabled() ?? true,
                isSelected: nil,
                attributes: ["role": "AXMenu"])

            elements.append(menuElement)
            elementIdMap[menuId] = menuElement

            if let menuItems = menu.children() {
                self.appendMenuItems(menuItems, elements: &elements, elementIdMap: &elementIdMap)
            }
        }
    }

    private func appendMenuItems(
        _ items: [Element],
        elements: inout [DetectedElement],
        elementIdMap: inout [String: DetectedElement])
    {
        for item in items {
            let itemId = "menuitem_\(elements.count)"
            let menuItemElement = DetectedElement(
                id: itemId,
                type: .other,
                label: item.title() ?? "Menu Item",
                value: nil,
                bounds: item.frame() ?? .zero,
                isEnabled: item.isEnabled() ?? true,
                isSelected: nil,
                attributes: self.menuItemAttributes(item))

            elements.append(menuItemElement)
            elementIdMap[itemId] = menuItemElement

            if let submenu = item.children(), !submenu.isEmpty {
                self.appendMenuItems(submenu, elements: &elements, elementIdMap: &elementIdMap)
            }
        }
    }

    private func menuItemAttributes(_ item: Element) -> [String: String] {
        var attributes = ["role": "AXMenuItem"]

        if let title = item.title() {
            attributes["title"] = title
        }
        if let shortcut = self.keyboardShortcut(item) {
            attributes["keyboardShortcut"] = shortcut
        }
        if item.isEnabled() == false {
            attributes["isEnabled"] = "false"
        }

        return attributes
    }

    private func keyboardShortcut(_ item: Element) -> String? {
        if let shortcut = item.keyboardShortcut() {
            return shortcut
        }

        if let description = item.descriptionText(),
           description.contains("⌘") || description.contains("⌥") || description.contains("⌃")
        {
            return description
        }

        return nil
    }
}
