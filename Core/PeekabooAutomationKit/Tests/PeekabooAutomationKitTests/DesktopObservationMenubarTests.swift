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
            targetResolver: MenuBarTargetResolver(bounds: menuBarBounds))

        let result = try await service.observe(DesktopObservationRequest(
            target: .menubar,
            detection: DesktopDetectionOptions(mode: .none)))

        XCTAssertEqual(capture.capturedAreas, [menuBarBounds])
        XCTAssertEqual(result.target.kind, .menubar)
        XCTAssertEqual(result.target.bounds, menuBarBounds)
        XCTAssertEqual(result.timings.spans.map(\.name), ["state.snapshot", "target.resolve", "capture.area"])
    }
}

@MainActor
private final class MenuBarTargetResolver: ObservationTargetResolving {
    private let bounds: CGRect

    init(bounds: CGRect) {
        self.bounds = bounds
    }

    func resolve(
        _: DesktopObservationTargetRequest,
        snapshot _: DesktopStateSnapshot) async throws -> ResolvedObservationTarget
    {
        ResolvedObservationTarget(kind: .menubar, bounds: self.bounds)
    }
}

@MainActor
private final class MenuBarRecordingScreenCaptureService: ScreenCaptureServiceProtocol {
    var capturedAreas: [CGRect] = []

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
        windowID _: CGWindowID,
        visualizerMode _: CaptureVisualizerMode,
        scale _: CaptureScalePreference) async throws -> CaptureResult
    {
        throw DesktopObservationError.unsupportedTarget("window id")
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
