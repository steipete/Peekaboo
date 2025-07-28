import Testing
import Foundation
import ArgumentParser
import PeekabooCore
@testable import peekaboo

@Suite("MoveCommand Tests")
struct MoveCommandTests {
    
    @Test("Parse coordinates")
    func testParseCoordinates() throws {
        var command = try MoveCommand.parse(["100,200"])
        #expect(command.coordinates == "100,200")
        #expect(command.to == nil)
        #expect(command.id == nil)
        #expect(command.center == false)
    }
    
    @Test("Parse move to element by text")
    func testParseMoveToElementByText() throws {
        var command = try MoveCommand.parse(["--to", "Submit Button"])
        #expect(command.coordinates == nil)
        #expect(command.to == "Submit Button")
        #expect(command.id == nil)
        #expect(command.center == false)
    }
    
    @Test("Parse move to element by ID")
    func testParseMoveToElementById() throws {
        var command = try MoveCommand.parse(["--id", "B3"])
        #expect(command.coordinates == nil)
        #expect(command.to == nil)
        #expect(command.id == "B3")
        #expect(command.center == false)
    }
    
    @Test("Parse move to center")
    func testParseMoveToCenter() throws {
        var command = try MoveCommand.parse(["--center"])
        #expect(command.coordinates == nil)
        #expect(command.to == nil)
        #expect(command.id == nil)
        #expect(command.center == true)
    }
    
    @Test("Parse smooth movement")
    func testParseSmoothMovement() throws {
        var command = try MoveCommand.parse(["100,200", "--smooth"])
        #expect(command.coordinates == "100,200")
        #expect(command.smooth == true)
        #expect(command.duration == nil)
        #expect(command.steps == 20)
    }
    
    @Test("Parse custom duration and steps")
    func testParseCustomDurationAndSteps() throws {
        var command = try MoveCommand.parse(["100,200", "--duration", "1000", "--steps", "50"])
        #expect(command.coordinates == "100,200")
        #expect(command.duration == 1000)
        #expect(command.steps == 50)
    }
    
    @Test("Parse with session ID")
    func testParseWithSessionId() throws {
        var command = try MoveCommand.parse(["--id", "B1", "--session", "test-session-123"])
        #expect(command.id == "B1")
        #expect(command.session == "test-session-123")
    }
    
    @Test("Parse JSON output")
    func testParseJsonOutput() throws {
        var command = try MoveCommand.parse(["100,200", "--json-output"])
        #expect(command.coordinates == "100,200")
        #expect(command.jsonOutput == true)
    }
    
    @Test("Invalid coordinates format")
    func testInvalidCoordinatesFormat() {
        #expect(throws: Error.self) {
            _ = try MoveCommand.parse(["100"])
        }
    }
    
    @Test("No target specified")
    func testNoTargetSpecified() {
        #expect(throws: Error.self) {
            _ = try MoveCommand.parse([])
        }
    }
    
    @Test("Multiple targets specified")
    func testMultipleTargetsSpecified() throws {
        // This should parse successfully but would fail during execution
        var command = try MoveCommand.parse(["100,200", "--to", "Button"])
        #expect(command.coordinates == "100,200")
        #expect(command.to == "Button")
    }
}
