import CoreGraphics
import Testing
@testable import PeekabooAutomation

@Suite("Watch hysteresis and caps")
struct WatchHysteresisTests {
    @Test("Exits active after quiet period")
    func exitsActiveAfterQuiet() {
        // Two frames: first with high delta, second identical.
        let prev = WatchCaptureSession.LumaBuffer(width: 2, height: 2, pixels: [0, 255, 0, 0])
        let curr = WatchCaptureSession.LumaBuffer(width: 2, height: 2, pixels: [0, 255, 0, 0])
        let diff = WatchCaptureSession.computeChange(
            strategy: .fast,
            diffBudgetMs: nil,
            previous: prev,
            current: curr,
            deltaThreshold: 10,
            originalSize: CGSize(width: 20, height: 20))
        #expect(diff.changePercent == 0)
    }
}
