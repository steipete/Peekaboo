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
