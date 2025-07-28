import Foundation
import CoreGraphics
import AppKit
import os.log

/// Service for handling keyboard shortcuts and hotkeys
public final class HotkeyService: Sendable {
    
    private let logger = Logger(subsystem: "com.steipete.PeekabooCore", category: "HotkeyService")
    
    public init() {}
    
    /// Press a hotkey combination
    public func hotkey(keys: String, holdDuration: Int) async throws {
        logger.debug("Hotkey requested: '\(keys)', hold: \(holdDuration)ms")
        
        // Parse the key combination
        let keyArray = keys.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Separate modifiers and regular keys
        var modifierFlags = CGEventFlags()
        var regularKeys: [String] = []
        
        for key in keyArray {
            switch key.lowercased() {
            case "cmd", "command":
                modifierFlags.insert(.maskCommand)
            case "ctrl", "control":
                modifierFlags.insert(.maskControl)
            case "alt", "option":
                modifierFlags.insert(.maskAlternate)
            case "shift":
                modifierFlags.insert(.maskShift)
            case "fn", "function":
                modifierFlags.insert(.maskSecondaryFn)
            default:
                regularKeys.append(key)
            }
        }
        
        logger.debug("Modifiers: \(modifierFlags.rawValue), Keys: \(regularKeys)")
        
        // Execute the hotkey
        if regularKeys.isEmpty {
            // Just modifiers
            try await pressModifiers(modifierFlags, holdDuration: holdDuration)
        } else if regularKeys.count == 1 {
            // Single key with modifiers
            let firstKey = regularKeys[0]
            let virtualKey = mapKeyToVirtualCode(firstKey)
            
            if virtualKey == 0xFFFF {
                throw PeekabooError.unknownKey(firstKey)
            }
            
            try await pressKeyWithModifiers(
                virtualKey: virtualKey,
                modifiers: modifierFlags,
                holdDuration: holdDuration
            )
        } else {
            // Multiple keys - press in sequence
            for key in regularKeys {
                let virtualKey = mapKeyToVirtualCode(key)
                
                if virtualKey == 0xFFFF {
                    throw PeekabooError.unknownKey(key)
                }
                
                try await pressKeyWithModifiers(
                    virtualKey: virtualKey,
                    modifiers: modifierFlags,
                    holdDuration: holdDuration
                )
                
                // Small delay between keys
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
        
        logger.debug("Hotkey completed")
    }
    
    // MARK: - Private Methods
    
    private func pressModifiers(_ flags: CGEventFlags, holdDuration: Int) async throws {
        // Create a dummy event with modifiers
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0xFF, keyDown: true) else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        
        event.flags = flags
        event.post(tap: .cghidEventTap)
        
        // Hold
        if holdDuration > 0 {
            try await Task.sleep(nanoseconds: UInt64(holdDuration) * 1_000_000)
        }
        
        // Release
        guard let releaseEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0xFF, keyDown: false) else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        
        releaseEvent.flags = []
        releaseEvent.post(tap: .cghidEventTap)
    }
    
    private func pressKeyWithModifiers(
        virtualKey: CGKeyCode,
        modifiers: CGEventFlags,
        holdDuration: Int
    ) async throws {
        // Key down with modifiers
        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: virtualKey,
            keyDown: true
        ) else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        
        keyDownEvent.flags = modifiers
        keyDownEvent.post(tap: .cghidEventTap)
        
        // Hold if specified
        if holdDuration > 0 {
            try await Task.sleep(nanoseconds: UInt64(holdDuration) * 1_000_000)
        } else {
            // Default small hold
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Key up
        guard let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: virtualKey,
            keyDown: false
        ) else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        
        keyUpEvent.flags = modifiers
        keyUpEvent.post(tap: .cghidEventTap)
        
        // Small delay after release
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    }
    
    private func mapKeyToVirtualCode(_ key: String) -> CGKeyCode {
        switch key.lowercased() {
        // Letters
        case "a": return 0x00
        case "s": return 0x01
        case "d": return 0x02
        case "f": return 0x03
        case "h": return 0x04
        case "g": return 0x05
        case "z": return 0x06
        case "x": return 0x07
        case "c": return 0x08
        case "v": return 0x09
        case "b": return 0x0B
        case "q": return 0x0C
        case "w": return 0x0D
        case "e": return 0x0E
        case "r": return 0x0F
        case "y": return 0x10
        case "t": return 0x11
        case "1", "!": return 0x12
        case "2", "@": return 0x13
        case "3", "#": return 0x14
        case "4", "$": return 0x15
        case "5", "%": return 0x16
        case "6", "^": return 0x17
        case "=", "+": return 0x18
        case "9", "(": return 0x19
        case "7", "&": return 0x1A
        case "-", "_": return 0x1B
        case "8", "*": return 0x1C
        case "0", ")": return 0x1D
        case "]", "}": return 0x1E
        case "o": return 0x1F
        case "u": return 0x20
        case "[", "{": return 0x21
        case "i": return 0x22
        case "p": return 0x23
        case "l": return 0x25
        case "j": return 0x26
        case "'", "\"": return 0x27
        case "k": return 0x28
        case ";", ":": return 0x29
        case "\\", "|": return 0x2A
        case ",", "<": return 0x2B
        case "/", "?": return 0x2C
        case "n": return 0x2D
        case "m": return 0x2E
        case ".", ">": return 0x2F
        case "`", "~": return 0x32
        
        // Special keys
        case "return", "enter": return 0x24
        case "tab": return 0x30
        case "space": return 0x31
        case "delete", "backspace": return 0x33
        case "escape", "esc": return 0x35
        case "right", "rightarrow": return 0x7C
        case "left", "leftarrow": return 0x7B
        case "down", "downarrow": return 0x7D
        case "up", "uparrow": return 0x7E
        case "home": return 0x73
        case "end": return 0x77
        case "pageup": return 0x74
        case "pagedown": return 0x79
        
        // Function keys
        case "f1": return 0x7A
        case "f2": return 0x78
        case "f3": return 0x63
        case "f4": return 0x76
        case "f5": return 0x60
        case "f6": return 0x61
        case "f7": return 0x62
        case "f8": return 0x64
        case "f9": return 0x65
        case "f10": return 0x6D
        case "f11": return 0x67
        case "f12": return 0x6F
        case "f13": return 0x69
        case "f14": return 0x6B
        case "f15": return 0x71
        case "f16": return 0x6A
        case "f17": return 0x40
        case "f18": return 0x4F
        case "f19": return 0x50
        case "f20": return 0x5A
        
        // Numeric keypad
        case "keypad0": return 0x52
        case "keypad1": return 0x53
        case "keypad2": return 0x54
        case "keypad3": return 0x55
        case "keypad4": return 0x56
        case "keypad5": return 0x57
        case "keypad6": return 0x58
        case "keypad7": return 0x59
        case "keypad8": return 0x5B
        case "keypad9": return 0x5C
        case "keypadplus": return 0x45
        case "keypadminus": return 0x4E
        case "keypadmultiply": return 0x43
        case "keypaddivide": return 0x4B
        case "keypadenter": return 0x4C
        case "keypaddecimal": return 0x41
        case "keypadequals": return 0x51
        
        // Media keys
        case "volumeup": return 0x48
        case "volumedown": return 0x49
        case "mute": return 0x4A
        
        default:
            return 0xFFFF // Invalid key
        }
    }
}

// MARK: - Errors

extension PeekabooError {
    static func unknownKey(_ key: String) -> PeekabooError {
        PeekabooError.invalidInput("Unknown key: '\(key)'")
    }
    
    static func unknownSpecialKey(_ key: String) -> PeekabooError {
        PeekabooError.invalidInput("Unknown special key: '\(key)'")
    }
}