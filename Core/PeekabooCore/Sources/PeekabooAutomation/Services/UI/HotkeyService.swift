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

        let holdSeconds = TimeInterval(max(0, holdDuration)) / 1000.0
        try InputDriver.hotkey(keys: parsed, holdDuration: holdSeconds)

        // Small post-delay for consistency with previous behavior
        if holdDuration <= 0 {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        self.logger.debug("Hotkey completed")
    }
}
