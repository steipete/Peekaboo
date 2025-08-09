import AppKit
import PeekabooFoundation
import CoreGraphics
import Foundation
import os.log

/// Service for handling gesture operations (swipe, drag, mouse movement)
@MainActor
public final class GestureService {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "GestureService")

    public init() {}

    /// Perform a swipe gesture
    public func swipe(from: CGPoint, to: CGPoint, duration: Int, steps: Int) async throws {
        self.logger
            .debug(
                "Swipe requested - from: (\(from.x), \(from.y)) to: (\(to.x), \(to.y)), duration: \(duration)ms, steps: \(steps)")

        guard steps > 0 else {
            throw PeekabooError.invalidInput("Steps must be greater than 0")
        }

        // Calculate increments
        let deltaX = (to.x - from.x) / CGFloat(steps)
        let deltaY = (to.y - from.y) / CGFloat(steps)
        let stepDuration = TimeInterval(duration) / TimeInterval(steps) / 1000.0

        // Move to start position
        try await self.moveMouseToPoint(from)

        // Mouse down at start
        guard let downEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: from,
            mouseButton: .left)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        downEvent.post(tap: .cghidEventTap)

        // Perform swipe motion
        for i in 1...steps {
            let currentPoint = CGPoint(
                x: from.x + (deltaX * CGFloat(i)),
                y: from.y + (deltaY * CGFloat(i)))

            guard let dragEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDragged,
                mouseCursorPosition: currentPoint,
                mouseButton: .left)
            else {
                throw PeekabooError.operationError(message: "Failed to create event")
            }

            dragEvent.post(tap: .cghidEventTap)

            // Delay between steps
            if stepDuration > 0 {
                try await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            }
        }

        // Mouse up at end
        guard let upEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: to,
            mouseButton: .left)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }
        upEvent.post(tap: .cghidEventTap)

        self.logger.debug("Swipe completed")
    }

    /// Perform a drag operation with optional modifiers
    public func drag(
        from: CGPoint,
        to: CGPoint,
        duration: Int,
        steps: Int,
        modifiers: String?) async throws
    {
        self.logger
            .debug(
                "Drag requested - from: (\(from.x), \(from.y)) to: (\(to.x), \(to.y)), duration: \(duration)ms, modifiers: \(modifiers ?? "none")")

        guard steps > 0 else {
            throw PeekabooError.invalidInput("Steps must be greater than 0")
        }

        // Parse modifier keys
        let eventFlags = self.parseModifierKeys(modifiers)

        // Calculate motion parameters
        let deltaX = to.x - from.x
        let deltaY = to.y - from.y
        let stepDuration = duration / steps
        let stepDelayNanos = UInt64(stepDuration) * 1_000_000

        // Move to start position
        try await moveMouseToPoint(from)
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Mouse down with modifiers
        guard let downEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: from,
            mouseButton: .left)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }

        downEvent.flags = eventFlags
        downEvent.post(tap: .cghidEventTap)

        // Perform drag motion
        for i in 1...steps {
            let progress = Double(i) / Double(steps)
            let currentX = from.x + (deltaX * progress)
            let currentY = from.y + (deltaY * progress)
            let currentPoint = CGPoint(x: currentX, y: currentY)

            guard let dragEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDragged,
                mouseCursorPosition: currentPoint,
                mouseButton: .left)
            else {
                throw PeekabooError.operationError(message: "Failed to create event")
            }

            dragEvent.flags = eventFlags
            dragEvent.post(tap: .cghidEventTap)

            if stepDelayNanos > 0 {
                try await Task.sleep(nanoseconds: stepDelayNanos)
            }
        }

        // Mouse up
        guard let upEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: to,
            mouseButton: .left)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }

        upEvent.flags = eventFlags
        upEvent.post(tap: .cghidEventTap)

        self.logger.debug("Drag completed")
    }

    /// Move mouse to a specific point
    public func moveMouse(to: CGPoint, duration: Int, steps: Int) async throws {
        self.logger.debug("Mouse move requested - to: (\(to.x), \(to.y)), duration: \(duration)ms, steps: \(steps)")

        guard steps > 0 else {
            throw PeekabooError.invalidInput("Steps must be greater than 0")
        }

        // Get current mouse location
        let currentLocation = self.getCurrentMouseLocation()
        let deltaX = to.x - currentLocation.x
        let deltaY = to.y - currentLocation.y
        let stepDuration = duration / steps
        let stepDelayNanos = UInt64(stepDuration) * 1_000_000

        // Perform smooth movement
        for i in 1...steps {
            let progress = Double(i) / Double(steps)
            let currentX = currentLocation.x + (deltaX * progress)
            let currentY = currentLocation.y + (deltaY * progress)
            let currentPoint = CGPoint(x: currentX, y: currentY)

            guard let moveEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: .mouseMoved,
                mouseCursorPosition: currentPoint,
                mouseButton: .left)
            else {
                throw PeekabooError.operationError(message: "Failed to create event")
            }

            moveEvent.post(tap: .cghidEventTap)

            if stepDelayNanos > 0 {
                try await Task.sleep(nanoseconds: stepDelayNanos)
            }
        }

        self.logger.debug("Mouse move completed")
    }

    // MARK: - Private Methods

    private func getCurrentMouseLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? CGPoint.zero
    }

    private func moveMouseToPoint(_ point: CGPoint) async throws {
        guard let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }

        moveEvent.post(tap: .cghidEventTap)

        // Small delay after move
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    }

    private func parseModifierKeys(_ modifierString: String?) -> CGEventFlags {
        guard let modString = modifierString else { return [] }

        var flags: CGEventFlags = []
        let modifiers = modString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        for modifier in modifiers {
            switch modifier {
            case "cmd", "command":
                flags.insert(.maskCommand)
            case "ctrl", "control":
                flags.insert(.maskControl)
            case "alt", "option":
                flags.insert(.maskAlternate)
            case "shift":
                flags.insert(.maskShift)
            case "fn", "function":
                flags.insert(.maskSecondaryFn)
            default:
                self.logger.warning("Unknown modifier: \(modifier)")
            }
        }

        return flags
    }
}
