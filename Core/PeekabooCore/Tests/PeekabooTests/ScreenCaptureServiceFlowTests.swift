import AppKit
import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@Suite("ScreenCaptureService test harness", .tags(.ui))
@MainActor
struct ScreenCaptureServiceFlowTests {
    private func makeFixtures() -> ScreenCaptureService.TestFixtures {
        let primary = ScreenCaptureService.TestFixtures.Display(
            name: "Primary",
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            scaleFactor: 2.0,
            imageSize: CGSize(width: 1920, height: 1080),
            imageData: ScreenCaptureService.TestFixtures.makeImage(width: 10, height: 5, color: .systemBlue))

        let external = ScreenCaptureService.TestFixtures.Display(
            name: "External",
            bounds: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
            scaleFactor: 2.0,
            imageSize: CGSize(width: 2560, height: 1440),
            imageData: ScreenCaptureService.TestFixtures.makeImage(width: 8, height: 8, color: .systemPink))

        let app = ServiceApplicationInfo(
            processIdentifier: 4242,
            bundleIdentifier: "com.peekaboo.testapp",
            name: "TestApp",
            bundlePath: "/Applications/TestApp.app",
            isActive: true,
            isHidden: false,
            windowCount: 2)

        let windows = [
            ScreenCaptureService.TestFixtures.Window(
                application: app,
                title: "Dashboard",
                bounds: CGRect(x: 200, y: 200, width: 900, height: 700),
                imageData: ScreenCaptureService.TestFixtures.makeImage(width: 6, height: 4, color: .systemGreen)),
            ScreenCaptureService.TestFixtures.Window(
                application: app,
                title: "Logs",
                bounds: CGRect(x: 300, y: 300, width: 600, height: 400),
                imageData: ScreenCaptureService.TestFixtures.makeImage(width: 4, height: 3, color: .systemYellow)),
        ]

        return ScreenCaptureService.TestFixtures(displays: [primary, external], windows: windows)
    }

    @Test("captureScreen returns fixture metadata")
    func captureScreenUsesFixtures() async throws {
        let fixtures = self.makeFixtures()
        let logging = MockLoggingService()
        let service = ScreenCaptureService.makeTestService(fixtures: fixtures, loggingService: logging)

        let result = try await service.captureScreen(displayIndex: 1)

        #expect(result.metadata.displayInfo?.name == "External")
        #expect(result.metadata.size == CGSize(width: 2560, height: 1440))
        #expect(result.imageData == fixtures.displays[1].imageData)
        #expect(logging.loggedEntries.isEmpty == false)
    }

    @Test("captureWindow resolves applications via fixtures")
    func captureWindowUsesFixtures() async throws {
        let fixtures = self.makeFixtures()
        let service = ScreenCaptureService.makeTestService(fixtures: fixtures)

        let result = try await service.captureWindow(appIdentifier: "com.peekaboo.testapp", windowIndex: 1)

        #expect(result.metadata.windowInfo?.title == "Logs")
        #expect(result.metadata.applicationInfo?.bundleIdentifier == "com.peekaboo.testapp")
        #expect(result.metadata.windowInfo?.index == 1)
    }

    @Test("permission denial surfaces permission error")
    func permissionFailureShortCircuitsCapture() async {
        let fixtures = self.makeFixtures()
        let service = ScreenCaptureService.makeTestService(fixtures: fixtures, permissionGranted: false)

        do {
            _ = try await service.captureScreen(displayIndex: nil)
            Issue.record("Expected captureScreen to throw when permission denied")
        } catch PeekabooError.permissionDeniedScreenRecording {
            // expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("captureArea returns area metadata")
    func captureAreaRespectsRequestedRect() async throws {
        let fixtures = self.makeFixtures()
        let service = ScreenCaptureService.makeTestService(fixtures: fixtures)
        let rect = CGRect(x: 20, y: 40, width: 128, height: 256)

        let result = try await service.captureArea(rect)

        #expect(result.metadata.mode == .area)
        #expect(result.metadata.size == CGSize(width: rect.width, height: rect.height))
        #expect(result.metadata.displayInfo?.bounds == rect)
    }

    @Test("modern timeout falls back to legacy")
    func modernTimeoutFallsBackToLegacy() async throws {
        let fixtures = self.makeFixtures()
        let failingOperator = TimeoutModernOperator()
        let legacyOperator = FixtureCaptureOperator(fixtures: fixtures)

        let dependencies = ScreenCaptureService.Dependencies(
            visualizerClient: StubVisualizationClient(),
            permissionEvaluator: CountingPermissionEvaluator(),
            fallbackRunner: ScreenCaptureFallbackRunner(apis: [.modern, .legacy]),
            applicationResolver: FixtureResolver(fixtures: fixtures),
            makeModernOperator: { _, _ in failingOperator },
            makeLegacyOperator: { _ in legacyOperator })

        let service = ScreenCaptureService(loggingService: MockLoggingService(), dependencies: dependencies)

        let result = try await service.captureScreen(displayIndex: 0)

        #expect(result.metadata.displayInfo?.name == "Primary")
        #expect(failingOperator.captureScreenAttempts == 1)
    }

    @Test("captureScreen checks permission once")
    func captureScreenChecksPermissionOnce() async throws {
        let fixtures = self.makeFixtures()
        let permission = CountingPermissionEvaluator()

        let dependencies = ScreenCaptureService.Dependencies(
            visualizerClient: StubVisualizationClient(),
            permissionEvaluator: permission,
            fallbackRunner: ScreenCaptureFallbackRunner(apis: [.modern]),
            applicationResolver: FixtureResolver(fixtures: fixtures),
            makeModernOperator: { _, _ in FixtureCaptureOperator(fixtures: fixtures) },
            makeLegacyOperator: { _ in FixtureCaptureOperator(fixtures: fixtures) })

        let service = ScreenCaptureService(loggingService: MockLoggingService(), dependencies: dependencies)

        _ = try await service.captureScreen(displayIndex: nil)

        let recordedCalls = await permission.callCount
        #expect(recordedCalls == 1)
    }
}

// MARK: - Test Doubles

@MainActor
private final class StubVisualizationClient: VisualizationClientProtocol, @unchecked Sendable {
    func connect() {}
    func showScreenshotFlash(in rect: CGRect) async -> Bool { false }
    func showWatchCapture(in rect: CGRect) async -> Bool { false }
}

@MainActor
private final class CountingPermissionEvaluator: ScreenRecordingPermissionEvaluating {
    private(set) var callCount = 0

    func hasPermission(logger: CategoryLogger) async -> Bool {
        self.callCount += 1
        return true
    }
}

private struct FixtureResolver: ApplicationResolving {
    let fixtures: ScreenCaptureService.TestFixtures

    func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        if let app = fixtures.application(for: identifier) {
            return app
        }
        throw NotFoundError.application(identifier)
    }
}

@MainActor
private final class FixtureCaptureOperator: ModernScreenCaptureOperating, LegacyScreenCaptureOperating,
@unchecked Sendable {
    private let fixtures: ScreenCaptureService.TestFixtures

    init(fixtures: ScreenCaptureService.TestFixtures) {
        self.fixtures = fixtures
    }

    func captureScreen(
        displayIndex: Int?,
        correlationId: String,
        visualizerMode _: CaptureVisualizerMode) async throws -> CaptureResult
    {
        let display = try fixtures.display(at: displayIndex)
        let metadata = CaptureMetadata(
            size: display.imageSize,
            mode: .screen,
            displayInfo: DisplayInfo(
                index: displayIndex ?? 0,
                name: display.name,
                bounds: display.bounds,
                scaleFactor: display.scaleFactor))
        return CaptureResult(imageData: display.imageData, metadata: metadata)
    }

    func captureWindow(
        app: ServiceApplicationInfo,
        windowIndex: Int?,
        correlationId: String,
        visualizerMode _: CaptureVisualizerMode) async throws -> CaptureResult
    {
        let windows = self.fixtures.windows(for: app)
        guard !windows.isEmpty else {
            throw NotFoundError.window(app: app.name)
        }

        let target: ScreenCaptureService.TestFixtures.Window
        if let index = windowIndex {
            guard index >= 0, index < windows.count else {
                throw PeekabooError.invalidInput(
                    "windowIndex: Index \(index) is out of range. Available windows: 0-\(windows.count - 1)")
            }
            target = windows[index]
        } else {
            target = windows[0]
        }

        let metadata = CaptureMetadata(
            size: target.bounds.size,
            mode: .window,
            applicationInfo: app,
            windowInfo: ServiceWindowInfo(
                windowID: target.title.hashValue,
                title: target.title,
                bounds: target.bounds,
                isMinimized: false,
                isMainWindow: true,
                windowLevel: 0,
                alpha: 1.0,
                index: windowIndex ?? 0))
        return CaptureResult(imageData: target.imageData, metadata: metadata)
    }

    func captureArea(_ rect: CGRect, correlationId: String) async throws -> CaptureResult {
        let width = max(1, Int(rect.width.rounded()))
        let height = max(1, Int(rect.height.rounded()))
        let imageData = self.fixtures.displays.first?.imageData ?? Data(count: width * height * 4)
        let metadata = CaptureMetadata(
            size: CGSize(width: rect.width, height: rect.height),
            mode: .area,
            displayInfo: DisplayInfo(
                index: 0,
                name: self.fixtures.displays.first?.name,
                bounds: rect,
                scaleFactor: self.fixtures.displays.first?.scaleFactor ?? 1.0))
        return CaptureResult(imageData: imageData, metadata: metadata)
    }
}

private final class TimeoutModernOperator: ModernScreenCaptureOperating, @unchecked Sendable {
    private(set) var captureScreenAttempts = 0

    func captureScreen(
        displayIndex: Int?,
        correlationId: String,
        visualizerMode _: CaptureVisualizerMode) async throws -> CaptureResult
    {
        self.captureScreenAttempts += 1
        throw OperationError.timeout(operation: "mock", duration: 0.1)
    }

    func captureWindow(
        app: ServiceApplicationInfo,
        windowIndex: Int?,
        correlationId: String,
        visualizerMode _: CaptureVisualizerMode) async throws -> CaptureResult
    {
        throw OperationError.captureFailed(reason: "Not implemented in TimeoutModernOperator")
    }

    func captureArea(_ rect: CGRect, correlationId: String) async throws -> CaptureResult {
        throw OperationError.captureFailed(reason: "Not implemented in TimeoutModernOperator")
    }
}
