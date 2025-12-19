import CoreGraphics
import PeekabooAutomationKit
import Testing

@Suite("Window Movement Tracking", .tags(.safe))
struct WindowMovementTrackingTests {
    @Test("Adjusts points when window moves")
    @MainActor
    func adjustsPointWhenWindowMoves() {
        let snapshot = UIAutomationSnapshot(
            windowBounds: CGRect(x: 100, y: 100, width: 200, height: 200),
            windowID: 42)

        let tracker = StubWindowTracker(bounds: CGRect(x: 140, y: 150, width: 200, height: 200))
        WindowMovementTracking.provider = tracker
        defer { WindowMovementTracking.provider = nil }

        let original = CGPoint(x: 150, y: 150)
        let result = WindowMovementTracking.adjustPoint(original, snapshot: snapshot)

        switch result {
        case let .adjusted(point, delta):
            #expect(delta.x == 40)
            #expect(delta.y == 50)
            #expect(point == CGPoint(x: 190, y: 200))
        default:
            Issue.record("Expected adjusted point, got \(result)")
        }
    }

    @Test("Returns stale when window resizes")
    @MainActor
    func detectsResize() {
        let snapshot = UIAutomationSnapshot(
            windowBounds: CGRect(x: 0, y: 0, width: 200, height: 200),
            windowID: 99)

        let tracker = StubWindowTracker(bounds: CGRect(x: 0, y: 0, width: 300, height: 200))
        WindowMovementTracking.provider = tracker
        defer { WindowMovementTracking.provider = nil }

        let result = WindowMovementTracking.adjustPoint(CGPoint(x: 10, y: 10), snapshot: snapshot)
        switch result {
        case let .stale(message):
            #expect(message.contains("resized"))
        default:
            Issue.record("Expected stale result, got \(result)")
        }
    }
}

@MainActor
private final class StubWindowTracker: WindowTrackingProviding {
    private let bounds: CGRect

    init(bounds: CGRect) {
        self.bounds = bounds
    }

    func windowBounds(for windowID: CGWindowID) -> CGRect? {
        guard windowID > 0 else { return nil }
        return self.bounds
    }
}
