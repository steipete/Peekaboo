import Testing
@testable import peekaboo
import Foundation

#if os(macOS) && swift(>=5.9)
@available(macOS 14.0, *)
@Suite("SeeCommand Tests", .serialized)
struct SeeCommandTests {
    
    @Test("See command parses correctly with minimal arguments")
    func parseMinimalArguments() throws {
        let command = try SeeCommand.parse(["--path", "/tmp/test.png"])
        #expect(command.path == "/tmp/test.png")
        #expect(command.app == nil)
        #expect(command.mode == nil)
        #expect(command.session == nil)
        #expect(command.annotate == false)
        #expect(command.jsonOutput == false)
    }
    
    @Test("See command parses all arguments correctly")
    func parseAllArguments() throws {
        let command = try SeeCommand.parse([
            "--app", "Safari",
            "--path", "/tmp/screenshot.png",
            "--session", "test-session-123",
            "--annotate",
            "--json-output"
        ])
        #expect(command.app == "Safari")
        #expect(command.path == "/tmp/screenshot.png")
        #expect(command.session == "test-session-123")
        #expect(command.annotate == true)
        #expect(command.jsonOutput == true)
    }
    
    @Test("See command handles different capture modes", arguments: [
        ("screen", 0),
        ("window", nil),
        ("frontmost", nil),
        ("multi", nil)
    ])
    func parseCaptureMode(mode: String, screenIndex: Int?) throws {
        var args = ["--mode", mode]
        if let index = screenIndex {
            args.append(contentsOf: ["--screen-index", String(index)])
        }
        
        let command = try SeeCommand.parse(args)
        #expect(command.mode?.rawValue == mode)
        if let index = screenIndex {
            #expect(command.screenIndex == index)
        }
    }
    
    @Test("See result structure contains all required fields")
    func seeResultStructure() {
        let element = SeeResult.UIElement(
            id: "B1",
            role: "AXButton",
            title: "Save",
            label: nil,
            value: nil,
            bounds: Bounds(x: 100, y: 200, width: 80, height: 30),
            isActionable: true
        )
        
        let result = SeeResult(
            sessionId: "test-123",
            screenshotPath: "/tmp/screenshot.png",
            annotatedPath: "/tmp/screenshot_annotated.png",
            uiElements: [element],
            application: "TestApp",
            window: "Test Window",
            timestamp: Date()
        )
        
        #expect(result.sessionId == "test-123")
        #expect(result.screenshotPath == "/tmp/screenshot.png")
        #expect(result.annotatedPath == "/tmp/screenshot_annotated.png")
        #expect(result.uiElements.count == 1)
        #expect(result.uiElements.first?.id == "B1")
        #expect(result.application == "TestApp")
        #expect(result.window == "Test Window")
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
}
#endif