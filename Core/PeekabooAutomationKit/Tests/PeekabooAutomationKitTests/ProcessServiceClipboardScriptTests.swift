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

        let processService = self.makeProcessService(clipboard: clipboard)

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

        let processService = self.makeProcessService(clipboard: clipboard)

        await XCTAssertThrowsErrorAsync {
            _ = try await processService.executeStep(
                ScriptStep(stepId: "restore-missing", comment: nil, command: "clipboard", params: .generic([
                    "action": "restore",
                    "slot": "missing",
                ])),
                snapshotId: nil)
        }
    }

    func testClipboardFilePathExpandsHomeDirectoryPath() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        let clipboard = ClipboardService(pasteboard: pasteboard)
        let processService = self.makeProcessService(clipboard: clipboard)
        let relativePath = "Library/Caches/peekaboo-clipboard-\(UUID().uuidString).txt"
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(relativePath)
        let tildePath = "~/\(relativePath)"
        try Data("script file payload".utf8).write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await processService.executeStep(
            ScriptStep(stepId: "load-file", comment: nil, command: "clipboard", params: .generic([
                "action": "set",
                "filePath": tildePath,
            ])),
            snapshotId: nil)

        let readBack = try XCTUnwrap(try clipboard.get(prefer: .plainText))
        XCTAssertEqual(String(data: readBack.data, encoding: .utf8), "script file payload")
        guard case let .data(output) = result.output else {
            return XCTFail("Expected structured output")
        }
        guard case let .success(filePath)? = output["filePath"] else {
            return XCTFail("Expected filePath output")
        }
        XCTAssertEqual(filePath, url.path)
    }

    func testClipboardOutputPathExpandsHomeDirectoryPath() async throws {
        let pasteboard = NSPasteboard.withUniqueName()
        let clipboard = ClipboardService(pasteboard: pasteboard)
        let processService = self.makeProcessService(clipboard: clipboard)
        let relativePath = "Library/Caches/peekaboo-clipboard-out-\(UUID().uuidString).txt"
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(relativePath)
        let tildePath = "~/\(relativePath)"
        defer { try? FileManager.default.removeItem(at: url) }

        _ = try clipboard.set(ClipboardPayloadBuilder.textRequest(text: "clipboard output payload"))
        let result = try await processService.executeStep(
            ScriptStep(stepId: "get-file", comment: nil, command: "clipboard", params: .generic([
                "action": "get",
                "output": tildePath,
            ])),
            snapshotId: nil)

        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "clipboard output payload")
        guard case let .data(output) = result.output else {
            return XCTFail("Expected structured output")
        }
        guard case let .success(outputPath)? = output["output"] else {
            return XCTFail("Expected output path")
        }
        XCTAssertEqual(outputPath, url.path)
    }

    private func makeProcessService(clipboard: ClipboardService) -> ProcessService {
        ProcessService(
            applicationService: UnusedApplicationService(),
            screenCaptureService: UnusedScreenCaptureService(),
            snapshotManager: UnusedSnapshotManager(),
            uiAutomationService: UnusedUIAutomationService(),
            windowManagementService: UnusedWindowManagementService(),
            menuService: UnusedMenuService(),
            dockService: UnusedDockService(),
            clipboardService: clipboard)
    }
}
