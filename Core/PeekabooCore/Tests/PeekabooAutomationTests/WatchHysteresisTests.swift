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

    @Test("Exit requires calm for quietMs window")
    func exitActiveQuietElapsed() {
        let now = Date()
        let lastActivity = now.addingTimeInterval(-1.2)
        let shouldExit = WatchCaptureSession.shouldExitActive(
            changePercent: 0.5,
            threshold: 2.0,
            lastActivityTime: lastActivity,
            quietMs: 1000,
            now: now)
        #expect(shouldExit)
    }

    @Test("Stays active when change stays above half-threshold")
    func staysActiveWhenNoisy() {
        let now = Date()
        let lastActivity = now.addingTimeInterval(-2)
        let shouldExit = WatchCaptureSession.shouldExitActive(
            changePercent: 1.2, // >= threshold/2 when threshold is 2.0
            threshold: 2.0,
            lastActivityTime: lastActivity,
            quietMs: 500,
            now: now)
        #expect(!shouldExit)
    }

    @Test("Stays active until quietMs elapses")
    func staysActiveUntilQuietWindowPasses() {
        let now = Date()
        let lastActivity = now.addingTimeInterval(-0.3)
        let shouldExit = WatchCaptureSession.shouldExitActive(
            changePercent: 0.1,
            threshold: 1.0,
            lastActivityTime: lastActivity,
            quietMs: 1000,
            now: now)
        #expect(!shouldExit)
    }
}
