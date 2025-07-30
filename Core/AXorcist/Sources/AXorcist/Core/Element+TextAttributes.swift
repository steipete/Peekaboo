import ApplicationServices
import CoreGraphics
import Foundation

// MARK: - Text and Label Attributes

public extension Element {

    /// Get the label of the element (common for UI controls)
    @MainActor
    func label() -> String? {
        attribute(Attribute<String>("AXLabel"))
    }

    /// Get the string value of the element (for text fields, etc.)
    @MainActor
    func stringValue() -> String? {
        // First try to get as String directly
        if let str = attribute(Attribute<String>(AXAttributeNames.kAXValueAttribute)) {
            return str
        }
        // Fall back to value() and convert if it's a string
        if let val = value() as? String {
            return val
        }
        return nil
    }

    /// Get the placeholder value (for text fields)
    @MainActor
    func placeholderValue() -> String? {
        attribute(Attribute<String>("AXPlaceholderValue"))
    }

    /// Get the linked UI elements (for labels linked to controls)
    @MainActor
    func linkedUIElements() -> [Element]? {
        guard let linkedUI: [AXUIElement] = attribute(Attribute<[AXUIElement]>("AXLinkedUIElements")) else {
            return nil
        }
        return linkedUI.map { Element($0) }
    }

    /// Get the serves as title for UI elements (for labels that title other elements)
    @MainActor
    func servesAsTitleForUIElements() -> [Element]? {
        guard let servesAsUI: [AXUIElement] = attribute(Attribute<[AXUIElement]>("AXServesAsTitleForUIElements")) else {
            return nil
        }
        return servesAsUI.map { Element($0) }
    }

    /// Get the titled UI elements (elements that this element titles)
    @MainActor
    func titledUIElements() -> [Element]? {
        guard let titledUI: [AXUIElement] = attribute(Attribute<[AXUIElement]>("AXTitledUIElements")) else {
            return nil
        }
        return titledUI.map { Element($0) }
    }

    /// Get the described UI elements (elements that this element describes)
    @MainActor
    func describesUIElements() -> [Element]? {
        guard let describesUI: [AXUIElement] = attribute(Attribute<[AXUIElement]>("AXDescribesUIElements")) else {
            return nil
        }
        return describesUI.map { Element($0) }
    }

    /// Check if the element is editable (for text fields)
    @MainActor
    func isEditable() -> Bool? {
        attribute(Attribute<Bool>("AXEditable"))
    }

    /// Get the insertion point line number (for text areas)
    @MainActor
    func insertionPointLineNumber() -> Int? {
        attribute(Attribute<Int>("AXInsertionPointLineNumber"))
    }

    /// Get the title UI element (the element that serves as this element's title)
    @MainActor
    func titleUIElement() -> Element? {
        guard let titleUI = attribute(Attribute<AXUIElement>("AXTitleUIElement")) else {
            return nil
        }
        return Element(titleUI)
    }

    /// Get the menu item command character (for menu items with keyboard shortcuts)
    @MainActor
    func menuItemCmdChar() -> String? {
        attribute(Attribute<String>("AXMenuItemCmdChar"))
    }

    /// Get the menu item command virtual key code
    @MainActor
    func menuItemCmdVirtualKey() -> Int? {
        attribute(Attribute<Int>("AXMenuItemCmdVirtualKey"))
    }

    /// Get the menu item command modifiers
    @MainActor
    func menuItemCmdModifiers() -> Int? {
        attribute(Attribute<Int>("AXMenuItemCmdModifiers"))
    }

    /// Get the menu item mark character (checkmark, dash, etc.)
    @MainActor
    func menuItemMarkChar() -> String? {
        attribute(Attribute<String>("AXMenuItemMarkChar"))
    }

    /// Check if menu item has a submenu
    @MainActor
    func hasSubmenu() -> Bool {
        // Check if children exist and are menu items
        if let children = children(), !children.isEmpty {
            // If it has children and they're menu items, it's a submenu
            return children.first?.role() == "AXMenuItem"
        }
        return false
    }

    /// Get keyboard shortcut for the element (primarily for menu items)
    /// Returns a formatted string like "⌘S" or nil if no shortcut
    @MainActor
    func keyboardShortcut() -> String? {
        // First check if there's a direct keyboard shortcut attribute (non-standard but sometimes used)
        if let shortcut = attribute(Attribute<String>("AXKeyboardShortcut")) {
            return shortcut
        }

        // For menu items, construct from command character and modifiers
        if role() == "AXMenuItem", let cmdChar = menuItemCmdChar() {
            var shortcut = ""

            // Get modifiers and convert to CGEventFlags
            if let modifiers = menuItemCmdModifiers() {
                let flags = CGEventFlags(rawValue: UInt64(modifiers))

                if flags.contains(.maskControl) {
                    shortcut += "⌃"
                }
                if flags.contains(.maskAlternate) {
                    shortcut += "⌥"
                }
                if flags.contains(.maskShift) {
                    shortcut += "⇧"
                }
                if flags.contains(.maskCommand) {
                    shortcut += "⌘"
                }
            }

            shortcut += cmdChar.uppercased()
            return shortcut.isEmpty ? nil : shortcut
        }

        return nil
    }
}
