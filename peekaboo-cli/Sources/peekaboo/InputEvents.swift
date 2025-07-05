import AppKit
import CoreGraphics
import Foundation

/// Utility functions for synthesizing mouse and keyboard events
enum InputEvents {
    // MARK: - Mouse Events

    /// Performs a mouse click at the specified location
    static func click(at point: CGPoint, button: MouseButton = .left, clickCount: Int = 1) throws {
        // Move mouse to position
        let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: button.cgButton
        )
        moveEvent?.post(tap: .cghidEventTap)

        // Small delay for movement
        Thread.sleep(forTimeInterval: 0.01)

        // Perform click(s)
        for _ in 0..<clickCount {
            // Mouse down
            let downEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: button.downEventType,
                mouseCursorPosition: point,
                mouseButton: button.cgButton
            )
            downEvent?.post(tap: .cghidEventTap)

            // Small delay between down and up
            Thread.sleep(forTimeInterval: 0.05)

            // Mouse up
            let upEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: button.upEventType,
                mouseCursorPosition: point,
                mouseButton: button.cgButton
            )
            upEvent?.post(tap: .cghidEventTap)

            // Delay between clicks for double/triple click
            if clickCount > 1 {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }

    // MARK: - Keyboard Events

    /// Types a string of text
    static func typeString(_ text: String, delay: TimeInterval = 0.01) throws {
        for character in text {
            try typeCharacter(character)
            if delay > 0 {
                Thread.sleep(forTimeInterval: delay)
            }
        }
    }

    /// Types a single character
    static func typeCharacter(_ character: Character) throws {
        guard let keyCode = KeyCodeMapper.keyCode(for: character) else {
            // Use Unicode text input for characters without key codes
            let source = CGEventSource(stateID: .hidSystemState)
            let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            event?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [character.utf16.first!])
            event?.post(tap: .cghidEventTap)
            return
        }

        // Determine if shift is needed
        let needsShift = KeyCodeMapper.needsShift(for: character)

        if needsShift {
            // Press shift
            let shiftDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(0x38), keyDown: true)
            shiftDown?.flags = .maskShift
            shiftDown?.post(tap: .cghidEventTap)
        }

        // Type the key
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        if needsShift {
            keyDown?.flags = .maskShift
        }
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        if needsShift {
            keyUp?.flags = .maskShift
        }
        keyUp?.post(tap: .cghidEventTap)

        if needsShift {
            // Release shift
            let shiftUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(0x38), keyDown: false)
            shiftUp?.post(tap: .cghidEventTap)
        }
    }

    /// Presses a special key (return, tab, escape, etc.)
    static func pressKey(_ key: SpecialKey, modifiers: [KeyModifier] = []) throws {
        let flags = modifiers.reduce(CGEventFlags()) { result, modifier in
            var newFlags = result
            newFlags.insert(modifier.cgFlag)
            return newFlags
        }

        // Key down
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: key.keyCode, keyDown: true)
        keyDown?.flags = flags
        keyDown?.post(tap: .cghidEventTap)

        // Key up
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: key.keyCode, keyDown: false)
        keyUp?.flags = flags
        keyUp?.post(tap: .cghidEventTap)
    }

    /// Performs a keyboard shortcut (e.g., Cmd+C)
    static func performHotkey(keys: [String], holdDuration: TimeInterval = 0.1) throws {
        var modifiers: [KeyModifier] = []
        var regularKeys: [CGKeyCode] = []

        // Parse keys into modifiers and regular keys
        for key in keys {
            if let modifier = KeyModifier(rawValue: key.lowercased()) {
                modifiers.append(modifier)
            } else if let specialKey = SpecialKey(rawValue: key.lowercased()) {
                regularKeys.append(specialKey.keyCode)
            } else if let keyCode = KeyCodeMapper.keyCode(forKeyName: key) {
                regularKeys.append(keyCode)
            }
        }

        // Press modifiers
        for modifier in modifiers {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: modifier.keyCode, keyDown: true)
            event?.flags = modifier.cgFlag
            event?.post(tap: .cghidEventTap)
        }

        // Press regular keys
        let combinedFlags = modifiers.reduce(CGEventFlags()) { result, modifier in
            var newFlags = result
            newFlags.insert(modifier.cgFlag)
            return newFlags
        }

        for keyCode in regularKeys {
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
            keyDown?.flags = combinedFlags
            keyDown?.post(tap: .cghidEventTap)
        }

        // Hold for specified duration
        Thread.sleep(forTimeInterval: holdDuration)

        // Release regular keys
        for keyCode in regularKeys.reversed() {
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
            keyUp?.flags = combinedFlags
            keyUp?.post(tap: .cghidEventTap)
        }

        // Release modifiers
        for modifier in modifiers.reversed() {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: modifier.keyCode, keyDown: false)
            event?.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Types

    enum MouseButton {
        case left
        case right
        case middle

        var cgButton: CGMouseButton {
            switch self {
            case .left: .left
            case .right: .right
            case .middle: .center
            }
        }

        var downEventType: CGEventType {
            switch self {
            case .left: .leftMouseDown
            case .right: .rightMouseDown
            case .middle: .otherMouseDown
            }
        }

        var upEventType: CGEventType {
            switch self {
            case .left: .leftMouseUp
            case .right: .rightMouseUp
            case .middle: .otherMouseUp
            }
        }
    }

    enum SpecialKey: String {
        case `return`
        case tab
        case space
        case delete
        case escape, esc
        case leftArrow = "left"
        case rightArrow = "right"
        case upArrow = "up"
        case downArrow = "down"
        case pageUp = "pageup"
        case pageDown = "pagedown"
        case home
        case end
        case f1, f2, f3, f4
        case f5, f6, f7, f8
        case f9, f10, f11, f12

        var keyCode: CGKeyCode {
            switch self {
            case .return: 0x24
            case .tab: 0x30
            case .space: 0x31
            case .delete: 0x33
            case .escape, .esc: 0x35
            case .leftArrow: 0x7B
            case .rightArrow: 0x7C
            case .downArrow: 0x7D
            case .upArrow: 0x7E
            case .pageUp: 0x74
            case .pageDown: 0x79
            case .home: 0x73
            case .end: 0x77
            case .f1: 0x7A
            case .f2: 0x78
            case .f3: 0x63
            case .f4: 0x76
            case .f5: 0x60
            case .f6: 0x61
            case .f7: 0x62
            case .f8: 0x64
            case .f9: 0x65
            case .f10: 0x6D
            case .f11: 0x67
            case .f12: 0x6F
            }
        }
    }

    enum KeyModifier: String {
        case cmd, command
        case ctrl, control
        case opt, option, alt
        case shift
        case fn, function

        var cgFlag: CGEventFlags {
            switch self {
            case .cmd, .command: .maskCommand
            case .ctrl, .control: .maskControl
            case .opt, .option, .alt: .maskAlternate
            case .shift: .maskShift
            case .fn, .function: .maskSecondaryFn
            }
        }

        var keyCode: CGKeyCode {
            switch self {
            case .cmd, .command: 0x37
            case .ctrl, .control: 0x3B
            case .opt, .option, .alt: 0x3A
            case .shift: 0x38
            case .fn, .function: 0x3F
            }
        }
    }
}

/// Maps characters and key names to virtual key codes
enum KeyCodeMapper {
    static func keyCode(for character: Character) -> CGKeyCode? {
        switch character {
        // Letters
        case "a", "A": 0x00
        case "b", "B": 0x0B
        case "c", "C": 0x08
        case "d", "D": 0x02
        case "e", "E": 0x0E
        case "f", "F": 0x03
        case "g", "G": 0x05
        case "h", "H": 0x04
        case "i", "I": 0x22
        case "j", "J": 0x26
        case "k", "K": 0x28
        case "l", "L": 0x25
        case "m", "M": 0x2E
        case "n", "N": 0x2D
        case "o", "O": 0x1F
        case "p", "P": 0x23
        case "q", "Q": 0x0C
        case "r", "R": 0x0F
        case "s", "S": 0x01
        case "t", "T": 0x11
        case "u", "U": 0x20
        case "v", "V": 0x09
        case "w", "W": 0x0D
        case "x", "X": 0x07
        case "y", "Y": 0x10
        case "z", "Z": 0x06
        // Numbers
        case "0", ")": 0x1D
        case "1", "!": 0x12
        case "2", "@": 0x13
        case "3", "#": 0x14
        case "4", "$": 0x15
        case "5", "%": 0x17
        case "6", "^": 0x16
        case "7", "&": 0x1A
        case "8", "*": 0x1C
        case "9", "(": 0x19
        // Punctuation
        case "-", "_": 0x1B
        case "=", "+": 0x18
        case "[", "{": 0x21
        case "]", "}": 0x1E
        case ";", ":": 0x29
        case "'", "\"": 0x27
        case ",", "<": 0x2B
        case ".", ">": 0x2F
        case "/", "?": 0x2C
        case "`", "~": 0x32
        case "\\", "|": 0x2A
        // Special
        case " ": 0x31 // Space
        case "\t": 0x30 // Tab
        case "\n": 0x24 // Return
        default: nil
        }
    }

    static func keyCode(forKeyName name: String) -> CGKeyCode? {
        // Try single character first
        if name.count == 1, let code = keyCode(for: Character(name.lowercased())) {
            return code
        }

        // Try special keys
        if let special = InputEvents.SpecialKey(rawValue: name.lowercased()) {
            return special.keyCode
        }

        return nil
    }

    static func needsShift(for character: Character) -> Bool {
        switch character {
        case "A"..."Z": true
        case "!", "@", "#", "$", "%", "^", "&", "*", "(", ")": true
        case "_", "+", "{", "}", ":", "\"", "<", ">", "?", "~", "|": true
        default: false
        }
    }
}
