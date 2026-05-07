import CoreGraphics
import PeekabooAutomationKit
import Testing

@Suite(.tags(.safe))
struct WindowMovementTrackingTests {
    @Test
    @MainActor
    func `Adjusts points when window moves`() {
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

    @Test
    @MainActor
    func `Returns stale when window resizes`() {
        let snapshot = UIAutomationSnapshot(
            applicationName: "TextEdit",
            windowTitle: "Notes",
            windowBounds: CGRect(x: 0, y: 0, width: 200, height: 200),
            windowID: 99)

        let tracker = StubWindowTracker(bounds: CGRect(x: 0, y: 0, width: 300, height: 200))
        WindowMovementTracking.provider = tracker
        defer { WindowMovementTracking.provider = nil }

        let result = WindowMovementTracking.adjustPoint(CGPoint(x: 10, y: 10), snapshot: snapshot)
        switch result {
        case let .stale(message):
            #expect(message.contains("changed size"))
            #expect(message.contains("windowID: 99"))
            #expect(message.contains("app: TextEdit"))
            #expect(message.contains("title: Notes"))
            #expect(message.contains("Previous bounds:"))
            #expect(message.contains("current bounds:"))
        default:
            Issue.record("Expected stale result, got \(result)")
        }
    }

    @Test
    @MainActor
    func `Returns stale when tracked window disappears`() {
        let snapshot = UIAutomationSnapshot(
            applicationBundleId: "com.apple.TextEdit",
            windowTitle: "Notes",
            windowBounds: CGRect(x: 0, y: 0, width: 200, height: 200),
            windowID: 100)

        let tracker = StubWindowTracker(bounds: nil)
        WindowMovementTracking.provider = tracker
        defer { WindowMovementTracking.provider = nil }

        let result = WindowMovementTracking.adjustPoint(CGPoint(x: 10, y: 10), snapshot: snapshot)
        switch result {
        case let .stale(message):
            #expect(message.contains("no longer available"))
            #expect(message.contains("windowID: 100"))
            #expect(message.contains("bundle: com.apple.TextEdit"))
            #expect(message.contains("title: Notes"))
        default:
            Issue.record("Expected stale result, got \(result)")
        }
    }
}

@MainActor
private final class StubWindowTracker: WindowTrackingProviding {
    private let bounds: CGRect?

    init(bounds: CGRect?) {
        self.bounds = bounds
    }

    func windowBounds(for windowID: CGWindowID) -> CGRect? {
        guard windowID > 0 else { return nil }
        return self.bounds
    }
}
