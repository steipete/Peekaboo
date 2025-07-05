import Foundation
import CoreGraphics
import AppKit

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
            case .left: return .left
            case .right: return .right
            case .middle: return .center
            }
        }
        
        var downEventType: CGEventType {
            switch self {
            case .left: return .leftMouseDown
            case .right: return .rightMouseDown
            case .middle: return .otherMouseDown
            }
        }
        
        var upEventType: CGEventType {
            switch self {
            case .left: return .leftMouseUp
            case .right: return .rightMouseUp
            case .middle: return .otherMouseUp
            }
        }
    }
    
    enum SpecialKey: String {
        case `return` = "return"
        case tab = "tab"
        case space = "space"
        case delete = "delete"
        case escape = "escape", esc = "esc"
        case leftArrow = "left"
        case rightArrow = "right"
        case upArrow = "up"
        case downArrow = "down"
        case pageUp = "pageup"
        case pageDown = "pagedown"
        case home = "home"
        case end = "end"
        case f1 = "f1", f2 = "f2", f3 = "f3", f4 = "f4"
        case f5 = "f5", f6 = "f6", f7 = "f7", f8 = "f8"
        case f9 = "f9", f10 = "f10", f11 = "f11", f12 = "f12"
        
        var keyCode: CGKeyCode {
            switch self {
            case .return: return 0x24
            case .tab: return 0x30
            case .space: return 0x31
            case .delete: return 0x33
            case .escape, .esc: return 0x35
            case .leftArrow: return 0x7B
            case .rightArrow: return 0x7C
            case .downArrow: return 0x7D
            case .upArrow: return 0x7E
            case .pageUp: return 0x74
            case .pageDown: return 0x79
            case .home: return 0x73
            case .end: return 0x77
            case .f1: return 0x7A
            case .f2: return 0x78
            case .f3: return 0x63
            case .f4: return 0x76
            case .f5: return 0x60
            case .f6: return 0x61
            case .f7: return 0x62
            case .f8: return 0x64
            case .f9: return 0x65
            case .f10: return 0x6D
            case .f11: return 0x67
            case .f12: return 0x6F
            }
        }
    }
    
    enum KeyModifier: String {
        case cmd = "cmd", command = "command"
        case ctrl = "ctrl", control = "control"
        case opt = "opt", option = "option", alt = "alt"
        case shift = "shift"
        case fn = "fn", function = "function"
        
        var cgFlag: CGEventFlags {
            switch self {
            case .cmd, .command: return .maskCommand
            case .ctrl, .control: return .maskControl
            case .opt, .option, .alt: return .maskAlternate
            case .shift: return .maskShift
            case .fn, .function: return .maskSecondaryFn
            }
        }
        
        var keyCode: CGKeyCode {
            switch self {
            case .cmd, .command: return 0x37
            case .ctrl, .control: return 0x3B
            case .opt, .option, .alt: return 0x3A
            case .shift: return 0x38
            case .fn, .function: return 0x3F
            }
        }
    }
}

/// Maps characters and key names to virtual key codes
enum KeyCodeMapper {
    
    static func keyCode(for character: Character) -> CGKeyCode? {
        switch character {
        // Letters
        case "a", "A": return 0x00
        case "b", "B": return 0x0B
        case "c", "C": return 0x08
        case "d", "D": return 0x02
        case "e", "E": return 0x0E
        case "f", "F": return 0x03
        case "g", "G": return 0x05
        case "h", "H": return 0x04
        case "i", "I": return 0x22
        case "j", "J": return 0x26
        case "k", "K": return 0x28
        case "l", "L": return 0x25
        case "m", "M": return 0x2E
        case "n", "N": return 0x2D
        case "o", "O": return 0x1F
        case "p", "P": return 0x23
        case "q", "Q": return 0x0C
        case "r", "R": return 0x0F
        case "s", "S": return 0x01
        case "t", "T": return 0x11
        case "u", "U": return 0x20
        case "v", "V": return 0x09
        case "w", "W": return 0x0D
        case "x", "X": return 0x07
        case "y", "Y": return 0x10
        case "z", "Z": return 0x06
            
        // Numbers
        case "0", ")": return 0x1D
        case "1", "!": return 0x12
        case "2", "@": return 0x13
        case "3", "#": return 0x14
        case "4", "$": return 0x15
        case "5", "%": return 0x17
        case "6", "^": return 0x16
        case "7", "&": return 0x1A
        case "8", "*": return 0x1C
        case "9", "(": return 0x19
            
        // Punctuation
        case "-", "_": return 0x1B
        case "=", "+": return 0x18
        case "[", "{": return 0x21
        case "]", "}": return 0x1E
        case ";", ":": return 0x29
        case "'", "\"": return 0x27
        case ",", "<": return 0x2B
        case ".", ">": return 0x2F
        case "/", "?": return 0x2C
        case "`", "~": return 0x32
        case "\\", "|": return 0x2A
            
        // Special
        case " ": return 0x31 // Space
        case "\t": return 0x30 // Tab
        case "\n": return 0x24 // Return
            
        default: return nil
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
        case "A"..."Z": return true
        case "!", "@", "#", "$", "%", "^", "&", "*", "(", ")": return true
        case "_", "+", "{", "}", ":", "\"", "<", ">", "?", "~", "|": return true
        default: return false
        }
    }
}