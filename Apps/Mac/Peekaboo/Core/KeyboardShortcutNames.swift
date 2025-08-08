//
//  KeyboardShortcutNames.swift
//  Peekaboo
//

import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePopover = Self("togglePopover", default: .init(.space, modifiers: [.command, .shift]))
    static let showMainWindow = Self("showMainWindow", default: .init(.p, modifiers: [.command, .shift]))
    static let showInspector = Self("showInspector", default: .init(.i, modifiers: [.command, .shift]))
}
