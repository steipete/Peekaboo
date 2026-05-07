@_spi(Testing) import PeekabooAutomationKit
import Testing

@Suite(.tags(.fast))
struct ElementDetectionTraversalPolicyTests {
    @Test
    func `Sparse tree may attempt web focus fallback`() {
        #expect(AXTraversalPolicy.shouldAttemptWebFocusFallback(
            attempt: 0,
            allowWebFocus: true,
            detectedElementCount: 20,
            hasTextField: false))
    }

    @Test
    func `Rich native tree skips web focus fallback`() {
        #expect(!AXTraversalPolicy.shouldAttemptWebFocusFallback(
            attempt: 0,
            allowWebFocus: true,
            detectedElementCount: 21,
            hasTextField: false))
    }

    @Test
    func `Visible text field skips web focus fallback`() {
        #expect(!AXTraversalPolicy.shouldAttemptWebFocusFallback(
            attempt: 0,
            allowWebFocus: true,
            detectedElementCount: 3,
            hasTextField: true))
    }

    @Test
    func `Disabled web focus skips fallback`() {
        #expect(!AXTraversalPolicy.shouldAttemptWebFocusFallback(
            attempt: 0,
            allowWebFocus: false,
            detectedElementCount: 3,
            hasTextField: false))
    }

    @Test
    func `Attempt limit skips fallback`() {
        #expect(!AXTraversalPolicy.shouldAttemptWebFocusFallback(
            attempt: 2,
            allowWebFocus: true,
            detectedElementCount: 3,
            hasTextField: false))
    }
}
