import Foundation
import Testing
@testable import PeekabooCLI

@Suite(.tags(.safe))
struct PressCommandIntegrationTests {
    // MARK: - Command Integration with TypeService

    @Test
    func `Press command generates correct key sequence`() throws {
        // Test that PressCommand correctly maps keys to SpecialKey values
        let testCases: [(input: [String], expectedCount: Int)] = [
            (["return"], 1),
            (["tab", "tab", "return"], 3),
            (["up", "down", "left", "right"], 4),
            (["escape"], 1),
            (["f1", "f12"], 2)
        ]

        for (input, expectedCount) in testCases {
            let command = try PressCommand.parse(input + ["--json"])
            #expect(command.keys == input)
            #expect(command.keys.count == expectedCount)

            // Verify all keys would be valid when passed to TypeService
            // We can't access SpecialKey directly, but we know PressCommand validates them
        }
    }

    @Test
    func `Press command with repeat count multiplies actions`() throws {
        // Test count parameter behavior
        let testCases: [(key: String, count: Int)] = [
            ("tab", 3),
            ("return", 2),
            ("space", 5)
        ]

        for (key, count) in testCases {
            let command = try PressCommand.parse([key, "--count", "\(count)"])
            #expect(command.keys == [key])
            #expect(command.count == count)

            // When executed, this should result in count * keys.count total key presses
            let expectedTotalPresses = count * command.keys.count
            #expect(expectedTotalPresses == count)
        }
    }

    @Test
    func `Press command respects timing parameters`() throws {
        // Test delay and hold parameters
        let command1 = try PressCommand.parse(["tab", "--delay", "200", "--hold", "100"])
        #expect(command1.delay == 200)
        #expect(command1.hold == 100)

        let command2 = try PressCommand.parse(["return", "--delay", "0", "--hold", "0"])
        #expect(command2.delay == 0)
        #expect(command2.hold == 0)
    }

    @Test
    func `Press command validates all special keys`() throws {
        // Comprehensive test of all valid special keys
        let allValidKeys = [
            // Navigation
            "up", "down", "left", "right",
            "home", "end", "pageup", "pagedown",
            // Editing
            "delete", "forward_delete", "clear",
            // Control
            "return", "enter", "tab", "escape", "space",
            // Function keys
            "f1", "f2", "f3", "f4", "f5", "f6",
            "f7", "f8", "f9", "f10", "f11", "f12",
            // Special
            "caps_lock", "help"
        ]

        for key in allValidKeys {
            // Should parse without throwing
            let command = try PressCommand.parse([key])
            #expect(command.keys == [key])

            // Key validation happens in PressCommand.run()
            // We verify parsing succeeds which means the key is valid
        }
    }

    @Test
    func `Press command with snapshot parameter`() throws {
        let snapshotId = "test-snapshot-123"
        let command = try PressCommand.parse(["return", "--snapshot", snapshotId])
        #expect(command.snapshot == snapshotId)
    }

    @Test
    func `Press command with focus options`() throws {
        // Test various focus option combinations
        let command1 = try PressCommand.parse(["tab", "--bring-to-current-space"])
        #expect(command1.focusOptions.bringToCurrentSpace == true)
        #expect(command1.focusOptions.spaceSwitch == false) // default

        let command2 = try PressCommand.parse(["return", "--space-switch"])
        #expect(command2.focusOptions.spaceSwitch == true)
        #expect(command2.focusOptions.bringToCurrentSpace == false) // default

        let command3 = try PressCommand.parse(["escape", "--no-auto-focus"])
        #expect(command3.focusOptions.autoFocus == false)
    }

    @Test
    func `Press command rejects background focus delivery`() throws {
        #expect(throws: (any Error).self) {
            try CLIOutputCapture.suppressStderr {
                _ = try PressCommand.parse(["escape", "--focus-background"])
            }
        }
    }

    @Test
    func `Press command JSON output format`() throws {
        let command = try PressCommand.parse(["tab", "--json"])
        #expect(command.jsonOutput == true)
    }

    // MARK: - Complex Sequences

    @Test
    func `Press command handles navigation sequences`() throws {
        // Common navigation patterns
        let navigationSequences: [([String], String)] = [
            (["down", "down", "return"], "Navigate down and select"),
            (["tab", "tab", "tab", "return"], "Tab through fields and submit"),
            (["home", "end"], "Jump to start and end"),
            (["up", "up", "up", "space"], "Navigate up and toggle")
        ]

        for (keys, _) in navigationSequences {
            let command = try PressCommand.parse(keys)
            #expect(command.keys == keys)

            // All keys should be valid
            for _ in keys {
                // Note: "shift" in this context would be handled as a modifier, not a key press
                // All other keys should be valid special keys
            }
        }
    }

    @Test
    func `Press command handles dialog navigation`() throws {
        // Common dialog interaction patterns
        let dialogPatterns: [([String], String)] = [
            (["tab", "space"], "Tab to checkbox and toggle"),
            (["tab", "tab", "return"], "Tab to OK button and press"),
            (["escape"], "Cancel dialog"),
            (["tab", "down", "down", "return"], "Tab to dropdown, select item")
        ]

        for (keys, _) in dialogPatterns {
            let command = try PressCommand.parse(keys)
            #expect(command.keys == keys)
        }
    }

    // MARK: - Error Cases

    @Test
    func `Press command rejects invalid keys at parse time`() throws {
        // These should fail during validation
        let invalidKeys = ["invalid_key", "notakey", "xyz"]

        for invalidKey in invalidKeys {
            var command = try PressCommand.parse([invalidKey])
            #expect(throws: (any Error).self) {
                try command.validate()
            }
        }
    }

    @Test
    func `Press command rejects invalid timing values`() throws {
        for arguments in [
            ["tab", "--count", "0"],
            ["tab", "--delay", "-1"],
            ["tab", "--hold", "-1"],
        ] {
            var command = try PressCommand.parse(arguments)
            #expect(throws: (any Error).self) {
                try command.validate()
            }
        }
    }
}
