import Foundation
import Testing
import PeekabooCore
@testable import peekaboo

@Suite("SeeCommand Tests", .serialized)
struct SeeCommandTests {
    @Test("See command parses correctly with minimal arguments")
    func parseMinimalArguments() throws {
        let command = try SeeCommand.parse(["--path", "/tmp/test.png"])
        #expect(command.path == "/tmp/test.png")
        #expect(command.app == nil)
        #expect(command.mode == nil) // No longer has default value
        #expect(command.windowTitle == nil)
        #expect(command.annotate == false)
        #expect(command.jsonOutput == false)
    }

    @Test("See command parses all arguments correctly")
    func parseAllArguments() throws {
        let command = try SeeCommand.parse([
            "--app", "Safari",
            "--path", "/tmp/screenshot.png",
            "--annotate",
            "--json-output",
        ])
        #expect(command.app == "Safari")
        #expect(command.path == "/tmp/screenshot.png")
        #expect(command.annotate == true)
        #expect(command.jsonOutput == true)
    }

    @Test("See command handles different capture modes", arguments: [
        "screen",
        "window",
        "frontmost",
    ])
    func parseCaptureMode(modeString: String) throws {
        let command = try SeeCommand.parse(["--mode", modeString])
        #expect(command.mode?.rawValue == modeString)
    }

    @Test("See command auto-infers window mode when app is specified")
    func autoInferWindowModeWithApp() throws {
        let command = try SeeCommand.parse(["--app", "Safari"])
        #expect(command.app == "Safari")
        #expect(command.mode == nil) // Mode not explicitly set
    }

    @Test("See command auto-infers window mode when window title is specified")
    func autoInferWindowModeWithTitle() throws {
        let command = try SeeCommand.parse(["--window-title", "Document"])
        #expect(command.windowTitle == "Document")
        #expect(command.mode == nil) // Mode not explicitly set
    }

    @Test("See result structure contains all required fields")
    func seeResultStructure() {
        let element = UIElementSummary(
            id: "B1",
            role: "AXButton",
            title: "Save",
            label: nil,
            identifier: nil,
            is_actionable: true,
            keyboard_shortcut: nil)

        let result = SeeResult(
            session_id: "test-123",
            screenshot_raw: "/tmp/screenshot.png",
            screenshot_annotated: "/tmp/screenshot_annotated.png",
            ui_map: "/tmp/map.json",
            application_name: "TestApp",
            window_title: "Test Window",
            element_count: 10,
            interactable_count: 5,
            capture_mode: "frontmost",
            analysis_result: nil,
            execution_time: 1.5,
            ui_elements: [element],
            menu_bar: nil)

        #expect(result.session_id == "test-123")
        #expect(result.screenshot_raw == "/tmp/screenshot.png")
        #expect(result.screenshot_annotated == "/tmp/screenshot_annotated.png")
        #expect(result.ui_map == "/tmp/map.json")
        #expect(result.ui_elements.count == 1)
        #expect(result.ui_elements.first?.id == "B1")
        #expect(result.application_name == "TestApp")
        #expect(result.window_title == "Test Window")
    }

    @Test("See command validates path parameter")
    func validatePathParameter() {
        // Test that command can be created with valid path
        #expect(throws: Never.self) {
            _ = try SeeCommand.parse(["--path", "/tmp/valid.png"])
        }

        // Test default path generation when not provided
        #expect(throws: Never.self) {
            let command = try SeeCommand.parse([])
            #expect(command.path == nil)
        }
    }

    @Test("See command with analyze option")
    func parseAnalyzeOption() throws {
        let command = try SeeCommand.parse([
            "--analyze", "What is shown in this screenshot?",
        ])
        #expect(command.analyze == "What is shown in this screenshot?")
    }

    @Test("See command with window title")
    func parseWindowTitle() throws {
        let command = try SeeCommand.parse([
            "--app", "Safari",
            "--window-title", "GitHub",
        ])
        #expect(command.app == "Safari")
        #expect(command.windowTitle == "GitHub")
    }
}
