import AXorcist
import CoreGraphics
import Darwin
import Foundation
import os.log
import PeekabooFoundation

/// Service for handling keyboard shortcuts and hotkeys.
@MainActor
public final class HotkeyService {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "HotkeyService")
    private let postEventAccessEvaluator: @MainActor @Sendable () -> Bool
    private let eventPoster: @MainActor @Sendable (CGEvent, pid_t) -> Void

    public init(
        postEventAccessEvaluator: @escaping @MainActor @Sendable ()
            -> Bool = { CGPreflightPostEventAccess() },
        eventPoster: @escaping @MainActor @Sendable (CGEvent, pid_t) -> Void = { event, pid in
            event.postToPid(pid)
        })
    {
        self.postEventAccessEvaluator = postEventAccessEvaluator
        self.eventPoster = eventPoster
    }

    /// Press a hotkey combination.
    /// Keys are comma-separated (e.g. "cmd,shift,4" or "ctrl,alt,backspace").
    public func hotkey(keys: String, holdDuration: Int) async throws {
        self.logger.debug("Hotkey requested: '\(keys)', hold: \(holdDuration)ms")

        try InputDriver.hotkey(
            keys: self.parsedKeys(keys),
            holdDuration: TimeInterval(max(0, holdDuration)) / 1000)

        if holdDuration <= 0 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        self.logger.debug("Hotkey completed")
    }

    /// Press a hotkey combination by posting the key event to a specific process.
    ///
    /// This path avoids changing the frontmost application, but macOS delivers it differently
    /// from hardware keyboard input. Some apps only handle shortcuts for their key window and
    /// may ignore targeted events while in the background.
    public func hotkey(keys: String, holdDuration: Int, targetProcessIdentifier: pid_t) async throws {
        self.logger.debug(
            "Targeted hotkey requested: '\(keys)', hold: \(holdDuration)ms, pid: \(targetProcessIdentifier)")

        guard targetProcessIdentifier > 0 else {
            throw PeekabooError.invalidInput("Target process identifier must be greater than 0")
        }

        guard Self.isProcessAlive(targetProcessIdentifier) else {
            throw PeekabooError.invalidInput("Target process identifier is not running: \(targetProcessIdentifier)")
        }

        let plan = try self.makeHotkeyPlan(keys)
        let holdNanoseconds = try Self.holdNanoseconds(for: holdDuration)
        try await self.postHotkey(
            plan,
            holdNanoseconds: holdNanoseconds,
            targetProcessIdentifier: targetProcessIdentifier)

        if holdDuration <= 0 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        self.logger.debug("Targeted hotkey completed")
    }

    private func makeHotkeyPlan(_ keys: String) throws -> HotkeyPlan {
        try self.makeHotkeyPlan(self.parsedKeys(keys))
    }

    private func makeHotkeyPlan(_ keys: [String]) throws -> HotkeyPlan {
        try HotkeyChord(keys: keys).plan
    }

    private func parsedKeys(_ keys: String) throws -> [String] {
        let parsed = keys
            .split(separator: ",")
            .map { HotkeyKey.normalizedName(for: String($0)) }
            .filter { !$0.isEmpty }
        guard !parsed.isEmpty else { throw PeekabooError.invalidInput("Hotkey string is empty") }
        return parsed
    }

    private func postHotkey(_ plan: HotkeyPlan, holdNanoseconds: UInt64, targetProcessIdentifier: pid_t) async throws {
        guard self.postEventAccessEvaluator() else {
            throw PeekabooError.permissionDeniedEventSynthesizing
        }

        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: plan.keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: plan.keyCode, keyDown: false)
        else {
            throw PeekabooError.operationError(message: "Failed to create keyboard events")
        }

        keyDown.flags = plan.modifierFlags
        keyUp.flags = plan.modifierFlags

        self.eventPoster(keyDown, targetProcessIdentifier)
        var keyUpPosted = false
        defer {
            if !keyUpPosted {
                self.eventPoster(keyUp, targetProcessIdentifier)
            }
        }

        if holdNanoseconds > 0 {
            try await Task.sleep(nanoseconds: holdNanoseconds)
        }

        self.eventPoster(keyUp, targetProcessIdentifier)
        keyUpPosted = true
    }

    private static func holdNanoseconds(for holdDuration: Int) throws -> UInt64 {
        let holdMilliseconds = max(0, holdDuration)
        let (nanoseconds, overflow) = UInt64(holdMilliseconds).multipliedReportingOverflow(by: 1_000_000)
        if overflow {
            throw PeekabooError.invalidInput("Hold duration is too large")
        }

        return nanoseconds
    }

    private static func isProcessAlive(_ processIdentifier: pid_t) -> Bool {
        errno = 0
        if kill(processIdentifier, 0) == 0 {
            return true
        }

        return errno == EPERM
    }

    private struct HotkeyPlan: Equatable {
        let primaryKey: String
        let keyCode: CGKeyCode
        let modifierFlags: CGEventFlags
    }

    private struct HotkeyChord {
        let plan: HotkeyPlan

        init(keys: [String]) throws {
            var modifierFlags: CGEventFlags = []
            var primaryKey: HotkeyPrimaryKey?

            for rawKey in keys {
                let key = HotkeyKey.normalizedName(for: rawKey)
                if let modifierFlag = HotkeyKey.modifierFlag(for: key) {
                    modifierFlags.insert(modifierFlag)
                    continue
                }

                guard let resolvedKey = HotkeyPrimaryKey(key) else {
                    throw PeekabooError.invalidInput("Invalid hotkey: \(keys.joined(separator: "+"))")
                }

                if let existing = primaryKey {
                    throw PeekabooError.invalidInput("Invalid hotkey: \(existing.name)+\(resolvedKey.name)")
                }

                primaryKey = resolvedKey
            }

            guard let primaryKey else {
                throw PeekabooError.invalidInput("Invalid hotkey: \(keys.joined(separator: "+"))")
            }

            self.plan = HotkeyPlan(
                primaryKey: primaryKey.name,
                keyCode: primaryKey.keyCode,
                modifierFlags: modifierFlags)
        }
    }

    private enum HotkeyKey {
        static func normalizedName(for rawKey: String) -> String {
            let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return self.aliases[key] ?? key
        }

        static func modifierFlag(for key: String) -> CGEventFlags? {
            switch key {
            case "cmd":
                .maskCommand
            case "shift":
                .maskShift
            case "alt":
                .maskAlternate
            case "ctrl":
                .maskControl
            case "fn":
                .maskSecondaryFn
            default:
                nil
            }
        }

        private static let aliases: [String: String] = [
            "command": "cmd",
            "meta": "cmd",
            "win": "cmd",
            "windows": "cmd",
            "cmdorctrl": "cmd",
            "cmd+ctrl": "cmd",
            "control": "ctrl",
            "option": "alt",
            "opt": "alt",
            "function": "fn",
            "enter": "return",
            "esc": "escape",
            "backspace": "delete",
            "del": "delete",
            "spacebar": "space",
            "page_up": "pageup",
            "page_down": "pagedown",
            "forward_delete": "forwarddelete",
            "arrow_left": "left",
            "arrow_right": "right",
            "arrow_down": "down",
            "arrow_up": "up",
            "left_bracket": "leftbracket",
            "[": "leftbracket",
            "right_bracket": "rightbracket",
            "]": "rightbracket",
            "=": "equal",
            "-": "minus",
            "'": "quote",
            ";": "semicolon",
            "\\": "backslash",
            ",": "comma",
            "/": "slash",
            ".": "period",
            "`": "grave",
            "caps_lock": "capslock",
        ]
    }

    private struct HotkeyPrimaryKey {
        let name: String
        let keyCode: CGKeyCode

        init?(_ key: String) {
            guard let keyCode = Self.keyCodes[key] else {
                return nil
            }

            self.name = key
            self.keyCode = keyCode
        }

        private static let keyCodes: [String: CGKeyCode] = [
            "a": 0x00,
            "s": 0x01,
            "d": 0x02,
            "f": 0x03,
            "h": 0x04,
            "g": 0x05,
            "z": 0x06,
            "x": 0x07,
            "c": 0x08,
            "v": 0x09,
            "b": 0x0B,
            "q": 0x0C,
            "w": 0x0D,
            "e": 0x0E,
            "r": 0x0F,
            "y": 0x10,
            "t": 0x11,
            "1": 0x12,
            "2": 0x13,
            "3": 0x14,
            "4": 0x15,
            "6": 0x16,
            "5": 0x17,
            "equal": 0x18,
            "9": 0x19,
            "7": 0x1A,
            "minus": 0x1B,
            "8": 0x1C,
            "0": 0x1D,
            "rightbracket": 0x1E,
            "o": 0x1F,
            "u": 0x20,
            "leftbracket": 0x21,
            "i": 0x22,
            "p": 0x23,
            "return": 0x24,
            "l": 0x25,
            "j": 0x26,
            "quote": 0x27,
            "k": 0x28,
            "semicolon": 0x29,
            "backslash": 0x2A,
            "comma": 0x2B,
            "slash": 0x2C,
            "n": 0x2D,
            "m": 0x2E,
            "period": 0x2F,
            "tab": 0x30,
            "space": 0x31,
            "grave": 0x32,
            "delete": 0x33,
            "escape": 0x35,
            "capslock": 0x39,
            "clear": 0x47,
            "help": 0x72,
            "home": 0x73,
            "pageup": 0x74,
            "forwarddelete": 0x75,
            "end": 0x77,
            "pagedown": 0x79,
            "f1": 0x7A,
            "left": 0x7B,
            "right": 0x7C,
            "down": 0x7D,
            "up": 0x7E,
            "f2": 0x78,
            "f3": 0x63,
            "f4": 0x76,
            "f5": 0x60,
            "f6": 0x61,
            "f7": 0x62,
            "f8": 0x64,
            "f9": 0x65,
            "f10": 0x6D,
            "f11": 0x67,
            "f12": 0x6F,
        ]
    }
}

#if DEBUG
extension HotkeyService {
    public func normalizeKeysForTesting(_ raw: [String]) -> [String] {
        raw.map { HotkeyKey.normalizedName(for: $0) }
    }

    public func parsedKeysForTesting(_ raw: String) throws -> [String] {
        try self.parsedKeys(raw)
    }

    func targetedHotkeyPlanForTesting(_ raw: [String]) throws
    -> (primaryKey: String, keyCode: CGKeyCode, flags: CGEventFlags) {
        let plan = try self.makeHotkeyPlan(raw)
        return (plan.primaryKey, plan.keyCode, plan.modifierFlags)
    }

    static func holdNanosecondsForTesting(_ holdDuration: Int) throws -> UInt64 {
        try self.holdNanoseconds(for: holdDuration)
    }

    static func isProcessAliveForTesting(_ processIdentifier: pid_t) -> Bool {
        self.isProcessAlive(processIdentifier)
    }
}
#endif
