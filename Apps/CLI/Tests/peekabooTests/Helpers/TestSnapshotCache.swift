import Foundation
import PeekabooAutomationKit
import PeekabooCore

/// Test-only snapshot cache helper for UI automation snapshots.
///
/// Prefer using `TestServicesFactory.makeAutomationTestContext()` for most unit tests.
final class SnapshotCache {
    let snapshotId: String
    private let snapshotManager: SnapshotManager

    typealias UIAutomationSnapshot = PeekabooAutomationKit.UIAutomationSnapshot
    typealias UIElement = PeekabooCore.UIElement

    private init(snapshotId: String, snapshotManager: SnapshotManager) {
        self.snapshotId = snapshotId
        self.snapshotManager = snapshotManager
    }

    static func create() async throws -> SnapshotCache {
        let snapshotManager = SnapshotManager()
        let snapshotId = try await snapshotManager.createSnapshot()
        return SnapshotCache(snapshotId: snapshotId, snapshotManager: snapshotManager)
    }

    func save(_ data: UIAutomationSnapshot) async throws {
        if let screenshotPath = data.screenshotPath {
            try await self.snapshotManager.storeScreenshot(
                snapshotId: self.snapshotId,
                screenshotPath: screenshotPath,
                applicationBundleId: data.applicationBundleId,
                applicationProcessId: data.applicationProcessId,
                applicationName: data.applicationName,
                windowTitle: data.windowTitle,
                windowBounds: data.windowBounds
            )
        }
    }

    func load() async throws -> UIAutomationSnapshot? {
        try await self.snapshotManager.getUIAutomationSnapshot(snapshotId: self.snapshotId)
    }

    func clear() async throws {
        try await self.snapshotManager.cleanSnapshot(snapshotId: self.snapshotId)
    }

    func getSnapshotPaths() -> (map: String) {
        let baseDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".peekaboo/snapshots/\(self.snapshotId)")

        return (
            map: baseDir.appendingPathComponent("snapshot.json").path
        )
    }
}
