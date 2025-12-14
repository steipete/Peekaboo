import AppKit
import PeekabooFoundation
import UniformTypeIdentifiers
import XCTest

@testable import PeekabooAutomationKit

@available(macOS 14.0, *)
@MainActor
final class ProcessServiceClipboardScriptTests: XCTestCase {
    func testClipboardSaveRestoreWithinOneScriptExecution() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        let clipboard = ClipboardService(pasteboard: pasteboard)

        let processService = ProcessService(
            applicationService: UnusedApplicationService(),
            screenCaptureService: UnusedScreenCaptureService(),
            snapshotManager: UnusedSnapshotManager(),
            uiAutomationService: UnusedUIAutomationService(),
            windowManagementService: UnusedWindowManagementService(),
            menuService: UnusedMenuService(),
            dockService: UnusedDockService(),
            clipboardService: clipboard)

        _ = try await processService.executeStep(
            ScriptStep(stepId: "set-a", comment: nil, command: "clipboard", params: .generic([
                "action": "set",
                "text": "hello",
            ])),
            snapshotId: nil)

        _ = try await processService.executeStep(
            ScriptStep(stepId: "save-a", comment: nil, command: "clipboard", params: .generic([
                "action": "save",
                "slot": "a",
            ])),
            snapshotId: nil)

        _ = try await processService.executeStep(
            ScriptStep(stepId: "set-b", comment: nil, command: "clipboard", params: .generic([
                "action": "set",
                "text": "bye",
            ])),
            snapshotId: nil)

        _ = try await processService.executeStep(
            ScriptStep(stepId: "restore-a", comment: nil, command: "clipboard", params: .generic([
                "action": "restore",
                "slot": "a",
            ])),
            snapshotId: nil)

        let restored = try XCTUnwrap(try clipboard.get(prefer: .plainText))
        let restoredText = try XCTUnwrap(String(data: restored.data, encoding: .utf8))
        XCTAssertEqual(restoredText, "hello")
    }

    func testClipboardRestoreMissingSlotThrows() async {
        let pasteboard = NSPasteboard.withUniqueName()
        let clipboard = ClipboardService(pasteboard: pasteboard)

        let processService = ProcessService(
            applicationService: UnusedApplicationService(),
            screenCaptureService: UnusedScreenCaptureService(),
            snapshotManager: UnusedSnapshotManager(),
            uiAutomationService: UnusedUIAutomationService(),
            windowManagementService: UnusedWindowManagementService(),
            menuService: UnusedMenuService(),
            dockService: UnusedDockService(),
            clipboardService: clipboard)

        await XCTAssertThrowsErrorAsync {
            _ = try await processService.executeStep(
                ScriptStep(stepId: "restore-missing", comment: nil, command: "clipboard", params: .generic([
                    "action": "restore",
                    "slot": "missing",
                ])),
                snapshotId: nil)
        }
    }
}

@available(macOS 14.0, *)
private func XCTAssertThrowsErrorAsync(
    _ operation: @escaping () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line) async
{
    do {
        try await operation()
        XCTFail("Expected error to be thrown", file: file, line: line)
    } catch {
        // expected
    }
}

@available(macOS 14.0, *)
@MainActor
private final class UnusedApplicationService: ApplicationServiceProtocol {
    func listApplications() async throws -> UnifiedToolOutput<ServiceApplicationListData> { fatalError("unused") }
    func findApplication(identifier: String) async throws -> ServiceApplicationInfo { fatalError("unused") }
    func listWindows(
        for appIdentifier: String,
        timeout: Float?) async throws -> UnifiedToolOutput<ServiceWindowListData>
    {
        fatalError("unused")
    }

    func getFrontmostApplication() async throws -> ServiceApplicationInfo { fatalError("unused") }
    func isApplicationRunning(identifier: String) async -> Bool { fatalError("unused") }
    func launchApplication(identifier: String) async throws -> ServiceApplicationInfo { fatalError("unused") }
    func activateApplication(identifier: String) async throws { fatalError("unused") }
    func quitApplication(identifier: String, force: Bool) async throws -> Bool { fatalError("unused") }
    func hideApplication(identifier: String) async throws { fatalError("unused") }
    func unhideApplication(identifier: String) async throws { fatalError("unused") }
    func hideOtherApplications(identifier: String) async throws { fatalError("unused") }
    func showAllApplications() async throws { fatalError("unused") }
}

@available(macOS 14.0, *)
@MainActor
private final class UnusedScreenCaptureService: ScreenCaptureServiceProtocol {
    func captureScreen(
        displayIndex: Int?,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        fatalError("unused")
    }

    func captureWindow(
        appIdentifier: String,
        windowIndex: Int?,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        fatalError("unused")
    }

    func captureFrontmost(
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        fatalError("unused")
    }

    func captureArea(
        _ rect: CGRect,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        fatalError("unused")
    }

    func hasScreenRecordingPermission() async -> Bool { fatalError("unused") }
}

@available(macOS 14.0, *)
@MainActor
private final class UnusedSnapshotManager: SnapshotManagerProtocol {
    func createSnapshot() async throws -> String { fatalError("unused") }
    func storeDetectionResult(snapshotId: String, result: ElementDetectionResult) async throws { fatalError("unused") }
    func getDetectionResult(snapshotId: String) async throws -> ElementDetectionResult? { fatalError("unused") }
    func getMostRecentSnapshot() async -> String? { fatalError("unused") }
    func getMostRecentSnapshot(applicationBundleId: String) async -> String? { fatalError("unused") }
    func listSnapshots() async throws -> [SnapshotInfo] { fatalError("unused") }
    func cleanSnapshot(snapshotId: String) async throws { fatalError("unused") }
    func cleanSnapshotsOlderThan(days: Int) async throws -> Int { fatalError("unused") }
    func cleanAllSnapshots() async throws -> Int { fatalError("unused") }
    func getSnapshotStoragePath() -> String { fatalError("unused") }
    // swiftlint:disable function_parameter_count
    func storeScreenshot(
        snapshotId: String,
        screenshotPath: String,
        applicationBundleId: String?,
        applicationProcessId: Int32?,
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?) async throws
    {
        fatalError("unused")
    }

    // swiftlint:enable function_parameter_count

    func storeAnnotatedScreenshot(snapshotId: String, annotatedScreenshotPath: String) async throws {
        fatalError("unused")
    }

    func getElement(snapshotId: String, elementId: String) async throws -> UIElement? { fatalError("unused") }
    func findElements(snapshotId: String, matching query: String) async throws -> [UIElement] { fatalError("unused") }
    func getUIAutomationSnapshot(snapshotId: String) async throws -> UIAutomationSnapshot? { fatalError("unused") }
}

@available(macOS 14.0, *)
@MainActor
private final class UnusedUIAutomationService: UIAutomationServiceProtocol {
    func detectElements(in imageData: Data, snapshotId: String?, windowContext: WindowContext?) async throws
        -> ElementDetectionResult
    {
        fatalError("unused")
    }

    func click(target: ClickTarget, clickType: ClickType, snapshotId: String?) async throws { fatalError("unused") }

    func type(text: String, target: String?, clearExisting: Bool, typingDelay: Int, snapshotId: String?) async throws {
        fatalError("unused")
    }

    func typeActions(_ actions: [TypeAction], cadence: TypingCadence, snapshotId: String?) async throws -> TypeResult {
        fatalError("unused")
    }

    func scroll(_ request: ScrollRequest) async throws { fatalError("unused") }
    func hotkey(keys: String, holdDuration: Int) async throws { fatalError("unused") }
    func swipe(from: CGPoint, to: CGPoint, duration: Int, steps: Int, profile: MouseMovementProfile) async throws {
        fatalError("unused")
    }

    func hasAccessibilityPermission() async -> Bool { fatalError("unused") }
    func waitForElement(
        target: ClickTarget,
        timeout: TimeInterval,
        snapshotId: String?) async throws -> WaitForElementResult
    {
        fatalError("unused")
    }

    // swiftlint:disable function_parameter_count
    func drag(
        from: CGPoint,
        to: CGPoint,
        duration: Int,
        steps: Int,
        modifiers: String?,
        profile: MouseMovementProfile) async throws
    {
        fatalError("unused")
    }

    // swiftlint:enable function_parameter_count

    func moveMouse(to: CGPoint, duration: Int, steps: Int, profile: MouseMovementProfile) async throws {
        fatalError("unused")
    }

    func getFocusedElement() -> UIFocusInfo? { fatalError("unused") }
    func findElement(matching criteria: UIElementSearchCriteria, in appName: String?) async throws -> DetectedElement {
        fatalError("unused")
    }
}

@available(macOS 14.0, *)
private final class UnusedWindowManagementService: WindowManagementServiceProtocol {
    func closeWindow(target: WindowTarget) async throws { fatalError("unused") }
    func minimizeWindow(target: WindowTarget) async throws { fatalError("unused") }
    func maximizeWindow(target: WindowTarget) async throws { fatalError("unused") }
    func moveWindow(target: WindowTarget, to position: CGPoint) async throws { fatalError("unused") }
    func resizeWindow(target: WindowTarget, to size: CGSize) async throws { fatalError("unused") }
    func setWindowBounds(target: WindowTarget, bounds: CGRect) async throws { fatalError("unused") }
    func focusWindow(target: WindowTarget) async throws { fatalError("unused") }
    func listWindows(target: WindowTarget) async throws -> [ServiceWindowInfo] { fatalError("unused") }
    func getFocusedWindow() async throws -> ServiceWindowInfo? { fatalError("unused") }
}

@available(macOS 14.0, *)
@MainActor
private final class UnusedMenuService: MenuServiceProtocol {
    func listMenus(for appIdentifier: String) async throws -> MenuStructure { fatalError("unused") }
    func listFrontmostMenus() async throws -> MenuStructure { fatalError("unused") }
    func clickMenuItem(app: String, itemPath: String) async throws { fatalError("unused") }
    func clickMenuItemByName(app: String, itemName: String) async throws { fatalError("unused") }
    func clickMenuExtra(title: String) async throws { fatalError("unused") }
    func listMenuExtras() async throws -> [MenuExtraInfo] { fatalError("unused") }
    func listMenuBarItems(includeRaw: Bool) async throws -> [MenuBarItemInfo] { fatalError("unused") }
    func clickMenuBarItem(named name: String) async throws -> ClickResult { fatalError("unused") }
    func clickMenuBarItem(at index: Int) async throws -> ClickResult { fatalError("unused") }
}

@available(macOS 14.0, *)
@MainActor
private final class UnusedDockService: DockServiceProtocol {
    func listDockItems(includeAll: Bool) async throws -> [DockItem] { fatalError("unused") }
    func launchFromDock(appName: String) async throws { fatalError("unused") }
    func addToDock(path: String, persistent: Bool) async throws { fatalError("unused") }
    func removeFromDock(appName: String) async throws { fatalError("unused") }
    func rightClickDockItem(appName: String, menuItem: String?) async throws { fatalError("unused") }
    func hideDock() async throws { fatalError("unused") }
    func showDock() async throws { fatalError("unused") }
    func isDockAutoHidden() async -> Bool { fatalError("unused") }
    func findDockItem(name: String) async throws -> DockItem { fatalError("unused") }
}
