import CoreGraphics
import PeekabooFoundation
import XCTest
@testable import PeekabooAutomationKit

@MainActor
final class DesktopObservationServiceTests: XCTestCase {
    func testBestWindowPrefersLargestVisibleShareableWindow() {
        let small = Self.window(id: 1, title: "Small", bounds: CGRect(x: 100, y: 100, width: 100, height: 100))
        let minimized = Self.window(
            id: 2,
            title: "Minimized",
            bounds: CGRect(x: 100, y: 100, width: 1000, height: 1000),
            isMinimized: true)
        let large = Self.window(id: 3, title: "Large", bounds: CGRect(x: 100, y: 100, width: 400, height: 300))

        let selected = ObservationTargetResolver.bestWindow(from: [small, minimized, large])

        XCTAssertEqual(selected?.windowID, 3)
    }

    func testBestWindowSkipsAuxiliaryAndOffscreenWindows() {
        let toolbar = Self.window(id: 10, title: "", bounds: CGRect(x: 0, y: 0, width: 2560, height: 30), index: 0)
        let offscreen = Self.window(
            id: 11,
            title: "",
            bounds: CGRect(x: -50000, y: -50000, width: 2560, height: 30),
            index: 1)
        let main = Self.window(
            id: 12,
            title: "Zephyr Agency",
            bounds: CGRect(x: 500, y: 300, width: 1460, height: 945),
            index: 2)

        let selected = ObservationTargetResolver.bestWindow(from: [toolbar, offscreen, main])

        XCTAssertEqual(selected?.windowID, 12)
    }

    func testObservationWithoutDetectionCapturesResolvedWindowID() async throws {
        let imageData = Data([1, 2, 3])
        let app = Self.app()
        let window = Self.window(id: 42, title: "Main", bounds: CGRect(x: 100, y: 100, width: 400, height: 300))
        let applications = RecordingApplicationService(applications: [app], windows: [window])
        let capture = RecordingScreenCaptureService(
            result: Self.captureResult(imageData: imageData, app: app, window: window))
        let automation = RecordingUIAutomationService()
        let service = DesktopObservationService(
            screenCapture: capture,
            automation: automation,
            applications: applications)

        let result = try await service.observe(DesktopObservationRequest(
            target: .app(identifier: "Fixture", window: .automatic),
            detection: DesktopDetectionOptions(mode: .none)))

        XCTAssertEqual(capture.operations, [.windowID(42, .logical1x)])
        XCTAssertNil(result.elements)
        XCTAssertEqual(result.capture.imageData, imageData)
        XCTAssertEqual(result.target.window?.windowID, 42)
        XCTAssertEqual(result.timings.spans.map(\.name), ["target.resolve", "capture.window"])
        XCTAssertEqual(automation.detectCalls, 0)
    }

    func testObservationWithDetectionPassesWindowContextAndWebFocusPolicy() async throws {
        let app = Self.app()
        let window = Self.window(id: 77, title: "Editor", bounds: CGRect(x: 100, y: 100, width: 500, height: 400))
        let applications = RecordingApplicationService(applications: [app], windows: [window])
        let capture = RecordingScreenCaptureService(result: Self.captureResult(app: app, window: window))
        let automation = RecordingUIAutomationService()
        let service = DesktopObservationService(
            screenCapture: capture,
            automation: automation,
            applications: applications)

        let result = try await service.observe(DesktopObservationRequest(
            target: .app(identifier: "Fixture", window: .title("Edit")),
            detection: DesktopDetectionOptions(mode: .accessibility, allowWebFocusFallback: false),
            output: DesktopObservationOutputOptions(snapshotID: "snapshot-1")))

        XCTAssertNotNil(result.elements)
        XCTAssertEqual(automation.detectCalls, 1)
        XCTAssertEqual(automation.lastSnapshotID, "snapshot-1")
        XCTAssertEqual(automation.lastWindowContext?.applicationName, "Fixture")
        XCTAssertEqual(automation.lastWindowContext?.applicationBundleId, "com.example.fixture")
        XCTAssertEqual(automation.lastWindowContext?.windowTitle, "Editor")
        XCTAssertEqual(automation.lastWindowContext?.windowID, 77)
        XCTAssertEqual(automation.lastWindowContext?.shouldFocusWebContent, false)
        XCTAssertEqual(result.timings.spans.map(\.name), ["target.resolve", "capture.window", "detection.ax"])
    }

    private static func app() -> ServiceApplicationInfo {
        ServiceApplicationInfo(
            processIdentifier: 123,
            bundleIdentifier: "com.example.fixture",
            name: "Fixture",
            windowCount: 1)
    }

    private static func window(
        id: Int,
        title: String,
        bounds: CGRect,
        isMinimized: Bool = false,
        index: Int = 0) -> ServiceWindowInfo
    {
        ServiceWindowInfo(
            windowID: id,
            title: title,
            bounds: bounds,
            isMinimized: isMinimized,
            isMainWindow: false,
            windowLevel: 0,
            alpha: 1,
            index: index,
            layer: 0,
            isOnScreen: true,
            sharingState: .readOnly,
            isExcludedFromWindowsMenu: false)
    }

    private static func captureResult(
        imageData: Data = Data([9]),
        app: ServiceApplicationInfo,
        window: ServiceWindowInfo) -> CaptureResult
    {
        CaptureResult(
            imageData: imageData,
            metadata: CaptureMetadata(
                size: window.bounds.size,
                mode: .window,
                applicationInfo: app,
                windowInfo: window))
    }
}

@MainActor
private final class RecordingApplicationService: ApplicationServiceProtocol {
    let applications: [ServiceApplicationInfo]
    let windows: [ServiceWindowInfo]

    init(applications: [ServiceApplicationInfo], windows: [ServiceWindowInfo]) {
        self.applications = applications
        self.windows = windows
    }

    func listApplications() async throws -> UnifiedToolOutput<ServiceApplicationListData> {
        UnifiedToolOutput(
            data: ServiceApplicationListData(applications: self.applications),
            summary: .init(brief: "apps", status: .success),
            metadata: .init(duration: 0))
    }

    func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        guard let app = self.applications.first(where: {
            $0.name == identifier || $0.bundleIdentifier == identifier
        }) else {
            throw DesktopObservationError.targetNotFound(identifier)
        }
        return app
    }

    func listWindows(for _: String, timeout _: Float?) async throws -> UnifiedToolOutput<ServiceWindowListData> {
        UnifiedToolOutput(
            data: ServiceWindowListData(windows: self.windows, targetApplication: self.applications.first),
            summary: .init(brief: "windows", status: .success),
            metadata: .init(duration: 0))
    }

    func getFrontmostApplication() async throws -> ServiceApplicationInfo {
        guard let app = self.applications.first else {
            throw DesktopObservationError.targetNotFound("frontmost")
        }
        return app
    }

    func isApplicationRunning(identifier _: String) async -> Bool {
        true
    }

    func launchApplication(identifier _: String) async throws -> ServiceApplicationInfo {
        self.applications[0]
    }

    func activateApplication(identifier _: String) async throws {}
    func quitApplication(identifier _: String, force _: Bool) async throws -> Bool {
        true
    }

    func hideApplication(identifier _: String) async throws {}
    func unhideApplication(identifier _: String) async throws {}
    func hideOtherApplications(identifier _: String) async throws {}
    func showAllApplications() async throws {}
}

@MainActor
private final class RecordingScreenCaptureService: ScreenCaptureServiceProtocol {
    enum Operation: Equatable {
        case screen(Int?, CaptureScalePreference)
        case window(String, Int?, CaptureScalePreference)
        case windowID(Int, CaptureScalePreference)
        case frontmost(CaptureScalePreference)
        case area(CGRect, CaptureScalePreference)
    }

    private let result: CaptureResult
    var operations: [Operation] = []

    init(result: CaptureResult) {
        self.result = result
    }

    func captureScreen(
        displayIndex: Int?,
        visualizerMode _: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        self.operations.append(.screen(displayIndex, scale))
        return self.result
    }

    func captureWindow(
        appIdentifier: String,
        windowIndex: Int?,
        visualizerMode _: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        self.operations.append(.window(appIdentifier, windowIndex, scale))
        return self.result
    }

    func captureWindow(
        windowID: CGWindowID,
        visualizerMode _: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        self.operations.append(.windowID(Int(windowID), scale))
        return self.result
    }

    func captureFrontmost(
        visualizerMode _: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        self.operations.append(.frontmost(scale))
        return self.result
    }

    func captureArea(
        _ rect: CGRect,
        visualizerMode _: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        self.operations.append(.area(rect, scale))
        return self.result
    }

    func hasScreenRecordingPermission() async -> Bool {
        true
    }
}

@MainActor
private final class RecordingUIAutomationService: UIAutomationServiceProtocol {
    var detectCalls = 0
    var lastSnapshotID: String?
    var lastWindowContext: WindowContext?

    func detectElements(
        in _: Data,
        snapshotId: String?,
        windowContext: WindowContext?) async throws -> ElementDetectionResult
    {
        self.detectCalls += 1
        self.lastSnapshotID = snapshotId
        self.lastWindowContext = windowContext
        return ElementDetectionResult(
            snapshotId: snapshotId ?? "generated",
            screenshotPath: "/tmp/fake.png",
            elements: DetectedElements(),
            metadata: DetectionMetadata(detectionTime: 0, elementCount: 0, method: "fake"))
    }

    func click(target _: ClickTarget, clickType _: ClickType, snapshotId _: String?) async throws {}
    func type(
        text _: String,
        target _: String?,
        clearExisting _: Bool,
        typingDelay _: Int,
        snapshotId _: String?) async throws {}
    func typeActions(_: [TypeAction], cadence _: TypingCadence, snapshotId _: String?) async throws -> TypeResult {
        TypeResult(totalCharacters: 0, keyPresses: 0)
    }

    func scroll(_: ScrollRequest) async throws {}
    func hotkey(keys _: String, holdDuration _: Int) async throws {}
    func swipe(
        from _: CGPoint,
        to _: CGPoint,
        duration _: Int,
        steps _: Int,
        profile _: MouseMovementProfile) async throws {}
    func hasAccessibilityPermission() async -> Bool {
        true
    }

    func waitForElement(target _: ClickTarget, timeout _: TimeInterval, snapshotId _: String?) async throws
        -> WaitForElementResult
    {
        WaitForElementResult(found: false, element: nil, waitTime: 0)
    }

    func drag(_: DragOperationRequest) async throws {}
    func moveMouse(to _: CGPoint, duration _: Int, steps _: Int, profile _: MouseMovementProfile) async throws {}
    func getFocusedElement() -> UIFocusInfo? {
        nil
    }

    func findElement(matching _: UIElementSearchCriteria, in _: String?) async throws -> DetectedElement {
        DetectedElement(id: "B1", type: .button, bounds: .zero)
    }
}
