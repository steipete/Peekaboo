import CoreGraphics
import PeekabooFoundation
import XCTest
@testable import PeekabooAutomationKit

@MainActor
final class DesktopObservationMenubarTests: XCTestCase {
    func testObservationCapturesResolvedMenuBarBoundsAsArea() async throws {
        let menuBarBounds = CGRect(x: 0, y: 1080, width: 1728, height: 37)
        let capture = MenuBarRecordingScreenCaptureService()
        let service = DesktopObservationService(
            screenCapture: capture,
            automation: MenuBarRecordingAutomationService(),
            targetResolver: MenuBarTargetResolver(
                target: ResolvedObservationTarget(kind: .menubar, bounds: menuBarBounds)))

        let result = try await service.observe(DesktopObservationRequest(
            target: .menubar,
            detection: DesktopDetectionOptions(mode: .none)))

        XCTAssertEqual(capture.capturedAreas, [menuBarBounds])
        XCTAssertEqual(result.target.kind, .menubar)
        XCTAssertEqual(result.target.bounds, menuBarBounds)
        XCTAssertEqual(result.timings.spans.map(\.name), ["state.snapshot", "target.resolve", "capture.area"])
    }

    func testPopoverObservationCapturesResolvedWindowID() async throws {
        let capture = MenuBarRecordingScreenCaptureService()
        let bounds = CGRect(x: 1200, y: 920, width: 320, height: 260)
        let service = DesktopObservationService(
            screenCapture: capture,
            automation: MenuBarRecordingAutomationService(),
            targetResolver: MenuBarTargetResolver(target: ResolvedObservationTarget(
                kind: .menubarPopover,
                app: ApplicationIdentity(processIdentifier: 123, bundleIdentifier: nil, name: "Trimmy"),
                window: WindowIdentity(windowID: 42, title: "", bounds: bounds, index: 0),
                bounds: bounds)))

        let result = try await service.observe(DesktopObservationRequest(
            target: .menubarPopover(hints: ["Trimmy"]),
            detection: DesktopDetectionOptions(mode: .none)))

        XCTAssertEqual(capture.capturedWindowIDs, [42])
        XCTAssertEqual(result.target.kind, .menubarPopover)
        XCTAssertEqual(result.target.bounds, bounds)
        XCTAssertEqual(result.timings.spans.map(\.name), ["state.snapshot", "target.resolve", "capture.area"])
    }

    func testPopoverResolverPrefersHintedOwnerNearMenuBar() {
        let screen = ScreenInfo(
            index: 0,
            name: "Main",
            frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
            visibleFrame: CGRect(x: 0, y: 0, width: 1728, height: 1080),
            isPrimary: true,
            scaleFactor: 2,
            displayID: 1)
        let windows = [
            Self.windowInfo(
                id: 1,
                ownerPID: 100,
                ownerName: "Other",
                bounds: CGRect(x: 100, y: 940, width: 260, height: 120)),
            Self.windowInfo(
                id: 2,
                ownerPID: 200,
                ownerName: "Trimmy",
                bounds: CGRect(x: 1100, y: 860, width: 300, height: 220)),
            Self.windowInfo(
                id: 3,
                ownerPID: 300,
                ownerName: "Window Server",
                title: "Menubar",
                bounds: CGRect(x: 0, y: 1080, width: 1728, height: 37),
                layer: 24),
        ]

        let candidate = ObservationMenuBarPopoverResolver.resolve(
            hints: ["Trimmy"],
            windowList: windows,
            screens: [screen])

        XCTAssertEqual(candidate?.windowID, 2)
        XCTAssertEqual(candidate?.ownerPID, 200)
    }

    private static func windowInfo(
        id: Int,
        ownerPID: Int,
        ownerName: String,
        title: String = "",
        bounds: CGRect,
        layer: Int = 0) -> [String: Any]
    {
        [
            kCGWindowNumber as String: id,
            kCGWindowOwnerPID as String: ownerPID,
            kCGWindowOwnerName as String: ownerName,
            kCGWindowName as String: title,
            kCGWindowLayer as String: layer,
            kCGWindowIsOnscreen as String: true,
            kCGWindowAlpha as String: 1.0,
            kCGWindowBounds as String: [
                "X": bounds.origin.x,
                "Y": bounds.origin.y,
                "Width": bounds.width,
                "Height": bounds.height,
            ],
        ]
    }
}

@MainActor
private final class MenuBarTargetResolver: ObservationTargetResolving {
    private let target: ResolvedObservationTarget

    init(target: ResolvedObservationTarget) {
        self.target = target
    }

    func resolve(
        _: DesktopObservationTargetRequest,
        snapshot _: DesktopStateSnapshot) async throws -> ResolvedObservationTarget
    {
        self.target
    }
}

@MainActor
private final class MenuBarRecordingScreenCaptureService: ScreenCaptureServiceProtocol {
    var capturedAreas: [CGRect] = []
    var capturedWindowIDs: [CGWindowID] = []

    func captureScreen(
        displayIndex _: Int?,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        throw DesktopObservationError.unsupportedTarget("screen")
    }

    func captureWindow(
        appIdentifier _: String,
        windowIndex _: Int?,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        throw DesktopObservationError.unsupportedTarget("window")
    }

    func captureWindow(
        windowID: CGWindowID,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        self.capturedWindowIDs.append(windowID)
        return CaptureResult(
            imageData: Data([4, 5, 6]),
            metadata: CaptureMetadata(size: CGSize(width: 320, height: 260), mode: .window))
    }

    func captureFrontmost(
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        throw DesktopObservationError.unsupportedTarget("frontmost")
    }

    func captureArea(
        _ rect: CGRect,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        self.capturedAreas.append(rect)
        return CaptureResult(
            imageData: Data([1, 2, 3]),
            metadata: CaptureMetadata(size: rect.size, mode: .area))
    }

    func hasScreenRecordingPermission() async -> Bool {
        true
    }
}

@MainActor
private final class MenuBarRecordingAutomationService: UIAutomationServiceProtocol {
    func detectElements(
        in _: Data,
        snapshotId _: String?,
        windowContext _: WindowContext?) async throws -> ElementDetectionResult
    {
        throw DesktopObservationError.unsupportedTarget("detection")
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
