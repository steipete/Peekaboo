import CoreGraphics
import Foundation
import PeekabooFoundation
import Testing

@testable import PeekabooCore

@Suite("CaptureSession with fake frame source")
struct CaptureSessionTests {
    @Test("keeps all frames and writes contact/metadata")
    func keepAllFrames() async throws {
        let framesToEmit = 5
        let frameSource = FakeFrameSource(frameCount: framesToEmit, size: CGSize(width: 100, height: 80))
        let outputDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("peekaboo-capture-test-\(UUID().uuidString)", isDirectory: true)

        let deps = WatchCaptureDependencies(
            screenCapture: NoOpScreenCaptureService(),
            screenService: NoOpScreenService(),
            frameSource: frameSource)

        let options = CaptureOptions(
            duration: 10,
            idleFps: 1,
            activeFps: 1,
            changeThresholdPercent: 0,
            heartbeatSeconds: 0,
            quietMsToIdle: 0,
            maxFrames: 50,
            maxMegabytes: nil,
            highlightChanges: false,
            captureFocus: .auto,
            resolutionCap: nil,
            diffStrategy: .fast,
            diffBudgetMs: nil)

        let config = WatchCaptureConfiguration(
            scope: CaptureScope(kind: .frontmost),
            options: options,
            outputRoot: outputDir,
            autoclean: WatchAutocleanConfig(minutes: 120, managed: false),
            sourceKind: .live,
            videoIn: nil,
            videoOut: nil,
            keepAllFrames: true)

        let session = WatchCaptureSession(dependencies: deps, configuration: config)
        let result = try await session.run()

        #expect(result.frames.count == framesToEmit)
        #expect(result.stats.framesKept == framesToEmit)
        #expect(FileManager.default.fileExists(atPath: result.contactSheet.path))
        #expect(FileManager.default.fileExists(atPath: result.metadataFile))
    }
}

// MARK: - Fakes

private struct FakeFrameSource: CaptureFrameSource {
    private var remaining: Int
    private let size: CGSize

    init(frameCount: Int, size: CGSize) {
        self.remaining = frameCount
        self.size = size
    }

    mutating func nextFrame() async throws -> (cgImage: CGImage?, metadata: CaptureMetadata)? {
        guard self.remaining > 0 else { return nil }
        self.remaining -= 1
        let image = FakeFrameSource.makeSolidImage(size: self.size)
        let meta = CaptureMetadata(size: size, mode: .screen, timestamp: Date())
        return (image, meta)
    }

    private static func makeSolidImage(size: CGSize) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerRow = width * bytesPerPixel
        var data = [UInt8](repeating: 255, count: width * height * bytesPerPixel)
        let ctx = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        return ctx?.makeImage()
    }
}

private struct NoOpScreenCaptureService: ScreenCaptureServiceProtocol {
    func captureScreen(displayIndex: Int?, visualizerMode: CaptureVisualizerMode) async throws -> CaptureResult {
        throw PeekabooError.captureFailed(reason: "unused")
    }

    func captureWindow(
        appIdentifier: String,
        windowIndex: Int?,
        visualizerMode: CaptureVisualizerMode) async throws -> CaptureResult
    {
        throw PeekabooError.captureFailed(reason: "unused")
    }

    func captureFrontmost(visualizerMode: CaptureVisualizerMode) async throws -> CaptureResult {
        throw PeekabooError.captureFailed(reason: "unused")
    }

    func captureArea(_ rect: CGRect, visualizerMode: CaptureVisualizerMode) async throws -> CaptureResult {
        throw PeekabooError.captureFailed(reason: "unused")
    }

    func hasScreenRecordingPermission() async -> Bool { true }
}

private struct NoOpScreenService: ScreenServiceProtocol {
    func listScreens() -> [ScreenInfo] { [ScreenInfo(index: 0, name: "Mock", frame: .zero)] }
}
