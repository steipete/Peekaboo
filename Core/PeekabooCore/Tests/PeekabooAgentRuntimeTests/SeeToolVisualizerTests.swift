import CoreGraphics
import PeekabooAutomation
import Testing
@testable import PeekabooAgentRuntime

@Suite("SeeTool Visualizer Support")
@MainActor
struct SeeToolVisualizerTests {
    @Test("Converts accessibility bounds into screen-space rectangles")
    func convertsAccessibilityRect() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let accessibilityRect = CGRect(x: 120, y: 50, width: 200, height: 40)

        let converted = VisualizerBoundsConverter.convertAccessibilityRect(accessibilityRect, screenBounds: screen)

        let expectedY: CGFloat = 900 - 50 - 40
        #expect(converted.origin.x == 120)
        #expect(converted.origin.y == expectedY)
        #expect(converted.width == 200)
        #expect(converted.height == 40)
    }

    @Test("Produces protocol elements with flipped coordinates")
    func producesVisualizerElements() {
        let sample = PeekabooAutomation.DetectedElement(
            id: "B1",
            type: .button,
            label: "Submit",
            value: nil,
            bounds: CGRect(x: 10, y: 20, width: 60, height: 24),
            isEnabled: true)

        let elements = VisualizerBoundsConverter.makeVisualizerElements(
            from: [sample],
            screenBounds: CGRect(x: 0, y: 0, width: 300, height: 200))

        #expect(elements.count == 1)
        guard let first = elements.first else {
            Issue.record("Expected at least one converted element")
            return
        }
        let expectedY: CGFloat = 200 - 20 - 24
        #expect(first.bounds.origin.y == expectedY)
    }
}
