import CoreGraphics
import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooCore

@MainActor
struct CaptureSessionTests {
    @Test
    func `keeps all frames and writes contact/metadata`() async throws {
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

    @Test
    func `video capture result preserves video sampling options`() async throws {
        let frameSource = FakeFrameSource(frameCount: 1, size: CGSize(width: 100, height: 80))
        let outputDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("peekaboo-video-options-test-\(UUID().uuidString)", isDirectory: true)

        let options = CaptureOptions(
            duration: 3600,
            idleFps: 60,
            activeFps: 60,
            changeThresholdPercent: 2.5,
            heartbeatSeconds: 5,
            quietMsToIdle: 1000,
            maxFrames: 10,
            maxMegabytes: nil,
            highlightChanges: false,
            captureFocus: .auto,
            resolutionCap: 1440,
            diffStrategy: .fast,
            diffBudgetMs: nil)
        let videoOptions = CaptureVideoOptionsSnapshot(
            sampleFps: nil,
            everyMs: 100,
            effectiveFps: 10,
            startMs: 250,
            endMs: 1250,
            keepAllFrames: true)
        let config = WatchCaptureConfiguration(
            scope: CaptureScope(kind: .frontmost),
            options: options,
            outputRoot: outputDir,
            autoclean: WatchAutocleanConfig(minutes: 120, managed: false),
            sourceKind: .video,
            videoIn: "/tmp/input.mov",
            videoOut: nil,
            keepAllFrames: true,
            videoOptions: videoOptions)

        let session = WatchCaptureSession(
            dependencies: WatchCaptureDependencies(
                screenCapture: NoOpScreenCaptureService(),
                screenService: NoOpScreenService(),
                frameSource: frameSource),
            configuration: config)
        let result = try await session.run()

        #expect(result.source == .video)
        #expect(result.videoIn == "/tmp/input.mov")
        #expect(result.options.video == videoOptions)
    }
}

// MARK: - Fakes

private final class FakeFrameSource: CaptureFrameSource {
    private var remaining: Int
    private let size: CGSize

    init(frameCount: Int, size: CGSize) {
        self.remaining = frameCount
        self.size = size
    }

    func nextFrame() async throws -> (cgImage: CGImage?, metadata: CaptureMetadata)? {
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
    func captureScreen(
        displayIndex: Int?,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        throw PeekabooError.captureFailed(reason: "unused")
    }

    func captureWindow(
        appIdentifier: String,
        windowIndex: Int?,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        throw PeekabooError.captureFailed(reason: "unused")
    }

    func captureFrontmost(
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        throw PeekabooError.captureFailed(reason: "unused")
    }

    func captureArea(
        _ rect: CGRect,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        throw PeekabooError.captureFailed(reason: "unused")
    }

    func hasScreenRecordingPermission() async -> Bool {
        true
    }
}

private struct NoOpScreenService: ScreenServiceProtocol {
    func listScreens() -> [ScreenInfo] {
        [
            ScreenInfo(
                index: 0,
                name: "Mock",
                frame: .zero,
                visibleFrame: .zero,
                isPrimary: true,
                scaleFactor: 2.0,
                displayID: 0),
        ]
    }

    func screenContainingWindow(bounds: CGRect) -> ScreenInfo? {
        self.listScreens().first
    }

    func screen(at index: Int) -> ScreenInfo? {
        self.listScreens().first(where: { $0.index == index })
    }

    var primaryScreen: ScreenInfo? {
        self.listScreens().first
    }
}
