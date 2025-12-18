import CoreGraphics
import Testing

@testable import PeekabooAutomationKit

@Suite("TypeService target resolution")
struct TypeServiceTargetResolutionTests {
    @Test("resolveTargetElement matches identifier over other fields")
    @MainActor
    func resolvesByIdentifier() async throws {
        let basic = DetectedElement(
            id: "T1",
            type: .textField,
            label: "Type here...",
            value: nil,
            bounds: .init(x: 0, y: 0, width: 100, height: 20),
            isEnabled: true,
            isSelected: nil,
            attributes: ["identifier": "basic-text-field"])
        let number = DetectedElement(
            id: "T2",
            type: .textField,
            label: "Numbers only...",
            value: nil,
            bounds: .init(x: 0, y: 24, width: 100, height: 20),
            isEnabled: true,
            isSelected: nil,
            attributes: ["identifier": "number-text-field"])

        let detectionResult = ElementDetectionResult(
            snapshotId: "snapshot",
            screenshotPath: "/tmp/shot.png",
            elements: DetectedElements(textFields: [basic, number]),
            metadata: DetectionMetadata(detectionTime: 0.01, elementCount: 2, method: "test"))

        #expect(TypeService.resolveTargetElement(query: "basic-text-field", in: detectionResult)?.id == "T1")
        #expect(TypeService.resolveTargetElement(query: "number-text-field", in: detectionResult)?.id == "T2")
        #expect(TypeService.resolveTargetElement(query: "Type here...", in: detectionResult)?.id == "T1")
        #expect(TypeService.resolveTargetElement(query: "Numbers only...", in: detectionResult)?.id == "T2")
    }

    @Test("resolveTargetElement returns nil for unknown query")
    @MainActor
    func returnsNilWhenNoMatch() async throws {
        let element = DetectedElement(
            id: "T1",
            type: .textField,
            label: "Type here...",
            value: nil,
            bounds: .init(x: 0, y: 0, width: 100, height: 20),
            isEnabled: true,
            isSelected: nil,
            attributes: ["identifier": "basic-text-field"])

        let detectionResult = ElementDetectionResult(
            snapshotId: "snapshot",
            screenshotPath: "/tmp/shot.png",
            elements: DetectedElements(textFields: [element]),
            metadata: DetectionMetadata(detectionTime: 0.01, elementCount: 1, method: "test"))

        #expect(TypeService.resolveTargetElement(query: "does-not-exist", in: detectionResult) == nil)
    }

    @Test("resolveTargetElement breaks ties deterministically")
    @MainActor
    func resolvesDeterministicTieBreak() async throws {
        let higher = DetectedElement(
            id: "T_HIGH",
            type: .textField,
            label: "Type here...",
            value: nil,
            bounds: .init(x: 0, y: 100, width: 100, height: 20),
            isEnabled: true,
            isSelected: nil,
            attributes: ["identifier": "basic-text-field"])
        let lower = DetectedElement(
            id: "T_LOW",
            type: .textField,
            label: "Type here...",
            value: nil,
            bounds: .init(x: 0, y: 40, width: 100, height: 20),
            isEnabled: true,
            isSelected: nil,
            attributes: ["identifier": "basic-text-field"])

        let detectionResult = ElementDetectionResult(
            snapshotId: "snapshot",
            screenshotPath: "/tmp/shot.png",
            elements: DetectedElements(textFields: [higher, lower]),
            metadata: DetectionMetadata(detectionTime: 0.01, elementCount: 2, method: "test"))

        #expect(TypeService.resolveTargetElement(query: "basic-text-field", in: detectionResult)?.id == "T_LOW")
    }
}
