import CoreGraphics
import Testing
@testable import PeekabooAutomation

@Suite("WatchCaptureSession diffing")
struct WatchCaptureSessionTests {
    @Test("Fast diff detects change and bounding box")
    func fastDiff() {
        let prev = WatchCaptureSession.LumaBuffer(width: 2, height: 2, pixels: [0, 0, 0, 0])
        let curr = WatchCaptureSession.LumaBuffer(width: 2, height: 2, pixels: [0, 255, 0, 0])
        let result = WatchCaptureSession.computeChange(
            strategy: .fast,
            previous: prev,
            current: curr,
            deltaThreshold: 10,
            originalSize: CGSize(width: 200, height: 200))
        #expect(result.changePercent > 0)
        #expect(abs((result.boundingBox?.origin.x ?? 0) - 100) < 0.1)
        #expect(abs((result.boundingBox?.origin.y ?? 0) - 0) < 0.1)
    }

    @Test("Quality diff near-zero for identical frames")
    func qualityNoChange() {
        let buffer = WatchCaptureSession.LumaBuffer(width: 4, height: 4, pixels: Array(repeating: 64, count: 16))
        let result = WatchCaptureSession.computeChange(
            strategy: .quality,
            previous: buffer,
            current: buffer,
            deltaThreshold: 10,
            originalSize: CGSize(width: 100, height: 100))
        #expect(result.changePercent < 0.01)
        #expect(result.boundingBox == nil)
    }

    @Test("Quality diff caps at 100")
    func qualityCaps() {
        let prev = WatchCaptureSession.LumaBuffer(width: 2, height: 2, pixels: [0, 0, 0, 0])
        let curr = WatchCaptureSession.LumaBuffer(width: 2, height: 2, pixels: [255, 255, 255, 255])
        let result = WatchCaptureSession.computeChange(
            strategy: .quality,
            previous: prev,
            current: curr,
            deltaThreshold: 10,
            originalSize: CGSize(width: 100, height: 100))
        #expect(result.changePercent <= 100)
    }
}
