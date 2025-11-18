import CoreGraphics
import Foundation
import Testing
@testable import PeekabooAutomation
@testable import PeekabooCore

@Suite("UIAutomationService Wait Tests", .tags(.safe))
struct UIAutomationServiceWaitTests {
    @Test("Coordinates return immediately")
    @MainActor
    func coordinatesReturnImmediately() async throws {
        let service = UIAutomationService(sessionManager: InMemorySessionManager())

        let result = try await service.waitForElement(
            target: .coordinates(CGPoint(x: 10, y: 20)),
            timeout: 1.0,
            sessionId: nil)

        #expect(result.found)
        #expect(result.waitTime == 0)
    }

    @Test("Element ID resolves from session cache")
    @MainActor
    func elementIdResolvesFromSessionCache() async throws {
        let elements = DetectedElements(
            buttons: [DetectedElement(
                id: "B42",
                type: .button,
                label: "Launch",
                value: nil,
                bounds: CGRect(x: 100, y: 200, width: 50, height: 20))])
        let detection = Self.makeDetectionResult(elements: elements)

        let service = UIAutomationService(sessionManager: InMemorySessionManager(detectionResult: detection))

        let result = try await service.waitForElement(
            target: .elementId("B42"),
            timeout: 1.0,
            sessionId: detection.sessionId)

        #expect(result.found)
        #expect(result.element?.id == "B42")
        #expect(result.waitTime < 0.1)
    }

    @Test("Query resolves using session detection cache")
    @MainActor
    func queryResolvesFromSessionDetection() async throws {
        let elements = DetectedElements(
            buttons: [DetectedElement(
                id: "B1",
                type: .button,
                label: "Submit",
                value: nil,
                bounds: CGRect(x: 10, y: 10, width: 80, height: 30))])
        let detection = Self.makeDetectionResult(elements: elements)

        let service = UIAutomationService(sessionManager: InMemorySessionManager(detectionResult: detection))

        let result = try await service.waitForElement(
            target: .query("submit"),
            timeout: 1.0,
            sessionId: detection.sessionId)

        #expect(result.found)
        #expect(result.element?.label?.lowercased() == "submit")
    }

    // MARK: - Helpers

    private static func makeDetectionResult(
        sessionId: String = "session-test",
        elements: DetectedElements) -> ElementDetectionResult
    {
        let metadata = DetectionMetadata(
            detectionTime: 0.01,
            elementCount: elements.all.count,
            method: "test")

        return ElementDetectionResult(
            sessionId: sessionId,
            screenshotPath: "/tmp/test.png",
            elements: elements,
            metadata: metadata)
    }
}

// MARK: - Test doubles

@MainActor
private final class InMemorySessionManager: SessionManagerProtocol {
    private var storedResults: [String: ElementDetectionResult]

    init(detectionResult: ElementDetectionResult? = nil) {
        if let detectionResult {
            self.storedResults = [detectionResult.sessionId: detectionResult]
        } else {
            self.storedResults = [:]
        }
    }

    func createSession() async throws -> String { "session-" + UUID().uuidString }

    func storeDetectionResult(sessionId: String, result: ElementDetectionResult) async throws {
        self.storedResults[sessionId] = result
    }

    func getDetectionResult(sessionId: String) async throws -> ElementDetectionResult? {
        self.storedResults[sessionId]
    }

    func getMostRecentSession() async -> String? {
        self.storedResults.keys.max()
    }

    func listSessions() async throws -> [SessionInfo] { [] }

    func cleanSession(sessionId: String) async throws {
        self.storedResults.removeValue(forKey: sessionId)
    }

    func cleanSessionsOlderThan(days: Int) async throws -> Int { 0 }

    func cleanAllSessions() async throws -> Int {
        let count = self.storedResults.count
        self.storedResults.removeAll()
        return count
    }

    func getSessionStoragePath() -> String { "/tmp" }

    func storeScreenshot(
        sessionId: String,
        screenshotPath: String,
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?) async throws
    {
        // Not needed for these tests
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
