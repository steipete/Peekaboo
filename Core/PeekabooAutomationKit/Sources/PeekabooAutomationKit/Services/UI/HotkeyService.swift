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
