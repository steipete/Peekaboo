import CoreGraphics
import Foundation
import PeekabooFoundation
import UniformTypeIdentifiers
import XCTest
@testable import PeekabooAutomationKit

@available(macOS 14.0, *)
@MainActor
final class ProcessServiceInteractionScriptTests: XCTestCase {
    func testSwipeWithoutExplicitStartUsesPrimaryScreenServiceCenter() async throws {
        let automation = RecordingSwipeUIAutomationService()
        let processService = ProcessService(
            applicationService: UnusedApplicationService(),
            screenCaptureService: UnusedScreenCaptureService(),
            snapshotManager: UnusedSnapshotManager(),
            uiAutomationService: automation,
            windowManagementService: UnusedWindowManagementService(),
            menuService: UnusedMenuService(),
            dockService: UnusedDockService(),
            clipboardService: UnusedClipboardService(),
            screenService: StaticScreenService(frame: CGRect(x: 100, y: 50, width: 600, height: 400)))

        _ = try await processService.executeStep(
            ScriptStep(stepId: "swipe", comment: nil, command: "swipe", params: .generic([
                "direction": "left",
                "distance": "40",
                "duration": "0.25",
            ])),
            snapshotId: nil)

        XCTAssertEqual(automation.swipes.count, 1)
        XCTAssertEqual(automation.swipes[0].from, CGPoint(x: 400, y: 250))
        XCTAssertEqual(automation.swipes[0].to, CGPoint(x: 360, y: 250))
        XCTAssertEqual(automation.swipes[0].duration, 250)
    }
}

@available(macOS 14.0, *)
@MainActor
private final class UnusedClipboardService: ClipboardServiceProtocol {
    func get(prefer _: UTType?) throws -> ClipboardReadResult? {
        fatalError("unused")
    }

    func set(_: ClipboardWriteRequest) throws -> ClipboardReadResult {
        fatalError("unused")
    }

    func clear() {
        fatalError("unused")
    }

    func save(slot _: String) throws {
        fatalError("unused")
    }

    func restore(slot _: String) throws -> ClipboardReadResult {
        fatalError("unused")
    }
}

@available(macOS 14.0, *)
@MainActor
private final class StaticScreenService: ScreenServiceProtocol {
    private let screen: ScreenInfo

    init(frame: CGRect) {
        self.screen = ScreenInfo(
            index: 0,
            name: "Test Display",
            frame: frame,
            visibleFrame: frame,
            isPrimary: true,
            scaleFactor: 2,
            displayID: 1)
    }

    func listScreens() -> [ScreenInfo] {
        [self.screen]
    }

    func screenContainingWindow(bounds: CGRect) -> ScreenInfo? {
        self.screen.frame.intersects(bounds) ? self.screen : nil
    }

    func screen(at index: Int) -> ScreenInfo? {
        index == 0 ? self.screen : nil
    }

    var primaryScreen: ScreenInfo? {
        self.screen
    }
}

@available(macOS 14.0, *)
@MainActor
private final class RecordingSwipeUIAutomationService: UIAutomationServiceProtocol {
    struct SwipeCall {
        let from: CGPoint
        let to: CGPoint
        let duration: Int
    }

    var swipes: [SwipeCall] = []

    func swipe(from: CGPoint, to: CGPoint, duration: Int, steps _: Int, profile _: MouseMovementProfile) async throws {
        self.swipes.append(SwipeCall(from: from, to: to, duration: duration))
    }

    func detectElements(in _: Data, snapshotId _: String?, windowContext _: WindowContext?) async throws
        -> ElementDetectionResult
    {
        fatalError("unused")
    }

    func click(target _: ClickTarget, clickType _: ClickType, snapshotId _: String?) async throws {
        fatalError("unused")
    }

    func type(text _: String, target _: String?, clearExisting _: Bool, typingDelay _: Int, snapshotId _: String?)
        async throws
    {
        fatalError("unused")
    }

    func typeActions(_: [TypeAction], cadence _: TypingCadence, snapshotId _: String?) async throws -> TypeResult {
        fatalError("unused")
    }

    func scroll(_: ScrollRequest) async throws {
        fatalError("unused")
    }

    func hotkey(keys _: String, holdDuration _: Int) async throws {
        fatalError("unused")
    }

    func hasAccessibilityPermission() async -> Bool {
        fatalError("unused")
    }

    func waitForElement(target _: ClickTarget, timeout _: TimeInterval, snapshotId _: String?) async throws
        -> WaitForElementResult
    {
        fatalError("unused")
    }

    func drag(_: DragOperationRequest) async throws {
        fatalError("unused")
    }

    func moveMouse(to _: CGPoint, duration _: Int, steps _: Int, profile _: MouseMovementProfile) async throws {
        fatalError("unused")
    }

    func getFocusedElement() -> UIFocusInfo? {
        fatalError("unused")
    }

    func findElement(matching _: UIElementSearchCriteria, in _: String?) async throws -> DetectedElement {
        fatalError("unused")
    }
}
