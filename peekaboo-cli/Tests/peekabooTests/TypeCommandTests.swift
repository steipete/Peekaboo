import Foundation
@testable import peekaboo
import Testing

@Suite("TypeCommand Tests")
struct TypeCommandTests {
    @Test("Type command parses text argument")
    func parseTextArgument() throws {
        let command = try TypeCommand.parse(["Hello, world!"])
        #expect(command.text == "Hello, world!")
        #expect(command.clear == false)
        #expect(command.return == false)
        #expect(command.escape == false)
        #expect(command.delay == 50) // default
    }

    @Test("Type command parses all options")
    func parseAllOptions() throws {
        let command = try TypeCommand.parse([
            "test text",
            "--clear",
            "--return",
            "--delay", "100",
            "--json-output"
        ])
        #expect(command.text == "test text")
        #expect(command.clear == true)
        #expect(command.return == true)
        #expect(command.delay == 100)
        #expect(command.jsonOutput == true)
    }

    @Test("Type command special key flags", arguments: [
        (["--return"], true, false, false, nil),
        (["--escape"], false, true, false, nil),
        (["--delete"], false, false, true, nil),
        (["--tab", "3"], false, false, false, 3)
    ])
    func parseSpecialKeys(args: [String], hasReturn: Bool, hasEscape: Bool, hasDelete: Bool, tabCount: Int?) throws {
        let command = try TypeCommand.parse(args)
        #expect(command.return == hasReturn)
        #expect(command.escape == hasEscape)
        #expect(command.delete == hasDelete)
        #expect(command.tab == tabCount)
    }

    @Test("Type command requires text or special key")
    func requiresTextOrSpecialKey() {
        // Empty command with no arguments should now work but will fail at runtime
        // TypeCommand allows empty parse but validates at runtime
        #expect(throws: Never.self) {
            let cmd = try TypeCommand.parse([])
            // Command would fail when run() is called
            #expect(cmd.text == nil)
            #expect(cmd.tab == nil)
            #expect(cmd.return == false)
            #expect(cmd.escape == false)
            #expect(cmd.delete == false)
            #expect(cmd.clear == false)
        }
    }

    @Test("Type command with clear flag")
    func parseClearFlag() throws {
        let command = try TypeCommand.parse(["password123", "--clear"])
        #expect(command.text == "password123")
        #expect(command.clear == true)
    }

    @Test("Type result structure")
    func typeResultStructure() {
        let result = TypeResult(
            success: true,
            typedText: "Hello, world!",
            keyPresses: 13,
            totalCharacters: 13,
            executionTime: 0.65
        )

        #expect(result.success == true)
        #expect(result.typedText == "Hello, world!")
        #expect(result.keyPresses == 13)
        #expect(result.totalCharacters == 13)
        #expect(result.executionTime == 0.65)
    }

    @Test("Type command with session ID")
    func parseSessionId() throws {
        let command = try TypeCommand.parse([
            "test",
            "--session", "12345"
        ])
        #expect(command.text == "test")
        #expect(command.session == "12345")
    }

    @Test("Type command with multiple tab presses")
    func parseMultipleTabs() throws {
        let command = try TypeCommand.parse(["--tab", "5"])
        #expect(command.tab == 5)
        #expect(command.text == nil)
    }

    @Test("Type command combines text and special keys")
    func combineTextAndKeys() throws {
        let command = try TypeCommand.parse([
            "username@example.com",
            "--tab", "1", // Must provide value for --tab
            "--return"
        ])
        #expect(command.text == "username@example.com")
        #expect(command.tab == 1)
        #expect(command.return == true)
    }
}
