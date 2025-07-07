import CoreGraphics
import Foundation
import Testing
@testable import peekaboo

@Suite("ClickCommand Tests", .serialized)
struct ClickCommandTests {
    @Test("Click command parses query argument")
    func parseQueryArgument() throws {
        let command = try ClickCommand.parse(["Sign In"])
        #expect(command.query == "Sign In")
        #expect(command.on == nil)
        #expect(command.coords == nil)
        #expect(command.waitFor == 5000)
        #expect(command.double == false)
        #expect(command.right == false)
    }

    @Test("Click command parses element ID")
    func parseElementID() throws {
        let command = try ClickCommand.parse(["--on", "B1"])
        #expect(command.query == nil)
        #expect(command.on == "B1")
        #expect(command.coords == nil)
    }

    @Test("Click command parses coordinates")
    func parseCoordinates() throws {
        let command = try ClickCommand.parse(["--coords", "100,200"])
        #expect(command.query == nil)
        #expect(command.on == nil)
        #expect(command.coords == "100,200")
    }

    @Test("Click command parses all options")
    func parseAllOptions() throws {
        let command = try ClickCommand.parse([
            "Submit",
            "--session", "test-123",
            "--wait-for", "10000",
            "--double",
            "--json-output",
        ])
        #expect(command.query == "Submit")
        #expect(command.session == "test-123")
        #expect(command.waitFor == 10000)
        #expect(command.double == true)
        #expect(command.right == false)
        #expect(command.jsonOutput == true)
    }

    @Test("Click command allows right-click")
    func parseRightClick() throws {
        let command = try ClickCommand.parse(["--on", "B1", "--right"])
        #expect(command.right == true)
        #expect(command.double == false)
    }

    @Test("Click result structure")
    func clickResultStructure() {
        // Test using the CGPoint initializer
        let result = ClickResult(
            success: true,
            clickedElement: "AXButton: Save",
            clickLocation: CGPoint(x: 150.0, y: 250.0),
            waitTime: 1.5,
            executionTime: 2.0)

        #expect(result.success == true)
        #expect(result.clickedElement == "AXButton: Save")
        #expect(result.clickLocation["x"] == 150.0)
        #expect(result.clickLocation["y"] == 250.0)
        #expect(result.waitTime == 1.5)
        #expect(result.executionTime == 2.0)
    }

    @Test("Click target validation", arguments: [
        (query: "Button", on: nil, coords: nil, valid: true),
        (query: nil, on: "B1", coords: nil, valid: true),
        (query: nil, on: nil, coords: "100,200", valid: true),
        (query: nil, on: nil, coords: nil, valid: false)
    ])
    func validateClickTarget(query: String?, on: String?, coords: String?, valid: Bool) throws {
        var args: [String] = []

        if let q = query {
            args.append(q)
        }
        if let elementId = on {
            args.append(contentsOf: ["--on", elementId])
        }
        if let c = coords {
            args.append(contentsOf: ["--coords", c])
        }

        // Parsing always succeeds, validation happens at runtime
        let command = try ClickCommand.parse(args)

        if valid {
            // Should have at least one target specified
            #expect(command.query != nil || command.on != nil || command.coords != nil)
        } else {
            // No target specified
            #expect(command.query == nil && command.on == nil && command.coords == nil)
        }
    }
}
