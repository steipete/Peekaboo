import CoreGraphics
import Foundation
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
    func `Allows tiny window size jitter`() {
        let snapshot = UIAutomationSnapshot(
            windowBounds: CGRect(x: 100, y: 100, width: 200, height: 200),
            windowID: 98)

        let tracker = StubWindowTracker(bounds: CGRect(x: 110, y: 120, width: 203, height: 204))
        WindowMovementTracking.provider = tracker
        defer { WindowMovementTracking.provider = nil }

        let result = WindowMovementTracking.adjustPoint(CGPoint(x: 150, y: 150), snapshot: snapshot)
        switch result {
        case let .adjusted(point, delta):
            #expect(delta == CGPoint(x: 10, y: 20))
            #expect(point == CGPoint(x: 160, y: 170))
        default:
            Issue.record("Expected adjusted point for tiny size jitter, got \(result)")
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

    @Test
    @MainActor
    func `Adjusts points by snapshot id using snapshot manager`() async throws {
        let snapshot = UIAutomationSnapshot(
            windowBounds: CGRect(x: 10, y: 20, width: 200, height: 200),
            windowID: 101)
        let snapshots = PointSnapshotManager(snapshot: snapshot)

        let tracker = StubWindowTracker(bounds: CGRect(x: 15, y: 35, width: 200, height: 200))
        WindowMovementTracking.provider = tracker
        defer { WindowMovementTracking.provider = nil }

        let adjusted = try await WindowMovementTracking.adjustPoint(
            CGPoint(x: 50, y: 60),
            snapshotId: "snapshot-id",
            snapshots: snapshots)

        #expect(adjusted == CGPoint(x: 55, y: 75))
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

@MainActor
private final class PointSnapshotManager: SnapshotManagerProtocol {
    private let snapshot: UIAutomationSnapshot

    init(snapshot: UIAutomationSnapshot) {
        self.snapshot = snapshot
    }

    func createSnapshot() async throws -> String {
        "snapshot-id"
    }

    func storeDetectionResult(snapshotId _: String, result _: ElementDetectionResult) async throws {}

    func getDetectionResult(snapshotId _: String) async throws -> ElementDetectionResult? {
        nil
    }

    func getMostRecentSnapshot() async -> String? {
        "snapshot-id"
    }

    func getMostRecentSnapshot(applicationBundleId _: String) async -> String? {
        "snapshot-id"
    }

    func listSnapshots() async throws -> [SnapshotInfo] {
        []
    }

    func cleanSnapshot(snapshotId _: String) async throws {}

    func cleanSnapshotsOlderThan(days _: Int) async throws -> Int {
        0
    }

    func cleanAllSnapshots() async throws -> Int {
        0
    }

    func getSnapshotStoragePath() -> String {
        "memory"
    }

    func storeScreenshot(_: SnapshotScreenshotRequest) async throws {}

    func storeAnnotatedScreenshot(snapshotId _: String, annotatedScreenshotPath _: String) async throws {}

    func getElement(snapshotId _: String, elementId _: String) async throws -> UIElement? {
        nil
    }

    func findElements(snapshotId _: String, matching _: String) async throws -> [UIElement] {
        []
    }

    func getUIAutomationSnapshot(snapshotId _: String) async throws -> UIAutomationSnapshot? {
        self.snapshot
    }
}
