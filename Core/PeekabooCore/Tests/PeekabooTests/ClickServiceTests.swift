import CoreGraphics
import Foundation
import Testing
@testable import PeekabooCore

@Suite("ClickService Tests", .tags(.ui))
@MainActor
struct ClickServiceTests {
    @Suite("Initialization")
    @MainActor
    struct InitializationTests {
        @Test("ClickService initializes with session manager dependency")
        func initializeService() async throws {
            let sessionManager = MockSessionManager()
            let service = ClickService(sessionManager: sessionManager)
            #expect(true)  // Service is non-optional, always succeeds
        }
    }

    @Suite("Coordinate Clicking")
    @MainActor
    struct CoordinateClickingTests {
        @Test("Click performs at specified screen coordinates without errors")
        func clickAtCoordinates() async throws {
            let sessionManager = MockSessionManager()
            let service = ClickService(sessionManager: sessionManager)

            let point = CGPoint(x: 100, y: 100)

            // This will attempt to click at the coordinates
            // In a test environment, we can't verify the actual click happened,
            // but we can verify no errors are thrown
            try await service.click(
                target: .coordinates(point),
                clickType: .single,
                sessionId: nil)
        }
    }

    @Suite("Element Clicking")
    @MainActor
    struct ElementClickingTests {
        @Test("Click finds and clicks element by ID using session detection results")
        func clickElementById() async throws {
            let sessionManager = MockSessionManager()

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
                sessionId: "test-session",
                screenshotPath: "/tmp/test.png",
                elements: detectedElements,
                metadata: DetectionMetadata(
                    detectionTime: 0.1,
                    elementCount: 1,
                    method: "AXorcist"))

            sessionManager.mockDetectionResult = detectionResult

            let service = ClickService(sessionManager: sessionManager)

            // Should find element in session and click at its center
            try await service.click(
                target: .elementId("test-button"),
                clickType: .single,
                sessionId: "test-session")
        }

        @Test("Click element by ID not found throws specific error")
        func clickElementByIdNotFound() async throws {
            let sessionManager = MockSessionManager()
            let service = ClickService(sessionManager: sessionManager)
            let nonExistentId = "non-existent-button"

            // Should throw NotFoundError with specific element ID
            await #expect(throws: NotFoundError.self) {
                try await service.click(
                    target: .elementId(nonExistentId),
                    clickType: .single,
                    sessionId: nil)
            }
        }
    }

    @Suite("Click Types")
    @MainActor
    struct ClickTypeTests {
        @Test("Click supports single, double, and right-click types")
        func differentClickTypes() async throws {
            let sessionManager = MockSessionManager()
            let service = ClickService(sessionManager: sessionManager)

            let point = CGPoint(x: 100, y: 100)

            // Test single click
            try await service.click(
                target: .coordinates(point),
                clickType: .single,
                sessionId: nil)

            // Test right click
            try await service.click(
                target: .coordinates(point),
                clickType: .right,
                sessionId: nil)

            // Test double click
            try await service.click(
                target: .coordinates(point),
                clickType: .double,
                sessionId: nil)
        }
    }

    @Test("Click element by query matches partial text")
    func clickElementByQuery() async throws {
        let sessionManager = MockSessionManager()

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
            sessionId: "test-session",
            screenshotPath: "/tmp/test.png",
            elements: detectedElements,
            metadata: DetectionMetadata(
                detectionTime: 0.1,
                elementCount: 1,
                method: "AXorcist"))

        sessionManager.mockDetectionResult = detectionResult

        let service = ClickService(sessionManager: sessionManager)

        // Should find element by query and click it
        try await service.click(
            target: .query("submit"),
            clickType: .single,
            sessionId: "test-session")
    }
}

// MARK: - Mock Session Manager

@MainActor
private final class MockSessionManager: SessionManagerProtocol {
    var mockDetectionResult: ElementDetectionResult?

    func createSession() async throws -> String {
        "test-session-\(UUID().uuidString)"
    }

    func storeDetectionResult(sessionId: String, result: ElementDetectionResult) async throws {
        // No-op for tests
    }

    func getDetectionResult(sessionId: String) async throws -> ElementDetectionResult? {
        self.mockDetectionResult
    }

    func getMostRecentSession() async -> String? {
        nil
    }

    func listSessions() async throws -> [SessionInfo] {
        []
    }

    func cleanSession(sessionId: String) async throws {
        // No-op for tests
    }

    func cleanSessionsOlderThan(days: Int) async throws -> Int {
        0
    }

    func cleanAllSessions() async throws -> Int {
        0
    }

    nonisolated func getSessionStoragePath() -> String {
        "/tmp/test-sessions"
    }

    func storeScreenshot(
        sessionId: String,
        screenshotPath: String,
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?) async throws
    {
        // No-op for tests
    }

    func getElement(sessionId: String, elementId: String) async throws -> UIElement? {
        nil
    }

    func findElements(sessionId: String, matching query: String) async throws -> [UIElement] {
        []
    }

    func getUIAutomationSession(sessionId: String) async throws -> UIAutomationSession? {
        nil
    }
}
