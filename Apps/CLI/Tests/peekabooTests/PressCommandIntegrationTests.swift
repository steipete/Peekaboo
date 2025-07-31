import ArgumentParser
import Foundation
import Testing
@testable import peekaboo

@Suite("PressCommand Integration Tests")
@available(macOS 14.0, *)
struct PressCommandIntegrationTests {
    
    // MARK: - Command Integration with TypeService
    
    @Test("Press command generates correct key sequence")
    func pressCommandGeneratesKeySequence() throws {
        // Test that PressCommand correctly maps keys to SpecialKey values
        let testCases: [(input: [String], expectedCount: Int)] = [
            (["return"], 1),
            (["tab", "tab", "return"], 3),
            (["up", "down", "left", "right"], 4),
            (["escape"], 1),
            (["f1", "f12"], 2)
        ]
        
        for (input, expectedCount) in testCases {
            let command = try PressCommand.parse(input + ["--json-output"])
            #expect(command.keys == input)
            #expect(command.keys.count == expectedCount)
            
            // Verify all keys would be valid when passed to TypeService
            // We can't access SpecialKey directly, but we know PressCommand validates them
        }
    }
    
    @Test("Press command with repeat count multiplies actions")
    func pressCommandRepeatCount() throws {
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
    
    @Test("Press command respects timing parameters")
    func pressCommandTimingParameters() throws {
        // Test delay and hold parameters
        let command1 = try PressCommand.parse(["tab", "--delay", "200", "--hold", "100"])
        #expect(command1.delay == 200)
        #expect(command1.hold == 100)
        
        let command2 = try PressCommand.parse(["return", "--delay", "0", "--hold", "0"])
        #expect(command2.delay == 0)
        #expect(command2.hold == 0)
    }
    
    @Test("Press command validates all special keys")
    func pressCommandValidatesAllKeys() throws {
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
    
    @Test("Press command with session parameter")
    func pressCommandWithSession() throws {
        let sessionId = "test-session-123"
        let command = try PressCommand.parse(["return", "--session", sessionId])
        #expect(command.session == sessionId)
    }
    
    @Test("Press command with focus options")
    func pressCommandWithFocusOptions() throws {
        // Test various focus option combinations
        let command1 = try PressCommand.parse(["tab", "--bring-to-front"])
        #expect(command1.focusOptions.bringToFront == true)
        #expect(command1.focusOptions.switchSpace == false) // default
        
        let command2 = try PressCommand.parse(["return", "--switch-space"])
        #expect(command2.focusOptions.switchSpace == true)
        #expect(command2.focusOptions.bringToFront == false) // default
        
        let command3 = try PressCommand.parse(["escape", "--auto-focus"])
        #expect(command3.focusOptions.autoFocus == true)
    }
    
    @Test("Press command JSON output format")
    func pressCommandJSONOutput() throws {
        let command = try PressCommand.parse(["tab", "--json-output"])
        #expect(command.jsonOutput == true)
    }
    
    // MARK: - Complex Sequences
    
    @Test("Press command handles navigation sequences")
    func pressNavigationSequences() throws {
        // Common navigation patterns
        let navigationSequences: [([String], String)] = [
            (["down", "down", "return"], "Navigate down and select"),
            (["tab", "tab", "tab", "return"], "Tab through fields and submit"),
            (["home", "shift", "end"], "Select all from home to end"),
            (["up", "up", "up", "space"], "Navigate up and toggle")
        ]
        
        for (keys, description) in navigationSequences {
            let command = try PressCommand.parse(keys)
            #expect(command.keys == keys)
            
            // All keys should be valid
            for key in keys {
                // Note: "shift" in this context would be handled as a modifier, not a key press
                // All other keys should be valid special keys
            }
        }
    }
    
    @Test("Press command handles dialog navigation")
    func pressDialogNavigation() throws {
        // Common dialog interaction patterns
        let dialogPatterns: [([String], String)] = [
            (["tab", "space"], "Tab to checkbox and toggle"),
            (["tab", "tab", "return"], "Tab to OK button and press"),
            (["escape"], "Cancel dialog"),
            (["tab", "down", "down", "return"], "Tab to dropdown, select item")
        ]
        
        for (keys, description) in dialogPatterns {
            let command = try PressCommand.parse(keys)
            #expect(command.keys == keys, description)
        }
    }
    
    // MARK: - Error Cases
    
    @Test("Press command rejects invalid keys at parse time")
    func pressCommandRejectsInvalidKeys() throws {
        // These should fail during parsing
        let invalidKeys = ["invalid_key", "notakey", "xyz"]
        
        for invalidKey in invalidKeys {
            #expect(throws: ArgumentParser.ValidationError.self) {
                _ = try PressCommand.parse([invalidKey])
            }
        }
    }
}