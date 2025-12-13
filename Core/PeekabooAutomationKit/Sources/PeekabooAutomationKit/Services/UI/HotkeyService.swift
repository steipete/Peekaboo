import AppKit
@preconcurrency import AXorcist
import CoreGraphics
import Foundation
import os.log
import PeekabooFoundation

/// Service for handling keyboard shortcuts and hotkeys (delegates to AXorcist InputDriver).
@MainActor
public final class HotkeyService {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "HotkeyService")

    public init() {}

    /// Press a hotkey combination.
    /// Keys are comma-separated (e.g. "cmd,shift,4" or "ctrl,alt,backspace").
    public func hotkey(keys: String, holdDuration: Int) async throws {
        self.logger.debug("Hotkey requested: '\(keys)', hold: \(holdDuration)ms")

        let parsed = keys.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard !parsed.isEmpty else { throw PeekabooError.invalidInput("Hotkey string is empty") }

        let normalized = self.normalizeKeys(parsed)

        let holdSeconds = TimeInterval(max(0, holdDuration)) / 1000.0
        try InputDriver.hotkey(keys: normalized, holdDuration: holdSeconds)

        // Small post-delay for consistency with previous behavior
        if holdDuration <= 0 {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        self.logger.debug("Hotkey completed")
    }

    private func normalizeKeys(_ raw: [String]) -> [String] {
        raw.map { key in
            let lower = key.lowercased()
            switch lower {
            case "command": return "cmd"
            case "control": return "ctrl"
            case "option": return "alt"
            case "opt": return "alt"
            case "meta", "win", "windows": return "cmd"
            case "cmdorctrl", "cmd+ctrl": return "cmd"
            case "return", "enter": return "return"
            case "esc": return "escape"
            case "backspace": return "delete"
            case "spacebar": return "space"
            case "del": return "delete"
            default: return lower
            }
        }
    }
}

#if DEBUG
extension HotkeyService {
    public func normalizeKeysForTesting(_ raw: [String]) -> [String] {
        self.normalizeKeys(raw)
    }
}
#endif
