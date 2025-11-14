import AppKit
import CoreGraphics
import Foundation
import os.log
import PeekabooFoundation

/// Service for handling keyboard shortcuts and hotkeys
@MainActor
public final class HotkeyService {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "HotkeyService")

    public init() {}

    /// Press a hotkey combination
    public func hotkey(keys: String, holdDuration: Int) async throws {
        // Press a hotkey combination
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
        HotkeyKeyMapping.value(for: key)
    }
}

private enum HotkeyKeyMapping {
    private static let unknown: CGKeyCode = 0xFFFF

    private static let map: [String: CGKeyCode] = {
        var dictionary: [String: CGKeyCode] = [:]

        func register(_ code: CGKeyCode, keys: [String]) {
            for key in keys {
                dictionary[key] = code
            }
        }

        // Letters
        register(0x00, keys: ["a"])
        register(0x01, keys: ["s"])
        register(0x02, keys: ["d"])
        register(0x03, keys: ["f"])
        register(0x04, keys: ["h"])
        register(0x05, keys: ["g"])
        register(0x06, keys: ["z"])
        register(0x07, keys: ["x"])
        register(0x08, keys: ["c"])
        register(0x09, keys: ["v"])
        register(0x0B, keys: ["b"])
        register(0x0C, keys: ["q"])
        register(0x0D, keys: ["w"])
        register(0x0E, keys: ["e"])
        register(0x0F, keys: ["r"])
        register(0x10, keys: ["y"])
        register(0x11, keys: ["t"])
        register(0x12, keys: ["1", "!"])
        register(0x13, keys: ["2", "@"])
        register(0x14, keys: ["3", "#"])
        register(0x15, keys: ["4", "$"])
        register(0x16, keys: ["5", "%"])
        register(0x17, keys: ["6", "^"])
        register(0x18, keys: ["=", "+"])
        register(0x19, keys: ["9", "("])
        register(0x1A, keys: ["7", "&"])
        register(0x1B, keys: ["-", "_"])
        register(0x1C, keys: ["8", "*"])
        register(0x1D, keys: ["0", ")"])
        register(0x1E, keys: ["]", "}"])
        register(0x1F, keys: ["o"])
        register(0x20, keys: ["u"])
        register(0x21, keys: ["[", "{"])
        register(0x22, keys: ["i"])
        register(0x23, keys: ["p"])
        register(0x25, keys: ["l"])
        register(0x26, keys: ["j"])
        register(0x27, keys: ["'", "\""])
        register(0x28, keys: ["k"])
        register(0x29, keys: [";", ":"])
        register(0x2A, keys: ["\\", "|"])
        register(0x2B, keys: [",", "<"])
        register(0x2C, keys: ["/", "?"])
        register(0x2D, keys: ["n"])
        register(0x2E, keys: ["m"])
        register(0x2F, keys: [".", ">"])
        register(0x32, keys: ["`", "~"])

        // Special keys
        register(0x24, keys: ["return", "enter"])
        register(0x30, keys: ["tab"])
        register(0x31, keys: ["space"])
        register(0x33, keys: ["delete", "backspace"])
        register(0x35, keys: ["escape", "esc"])
        register(0x7C, keys: ["right", "rightarrow"])
        register(0x7B, keys: ["left", "leftarrow"])
        register(0x7D, keys: ["down", "downarrow"])
        register(0x7E, keys: ["up", "uparrow"])
        register(0x73, keys: ["home"])
        register(0x77, keys: ["end"])
        register(0x74, keys: ["pageup"])
        register(0x79, keys: ["pagedown"])

        // Function keys
        register(0x7A, keys: ["f1"])
        register(0x78, keys: ["f2"])
        register(0x63, keys: ["f3"])
        register(0x76, keys: ["f4"])
        register(0x60, keys: ["f5"])
        register(0x61, keys: ["f6"])
        register(0x62, keys: ["f7"])
        register(0x64, keys: ["f8"])
        register(0x65, keys: ["f9"])
        register(0x6D, keys: ["f10"])
        register(0x67, keys: ["f11"])
        register(0x6F, keys: ["f12"])
        register(0x69, keys: ["f13"])
        register(0x6B, keys: ["f14"])
        register(0x71, keys: ["f15"])
        register(0x6A, keys: ["f16"])
        register(0x40, keys: ["f17"])
        register(0x4F, keys: ["f18"])
        register(0x50, keys: ["f19"])
        register(0x5A, keys: ["f20"])

        // Numeric keypad
        register(0x52, keys: ["keypad0"])
        register(0x53, keys: ["keypad1"])
        register(0x54, keys: ["keypad2"])
        register(0x55, keys: ["keypad3"])
        register(0x56, keys: ["keypad4"])
        register(0x57, keys: ["keypad5"])
        register(0x58, keys: ["keypad6"])
        register(0x59, keys: ["keypad7"])
        register(0x5B, keys: ["keypad8"])
        register(0x5C, keys: ["keypad9"])
        register(0x45, keys: ["keypadplus"])
        register(0x4E, keys: ["keypadminus"])
        register(0x43, keys: ["keypadmultiply"])
        register(0x4B, keys: ["keypaddivide"])
        register(0x4C, keys: ["keypadenter"])
        register(0x41, keys: ["keypaddecimal"])
        register(0x51, keys: ["keypadequals"])

        // Media keys
        register(0x48, keys: ["volumeup"])
        register(0x49, keys: ["volumedown"])
        register(0x4A, keys: ["mute"])

        return dictionary
    }()

    static func value(for key: String) -> CGKeyCode {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return self.map[normalized] ?? Self.unknown
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
