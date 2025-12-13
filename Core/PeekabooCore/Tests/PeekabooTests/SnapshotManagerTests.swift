import Foundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@Suite("SnapshotManager Tests")
@MainActor
struct SnapshotManagerTests {
    let snapshotManager = SnapshotManager()

    @Test("Create and retrieve snapshot")
    func createAndRetrieveSnapshot() async throws {
        // Create a snapshot
        let snapshotId = try await snapshotManager.createSnapshot()
        #expect(!snapshotId.isEmpty)
        #expect(snapshotId.contains("-")) // Should have timestamp-suffix format

        // Verify it shows up in the list
        let snapshots = try await snapshotManager.listSnapshots()
        #expect(snapshots.contains { $0.id == snapshotId })

        // Clean up
        try await self.snapshotManager.cleanSnapshot(snapshotId: snapshotId)
    }

    @Test("Store and retrieve detection result")
    func storeAndRetrieveDetectionResult() async throws {
        // Create a snapshot
        let snapshotId = try await snapshotManager.createSnapshot()

        // Create a mock detection result
        let element = DetectedElement(
            id: "B1",
            type: .button,
            label: "Test Button",
            bounds: CGRect(x: 100, y: 100, width: 100, height: 50))

        let elements = DetectedElements(buttons: [element])
        let metadata = DetectionMetadata(
            detectionTime: 0.5,
            elementCount: 1,
            method: "test")

        let result = ElementDetectionResult(
            snapshotId: snapshotId,
            screenshotPath: "/tmp/test.png",
            elements: elements,
            metadata: metadata)

        // Store the result
        try await snapshotManager.storeDetectionResult(snapshotId: snapshotId, result: result)

        // Retrieve it
        let retrieved = try await snapshotManager.getDetectionResult(snapshotId: snapshotId)
        #expect(retrieved != nil)
        #expect(retrieved?.elements.buttons.count == 1)
        #expect(retrieved?.elements.buttons.first?.id == "B1")
        #expect(retrieved?.elements.buttons.first?.label == "Test Button")

        // Clean up
        try await self.snapshotManager.cleanSnapshot(snapshotId: snapshotId)
    }

    @Test("Find elements by query")
    func findElementsByQuery() async throws {
        // Create a snapshot
        let snapshotId = try await snapshotManager.createSnapshot()

        // Create mock detection elements
        let element1 = DetectedElement(
            id: "B1",
            type: .button,
            label: "Save Document",
            bounds: CGRect(x: 100, y: 100, width: 100, height: 50))

        let element2 = DetectedElement(
            id: "B2",
            type: .button,
            label: "Cancel Operation",
            bounds: CGRect(x: 210, y: 100, width: 100, height: 50))

        let elements = DetectedElements(buttons: [element1, element2])
        let metadata = DetectionMetadata(
            detectionTime: 0.5,
            elementCount: 2,
            method: "test")

        let result = ElementDetectionResult(
            snapshotId: snapshotId,
            screenshotPath: "/tmp/test.png",
            elements: elements,
            metadata: metadata)

        // Store the detection result which will create the UI map
        try await snapshotManager.storeDetectionResult(snapshotId: snapshotId, result: result)

        // Now find elements by query
        let foundElements = try await snapshotManager.findElements(snapshotId: snapshotId, matching: "save")
        #expect(foundElements.count == 1)
        #expect(foundElements.first?.label?.lowercased().contains("save") == true)

        // Find by partial match
        let cancelElements = try await snapshotManager.findElements(snapshotId: snapshotId, matching: "cancel")
        #expect(cancelElements.count == 1)
        #expect(cancelElements.first?.label?.lowercased().contains("cancel") == true)

        // Clean up
        try await self.snapshotManager.cleanSnapshot(snapshotId: snapshotId)
    }

    @Test("Get most recent snapshot")
    func testGetMostRecentSnapshot() async throws {
        // Create two snapshots with a delay
        let snapshot1 = try await snapshotManager.createSnapshot()
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        let snapshot2 = try await snapshotManager.createSnapshot()

        // The most recent should be snapshot2
        let mostRecent = await snapshotManager.getMostRecentSnapshot()
        #expect(mostRecent == snapshot2)

        // Clean up
        try await self.snapshotManager.cleanSnapshot(snapshotId: snapshot1)
        try await self.snapshotManager.cleanSnapshot(snapshotId: snapshot2)
    }

    @Test("Snapshot cleanup")
    func snapshotCleanup() async throws {
        // Create multiple snapshots
        let snapshot1 = try await snapshotManager.createSnapshot()
        let snapshot2 = try await snapshotManager.createSnapshot()
        let snapshot3 = try await snapshotManager.createSnapshot()

        // Clean all snapshots
        let cleanedCount = try await snapshotManager.cleanAllSnapshots()
        #expect(cleanedCount >= 3)

        // Verify they're gone
        let snapshots = try await snapshotManager.listSnapshots()
        #expect(!snapshots.contains { $0.id == snapshot1 })
        #expect(!snapshots.contains { $0.id == snapshot2 })
        #expect(!snapshots.contains { $0.id == snapshot3 })
    }
}
