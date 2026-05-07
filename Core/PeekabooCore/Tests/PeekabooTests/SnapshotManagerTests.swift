import CoreGraphics
import Foundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@MainActor
struct SnapshotManagerTests {
    let snapshotManager = SnapshotManager()

    @Test
    func `Create and retrieve snapshot`() async throws {
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

    @Test
    func `Store and retrieve detection result`() async throws {
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

    @Test
    func `Store detection result preserves typed window context`() async throws {
        let snapshotId = try await snapshotManager.createSnapshot()
        let windowBounds = CGRect(x: 10, y: 20, width: 300, height: 200)
        let metadata = DetectionMetadata(
            detectionTime: 0.1,
            elementCount: 0,
            method: "test",
            windowContext: WindowContext(
                applicationName: "TextEdit",
                applicationBundleId: "com.apple.TextEdit",
                applicationProcessId: 1234,
                windowTitle: "Notes",
                windowID: 777,
                windowBounds: windowBounds))
        let result = ElementDetectionResult(
            snapshotId: snapshotId,
            screenshotPath: "/tmp/test.png",
            elements: DetectedElements(),
            metadata: metadata)

        try await snapshotManager.storeDetectionResult(snapshotId: snapshotId, result: result)

        let snapshot = try await snapshotManager.getUIAutomationSnapshot(snapshotId: snapshotId)
        #expect(snapshot?.applicationName == "TextEdit")
        #expect(snapshot?.applicationBundleId == "com.apple.TextEdit")
        #expect(snapshot?.applicationProcessId == 1234)
        #expect(snapshot?.windowTitle == "Notes")
        #expect(snapshot?.windowID == CGWindowID(777))
        #expect(snapshot?.windowBounds == windowBounds)

        try await self.snapshotManager.cleanSnapshot(snapshotId: snapshotId)
    }

    @Test
    func `In-memory snapshot manager preserves typed window context`() async throws {
        let manager = InMemorySnapshotManager()
        let snapshotId = try await manager.createSnapshot()
        let windowBounds = CGRect(x: 30, y: 40, width: 500, height: 400)
        let metadata = DetectionMetadata(
            detectionTime: 0.1,
            elementCount: 0,
            method: "test",
            windowContext: WindowContext(
                applicationName: "Safari",
                applicationBundleId: "com.apple.Safari",
                applicationProcessId: 4321,
                windowTitle: "Example",
                windowID: 888,
                windowBounds: windowBounds))
        let result = ElementDetectionResult(
            snapshotId: snapshotId,
            screenshotPath: "/tmp/test.png",
            elements: DetectedElements(),
            metadata: metadata)

        try await manager.storeDetectionResult(snapshotId: snapshotId, result: result)

        let snapshot = try await manager.getUIAutomationSnapshot(snapshotId: snapshotId)
        #expect(snapshot?.applicationName == "Safari")
        #expect(snapshot?.applicationBundleId == "com.apple.Safari")
        #expect(snapshot?.applicationProcessId == 4321)
        #expect(snapshot?.windowTitle == "Example")
        #expect(snapshot?.windowID == CGWindowID(888))
        #expect(snapshot?.windowBounds == windowBounds)
    }

    @Test
    func `Find elements by query`() async throws {
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

    @Test
    func `Get most recent snapshot`() async throws {
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

    @Test
    func `Snapshot cleanup`() async throws {
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
