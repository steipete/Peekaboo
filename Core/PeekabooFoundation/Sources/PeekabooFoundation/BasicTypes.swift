//
//  BasicTypes.swift
//  PeekabooFoundation
//

import Foundation

// MARK: - Element Types

/// Type of UI element
public enum ElementType: String, Sendable, Codable {
    case button
    case textField
    case link
    case image
    case group
    case slider
    case checkbox
    case menu
    case other
    case staticText
    case radioButton
    case menuItem
    case window
    case dialog
}

// MARK: - Click Types

/// Type of click operation
public enum ClickType: String, Sendable {
    case single
    case right
    case double
}

// MARK: - Scroll & Swipe

/// Direction for scroll operations
public enum ScrollDirection: String, Sendable {
    case up
    case down
    case left
    case right
}

/// Direction for swipe operations
public enum SwipeDirection: String, Sendable {
    case up
    case down
    case left
    case right
}

// MARK: - Keyboard

/// Modifier keys for keyboard operations
public enum ModifierKey: String, Sendable {
    case command = "cmd"
    case control = "ctrl"
    case option = "alt"
    case shift = "shift"
    case function = "fn"
}

/// Special keys for typing operations
public enum SpecialKey: String, Sendable {
    case `return` = "return"
    case tab = "tab"
    case space = "space"
    case delete = "delete"
    case escape = "escape"
    case up = "up"
    case down = "down"
    case left = "left"
    case right = "right"
    case home = "home"
    case end = "end"
    case pageUp = "pageup"
    case pageDown = "pagedown"
}

// MARK: - Type Actions

/// Actions for typing operations
public enum TypeAction: Sendable {
    case text(String)
    case key(SpecialKey)
    case clear
}