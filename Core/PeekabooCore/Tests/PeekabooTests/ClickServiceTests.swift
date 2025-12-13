import CoreGraphics
import Foundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@Suite(
    "ClickService Tests",
    .tags(.ui, .automation),
    .enabled(if: TestEnvironment.runInputAutomationScenarios))
@MainActor
struct ClickServiceTests {
    @Suite("Initialization")
    @MainActor
    struct InitializationTests {
        @Test("ClickService initializes with snapshot manager dependency")
        func initializeService() async throws {
            let snapshotManager = MockSnapshotManager()
            let service: ClickService? = ClickService(snapshotManager: snapshotManager)
            #expect(service != nil)
        }
    }

    @Suite("Coordinate Clicking")
    @MainActor
    struct CoordinateClickingTests {
        @Test("Click performs at specified screen coordinates without errors")
        func clickAtCoordinates() async throws {
            let snapshotManager = MockSnapshotManager()
            let service = ClickService(snapshotManager: snapshotManager)

            let point = CGPoint(x: 100, y: 100)

            // This will attempt to click at the coordinates
            // In a test environment, we can't verify the actual click happened,
            // but we can verify no errors are thrown
            try await service.click(
                target: .coordinates(point),
                clickType: .single,
                snapshotId: nil)
        }
    }

    @Suite("Element Clicking")
    @MainActor
    struct ElementClickingTests {
        @Test("Click finds and clicks element by ID using snapshot detection results")
        func clickElementById() async throws {
            let snapshotManager = MockSnapshotManager()

            // Create mock detection result
            let mockElement = DetectedElement(
                id: "test-button",
                type: .button,
                label: "Test Button",
                value: nil,
                bounds: CGRect(x: 50, y: 50, width: 100, height: 50),
                isEnabled: true,
                isSelected: nil,
                attributes: [:])

            let detectedElements = DetectedElements(
                buttons: [mockElement])

            let detectionResult = ElementDetectionResult(
                snapshotId: "test-snapshot",
                screenshotPath: "/tmp/test.png",
                elements: detectedElements,
                metadata: DetectionMetadata(
                    detectionTime: 0.1,
                    elementCount: 1,
                    method: "AXorcist"))

            await snapshotManager.primeDetectionResult(detectionResult)

            let service = ClickService(snapshotManager: snapshotManager)

            // Should find element in session and click at its center
            try await service.click(
                target: .elementId("test-button"),
                clickType: .single,
                snapshotId: "test-snapshot")
        }

        @Test("Click element by ID not found throws specific error")
        func clickElementByIdNotFound() async throws {
            let snapshotManager = MockSnapshotManager()
            let service = ClickService(snapshotManager: snapshotManager)
            let nonExistentId = "non-existent-button"

            // Should throw NotFoundError with specific element ID
            await #expect(throws: NotFoundError.self) {
                try await service.click(
                    target: .elementId(nonExistentId),
                    clickType: .single,
                    snapshotId: nil)
            }
        }
    }

    @Suite("Click Types")
    @MainActor
    struct ClickTypeTests {
        @Test("Click supports single, double, and right-click types")
        func differentClickTypes() async throws {
            let snapshotManager = MockSnapshotManager()
            let service = ClickService(snapshotManager: snapshotManager)

            let point = CGPoint(x: 100, y: 100)

            // Test single click
            try await service.click(
                target: .coordinates(point),
                clickType: .single,
                snapshotId: nil)

            // Test right click
            try await service.click(
                target: .coordinates(point),
                clickType: .right,
                snapshotId: nil)

            // Test double click
            try await service.click(
                target: .coordinates(point),
                clickType: .double,
                snapshotId: nil)
        }
    }

    @Test("Click element by query matches partial text")
    func clickElementByQuery() async throws {
        let snapshotManager = MockSnapshotManager()

        // Create mock detection result with searchable element
        let mockElement = DetectedElement(
            id: "submit-btn",
            type: .button,
            label: "Submit Form",
            value: nil,
            bounds: CGRect(x: 100, y: 100, width: 80, height: 40),
            isEnabled: true,
            isSelected: nil,
            attributes: [:])

        let detectedElements = DetectedElements(
            buttons: [mockElement])

        let detectionResult = ElementDetectionResult(
            snapshotId: "test-snapshot",
            screenshotPath: "/tmp/test.png",
            elements: detectedElements,
            metadata: DetectionMetadata(
                detectionTime: 0.1,
                elementCount: 1,
                method: "AXorcist"))

        await snapshotManager.primeDetectionResult(detectionResult)

        let service = ClickService(snapshotManager: snapshotManager)

        // Should find element by query and click it
        try await service.click(
            target: .query("submit"),
            clickType: .single,
            snapshotId: "test-snapshot")
    }
}

// MARK: - Mock Snapshot Manager

@MainActor
private final class MockSnapshotManager: SnapshotManagerProtocol {
    private var mockDetectionResult: ElementDetectionResult?

    func primeDetectionResult(_ result: ElementDetectionResult?) {
        self.mockDetectionResult = result
    }

    func createSnapshot() async throws -> String {
        "test-snapshot-\(UUID().uuidString)"
    }

    func storeDetectionResult(snapshotId: String, result: ElementDetectionResult) async throws {
        // No-op for tests
    }

    func getDetectionResult(snapshotId: String) async throws -> ElementDetectionResult? {
        self.mockDetectionResult
    }

    func getMostRecentSnapshot() async -> String? {
        nil
    }

    func getMostRecentSnapshot(applicationBundleId _: String) async -> String? {
        nil
    }

    func listSnapshots() async throws -> [SnapshotInfo] {
        []
    }

    func cleanSnapshot(snapshotId: String) async throws {
        // No-op for tests
    }

    func cleanSnapshotsOlderThan(days: Int) async throws -> Int {
        0
    }

    func cleanAllSnapshots() async throws -> Int {
        0
    }

    nonisolated func getSnapshotStoragePath() -> String {
        "/tmp/test-snapshots"
    }

    func storeScreenshot(
        snapshotId: String,
        screenshotPath: String,
        applicationBundleId _: String?,
        applicationProcessId _: Int32?,
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?) async throws
    {
        // No-op for tests
    }

    func storeAnnotatedScreenshot(snapshotId: String, annotatedScreenshotPath: String) async throws {
        _ = snapshotId
        _ = annotatedScreenshotPath
    }

    func getElement(snapshotId: String, elementId: String) async throws -> UIElement? {
        nil
    }

    func findElements(snapshotId: String, matching query: String) async throws -> [UIElement] {
        []
    }

    func getUIAutomationSnapshot(snapshotId: String) async throws -> UIAutomationSnapshot? {
        nil
    }
}
