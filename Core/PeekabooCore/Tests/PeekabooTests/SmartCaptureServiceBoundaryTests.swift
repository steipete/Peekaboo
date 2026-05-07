import AppKit
import CoreGraphics
import Foundation
import Testing
@_spi(Testing) import PeekabooAutomationKit

@MainActor
struct SmartCaptureServiceBoundaryTests {
    @Test
    func `Region capture clamps through injected screen service`() async throws {
        let capture = StubSmartScreenCaptureService()
        let appResolver = StubSmartApplicationResolver(appName: "TestApp")
        let screenService = StubSmartScreenService(
            primary: ScreenInfo(
                index: 0,
                name: "Primary",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                visibleFrame: CGRect(x: 0, y: 0, width: 100, height: 80),
                isPrimary: true,
                scaleFactor: 2,
                displayID: 1))
        let service = SmartCaptureService(
            captureService: capture,
            applicationResolver: appResolver,
            screenService: screenService)

        let result = try await service.captureAroundPoint(
            CGPoint(x: 90, y: 90),
            radius: 30,
            includeContextThumbnail: false)

        #expect(capture.capturedAreas == [CGRect(x: 60, y: 60, width: 40, height: 40)])
        if case let .region(_, _, bounds, _) = result.metadata {
            #expect(bounds == CGRect(x: 60, y: 60, width: 40, height: 40))
        } else {
            Issue.record("Expected region metadata")
        }
    }

    @Test
    func `Diff capture refreshes when injected frontmost app changes`() async throws {
        let capture = StubSmartScreenCaptureService()
        let appResolver = StubSmartApplicationResolver(appName: "First")
        let service = SmartCaptureService(
            captureService: capture,
            applicationResolver: appResolver,
            screenService: StubSmartScreenService())

        let first = try await service.captureIfChanged()
        #expect(first.changed)

        let unchanged = try await service.captureIfChanged()
        #expect(!unchanged.changed)

        appResolver.appName = "Second"
        let refreshed = try await service.captureIfChanged()

        #expect(refreshed.changed)
        #expect(capture.captureScreenCount == 3)
        #expect(appResolver.frontmostCallCount == 5)
    }
}

@MainActor
private final class StubSmartScreenCaptureService: ScreenCaptureServiceProtocol {
    private let imageData = ScreenCaptureService.TestFixtures.makeImage(
        width: 8,
        height: 8,
        color: .systemBlue)
    private(set) var captureScreenCount = 0
    private(set) var capturedAreas: [CGRect] = []

    func captureScreen(
        displayIndex: Int?,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        self.captureScreenCount += 1
        return self.result(mode: .screen)
    }

    func captureWindow(
        appIdentifier _: String,
        windowIndex _: Int?,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        self.result(mode: .window)
    }

    func captureWindow(
        windowID _: CGWindowID,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        self.result(mode: .window)
    }

    func captureFrontmost(
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        self.result(mode: .frontmost)
    }

    func captureArea(
        _ rect: CGRect,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        self.capturedAreas.append(rect)
        return self.result(mode: .area)
    }

    func hasScreenRecordingPermission() async -> Bool {
        true
    }

    private func result(mode: CaptureMode) -> CaptureResult {
        CaptureResult(
            imageData: self.imageData,
            metadata: CaptureMetadata(size: CGSize(width: 8, height: 8), mode: mode))
    }
}

private final class StubSmartApplicationResolver: ApplicationResolving, @unchecked Sendable {
    var appName: String
    private(set) var frontmostCallCount = 0

    init(appName: String) {
        self.appName = appName
    }

    func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        self.info(name: identifier)
    }

    func frontmostApplication() async throws -> ServiceApplicationInfo {
        self.frontmostCallCount += 1
        return self.info(name: self.appName)
    }

    private func info(name: String) -> ServiceApplicationInfo {
        ServiceApplicationInfo(
            processIdentifier: 123,
            bundleIdentifier: "com.example.\(name)",
            name: name,
            bundlePath: nil,
            isActive: true,
            isHidden: false,
            windowCount: 1)
    }
}

@MainActor
private final class StubSmartScreenService: ScreenServiceProtocol {
    private let primary: ScreenInfo?

    init(primary: ScreenInfo? = nil) {
        self.primary = primary
    }

    func listScreens() -> [ScreenInfo] {
        self.primary.map { [$0] } ?? []
    }

    func screenContainingWindow(bounds _: CGRect) -> ScreenInfo? {
        self.primary
    }

    func screen(at _: Int) -> ScreenInfo? {
        self.primary
    }

    var primaryScreen: ScreenInfo? {
        self.primary
    }
}
