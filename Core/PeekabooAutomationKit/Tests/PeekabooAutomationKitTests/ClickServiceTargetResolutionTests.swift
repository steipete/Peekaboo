import CoreGraphics
import Testing

@testable import PeekabooAutomationKit

@Suite("ClickService target resolution")
struct ClickServiceTargetResolutionTests {
    @Test("resolveTargetElement matches identifier and exact label")
    @MainActor
    func resolvesButton() async throws {
        let focusButton = DetectedElement(
            id: "B1",
            type: .button,
            label: "Focus Basic Field",
            value: nil,
            bounds: .init(x: 0, y: 0, width: 80, height: 30),
            isEnabled: true,
            isSelected: nil,
            attributes: ["identifier": "focus-basic-button", "role": "AXButton"])
        let basicField = DetectedElement(
            id: "T1",
            type: .textField,
            label: "Type here...",
            value: nil,
            bounds: .init(x: 0, y: 40, width: 200, height: 20),
            isEnabled: true,
            isSelected: nil,
            attributes: ["identifier": "basic-text-field", "role": "AXTextField"])

        let detectionResult = ElementDetectionResult(
            snapshotId: "snapshot",
            screenshotPath: "/tmp/shot.png",
            elements: DetectedElements(buttons: [focusButton], textFields: [basicField]),
            metadata: DetectionMetadata(detectionTime: 0.01, elementCount: 2, method: "test"))

        #expect(ClickService.resolveTargetElement(query: "focus-basic-button", in: detectionResult)?.id == "B1")
        #expect(ClickService.resolveTargetElement(query: "Focus Basic Field", in: detectionResult)?.id == "B1")
    }

    @Test("resolveTargetElement breaks ties deterministically")
    @MainActor
    func resolvesDeterministicTieBreak() async throws {
        let higher = DetectedElement(
            id: "T_HIGH",
            type: .textField,
            label: "Type here...",
            value: nil,
            bounds: .init(x: 0, y: 100, width: 200, height: 20),
            isEnabled: true,
            isSelected: nil,
            attributes: ["identifier": "basic-text-field", "role": "AXTextField"])
        let lower = DetectedElement(
            id: "T_LOW",
            type: .textField,
            label: "Type here...",
            value: nil,
            bounds: .init(x: 0, y: 40, width: 200, height: 20),
            isEnabled: true,
            isSelected: nil,
            attributes: ["identifier": "basic-text-field", "role": "AXTextField"])

        let detectionResult = ElementDetectionResult(
            snapshotId: "snapshot",
            screenshotPath: "/tmp/shot.png",
            elements: DetectedElements(textFields: [higher, lower]),
            metadata: DetectionMetadata(detectionTime: 0.01, elementCount: 2, method: "test"))

        #expect(ClickService.resolveTargetElement(query: "basic-text-field", in: detectionResult)?.id == "T_LOW")
    }
}
