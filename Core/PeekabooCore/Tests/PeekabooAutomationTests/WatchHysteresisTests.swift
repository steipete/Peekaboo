import CoreGraphics
import Foundation
import Testing
@testable import PeekabooAutomationKit

@Suite("Watch hysteresis and caps")
@MainActor
struct WatchHysteresisTests {
    @Test("Exits active after quiet period")
    func exitsActiveAfterQuiet() {
        // Two frames: first with high delta, second identical.
        let prev = WatchCaptureSession.LumaBuffer(width: 2, height: 2, pixels: [0, 255, 0, 0])
        let curr = WatchCaptureSession.LumaBuffer(width: 2, height: 2, pixels: [0, 255, 0, 0])
        let diff = WatchCaptureSession.computeChange(
            using: .init(
                strategy: .fast,
                diffBudgetMs: nil,
                previous: prev,
                current: curr,
                deltaThreshold: 10,
                originalSize: CGSize(width: 20, height: 20)))
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

    @Test("Idle → active → idle timeline honors quiet window")
    func timelineTransitions() {
        let start = Date()
        var lastActivity = start
        var active = false
        let threshold = 2.0
        let quietMs = 800

        func step(change: Double, deltaMs: Int) {
            let now = start.addingTimeInterval(Double(deltaMs) / 1000)
            let enter = change >= threshold
            if enter {
                active = true
                lastActivity = now
            }
            let shouldExit = active && WatchCaptureSession.shouldExitActive(
                changePercent: change,
                threshold: threshold,
                lastActivityTime: lastActivity,
                quietMs: quietMs,
                now: now)
            if shouldExit { active = false }
        }

        // Idle period with small jitter: stay idle.
        step(change: 0.3, deltaMs: 100)
        #expect(!active)

        // Motion spike: enter active.
        step(change: 4.0, deltaMs: 200)
        #expect(active)

        // Mild movement above half-threshold: remain active.
        step(change: 1.2, deltaMs: 500)
        #expect(active)

        // Quiet but not enough time elapsed: still active.
        step(change: 0.1, deltaMs: 900)
        #expect(active)

        // Quiet long enough: exit to idle.
        step(change: 0.1, deltaMs: 1200)
        #expect(!active)
    }
}
