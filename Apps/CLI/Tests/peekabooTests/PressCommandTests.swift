import ArgumentParser
import Foundation
import Testing
@testable import peekaboo

@Suite("PressCommand Tests")
struct PressCommandTests {
    @Test("Press command with single key")
    func pressSingleKey() throws {
        let command = try PressCommand.parse(["return", "--json-output"])

        #expect(command.keys == ["return"])
        #expect(command.count == 1) // default count
        #expect(command.delay == 100) // default delay
        #expect(command.hold == 50) // default hold
    }

    @Test("Press command with multiple keys")
    func pressMultipleKeys() throws {
        let command = try PressCommand.parse(["tab", "tab", "return", "--json-output"])

        #expect(command.keys == ["tab", "tab", "return"])
        #expect(command.count == 1)
    }

    @Test("Press command with count")
    func pressWithCount() throws {
        let command = try PressCommand.parse(["tab", "--count", "3", "--json-output"])

        #expect(command.keys == ["tab"])
        #expect(command.count == 3)
    }

    @Test("Press command with custom delay")
    func pressWithCustomDelay() throws {
        let command = try PressCommand.parse(["down", "--delay", "200", "--json-output"])

        #expect(command.keys == ["down"])
        #expect(command.delay == 200)
    }

    @Test("Press command argument parsing")
    func pressCommandArgumentParsing() throws {
        let command = try PressCommand.parse(["return", "--count", "2", "--delay", "150"])

        #expect(command.keys == ["return"])
        #expect(command.count == 2)
        #expect(command.delay == 150)
    }

    @Test("Press command with multiple keys parsing")
    func pressMultipleKeysParsing() throws {
        let command = try PressCommand.parse(["tab", "tab", "return"])

        #expect(command.keys == ["tab", "tab", "return"])
    }

    @Test("Press command with special keys")
    func pressSpecialKeys() throws {
        // Test various special keys
        let specialKeys = [
            "escape",
            "delete",
            "forward_delete",
            "up", "down", "left", "right",
            "home", "end",
            "pageup", "pagedown",
            "f1", "f12",
            "caps_lock",
            "clear",
            "help",
            "enter", // Numeric keypad enter
            "space"
        ]

        for key in specialKeys {
            let command = try PressCommand.parse([key])
            #expect(command.keys == [key])
        }
    }

    @Test("Press command with arrow keys")
    func pressArrowKeys() throws {
        let command = try PressCommand.parse(["up", "down", "left", "right", "--json-output"])

        #expect(command.keys == ["up", "down", "left", "right"])
    }

    @Test("Press command with function keys")
    func pressFunctionKeys() throws {
        // Test all function keys F1-F12
        let functionKeys = (1...12).map { "f\($0)" }
        let args = functionKeys + ["--json-output"]
        let command = try PressCommand.parse(args)

        #expect(command.keys == functionKeys)
        #expect(command.keys.count == 12)
    }

    @Test("Press command edge cases")
    func pressEdgeCases() throws {
        // Single key with high repeat count
        let command1 = try PressCommand.parse(["space", "--count", "10"])
        #expect(command1.keys == ["space"])
        #expect(command1.count == 10)

        // Zero delay (instant)
        let command2 = try PressCommand.parse(["return", "--delay", "0"])
        #expect(command2.delay == 0)

        // Zero hold (quick press)
        let command3 = try PressCommand.parse(["tab", "--hold", "0"])
        #expect(command3.hold == 0)
    }
}
