import ArgumentParser
import Foundation
import Testing
@testable import peekaboo

@Suite("TypeCommand Tests")
struct TypeCommandTests {
    @Test("Type command with text argument")
    func typeWithText() throws {
        let command = try TypeCommand.parse(["Hello World", "--json-output"])

        #expect(command.text == "Hello World")
        #expect(command.jsonOutput == true)
        #expect(command.delay == 2) // default delay
        #expect(command.pressReturn == false)
        #expect(command.clear == false)
    }

    @Test("Type command with special keys")
    func typeWithSpecialKeys() throws {
        let command = try TypeCommand.parse(["--tab", "2", "--return", "--json-output"])

        #expect(command.text == nil)
        #expect(command.tab == 2)
        #expect(command.pressReturn == true)
        #expect(command.escape == false)
        #expect(command.delete == false)
    }

    @Test("Type command with clear flag")
    func typeWithClear() throws {
        let command = try TypeCommand.parse(["New Text", "--clear", "--json-output"])

        #expect(command.text == "New Text")
        #expect(command.clear == true)
        #expect(command.delay == 2) // default delay
    }

    @Test("Type command with custom delay")
    func typeWithCustomDelay() throws {
        let command = try TypeCommand.parse(["Fast", "--delay", "0", "--json-output"])

        #expect(command.text == "Fast")
        #expect(command.delay == 0)
    }

    @Test("Type command argument parsing")
    func typeCommandArgumentParsing() throws {
        let command = try TypeCommand.parse(["Hello World", "--delay", "10", "--return"])

        #expect(command.text == "Hello World")
        #expect(command.delay == 10)
        #expect(command.pressReturn == true)
    }

    @Test("Type command with all special keys")
    func typeWithAllSpecialKeys() throws {
        let command = try TypeCommand.parse([
            "Test",
            "--clear",
            "--tab",
            "1",
            "--return",
            "--escape",
            "--delete",
            "--json-output"
        ])

        #expect(command.text == "Test")
        #expect(command.clear == true)
        #expect(command.tab == 1)
        #expect(command.pressReturn == true)
        #expect(command.escape == true)
        #expect(command.delete == true)
    }

    @Test("Process text with escape sequences")
    func processEscapeSequences() throws {
        // Test newline escape
        let newlineActions = TypeCommand.processTextWithEscapes("Line 1\\nLine 2")
        #expect(newlineActions.count == 3)
        if case .text("Line 1") = newlineActions[0] { } else { Issue.record("Expected text 'Line 1'") }
        if case .key(.return) = newlineActions[1] { } else { Issue.record("Expected return key") }
        if case .text("Line 2") = newlineActions[2] { } else { Issue.record("Expected text 'Line 2'") }

        // Test tab escape
        let tabActions = TypeCommand.processTextWithEscapes("Name:\\tJohn")
        #expect(tabActions.count == 3)
        if case .text("Name:") = tabActions[0] { } else { Issue.record("Expected text 'Name:'") }
        if case .key(.tab) = tabActions[1] { } else { Issue.record("Expected tab key") }
        if case .text("John") = tabActions[2] { } else { Issue.record("Expected text 'John'") }

        // Test backspace escape
        let backspaceActions = TypeCommand.processTextWithEscapes("ABC\\b")
        #expect(backspaceActions.count == 2)
        if case .text("ABC") = backspaceActions[0] { } else { Issue.record("Expected text 'ABC'") }
        if case .key(.delete) = backspaceActions[1] { } else { Issue.record("Expected delete key") }

        // Test escape key
        let escapeActions = TypeCommand.processTextWithEscapes("Cancel\\e")
        #expect(escapeActions.count == 2)
        if case .text("Cancel") = escapeActions[0] { } else { Issue.record("Expected text 'Cancel'") }
        if case .key(.escape) = escapeActions[1] { } else { Issue.record("Expected escape key") }

        // Test literal backslash
        let backslashActions = TypeCommand.processTextWithEscapes("Path: C\\\\data")
        #expect(backslashActions.count == 1)
        if case let .text(value) = backslashActions[0] {
            #expect(value == "Path: C\\data", "Value was: \(value)")
        } else {
            Issue.record("Expected text with backslash")
        }
    }

    @Test("Complex escape sequence combinations")
    func complexEscapeSequences() throws {
        // Test multiple escape sequences
        let complexActions = TypeCommand.processTextWithEscapes("Line 1\\nLine 2\\tTabbed\\bFixed\\eEsc\\\\Path")
        #expect(complexActions.count == 9)

        // Verify the sequence
        if case .text("Line 1") = complexActions[0] { } else { Issue.record("Expected 'Line 1'") }
        if case .key(.return) = complexActions[1] { } else { Issue.record("Expected return") }
        if case .text("Line 2") = complexActions[2] { } else { Issue.record("Expected 'Line 2'") }
        if case .key(.tab) = complexActions[3] { } else { Issue.record("Expected tab") }
        if case .text("Tabbed") = complexActions[4] { } else { Issue.record("Expected 'Tabbed'") }
        if case .key(.delete) = complexActions[5] { } else { Issue.record("Expected delete") }
        if case .text("Fixed") = complexActions[6] { } else { Issue.record("Expected 'Fixed'") }
        if case .key(.escape) = complexActions[7] { } else { Issue.record("Expected escape") }
        if case .text("Esc\\Path") = complexActions[8] { } else { Issue.record("Expected 'Esc\\Path'") }
    }

    @Test("Empty and edge case escape sequences")
    func edgeCaseEscapeSequences() throws {
        // Empty text
        let emptyActions = TypeCommand.processTextWithEscapes("")
        #expect(emptyActions.isEmpty)

        // Only escape sequences
        let onlyEscapes = TypeCommand.processTextWithEscapes("\\n\\t\\b\\e")
        #expect(onlyEscapes.count == 4)

        // Text ending with incomplete escape
        let incompleteEscape = TypeCommand.processTextWithEscapes("Text\\\\")
        #expect(incompleteEscape.count == 1)
        if case .text("Text\\") = incompleteEscape[0] { } else { Issue.record("Expected 'Text\\'") }

        // Multiple consecutive escapes
        let consecutiveEscapes = TypeCommand.processTextWithEscapes("Text\\n\\n\\t\\t")
        #expect(consecutiveEscapes.count == 5)
        if case .text("Text") = consecutiveEscapes[0] { } else { Issue.record("Expected 'Text'") }
        if case .key(.return) = consecutiveEscapes[1] { } else { Issue.record("Expected return") }
        if case .key(.return) = consecutiveEscapes[2] { } else { Issue.record("Expected return") }
        if case .key(.tab) = consecutiveEscapes[3] { } else { Issue.record("Expected tab") }
        if case .key(.tab) = consecutiveEscapes[4] { } else { Issue.record("Expected tab") }
    }

    @Test("Parse type command with escape sequences")
    func parseWithEscapeSequences() throws {
        // Test parsing text with escape sequences
        // Note: The escape sequences are processed at runtime, not during parsing
        let command = try TypeCommand.parse(["Line 1\\nLine 2", "--delay", "50"])

        #expect(command.text == "Line 1\\nLine 2")
        #expect(command.delay == 50)
    }
}
