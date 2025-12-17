import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite("Snapshot Not Found Regression Tests", .tags(.safe, .regression))
struct SnapshotNotFoundRegressionTests {
    @Test("click --snapshot errors when snapshot was cleaned")
    func clickSnapshotNotFound() async throws {
        let context = await MainActor.run { TestServicesFactory.makeAutomationTestContext() }

        let snapshotId = try await self.makeSnapshot(with: context.snapshots)
        try await context.snapshots.cleanSnapshot(snapshotId: snapshotId)

        let result = try await InProcessCommandRunner.run(
            ["click", "Single Click", "--snapshot", snapshotId, "--json", "--no-auto-focus"],
            services: context.services
        )

        #expect(result.exitStatus != 0)
        let response = try ExternalCommandRunner.decodeJSONResponse(from: result, as: JSONResponse.self)
        #expect(response.success == false)
        #expect(response.error?.code == ErrorCode.SNAPSHOT_NOT_FOUND.rawValue)
    }

    @Test("move --id --snapshot errors when snapshot was cleaned")
    func moveSnapshotNotFound() async throws {
        let context = await MainActor.run { TestServicesFactory.makeAutomationTestContext() }

        let snapshotId = try await self.makeSnapshot(with: context.snapshots)
        try await context.snapshots.cleanSnapshot(snapshotId: snapshotId)

        let result = try await InProcessCommandRunner.run(
            ["move", "--id", "B1", "--snapshot", snapshotId, "--json"],
            services: context.services
        )

        #expect(result.exitStatus != 0)
        let response = try ExternalCommandRunner.decodeJSONResponse(from: result, as: JSONResponse.self)
        #expect(response.success == false)
        #expect(response.error?.code == ErrorCode.SNAPSHOT_NOT_FOUND.rawValue)
    }

    @Test("scroll --on --snapshot errors when snapshot was cleaned")
    func scrollSnapshotNotFound() async throws {
        let context = await MainActor.run { TestServicesFactory.makeAutomationTestContext() }

        let snapshotId = try await self.makeSnapshot(with: context.snapshots)
        try await context.snapshots.cleanSnapshot(snapshotId: snapshotId)

        let result = try await InProcessCommandRunner.run(
            ["scroll", "--direction", "down", "--on", "B1", "--snapshot", snapshotId, "--json", "--no-auto-focus"],
            services: context.services
        )

        #expect(result.exitStatus != 0)
        let response = try ExternalCommandRunner.decodeJSONResponse(from: result, as: JSONResponse.self)
        #expect(response.success == false)
        #expect(response.error?.code == ErrorCode.SNAPSHOT_NOT_FOUND.rawValue)
    }

    private func makeSnapshot(with snapshots: StubSnapshotManager) async throws -> String {
        let snapshotId = try await snapshots.createSnapshot()

        let element = DetectedElement(
            id: "B1",
            type: .button,
            label: "Single Click",
            bounds: CGRect(x: 50, y: 70, width: 120, height: 40)
        )
        let detection = ElementDetectionResult(
            snapshotId: snapshotId,
            screenshotPath: "/tmp/screenshot.png",
            elements: DetectedElements(buttons: [element]),
            metadata: DetectionMetadata(detectionTime: 0, elementCount: 1, method: "stub")
        )
        try await snapshots.storeDetectionResult(snapshotId: snapshotId, result: detection)

        return snapshotId
    }
}
