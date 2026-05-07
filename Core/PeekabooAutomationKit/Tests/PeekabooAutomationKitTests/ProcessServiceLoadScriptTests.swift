import AppKit
import PeekabooFoundation
import XCTest
@testable import PeekabooAutomationKit

@available(macOS 14.0, *)
@MainActor
final class ProcessServiceLoadScriptTests: XCTestCase {
    func testLoadScriptInvalidEnumCodingThrowsInvalidInput() async throws {
        let processService = self.makeProcessService()

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
        try badScript.data(using: .utf8)?.write(to: url, options: .atomic)
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

    func testLoadScriptExpandsHomeDirectoryPath() async throws {
        let processService = self.makeProcessService()
        let relativePath = "Library/Caches/peekaboo-script-\(UUID().uuidString).peekaboo.json"
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(relativePath)
        let tildePath = "~/\(relativePath)"
        let script = """
        {
          "description": "home path script",
          "steps": []
        }
        """
        try script.data(using: .utf8)?.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = try await processService.loadScript(from: tildePath)

        XCTAssertEqual(loaded.description, "home path script")
    }

    private func makeProcessService() -> ProcessService {
        let pasteboard = NSPasteboard.withUniqueName()
        let clipboard = ClipboardService(pasteboard: pasteboard)

        return ProcessService(
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
