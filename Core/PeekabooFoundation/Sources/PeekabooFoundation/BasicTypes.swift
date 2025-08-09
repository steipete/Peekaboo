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
    case `return`
    case enter // Numeric keypad enter
    case tab
    case escape
    case delete // Backspace
    case forwardDelete = "forward_delete" // fn+delete
    case space
    case leftArrow = "left"
    case rightArrow = "right"
    case upArrow = "up"
    case downArrow = "down"
    case pageUp = "pageup"
    case pageDown = "pagedown"
    case home
    case end
    case f1
    case f2
    case f3
    case f4
    case f5
    case f6
    case f7
    case f8
    case f9
    case f10
    case f11
    case f12
    case capsLock = "caps_lock"
    case clear
    case help
}

// MARK: - Type Actions

/// Actions for typing operations
public enum TypeAction: Sendable {
    case text(String)
    case key(SpecialKey)
    case clear
}

// MARK: - CustomStringConvertible Conformances

extension ClickType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .single: "single"
        case .right: "right"
        case .double: "double"
        }
    }
}

extension ScrollDirection: CustomStringConvertible {
    public var description: String {
        switch self {
        case .up: "up"
        case .down: "down"
        case .left: "left"
        case .right: "right"
        }
    }
}