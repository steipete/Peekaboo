@preconcurrency import AXorcist
import CoreGraphics
import Foundation
import Testing
@testable import PeekabooAutomationKit

struct ClickServiceTargetResolutionTests {
    @Test
    @MainActor
    func `action-first missing snapshot fails as stale instead of falling back`() async {
        let service = ClickService(
            snapshotManager: InMemorySnapshotManager(),
            inputPolicy: UIInputPolicy(defaultStrategy: .actionFirst))

        do {
            try await service.click(target: .elementId("B1"), clickType: .single, snapshotId: "missing")
            Issue.record("Expected stale element error for missing action snapshot.")
        } catch let error as ActionInputError {
            #expect(error == .staleElement)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    @MainActor
    func `action-first unresolved snapshot element falls back to coordinate click`() async throws {
        let element = DetectedElement(
            id: "C1",
            type: .other,
            label: "peekaboo-unresolved-canvas-control-\(UUID().uuidString)",
            value: nil,
            bounds: .init(x: 100, y: 120, width: 40, height: 20),
            isEnabled: true,
            isSelected: nil,
            attributes: [:])
        let detectionResult = ElementDetectionResult(
            snapshotId: "snapshot",
            screenshotPath: "/tmp/shot.png",
            elements: DetectedElements(other: [element]),
            metadata: DetectionMetadata(detectionTime: 0.01, elementCount: 1, method: "test"))
        let synthetic = ClickRecordingSyntheticInputDriver()
        let service = ClickService(
            snapshotManager: InMemorySnapshotManager(detectionResult: detectionResult),
            inputPolicy: UIInputPolicy(defaultStrategy: .actionFirst),
            syntheticInputDriver: synthetic)

        let result = try await service.click(target: .elementId("C1"), clickType: .right, snapshotId: "snapshot")

        #expect(result.path == .synth)
        #expect(result.fallbackReason == .missingElement)
        #expect(synthetic.events == [
            .click(point: CGPoint(x: 120, y: 130), button: .right, count: 1),
        ])
    }

    @Test
    @MainActor
    func `background click delivers synthetic click to target process`() async throws {
        let synthetic = ClickRecordingSyntheticInputDriver()
        let service = ClickService(
            snapshotManager: InMemorySnapshotManager(),
            inputPolicy: UIInputPolicy(defaultStrategy: .actionFirst),
            syntheticInputDriver: synthetic)

        let result = try await service.click(
            target: .coordinates(CGPoint(x: 10, y: 20)),
            clickType: .double,
            snapshotId: nil,
            targetProcessIdentifier: 12345)

        #expect(result.path == .synth)
        #expect(result.strategy == .synthOnly)
        #expect(synthetic.events == [
            .targetedClick(point: CGPoint(x: 10, y: 20), button: .left, count: 2, targetProcessIdentifier: 12345),
        ])
    }

    @Test
    @MainActor
    func `background element click forces synthetic path despite action first policy`() async throws {
        let element = DetectedElement(
            id: "B1",
            type: .button,
            label: "Background Button",
            value: nil,
            bounds: .init(x: 20, y: 30, width: 100, height: 40),
            isEnabled: true,
            isSelected: nil,
            attributes: ["identifier": "background-button", "role": "AXButton"])
        let detectionResult = ElementDetectionResult(
            snapshotId: "snapshot",
            screenshotPath: "/tmp/shot.png",
            elements: DetectedElements(buttons: [element]),
            metadata: DetectionMetadata(detectionTime: 0.01, elementCount: 1, method: "test"))
        let synthetic = ClickRecordingSyntheticInputDriver()
        let service = ClickService(
            snapshotManager: InMemorySnapshotManager(detectionResult: detectionResult),
            inputPolicy: UIInputPolicy(defaultStrategy: .actionFirst),
            syntheticInputDriver: synthetic)

        let result = try await service.click(
            target: .elementId("B1"),
            clickType: .single,
            snapshotId: "snapshot",
            targetProcessIdentifier: 12345)

        #expect(result.path == .synth)
        #expect(result.strategy == .synthOnly)
        #expect(synthetic.events == [
            .targetedClick(point: CGPoint(x: 70, y: 50), button: .left, count: 1, targetProcessIdentifier: 12345),
        ])
    }

    @Test
    @MainActor
    func `resolveTargetElement matches identifier and exact label`() {
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

    @Test
    @MainActor
    func `resolveTargetElement breaks ties deterministically`() {
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

@MainActor
private final class ClickRecordingSyntheticInputDriver: SyntheticInputDriving {
    enum Event: Equatable {
        case click(point: CGPoint, button: MouseButton, count: Int)
        case targetedClick(point: CGPoint, button: MouseButton, count: Int, targetProcessIdentifier: pid_t)
        case move(CGPoint)
        case currentLocation
        case scroll(deltaX: Double, deltaY: Double, at: CGPoint?)
    }

    private(set) var events: [Event] = []

    func click(at point: CGPoint, button: MouseButton, count: Int) throws {
        self.events.append(.click(point: point, button: button, count: count))
    }

    func click(at point: CGPoint, button: MouseButton, count: Int, targetProcessIdentifier: pid_t) throws {
        self.events.append(.targetedClick(
            point: point,
            button: button,
            count: count,
            targetProcessIdentifier: targetProcessIdentifier))
    }

    func move(to point: CGPoint) throws {
        self.events.append(.move(point))
    }

    func currentLocation() -> CGPoint? {
        self.events.append(.currentLocation)
        return nil
    }

    func pressHold(at _: CGPoint, button _: MouseButton, duration _: TimeInterval) throws {}

    func scroll(deltaX: Double, deltaY: Double, at point: CGPoint?) throws {
        self.events.append(.scroll(deltaX: deltaX, deltaY: deltaY, at: point))
    }

    func type(_: String, delayPerCharacter _: TimeInterval) throws {}

    func tapKey(_: SpecialKey, modifiers _: CGEventFlags) throws {}

    func hotkey(keys _: [String], holdDuration _: TimeInterval) throws {}
}
