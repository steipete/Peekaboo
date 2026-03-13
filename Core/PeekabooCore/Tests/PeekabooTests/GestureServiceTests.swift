import CoreGraphics
import Foundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@Suite(
    .tags(.ui, .automation, .requiresDisplay),
    .enabled(if: TestEnvironment.runInputAutomationScenarios))
@MainActor
struct GestureServiceTests {
    @Test
    func `Initialize GestureService`() {
        let service: GestureService? = GestureService()
        #expect(service != nil)
    }

    @Test
    func `Move mouse to position`() async throws {
        let service = GestureService()

        // Test moving mouse to various positions
        let positions = [
            CGPoint(x: 0, y: 0), // Top-left
            CGPoint(x: 100, y: 100),
            CGPoint(x: 500, y: 300),
            CGPoint(x: 1000, y: 600),
        ]

        for position in positions {
            try await service.moveMouse(to: position, duration: 100, steps: 10, profile: .linear)
        }
    }

    @Test
    func `Drag from point to point`() async throws {
        let service = GestureService()

        let start = CGPoint(x: 100, y: 100)
        let end = CGPoint(x: 500, y: 500)

        try await service.drag(
            from: start,
            to: end,
            duration: 500,
            steps: 20,
            modifiers: nil,
            profile: .linear)
    }

    @Test
    func `Drag with duration`() async throws {
        let service = GestureService()

        let start = CGPoint(x: 200, y: 200)
        let end = CGPoint(x: 600, y: 400)

        let startTime = Date()
        try await service.drag(
            from: start,
            to: end,
            duration: 1000,
            steps: 20,
            modifiers: nil,
            profile: .linear) // 1 second drag
        let elapsed = Date().timeIntervalSince(startTime)

        // Should take approximately 1 second
        #expect(elapsed >= 0.9 && elapsed <= 1.2)
    }

    @Test
    func `Swipe gestures`() async throws {
        let service = GestureService()

        let center = CGPoint(x: 500, y: 500)
        let distance: CGFloat = 100

        // Test swipes in all directions
        try await service.swipe(
            from: center,
            to: CGPoint(x: center.x - distance, y: center.y),
            duration: 200,
            steps: 10,
            profile: .linear) // Left
        try await service.swipe(
            from: center,
            to: CGPoint(x: center.x + distance, y: center.y),
            duration: 200,
            steps: 10,
            profile: .linear) // Right
        try await service.swipe(
            from: center,
            to: CGPoint(x: center.x, y: center.y - distance),
            duration: 200,
            steps: 10,
            profile: .linear) // Up
        try await service.swipe(
            from: center,
            to: CGPoint(x: center.x, y: center.y + distance),
            duration: 200,
            steps: 10,
            profile: .linear) // Down
    }

    @Test
    func `Swipe with custom distance`() async throws {
        let service = GestureService()

        let center = CGPoint(x: 500, y: 500)
        let distances: [CGFloat] = [50, 100, 200, 400]

        for distance in distances {
            let endPoint = CGPoint(x: center.x + distance, y: center.y)
            try await service.swipe(
                from: center,
                to: endPoint,
                duration: 200,
                steps: 10,
                profile: .linear)
        }
    }

    @Test
    func `Pinch gesture`() async throws {
        let service = GestureService()

        let center = CGPoint(x: 500, y: 500)

        // Simulate pinch gestures using two-finger swipes
        // Pinch in (zoom out)
        let finger1Start = CGPoint(x: center.x - 100, y: center.y)
        let finger1End = CGPoint(x: center.x - 50, y: center.y)
        let finger2Start = CGPoint(x: center.x + 100, y: center.y)
        let finger2End = CGPoint(x: center.x + 50, y: center.y)

        // Perform simultaneous swipes to simulate pinch
        try await service.swipe(from: finger1Start, to: finger1End, duration: 500, steps: 20, profile: .linear)
        try await service.swipe(from: finger2Start, to: finger2End, duration: 500, steps: 20, profile: .linear)
    }

    @Test
    func `Rotate gesture`() async throws {
        let service = GestureService()

        let center = CGPoint(x: 500, y: 500)

        // Simulate rotation using circular drag motion
        let radius: CGFloat = 100
        let steps = 20

        // Perform circular motion to simulate rotation
        let startAngle: CGFloat = 0
        let endAngle: CGFloat = .pi / 2 // 90 degrees

        let startPoint = CGPoint(
            x: center.x + radius * cos(startAngle),
            y: center.y + radius * sin(startAngle))
        let endPoint = CGPoint(
            x: center.x + radius * cos(endAngle),
            y: center.y + radius * sin(endAngle))

        try await service.drag(
            from: startPoint,
            to: endPoint,
            duration: 500,
            steps: steps,
            modifiers: nil,
            profile: .linear)
    }

    @Test
    func `Multi-touch tap`() async throws {
        let service = GestureService()

        let points = [
            CGPoint(x: 300, y: 300),
            CGPoint(x: 400, y: 300),
            CGPoint(x: 350, y: 400),
        ]

        // GestureService doesn't have multiTouchTap, simulate with quick moves
        for point in points {
            try await service.moveMouse(to: point, duration: 50, steps: 1, profile: .linear)
        }
    }

    @Test
    func `Long press`() async throws {
        let service = GestureService()

        let point = CGPoint(x: 500, y: 500)

        // Simulate long press with drag that doesn't move
        let startTime = Date()
        try await service.drag(from: point, to: point, duration: 1000, steps: 1, modifiers: nil, profile: .linear)
        let elapsed = Date().timeIntervalSince(startTime)

        // Should hold for approximately 1 second
        #expect(elapsed >= 0.9)
    }

    @Test
    func `Complex gesture sequence`() async throws {
        let service = GestureService()

        // Simulate a complex interaction sequence
        let startPoint = CGPoint(x: 100, y: 100)
        let midPoint = CGPoint(x: 300, y: 300)
        let endPoint = CGPoint(x: 500, y: 500)

        // Move to start
        try await service.moveMouse(to: startPoint, duration: 100, steps: 10, profile: .linear)

        // Drag to middle
        try await service.drag(
            from: startPoint,
            to: midPoint,
            duration: 500,
            steps: 20,
            modifiers: nil,
            profile: .linear)

        // Continue drag to end
        try await service.drag(
            from: midPoint,
            to: endPoint,
            duration: 500,
            steps: 20,
            modifiers: nil,
            profile: .linear)

        // Swipe back
        let swipeEnd = CGPoint(x: endPoint.x - 200, y: endPoint.y)
        try await service.swipe(from: endPoint, to: swipeEnd, duration: 200, steps: 10, profile: .linear)
    }

    @Test
    func `Hover gesture`() async throws {
        let service = GestureService()

        let hoverPoint = CGPoint(x: 400, y: 400)

        // Move to point to simulate hover
        try await service.moveMouse(to: hoverPoint, duration: 100, steps: 10, profile: .linear)
        // Stay at position for hover duration
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
}
