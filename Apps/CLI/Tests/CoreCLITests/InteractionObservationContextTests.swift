import CoreGraphics
import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite(.tags(.safe))
@MainActor
struct InteractionObservationContextTests {
    @Test
    func `Explicit snapshot is trimmed and wins over latest`() async throws {
        let snapshots = CoreSnapshotManagerStub()
        let latest = try await snapshots.createSnapshot()

        let context = await InteractionObservationContext.resolve(
            explicitSnapshot: "  explicit-snapshot  ",
            fallbackToLatest: true,
            snapshots: snapshots
        )

        #expect(latest != "explicit-snapshot")
        #expect(context.explicitSnapshotId == "explicit-snapshot")
        #expect(context.snapshotId == "explicit-snapshot")
        #expect(context.source == .explicit)
    }

    @Test
    func `Latest snapshot is used only when requested`() async throws {
        let snapshots = CoreSnapshotManagerStub()
        let latest = try await snapshots.createSnapshot()

        let withoutFallback = await InteractionObservationContext.resolve(
            explicitSnapshot: nil,
            fallbackToLatest: false,
            snapshots: snapshots
        )
        let withFallback = await InteractionObservationContext.resolve(
            explicitSnapshot: nil,
            fallbackToLatest: true,
            snapshots: snapshots
        )

        #expect(withoutFallback.snapshotId == nil)
        #expect(withoutFallback.source == .none)
        #expect(withFallback.snapshotId == latest)
        #expect(withFallback.source == .latest)
    }

    @Test
    func `Focus snapshot is skipped for latest snapshot with explicit target`() async throws {
        let snapshots = CoreSnapshotManagerStub()
        let latest = try await snapshots.createSnapshot()
        var target = InteractionTargetOptions()
        target.app = "TextEdit"

        let latestContext = await InteractionObservationContext.resolve(
            explicitSnapshot: nil,
            fallbackToLatest: true,
            snapshots: snapshots
        )
        let explicitContext = await InteractionObservationContext.resolve(
            explicitSnapshot: "explicit",
            fallbackToLatest: true,
            snapshots: snapshots
        )

        #expect(latestContext.snapshotId == latest)
        #expect(latestContext.focusSnapshotId(for: target) == nil)
        #expect(explicitContext.focusSnapshotId(for: target) == "explicit")
    }

    @Test
    func `Latest snapshot invalidates after mutation`() async throws {
        let snapshots = CoreSnapshotManagerStub()
        let latest = try await snapshots.createSnapshot()

        let context = await InteractionObservationContext.resolve(
            explicitSnapshot: nil,
            fallbackToLatest: true,
            snapshots: snapshots
        )

        let invalidated = try await context.invalidateAfterMutation(using: snapshots)

        #expect(invalidated == latest)
        #expect(await snapshots.getMostRecentSnapshot() == nil)
        #expect(try await snapshots.listSnapshots().isEmpty)
    }

    @Test
    func `Explicit snapshot stays available after mutation`() async throws {
        let snapshots = CoreSnapshotManagerStub()
        let explicit = try await snapshots.createSnapshot(id: "explicit-snapshot")

        let context = await InteractionObservationContext.resolve(
            explicitSnapshot: "explicit-snapshot",
            fallbackToLatest: true,
            snapshots: snapshots
        )

        let invalidated = try await context.invalidateAfterMutation(using: snapshots)

        #expect(explicit == "explicit-snapshot")
        #expect(invalidated == nil)
        #expect(await snapshots.getMostRecentSnapshot() == "explicit-snapshot")
        #expect(try await snapshots.listSnapshots().map(\.id) == ["explicit-snapshot"])
    }

    @Test
    func `Latest snapshot can be invalidated after focus changes`() async throws {
        let snapshots = CoreSnapshotManagerStub()
        let latest = try await snapshots.createSnapshot()

        let invalidated = try await InteractionObservationContext.invalidateLatestSnapshot(using: snapshots)

        #expect(invalidated == latest)
        #expect(await snapshots.getMostRecentSnapshot() == nil)
        #expect(try await snapshots.listSnapshots().isEmpty)
    }

    @Test
    func `Latest snapshot invalidation is a no-op when none exists`() async throws {
        let snapshots = CoreSnapshotManagerStub()

        let invalidated = try await InteractionObservationContext.invalidateLatestSnapshot(using: snapshots)

        #expect(invalidated == nil)
    }

    @Test
    func `Mutation invalidation without observation drops latest snapshot`() async throws {
        let snapshots = CoreSnapshotManagerStub()
        let latest = try await snapshots.createSnapshot()
        let context = await InteractionObservationContext.resolve(
            explicitSnapshot: nil,
            fallbackToLatest: false,
            snapshots: snapshots
        )

        await InteractionObservationInvalidator.invalidateAfterMutationOrLatest(
            context,
            snapshots: snapshots,
            logger: Logger.shared,
            reason: "test mutation"
        )

        #expect(latest.isEmpty == false)
        #expect(await snapshots.getMostRecentSnapshot() == nil)
    }

    @Test
    func `Mutation invalidation preserves explicit snapshot`() async throws {
        let snapshots = CoreSnapshotManagerStub()
        let explicit = try await snapshots.createSnapshot(id: "explicit-snapshot")
        let context = await InteractionObservationContext.resolve(
            explicitSnapshot: "explicit-snapshot",
            fallbackToLatest: false,
            snapshots: snapshots
        )

        await InteractionObservationInvalidator.invalidateAfterMutationOrLatest(
            context,
            snapshots: snapshots,
            logger: Logger.shared,
            reason: "test mutation"
        )

        #expect(explicit == "explicit-snapshot")
        #expect(await snapshots.getMostRecentSnapshot() == "explicit-snapshot")
    }
}

private final class CoreSnapshotManagerStub: SnapshotManagerProtocol, @unchecked Sendable {
    private var snapshotInfos: [String: SnapshotInfo] = [:]
    private var detectionResults: [String: ElementDetectionResult] = [:]
    private var mostRecentSnapshotId: String?

    func createSnapshot() async throws -> String {
        try await self.createSnapshot(id: UUID().uuidString)
    }

    func createSnapshot(id snapshotId: String) async throws -> String {
        let now = Date()
        self.snapshotInfos[snapshotId] = SnapshotInfo(
            id: snapshotId,
            processId: 0,
            createdAt: now,
            lastAccessedAt: now,
            sizeInBytes: 0,
            screenshotCount: 0,
            isActive: true
        )
        self.mostRecentSnapshotId = snapshotId
        return snapshotId
    }

    func storeDetectionResult(snapshotId: String, result: ElementDetectionResult) async throws {
        self.detectionResults[snapshotId] = result
        self.mostRecentSnapshotId = snapshotId
    }

    func getDetectionResult(snapshotId: String) async throws -> ElementDetectionResult? {
        self.detectionResults[snapshotId]
    }

    func getMostRecentSnapshot() async -> String? {
        self.mostRecentSnapshotId
    }

    func getMostRecentSnapshot(applicationBundleId _: String) async -> String? {
        self.mostRecentSnapshotId
    }

    func listSnapshots() async throws -> [SnapshotInfo] {
        Array(self.snapshotInfos.values)
    }

    func cleanSnapshot(snapshotId: String) async throws {
        self.snapshotInfos.removeValue(forKey: snapshotId)
        self.detectionResults.removeValue(forKey: snapshotId)
        if self.mostRecentSnapshotId == snapshotId {
            self.mostRecentSnapshotId = nil
        }
    }

    func cleanSnapshotsOlderThan(days _: Int) async throws -> Int {
        0
    }

    func cleanAllSnapshots() async throws -> Int {
        let count = self.snapshotInfos.count
        self.snapshotInfos.removeAll()
        self.detectionResults.removeAll()
        self.mostRecentSnapshotId = nil
        return count
    }

    func getSnapshotStoragePath() -> String {
        "/tmp/peekaboo-snapshots"
    }

    func storeScreenshot(_: SnapshotScreenshotRequest) async throws {}

    func storeAnnotatedScreenshot(snapshotId _: String, annotatedScreenshotPath _: String) async throws {}

    func getElement(snapshotId _: String, elementId _: String) async throws -> PeekabooCore.UIElement? {
        nil
    }

    func findElements(snapshotId _: String, matching _: String) async throws -> [PeekabooCore.UIElement] {
        []
    }

    func getUIAutomationSnapshot(snapshotId _: String) async throws -> UIAutomationSnapshot? {
        nil
    }
}
