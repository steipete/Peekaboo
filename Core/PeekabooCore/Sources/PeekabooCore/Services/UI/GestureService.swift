import AppKit
import CoreGraphics
import Foundation
import os.log
import PeekabooFoundation

/// Service for handling gesture operations (swipe, drag, mouse movement)
@MainActor
public final class GestureService {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "GestureService")

    public init() {}

    /// Perform a swipe gesture
    public func swipe(from: CGPoint, to: CGPoint, duration: Int, steps: Int) async throws {
        let gestureDescription = self.describeGesture(
            name: "Swipe requested",
            details: [
                "from: (\(from.x), \(from.y))",
                "to: (\(to.x), \(to.y))",
                "duration: \(duration)ms",
                "steps: \(steps)",
            ])
        self.logger.debug("\(gestureDescription)")

        try self.ensurePositiveSteps(steps, action: "Swipe")

        let context = GesturePathContext(start: from, end: to, steps: steps)
        let stepDelayNanos = self.stepDelay(duration: duration, steps: steps)
        try await self.performSwipe(context: context, stepDelayNanos: stepDelayNanos)

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
        // Perform a drag operation with optional modifiers
        let gestureDescription = self.describeGesture(
            name: "Drag requested",
            details: [
                "from: (\(from.x), \(from.y))",
                "to: (\(to.x), \(to.y))",
                "duration: \(duration)ms",
                "modifiers: \(modifiers ?? "none")",
            ])
        self.logger.debug("\(gestureDescription)")

        try self.ensurePositiveSteps(steps, action: "Drag")

        let eventFlags = self.parseModifierKeys(modifiers)
        let stepDelayNanos = self.stepDelay(duration: duration, steps: steps)
        try await self.executeDrag(
            from: from,
            to: to,
            steps: steps,
            eventFlags: eventFlags,
            stepDelayNanos: stepDelayNanos)

        self.logger.debug("Drag completed")
    }

    /// Move mouse to a specific point
    public func moveMouse(to: CGPoint, duration: Int, steps: Int) async throws {
        // Move mouse to a specific point
        let gestureDescription = self.describeGesture(
            name: "Mouse move requested",
            details: [
                "to: (\(to.x), \(to.y))",
                "duration: \(duration)ms",
                "steps: \(steps)",
            ])
        self.logger.debug("\(gestureDescription)")

        try self.ensurePositiveSteps(steps, action: "Mouse move")

        // Get current mouse location
        let currentLocation = self.getCurrentMouseLocation()
        let deltaX = to.x - currentLocation.x
        let deltaY = to.y - currentLocation.y
        let stepDelayNanos = self.stepDelay(duration: duration, steps: steps)

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
        let event = try self.makeMouseEvent(type: .mouseMoved, position: point)
        event.post(tap: .cghidEventTap)

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

    private func describeGesture(name: String, details: [String]) -> String {
        ([name] + details).joined(separator: " | ")
    }

    private func ensurePositiveSteps(_ steps: Int, action: String) throws {
        guard steps > 0 else {
            throw PeekabooError.invalidInput("\(action) requires at least one step")
        }
    }

    private func stepDelay(duration: Int, steps: Int) -> UInt64 {
        guard duration > 0, steps > 0 else { return 0 }
        let secondsPerStep = Double(duration) / 1000.0 / Double(steps)
        return UInt64(secondsPerStep * 1_000_000_000)
    }

    private func performSwipe(context: GesturePathContext, stepDelayNanos: UInt64) async throws {
        try await self.moveMouseToPoint(context.start)
        try self.postMouseEvent(type: .leftMouseDown, at: context.start)

        for index in 1...context.steps {
            try self.postMouseEvent(type: .leftMouseDragged, at: context.point(at: index))
            try await self.sleepIfNeeded(stepDelayNanos)
        }

        try self.postMouseEvent(type: .leftMouseUp, at: context.end)
    }

    private func executeDrag(
        from: CGPoint,
        to: CGPoint,
        steps: Int,
        eventFlags: CGEventFlags,
        stepDelayNanos: UInt64) async throws
    {
        try await self.moveMouseToPoint(from)
        try self.postMouseEvent(type: .leftMouseDown, at: from, flags: eventFlags)

        let context = GesturePathContext(start: from, end: to, steps: steps)
        for index in 1...context.steps {
            try self.postMouseEvent(type: .leftMouseDragged, at: context.point(at: index), flags: eventFlags)
            try await self.sleepIfNeeded(stepDelayNanos)
        }

        try self.postMouseEvent(type: .leftMouseUp, at: to, flags: eventFlags)
    }

    private func postMouseEvent(
        type: CGEventType,
        at point: CGPoint,
        button: CGMouseButton = .left,
        flags: CGEventFlags = []) throws
    {
        let event = try self.makeMouseEvent(type: type, position: point, button: button, flags: flags)
        event.post(tap: .cghidEventTap)
    }

    private func makeMouseEvent(
        type: CGEventType,
        position: CGPoint,
        button: CGMouseButton = .left,
        flags: CGEventFlags = []) throws -> CGEvent
    {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: position,
            mouseButton: button)
        else {
            throw PeekabooError.operationError(message: "Failed to create event")
        }

        event.flags = flags
        return event
    }

    private func sleepIfNeeded(_ delay: UInt64) async throws {
        guard delay > 0 else { return }
        try await Task.sleep(nanoseconds: delay)
    }
}

private struct GesturePathContext {
    let start: CGPoint
    let end: CGPoint
    let steps: Int

    init(start: CGPoint, end: CGPoint, steps: Int) {
        self.start = start
        self.end = end
        self.steps = steps
    }

    var deltaX: CGFloat {
        (self.end.x - self.start.x) / CGFloat(self.steps)
    }

    var deltaY: CGFloat {
        (self.end.y - self.start.y) / CGFloat(self.steps)
    }

    func point(at index: Int) -> CGPoint {
        CGPoint(
            x: self.start.x + (self.deltaX * CGFloat(index)),
            y: self.start.y + (self.deltaY * CGFloat(index)))
    }
}
