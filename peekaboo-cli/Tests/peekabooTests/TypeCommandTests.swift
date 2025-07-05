import Testing
@testable import peekaboo
import Foundation

#if os(macOS) && swift(>=5.9)
@available(macOS 14.0, *)
@Suite("TypeCommand Tests")
struct TypeCommandTests {
    
    @Test("Type command parses text argument")
    func parseTextArgument() throws {
        let command = try TypeCommand.parse(["Hello, world!"])
        #expect(command.text == "Hello, world!")
        #expect(command.on == nil)
        #expect(command.clear == false)
        #expect(command.delay == 50)
    }
    
    @Test("Type command parses all options")
    func parseAllOptions() throws {
        let command = try TypeCommand.parse([
            "test@example.com",
            "--on", "T1",
            "--session", "test-123",
            "--clear",
            "--delay", "100",
            "--wait-for", "3000",
            "--json-output"
        ])
        #expect(command.text == "test@example.com")
        #expect(command.on == "T1")
        #expect(command.session == "test-123")
        #expect(command.clear == true)
        #expect(command.delay == 100)
        #expect(command.waitFor == 3000)
        #expect(command.jsonOutput == true)
    }
    
    @Test("Type command requires text argument")
    func requiresTextArgument() {
        #expect(throws: Error.self) {
            _ = try TypeCommand.parse([])
        }
    }
    
    @Test("Text parsing handles special sequences", arguments: [
        ("{return}", TextSegment.key(.return)),
        ("{tab}", TextSegment.key(.tab)),
        ("{escape}", TextSegment.key(.escape)),
        ("{delete}", TextSegment.key(.delete)),
        ("Hello", TextSegment.text("Hello")),
        ("{unknown}", TextSegment.text("{unknown}"))
    ])
    func parseTextSegments(input: String, expected: TextSegment) {
        let segments = TypeCommand.parseTextSegments(input)
        #expect(segments.count == 1)
        
        // Compare segments
        switch (segments.first, expected) {
        case let (.text(actual), .text(exp)):
            #expect(actual == exp)
        case let (.key(actual), .key(exp)):
            #expect(actual == exp)
        default:
            Issue.record("Segment types don't match")
        }
    }
    
    @Test("Complex text parsing")
    func parseComplexText() {
        let segments = TypeCommand.parseTextSegments("Hello{tab}World{return}")
        #expect(segments.count == 4)
        
        guard segments.count == 4 else { return }
        
        if case .text(let text) = segments[0] {
            #expect(text == "Hello")
        } else {
            Issue.record("Expected text segment")
        }
        
        if case .key(let key) = segments[1] {
            #expect(key == .tab)
        } else {
            Issue.record("Expected key segment")
        }
        
        if case .text(let text) = segments[2] {
            #expect(text == "World")
        } else {
            Issue.record("Expected text segment")
        }
        
        if case .key(let key) = segments[3] {
            #expect(key == .return)
        } else {
            Issue.record("Expected key segment")
        }
    }
    
    @Test("Type result structure")
    func typeResultStructure() {
        let result = TypeResult(
            success: true,
            typedText: "Hello, world!",
            targetElement: "AXTextField: Username",
            charactersTyped: 13,
            executionTime: 0.65
        )
        
        #expect(result.success == true)
        #expect(result.typedText == "Hello, world!")
        #expect(result.targetElement == "AXTextField: Username")
        #expect(result.charactersTyped == 13)
        #expect(result.executionTime == 0.65)
    }
}
#endif