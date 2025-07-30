import AppKit
import CoreGraphics
import Foundation
import os.log

/// Service for handling keyboard shortcuts and hotkeys
@MainActor
public final class HotkeyService {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "HotkeyService")

    public init() {}

    /// Press a hotkey combination
    public func hotkey(keys: String, holdDuration: Int) async throws {
        self.logger.debug("Hotkey requested: '\(keys)', hold: \(holdDuration)ms")

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

        self.logger.debug("Modifiers: \(modifierFlags.rawValue), Keys: \(regularKeys)")

        // Execute the hotkey
        if regularKeys.isEmpty {
            // Just modifiers
            try await self.pressModifiers(modifierFlags, holdDuration: holdDuration)
        } else if regularKeys.count == 1 {
            // Single key with modifiers
            let firstKey = regularKeys[0]
            let virtualKey = self.mapKeyToVirtualCode(firstKey)

            if virtualKey == 0xFFFF {
                throw PeekabooError.unknownKey(firstKey)
            }

            try await self.pressKeyWithModifiers(
                virtualKey: virtualKey,
                modifiers: modifierFlags,
                holdDuration: holdDuration)
        } else {
            // Multiple keys - press in sequence
            for key in regularKeys {
                let virtualKey = self.mapKeyToVirtualCode(key)

                if virtualKey == 0xFFFF {
                    throw PeekabooError.unknownKey(key)
                }

                try await self.pressKeyWithModifiers(
                    virtualKey: virtualKey,
                    modifiers: modifierFlags,
                    holdDuration: holdDuration)

                // Small delay between keys
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }

        self.logger.debug("Hotkey completed")
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
        holdDuration: Int) async throws
    {
        // Key down with modifiers
        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: virtualKey,
            keyDown: true)
        else {
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
            keyDown: false)
        else {
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
        case "a": 0x00
        case "s": 0x01
        case "d": 0x02
        case "f": 0x03
        case "h": 0x04
        case "g": 0x05
        case "z": 0x06
        case "x": 0x07
        case "c": 0x08
        case "v": 0x09
        case "b": 0x0B
        case "q": 0x0C
        case "w": 0x0D
        case "e": 0x0E
        case "r": 0x0F
        case "y": 0x10
        case "t": 0x11
        case "1", "!": 0x12
        case "2", "@": 0x13
        case "3", "#": 0x14
        case "4", "$": 0x15
        case "5", "%": 0x16
        case "6", "^": 0x17
        case "=", "+": 0x18
        case "9", "(": 0x19
        case "7", "&": 0x1A
        case "-", "_": 0x1B
        case "8", "*": 0x1C
        case "0", ")": 0x1D
        case "]", "}": 0x1E
        case "o": 0x1F
        case "u": 0x20
        case "[", "{": 0x21
        case "i": 0x22
        case "p": 0x23
        case "l": 0x25
        case "j": 0x26
        case "'", "\"": 0x27
        case "k": 0x28
        case ";", ":": 0x29
        case "\\", "|": 0x2A
        case ",", "<": 0x2B
        case "/", "?": 0x2C
        case "n": 0x2D
        case "m": 0x2E
        case ".", ">": 0x2F
        case "`", "~": 0x32
        // Special keys
        case "return", "enter": 0x24
        case "tab": 0x30
        case "space": 0x31
        case "delete", "backspace": 0x33
        case "escape", "esc": 0x35
        case "right", "rightarrow": 0x7C
        case "left", "leftarrow": 0x7B
        case "down", "downarrow": 0x7D
        case "up", "uparrow": 0x7E
        case "home": 0x73
        case "end": 0x77
        case "pageup": 0x74
        case "pagedown": 0x79
        // Function keys
        case "f1": 0x7A
        case "f2": 0x78
        case "f3": 0x63
        case "f4": 0x76
        case "f5": 0x60
        case "f6": 0x61
        case "f7": 0x62
        case "f8": 0x64
        case "f9": 0x65
        case "f10": 0x6D
        case "f11": 0x67
        case "f12": 0x6F
        case "f13": 0x69
        case "f14": 0x6B
        case "f15": 0x71
        case "f16": 0x6A
        case "f17": 0x40
        case "f18": 0x4F
        case "f19": 0x50
        case "f20": 0x5A
        // Numeric keypad
        case "keypad0": 0x52
        case "keypad1": 0x53
        case "keypad2": 0x54
        case "keypad3": 0x55
        case "keypad4": 0x56
        case "keypad5": 0x57
        case "keypad6": 0x58
        case "keypad7": 0x59
        case "keypad8": 0x5B
        case "keypad9": 0x5C
        case "keypadplus": 0x45
        case "keypadminus": 0x4E
        case "keypadmultiply": 0x43
        case "keypaddivide": 0x4B
        case "keypadenter": 0x4C
        case "keypaddecimal": 0x41
        case "keypadequals": 0x51
        // Media keys
        case "volumeup": 0x48
        case "volumedown": 0x49
        case "mute": 0x4A
        default:
            0xFFFF // Invalid key
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
