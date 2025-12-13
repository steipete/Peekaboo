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
