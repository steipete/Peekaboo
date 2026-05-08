import CoreGraphics
import Testing
@testable import PeekabooAutomationKit

struct UIAutomationServiceVisualizerTests {
    @Test
    @MainActor
    func `visual feedback point prefers action anchor over coordinate fallback`() {
        let actionAnchor = CGPoint(x: 20, y: 30)
        let fallback = CGPoint(x: 1, y: 2)

        let point = UIAutomationService.visualFeedbackPoint(actionAnchor: actionAnchor, fallbackPoint: fallback)

        #expect(point == actionAnchor)
    }

    @Test
    @MainActor
    func `visual feedback point uses fallback when action anchor is missing`() {
        let fallback = CGPoint(x: 1, y: 2)

        let point = UIAutomationService.visualFeedbackPoint(actionAnchor: nil, fallbackPoint: fallback)

        #expect(point == fallback)
    }
}
