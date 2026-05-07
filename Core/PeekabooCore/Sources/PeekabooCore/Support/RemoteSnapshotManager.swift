import CoreGraphics
import Foundation
import PeekabooAgentRuntime
import PeekabooAutomation
import PeekabooBridge
import PeekabooFoundation

@MainActor
public final class RemoteSnapshotManager: SnapshotManagerProtocol {
    private let client: PeekabooBridgeClient

    public init(client: PeekabooBridgeClient) {
        self.client = client
    }

    public func createSnapshot() async throws -> String {
        try await self.client.createSnapshot()
    }

    public func storeDetectionResult(snapshotId: String, result: ElementDetectionResult) async throws {
        try await self.client.storeDetectionResult(snapshotId: snapshotId, result: result)
    }

    public func getDetectionResult(snapshotId: String) async throws -> ElementDetectionResult? {
        do {
            return try await self.client.getDetectionResult(snapshotId: snapshotId)
        } catch let envelope as PeekabooBridgeErrorEnvelope where envelope.code == .notFound {
            return nil
        }
    }

    public func getMostRecentSnapshot() async -> String? {
        await (try? self.client.getMostRecentSnapshot())
    }

    public func getMostRecentSnapshot(applicationBundleId: String) async -> String? {
        await (try? self.client.getMostRecentSnapshot(applicationBundleId: applicationBundleId))
    }

    public func listSnapshots() async throws -> [SnapshotInfo] {
        try await self.client.listSnapshots()
    }

    public func cleanSnapshot(snapshotId: String) async throws {
        try await self.client.cleanSnapshot(snapshotId: snapshotId)
    }

    public func cleanSnapshotsOlderThan(days: Int) async throws -> Int {
        try await self.client.cleanSnapshotsOlderThan(days: days)
    }

    public func cleanAllSnapshots() async throws -> Int {
        try await self.client.cleanAllSnapshots()
    }

    public func getSnapshotStoragePath() -> String {
        // Remote side owns the storage; expose helper-visible path to callers when needed.
        SnapshotManager().getSnapshotStoragePath()
    }

    public func storeScreenshot(_ request: SnapshotScreenshotRequest) async throws {
        try await self.client.storeScreenshot(PeekabooBridgeStoreScreenshotRequest(request))
    }

    public func storeAnnotatedScreenshot(snapshotId: String, annotatedScreenshotPath: String) async throws {
        try await self.client.storeAnnotatedScreenshot(
            snapshotId: snapshotId,
            annotatedScreenshotPath: annotatedScreenshotPath)
    }

    public func getElement(snapshotId: String, elementId: String) async throws -> UIElement? {
        // Not exposed over XPC; rely on detection results.
        _ = snapshotId
        _ = elementId
        return nil
    }

    public func findElements(snapshotId: String, matching query: String) async throws -> [UIElement] {
        // Not exposed over XPC yet.
        _ = snapshotId
        _ = query
        return []
    }

    public func getUIAutomationSnapshot(snapshotId: String) async throws -> UIAutomationSnapshot? {
        // Not exposed over XPC; could be added later.
        _ = snapshotId
        return nil
    }
}
