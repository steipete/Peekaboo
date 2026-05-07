import Foundation
import Testing
@testable import PeekabooAutomationKit

@MainActor
struct InMemorySnapshotManagerTests {
    @Test
    func `createSnapshot prunes overflow immediately and deletes artifacts`() async throws {
        let artifact = try Self.createTemporaryArtifact(named: "overflow-prune.png")
        let manager = InMemorySnapshotManager(options: .init(maxSnapshots: 1, deleteArtifactsOnCleanup: true))

        let first = try await manager.createSnapshot()
        try await manager.storeScreenshot(Self.screenshotRequest(snapshotId: first, path: artifact.path))
        try await Task.sleep(nanoseconds: 1_000_000)

        let second = try await manager.createSnapshot()

        let snapshots = try await manager.listSnapshots()
        #expect(snapshots.map(\.id) == [second])
        #expect(!FileManager.default.fileExists(atPath: artifact.path))
    }

    @Test
    func `storeScreenshot prunes overflow immediately`() async throws {
        let manager = InMemorySnapshotManager(options: .init(maxSnapshots: 1))

        let first = try await manager.createSnapshot()
        try await Task.sleep(nanoseconds: 1_000_000)
        try await manager.storeScreenshot(Self.screenshotRequest(snapshotId: "external", path: "/tmp/external.png"))

        let snapshots = try await manager.listSnapshots()
        #expect(snapshots.map(\.id) == ["external"])
        #expect(snapshots.contains { $0.id == first } == false)
    }

    private static func screenshotRequest(snapshotId: String, path: String) -> SnapshotScreenshotRequest {
        SnapshotScreenshotRequest(
            snapshotId: snapshotId,
            screenshotPath: path,
            applicationBundleId: nil,
            applicationProcessId: nil,
            applicationName: nil,
            windowTitle: nil,
            windowBounds: nil)
    }

    private static func createTemporaryArtifact(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("peekaboo-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("artifact".utf8).write(to: url)
        return url
    }
}
