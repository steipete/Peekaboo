import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import PeekabooAutomation

@Suite("WatchCaptureSession diffing")
struct WatchCaptureSessionTests {
    @Test("Fast diff detects change and bounding box")
    func fastDiff() {
        let prev = WatchCaptureSession.LumaBuffer(width: 2, height: 2, pixels: [0, 0, 0, 0])
        let curr = WatchCaptureSession.LumaBuffer(width: 2, height: 2, pixels: [0, 255, 0, 0])
        let result = WatchCaptureSession.computeChange(
            using: .init(
                strategy: .fast,
                diffBudgetMs: nil,
                previous: prev,
                current: curr,
                deltaThreshold: 10,
                originalSize: CGSize(width: 200, height: 200)))
        #expect(result.changePercent > 0)
        let firstBox = result.boundingBoxes.first
        #expect(abs((firstBox?.origin.x ?? 0) - 100) < 0.1)
        #expect(abs((firstBox?.origin.y ?? 0) - 0) < 0.1)
    }

    @Test("Quality diff near-zero for identical frames")
    func qualityNoChange() {
        let buffer = WatchCaptureSession.LumaBuffer(width: 4, height: 4, pixels: Array(repeating: 64, count: 16))
        let result = WatchCaptureSession.computeChange(
            using: .init(
                strategy: .quality,
                diffBudgetMs: nil,
                previous: buffer,
                current: buffer,
                deltaThreshold: 10,
                originalSize: CGSize(width: 100, height: 100)))
        #expect(result.changePercent < 0.01)
        #expect(result.boundingBoxes.isEmpty)
    }

    @Test("Quality diff caps at 100")
    func qualityCaps() {
        let prev = WatchCaptureSession.LumaBuffer(width: 2, height: 2, pixels: [0, 0, 0, 0])
        let curr = WatchCaptureSession.LumaBuffer(width: 2, height: 2, pixels: [255, 255, 255, 255])
        let result = WatchCaptureSession.computeChange(
            using: .init(
                strategy: .quality,
                diffBudgetMs: nil,
                previous: prev,
                current: curr,
                deltaThreshold: 10,
                originalSize: CGSize(width: 100, height: 100)))
        #expect(result.changePercent <= 100)
    }

    @Test("Bounding boxes always include overall motion bounds")
    func boundingBoxesIncludeUnion() {
        // Two disjoint regions far apart should still report a union box that spans both.
        let width = 8
        let height = 8
        let prev = WatchCaptureSession.LumaBuffer(
            width: width,
            height: height,
            pixels: Array(repeating: 0, count: width * height))
        var pixels = Array(repeating: UInt8(0), count: width * height)
        func index(_ x: Int, _ y: Int) -> Int { y * width + x }
        // Activate a block in the top-left and another in the bottom-right.
        for y in 0..<2 {
            for x in 0..<2 {
                pixels[index(x, y)] = 255
            }
        }
        for y in (height - 2)..<height {
            for x in (width - 2)..<width {
                pixels[index(x, y)] = 255
            }
        }
        let curr = WatchCaptureSession.LumaBuffer(width: width, height: height, pixels: pixels)
        let result = WatchCaptureSession.computeChange(
            using: .init(
                strategy: .fast,
                diffBudgetMs: nil,
                previous: prev,
                current: curr,
                deltaThreshold: 1,
                originalSize: CGSize(width: 800, height: 800)))
        guard let union = result.boundingBoxes.first else {
            Issue.record("Expected bounding boxes to be reported")
            return
        }
        #expect(union.origin.x == 0)
        #expect(union.origin.y == 0)
        #expect(union.width == 800)
        #expect(union.height == 800)
        #expect(result.boundingBoxes.count <= 5)
    }

    @Test("Stops at max-frames cap and keeps first frame")
    @MainActor
    func respectsFrameCapDuringWatch() async throws {
        let png = Self.makePNG(size: CGSize(width: 20, height: 20))
        let capture = StubScreenCaptureService(result: png, size: CGSize(width: 20, height: 20))
        let screens = StubScreenService()
        let scope = WatchScope(
            kind: .frontmost,
            screenIndex: nil,
            displayUUID: nil,
            windowId: nil,
            applicationIdentifier: nil,
            windowIndex: nil,
            region: nil)

        let options = WatchCaptureOptions(
            duration: 2,
            idleFps: 5,
            activeFps: 5,
            changeThresholdPercent: 0,
            heartbeatSeconds: 0,
            quietMsToIdle: 0,
            maxFrames: 1,
            maxMegabytes: nil,
            highlightChanges: false,
            captureFocus: .auto,
            resolutionCap: nil,
            diffStrategy: .fast,
            diffBudgetMs: nil)

        let output = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("watch-cap-\(UUID().uuidString)", isDirectory: true)

        let dependencies = WatchCaptureDependencies(
            screenCapture: capture,
            screenService: screens)
        let configuration = WatchCaptureConfiguration(
            scope: scope,
            options: options,
            outputRoot: output,
            autoclean: WatchAutocleanConfig(minutes: 1, managed: false))
        let session = WatchCaptureSession(dependencies: dependencies, configuration: configuration)

        let result = try await session.run()
        #expect(result.frames.count == 1)
        #expect(result.warnings.contains { $0.code == .frameCap } || result.warnings.isEmpty == false)
    }

    @Test("Stops at size cap and emits warning")
    @MainActor
    func respectsSizeCapDuringWatch() async throws {
        let png = Self.makePNG(size: CGSize(width: 50, height: 50))
        let capture = StubScreenCaptureService(result: png, size: CGSize(width: 50, height: 50))
        let screens = StubScreenService()
        let scope = WatchScope(
            kind: .frontmost,
            screenIndex: nil,
            displayUUID: nil,
            windowId: nil,
            applicationIdentifier: nil,
            windowIndex: nil,
            region: nil)

        let options = WatchCaptureOptions(
            duration: 2,
            idleFps: 5,
            activeFps: 5,
            changeThresholdPercent: 0,
            heartbeatSeconds: 0,
            quietMsToIdle: 0,
            maxFrames: 100,
            maxMegabytes: 0, // trigger immediately
            highlightChanges: false,
            captureFocus: .auto,
            resolutionCap: nil,
            diffStrategy: .fast,
            diffBudgetMs: nil)

        let output = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("watch-sizecap-\(UUID().uuidString)", isDirectory: true)

        let dependencies = WatchCaptureDependencies(
            screenCapture: capture,
            screenService: screens)
        let configuration = WatchCaptureConfiguration(
            scope: scope,
            options: options,
            outputRoot: output,
            autoclean: WatchAutocleanConfig(minutes: 1, managed: false))
        let session = WatchCaptureSession(dependencies: dependencies, configuration: configuration)

        let result = try await session.run()
        #expect(result.warnings.contains { $0.code == .sizeCap })
    }

    // MARK: - Helpers

    private static func makePNG(size: CGSize) -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            fatalError("Failed to create context")
        }
        ctx.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))
        guard let image = ctx.makeImage() else {
            fatalError("Failed to build CGImage")
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil)
        else {
            fatalError("Failed to create image destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            fatalError("Failed to finalize PNG")
        }
        return data as Data
    }
}

// MARK: - Stubs

@MainActor
private final class StubScreenCaptureService: ScreenCaptureServiceProtocol {
    private let resultData: Data
    private let size: CGSize

    init(result: Data, size: CGSize) {
        self.resultData = result
        self.size = size
    }

    func captureScreen(displayIndex _: Int?, visualizerMode _: CaptureVisualizerMode) async throws -> CaptureResult {
        self.makeResult(mode: .screen)
    }

    func captureWindow(
        appIdentifier _: String,
        windowIndex _: Int?,
        visualizerMode _: CaptureVisualizerMode) async throws -> CaptureResult
    {
        self.makeResult(mode: .window)
    }

    func captureFrontmost(visualizerMode _: CaptureVisualizerMode) async throws -> CaptureResult {
        self.makeResult(mode: .frontmost)
    }

    func captureArea(_ rect: CGRect, visualizerMode _: CaptureVisualizerMode) async throws -> CaptureResult {
        let metadata = CaptureMetadata(
            size: rect.size,
            mode: .area,
            applicationInfo: nil,
            windowInfo: nil,
            displayInfo: DisplayInfo(index: 0, name: "Test", bounds: rect, scaleFactor: 2),
            timestamp: Date())
        return CaptureResult(imageData: self.resultData, savedPath: nil, metadata: metadata, warning: nil)
    }

    func hasScreenRecordingPermission() async -> Bool { true }

    private func makeResult(mode: CaptureMode) -> CaptureResult {
        CaptureResult(
            imageData: self.resultData,
            savedPath: nil,
            metadata: self.baseMetadata(mode: mode),
            warning: nil)
    }

    private func baseMetadata(mode: CaptureMode) -> CaptureMetadata {
        CaptureMetadata(
            size: self.size,
            mode: mode,
            applicationInfo: nil,
            windowInfo: nil,
            displayInfo: DisplayInfo(
                index: 0,
                name: "Test",
                bounds: CGRect(origin: .zero, size: self.size),
                scaleFactor: 2),
            timestamp: Date())
    }
}

@MainActor
private final class StubScreenService: ScreenServiceProtocol {
    func listScreens() -> [ScreenInfo] {
        [
            ScreenInfo(
                index: 0,
                name: "Test",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                visibleFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
                isPrimary: true,
                scaleFactor: 2,
                displayID: 1),
        ]
    }

    func screenContainingWindow(bounds _: CGRect) -> ScreenInfo? { self.listScreens().first }

    func screen(at index: Int) -> ScreenInfo? {
        self.listScreens().first(where: { $0.index == index })
    }

    var primaryScreen: ScreenInfo? { self.listScreens().first }
}
