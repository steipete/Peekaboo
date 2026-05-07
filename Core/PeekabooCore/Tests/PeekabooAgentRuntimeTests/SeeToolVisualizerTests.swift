import CoreGraphics
import PeekabooAutomation
import Testing
@testable import PeekabooAgentRuntime

@MainActor
struct SeeToolVisualizerTests {
    @Test
    func `Converts accessibility bounds into screen-space rectangles`() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let accessibilityRect = CGRect(x: 120, y: 50, width: 200, height: 40)

        let converted = VisualizerBoundsConverter.convertAccessibilityRect(accessibilityRect, screenBounds: screen)

        let expectedY: CGFloat = 900 - 50 - 40
        #expect(converted.origin.x == 120)
        #expect(converted.origin.y == expectedY)
        #expect(converted.width == 200)
        #expect(converted.height == 40)
    }

    @Test
    func `Produces protocol elements with flipped coordinates`() {
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

    @Test
    func `Resolves bounds from matching service screen`() {
        let screens = [
            self.makeScreen(
                frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
                isPrimary: true,
                index: 0),
            self.makeScreen(
                frame: CGRect(x: 1000, y: 0, width: 1200, height: 900),
                isPrimary: false,
                index: 1),
        ]

        let resolved = VisualizerBoundsConverter.resolveScreenBounds(
            windowBounds: CGRect(x: 1100, y: 100, width: 400, height: 300),
            displayBounds: nil,
            screens: screens)

        #expect(resolved == screens[1].frame)
    }

    @Test
    func `Prefers capture display metadata over service screens`() {
        let serviceScreen = self.makeScreen(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            isPrimary: true,
            index: 0)
        let displayBounds = CGRect(x: 2000, y: 0, width: 640, height: 480)

        let resolved = VisualizerBoundsConverter.resolveScreenBounds(
            windowBounds: serviceScreen.frame,
            displayBounds: displayBounds,
            screens: [serviceScreen])

        #expect(resolved == displayBounds)
    }

    @Test
    func `Falls back to primary screen when window is offscreen`() {
        let primary = self.makeScreen(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            isPrimary: true,
            index: 0)

        let resolved = VisualizerBoundsConverter.resolveScreenBounds(
            windowBounds: CGRect(x: 5000, y: 5000, width: 100, height: 100),
            displayBounds: nil,
            screens: [primary])

        #expect(resolved == primary.frame)
    }

    @Test
    func `Uses synthetic bounds without display metadata`() {
        let windowBounds = CGRect(x: 20, y: 30, width: 500, height: 400)

        let resolved = VisualizerBoundsConverter.resolveScreenBounds(
            windowBounds: windowBounds,
            displayBounds: nil,
            screens: [])

        #expect(resolved == CGRect(x: 20, y: 30, width: 1440, height: 900))
    }

    private func makeScreen(frame: CGRect, isPrimary: Bool, index: Int) -> PeekabooAutomation.ScreenInfo {
        PeekabooAutomation.ScreenInfo(
            index: index,
            name: "Display \(index)",
            frame: frame,
            visibleFrame: frame,
            isPrimary: isPrimary,
            scaleFactor: 2,
            displayID: CGDirectDisplayID(index + 1))
    }
}
