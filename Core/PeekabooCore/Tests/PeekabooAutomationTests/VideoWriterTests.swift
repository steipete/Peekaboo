@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import PeekabooFoundation
import Testing

@testable import PeekabooCore

@MainActor
@Suite("Video writer + capture video output")
struct VideoWriterTests {
    @Test("scaledVideoSize caps longest edge and keeps aspect")
    func scaledVideoSizeRespectsCap() {
        let size = CGSize(width: 4000, height: 2000)
        let capped = WatchCaptureSession.scaledVideoSize(for: size, maxDimension: 1440)
        #expect(capped.width == 1440)
        #expect(capped.height == 720)

        let unchanged = WatchCaptureSession.scaledVideoSize(for: size, maxDimension: 5000)
        #expect(unchanged.width == 4000)
        #expect(unchanged.height == 2000)
    }

    @Test("video sessions bound output size and preserve fps")
    func videoSessionBuildsBoundedMP4() async throws {
        let frameSize = CGSize(width: 4000, height: 2000)
        let frameSource = FakeFrameSource(frameCount: 5, size: frameSize)
        let outputDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("peekaboo-video-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let videoOut = outputDir.appendingPathComponent("capture.mp4").path

        let options = CaptureOptions(
            duration: 5,
            idleFps: 1,
            activeFps: 12,
            changeThresholdPercent: 0,
            heartbeatSeconds: 0,
            quietMsToIdle: 0,
            maxFrames: 10,
            maxMegabytes: nil,
            highlightChanges: false,
            captureFocus: .auto,
            resolutionCap: 1440,
            diffStrategy: .fast,
            diffBudgetMs: nil)

        let config = WatchCaptureConfiguration(
            scope: CaptureScope(kind: .frontmost),
            options: options,
            outputRoot: outputDir,
            autoclean: WatchAutocleanConfig(minutes: 120, managed: false),
            sourceKind: .video,
            videoIn: "mock.mov",
            videoOut: videoOut,
            keepAllFrames: true)

        let deps = WatchCaptureDependencies(
            screenCapture: NoOpScreenCaptureService(),
            screenService: NoOpScreenService(),
            frameSource: frameSource)

        let session = WatchCaptureSession(dependencies: deps, configuration: config)
        let result = try await session.run()

        let asset = AVAsset(url: URL(fileURLWithPath: videoOut))
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try #require(tracks.first)

        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        let natural = naturalSize.applying(preferredTransform)
        let width = Int(abs(natural.width.rounded()))
        let height = Int(abs(natural.height.rounded()))

        let nominalFrameRate = try await track.load(.nominalFrameRate)

        #expect(width == 1440)
        #expect(height == 720)
        #expect(abs(Double(nominalFrameRate) - 12) < 0.5)
        #expect(result.videoOut?.hasSuffix("capture.mp4") == true)
    }
}

// MARK: - Test fakes

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
        let meta = CaptureMetadata(size: self.size, mode: .screen, timestamp: Date())
        return (image, meta)
    }

    private static func makeSolidImage(size: CGSize) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var data = [UInt8](repeating: 200, count: width * height * bytesPerPixel)
        guard
            let ctx = CGContext(
                data: &data,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return nil
        }
        return ctx.makeImage()
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

    func hasScreenRecordingPermission() async -> Bool { true }
}

private struct NoOpScreenService: ScreenServiceProtocol {
    func listScreens() -> [ScreenInfo] { [] }
    func screenContainingWindow(bounds: CGRect) -> ScreenInfo? { nil }
    func screen(at index: Int) -> ScreenInfo? { nil }
    var primaryScreen: ScreenInfo? { nil }
}
