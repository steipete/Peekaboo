@preconcurrency import AXorcist
import Foundation
import os.log
import PeekabooFoundation

/// Service for handling gesture operations (swipe, drag, mouse movement)
@MainActor
public final class GestureService {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "GestureService")

    public init() {}

    /// Perform a swipe gesture
    public func swipe(
        from: CGPoint,
        to: CGPoint,
        duration: Int,
        steps: Int,
        profile: MouseMovementProfile) async throws
    {
        let gestureDescription = self.describeGesture(
            name: "Swipe requested",
            details: [
                "from: (\(from.x), \(from.y))",
                "to: (\(to.x), \(to.y))",
                "duration: \(duration)ms",
                "steps: \(steps)",
                "profile: \(profile.logDescription)",
            ])
        self.logger.debug("\(gestureDescription)")

        try self.ensurePositiveSteps(steps, action: "Swipe")

        let path = self.buildGesturePath(
            from: from,
            to: to,
            duration: duration,
            steps: steps,
            profile: profile)
        try await self.performSwipe(path: path, start: from, button: .left)

        self.logger.debug("Swipe completed")
    }

    /// Perform a drag operation with optional modifiers
    public func drag(_ request: DragOperationRequest) async throws {
        // Perform a drag operation with optional modifiers
        let gestureDescription = self.describeGesture(
            name: "Drag requested",
            details: [
                "from: (\(request.from.x), \(request.from.y))",
                "to: (\(request.to.x), \(request.to.y))",
                "duration: \(request.duration)ms",
                "modifiers: \(request.modifiers ?? "none")",
                "profile: \(request.profile.logDescription)",
            ])
        self.logger.debug("\(gestureDescription)")

        try self.ensurePositiveSteps(request.steps, action: "Drag")

        let path = self.buildGesturePath(
            from: request.from,
            to: request.to,
            duration: request.duration,
            steps: request.steps,
            profile: request.profile)
        try await self.performDrag(path: path, start: request.from)

        self.logger.debug("Drag completed")
    }

    /// Move mouse to a specific point
    public func moveMouse(
        to: CGPoint,
        duration: Int,
        steps: Int,
        profile: MouseMovementProfile) async throws
    {
        let gestureDescription = self.describeGesture(
            name: "Mouse move requested",
            details: [
                "to: (\(to.x), \(to.y))",
                "duration: \(duration)ms",
                "steps: \(steps)",
                "profile: \(profile.logDescription)",
            ])
        self.logger.debug("\(gestureDescription)")

        try self.ensurePositiveSteps(steps, action: "Mouse move")

        let startPoint = self.getCurrentMouseLocation()
        let distance = hypot(to.x - startPoint.x, to.y - startPoint.y)

        switch profile {
        case .linear:
            let path = self.linearPath(from: startPoint, to: to, steps: steps)
            try await self.playPath(path, duration: duration)
        case let .human(configuration):
            let generator = HumanMousePathGenerator(
                start: startPoint,
                target: to,
                distance: distance,
                duration: duration,
                stepsHint: steps,
                configuration: configuration)
            let path = generator.generate()
            try await self.playPath(path.points, duration: path.duration)
        }

        self.logger.debug("Mouse move completed")
    }

    // MARK: - Private Methods

    private func getCurrentMouseLocation() -> CGPoint {
        // Prefer AXorcist InputDriver move-less lookup; default to .zero when unavailable
        InputDriver.currentLocation() ?? .zero
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

    private func performSwipe(
        path: HumanMousePath,
        start: CGPoint,
        button: MouseButton) async throws
    {
        let endPoint = path.points.last ?? start
        let steps = max(path.points.count, 2)
        let interStepDelay = Double(path.duration) / 1000.0 / Double(steps)
        try InputDriver.drag(from: start, to: endPoint, button: button, steps: steps, interStepDelay: interStepDelay)
    }

    private func performDrag(
        path: HumanMousePath,
        start: CGPoint) async throws
    {
        let endPoint = path.points.last ?? start
        let steps = max(path.points.count, 2)
        let delay = Double(path.duration) / 1000.0 / Double(steps)
        try InputDriver.drag(from: start, to: endPoint, button: .left, steps: steps, interStepDelay: delay)
    }

    private func playPath(_ points: [CGPoint], duration: Int) async throws {
        guard !points.isEmpty else { return }
        let delay = self.stepDelay(duration: duration, steps: points.count)
        for point in points {
            try InputDriver.move(to: point)
            if delay > 0 { try await Task.sleep(nanoseconds: delay) }
        }
    }
}
