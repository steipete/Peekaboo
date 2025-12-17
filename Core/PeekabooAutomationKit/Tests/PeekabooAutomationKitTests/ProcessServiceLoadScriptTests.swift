import AppKit
import PeekabooFoundation
import XCTest

@testable import PeekabooAutomationKit

@available(macOS 14.0, *)
@MainActor
final class ProcessServiceLoadScriptTests: XCTestCase {
    func testLoadScriptInvalidEnumCodingThrowsInvalidInput() async throws {
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

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bad-\(UUID().uuidString).peekaboo.json")

        let badScript = """
        {
          "description": "bad script",
          "steps": [
            {
              "stepId": "bad-params",
              "comment": null,
              "command": "app",
              "params": {
                "generic": {
                  "name": "Playground"
                }
              }
            }
          ]
        }
        """
        try badScript.data(using: .utf8)!.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await processService.loadScript(from: url.path)
            XCTFail("Expected loadScript to throw")
        } catch let error as PeekabooError {
            switch error {
            case let .invalidInput(message):
                XCTAssertTrue(message.contains("Invalid script JSON"), "Unexpected message: \(message)")
                XCTAssertTrue(message.contains("Tip:"), "Missing enum coding tip: \(message)")
            default:
                XCTFail("Expected invalidInput, got: \(error)")
            }
        }
    }
}
