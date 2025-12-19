import AppKit
import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@_spi(Testing) import PeekabooAutomationKit
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
        #expect(logging.loggedEntries.isEmpty == false)
    }

    @Test("captureScreen respects scale preference")
    func captureScreenRespectsScalePreference() async throws {
        let retinaDisplay = ScreenCaptureService.TestFixtures.Display(
            name: "Retina",
            bounds: CGRect(x: 0, y: 0, width: 1200, height: 800),
            scaleFactor: 2.0,
            imageSize: CGSize(width: 2400, height: 1600),
            imageData: ScreenCaptureService.TestFixtures.makeImage(width: 20, height: 20, color: .systemIndigo))
        let fixtures = ScreenCaptureService.TestFixtures(displays: [retinaDisplay])
        let service = ScreenCaptureService.makeTestService(fixtures: fixtures)

        let logical = try await service.captureScreen(
            displayIndex: 0,
            visualizerMode: .screenshotFlash,
            scale: .logical1x)

        #expect(logical.metadata.size == CGSize(width: 1200, height: 800))
        #expect(logical.metadata.displayInfo?.scaleFactor == 1.0)

        let native = try await service.captureScreen(
            displayIndex: 0,
            visualizerMode: .screenshotFlash,
            scale: .native)

        #expect(native.metadata.size == CGSize(width: 2400, height: 1600))
        #expect(native.metadata.displayInfo?.scaleFactor == 2.0)
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

    @Test("captureWindow scales when requested")
    func captureWindowRespectsScale() async throws {
        let fixtures = self.makeFixtures()
        let service = ScreenCaptureService.makeTestService(fixtures: fixtures)

        let logical = try await service.captureWindow(
            appIdentifier: "com.peekaboo.testapp",
            windowIndex: 0,
            visualizerMode: .screenshotFlash,
            scale: .logical1x)
        #expect(logical.metadata.size == CGSize(width: 900, height: 700))
        #expect(logical.metadata.displayInfo?.scaleFactor == 1.0)

        let native = try await service.captureWindow(
            appIdentifier: "com.peekaboo.testapp",
            windowIndex: 0,
            visualizerMode: .screenshotFlash,
            scale: .native)
        #expect(native.metadata.size == CGSize(width: 900 * 2, height: 700 * 2))
        #expect(native.metadata.displayInfo?.scaleFactor == 2.0)
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
            feedbackClient: StubAutomationFeedbackClient(),
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
            feedbackClient: StubAutomationFeedbackClient(),
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

    @Test("displayLocalSourceRect converts global to display-local")
    func displayLocalSourceRectUsesDisplayOrigin() {
        // ScreenCaptureKit expects `sourceRect` in display-local coordinates (origin at (0,0) for that display),
        // but `SCDisplay.frame` / `SCWindow.frame` are global desktop coordinates (matching `NSScreen.frame`).
        //
        // This is especially important for secondary displays whose frames have non-zero (or negative) origins.
        let displayFrame = CGRect(x: 1920, y: 200, width: 2560, height: 1440)
        let globalRect = CGRect(x: 2000, y: 260, width: 300, height: 200)

        let local = ScreenCaptureService.displayLocalSourceRect(globalRect: globalRect, displayFrame: displayFrame)

        #expect(local == CGRect(x: 80, y: 60, width: 300, height: 200))
    }

    @Test("displayLocalSourceRect handles negative display origins")
    func displayLocalSourceRectHandlesNegativeOrigins() {
        let displayFrame = CGRect(x: -3008, y: 0, width: 3008, height: 1692)
        let globalRect = CGRect(x: -2998, y: 10, width: 200, height: 150)

        let local = ScreenCaptureService.displayLocalSourceRect(globalRect: globalRect, displayFrame: displayFrame)

        #expect(local == CGRect(x: 10, y: 10, width: 200, height: 150))
    }
}

// MARK: - Test Doubles

@MainActor
private final class StubAutomationFeedbackClient: AutomationFeedbackClient, @unchecked Sendable {
    func connect() {}

    func showScreenshotFlash(in _: CGRect) async -> Bool { false }

    func showWatchCapture(in _: CGRect) async -> Bool { false }
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
        visualizerMode _: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        let display = try fixtures.display(at: displayIndex)
        let scaleFactor = scale == .native ? display.scaleFactor : 1.0
        let outputSize = CGSize(width: display.bounds.width * scaleFactor, height: display.bounds.height * scaleFactor)
        let metadata = CaptureMetadata(
            size: outputSize,
            mode: .screen,
            displayInfo: DisplayInfo(
                index: displayIndex ?? 0,
                name: display.name,
                bounds: display.bounds,
                scaleFactor: scale == .native ? display.scaleFactor : 1.0))
        let imageData = ScreenCaptureService.TestFixtures.makeImage(
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            color: .systemTeal)
        return CaptureResult(imageData: imageData, metadata: metadata)
    }

    func captureWindow(
        app: ServiceApplicationInfo,
        windowIndex: Int?,
        correlationId: String,
        visualizerMode _: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
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

        let scaleFactor = scale == .native ? (self.fixtures.displays.first?.scaleFactor ?? 1.0) : 1.0
        let outputSize = CGSize(width: target.bounds.width * scaleFactor, height: target.bounds.height * scaleFactor)
        let imageData = ScreenCaptureService.TestFixtures.makeImage(
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            color: .systemGreen)

        let metadata = CaptureMetadata(
            size: outputSize,
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
                index: windowIndex ?? 0),
            displayInfo: DisplayInfo(
                index: 0,
                name: self.fixtures.displays.first?.name,
                bounds: self.fixtures.displays.first?.bounds ?? target.bounds,
                scaleFactor: scale == .native ? (self.fixtures.displays.first?.scaleFactor ?? 1.0) : 1.0))
        return CaptureResult(imageData: imageData, metadata: metadata)
    }

    func captureWindow(
        windowID: CGWindowID,
        correlationId _: String,
        visualizerMode _: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        let allWindows = self.fixtures.windowsByPID.values.flatMap(\.self)
        guard let target = allWindows.first(where: { CGWindowID($0.title.hashValue) == windowID }) else {
            throw PeekabooError.windowNotFound(criteria: "window_id \(windowID)")
        }

        let scaleFactor = scale == .native ? (self.fixtures.displays.first?.scaleFactor ?? 1.0) : 1.0
        let outputSize = CGSize(width: target.bounds.width * scaleFactor, height: target.bounds.height * scaleFactor)
        let imageData = ScreenCaptureService.TestFixtures.makeImage(
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            color: .systemGreen)

        let metadata = CaptureMetadata(
            size: outputSize,
            mode: .window,
            applicationInfo: target.application,
            windowInfo: ServiceWindowInfo(
                windowID: Int(windowID),
                title: target.title,
                bounds: target.bounds,
                isMinimized: false,
                isMainWindow: true,
                windowLevel: 0,
                alpha: 1.0,
                index: 0),
            displayInfo: DisplayInfo(
                index: 0,
                name: self.fixtures.displays.first?.name,
                bounds: self.fixtures.displays.first?.bounds ?? target.bounds,
                scaleFactor: scale == .native ? (self.fixtures.displays.first?.scaleFactor ?? 1.0) : 1.0))
        return CaptureResult(imageData: imageData, metadata: metadata)
    }

    func captureArea(
        _ rect: CGRect,
        correlationId: String,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        let width = max(1, Int(rect.width.rounded()))
        let height = max(1, Int(rect.height.rounded()))
        let scaleFactor = scale == .native ? (self.fixtures.displays.first?.scaleFactor ?? 1.0) : 1.0
        let imageData = ScreenCaptureService.TestFixtures.makeImage(
            width: Int(CGFloat(width) * scaleFactor),
            height: Int(CGFloat(height) * scaleFactor),
            color: .systemGray)
        let metadata = CaptureMetadata(
            size: CGSize(width: CGFloat(width) * scaleFactor, height: CGFloat(height) * scaleFactor),
            mode: .area,
            displayInfo: DisplayInfo(
                index: 0,
                name: self.fixtures.displays.first?.name,
                bounds: rect,
                scaleFactor: scale == .native ? (self.fixtures.displays.first?.scaleFactor ?? 1.0) : 1.0))
        return CaptureResult(imageData: imageData, metadata: metadata)
    }
}

private final class TimeoutModernOperator: ModernScreenCaptureOperating, @unchecked Sendable {
    private(set) var captureScreenAttempts = 0

    func captureScreen(
        displayIndex: Int?,
        correlationId: String,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        self.captureScreenAttempts += 1
        throw OperationError.timeout(operation: "mock", duration: 0.1)
    }

    func captureWindow(
        app: ServiceApplicationInfo,
        windowIndex: Int?,
        correlationId: String,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        throw OperationError.captureFailed(reason: "Not implemented in TimeoutModernOperator")
    }

    func captureWindow(
        windowID _: CGWindowID,
        correlationId _: String,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        throw OperationError.captureFailed(reason: "Not implemented in TimeoutModernOperator")
    }

    func captureArea(
        _ rect: CGRect,
        correlationId: String,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        throw OperationError.captureFailed(reason: "Not implemented in TimeoutModernOperator")
    }
}
