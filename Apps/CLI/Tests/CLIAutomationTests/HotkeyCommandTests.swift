import Commander
import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite(.tags(.safe)) struct HotkeyCommandTests {
    @Test func hotkeyParsing() async throws {
        // Test comma-separated format
        let command1 = try HotkeyCommand.parse(["--keys", "cmd,c"])
        #expect(command1.resolvedKeys == "cmd,c")
        #expect(command1.holdDuration == 50) // Default

        // Test space-separated format
        let command2 = try HotkeyCommand.parse(["--keys", "cmd a"])
        #expect(command2.resolvedKeys == "cmd a")

        // Test with custom hold duration
        let command3 = try HotkeyCommand.parse(["--keys", "cmd,v", "--hold-duration", "100"])
        #expect(command3.resolvedKeys == "cmd,v")
        #expect(command3.holdDuration == 100)

        // Test with snapshot ID
        let command4 = try HotkeyCommand.parse(["--keys", "cmd,z", "--snapshot", "test-snapshot"])
        #expect(command4.snapshot == "test-snapshot")

        // Test with app
        let command5 = try HotkeyCommand.parse(["--keys", "cmd,c", "--app", "TextEdit"])
        #expect(command5.target.app == "TextEdit")
    }

    @Test func invalidInputHandling() async throws {
        // Test missing keys
        #expect(throws: (any Error).self) {
            try CLIOutputCapture.suppressStderr {
                _ = try HotkeyCommand.parse([])
            }
        }

        // Test empty keys
        #expect(throws: ValidationError.self) {
            try CLIOutputCapture.suppressStderr {
                _ = try HotkeyCommand.parse(["--keys", ""])
            }
        }
    }

    @Test func keyFormatNormalization() async throws {
        // Test that both formats work
        let command1 = try HotkeyCommand.parse(["--keys", "cmd,shift,t"])
        #expect(command1.resolvedKeys == "cmd,shift,t")

        let command2 = try HotkeyCommand.parse(["--keys", "cmd shift t"])
        #expect(command2.resolvedKeys == "cmd shift t")

        // Test mixed case handling
        let command3 = try HotkeyCommand.parse(["--keys", "CMD,C"])
        #expect(command3.resolvedKeys == "CMD,C") // Original case preserved
    }

    @Test func complexHotkeys() async throws {
        // Test function keys
        let command1 = try HotkeyCommand.parse(["--keys", "f1"])
        #expect(command1.resolvedKeys == "f1")

        // Test multiple modifiers
        let command2 = try HotkeyCommand.parse(["--keys", "cmd,alt,shift,n"])
        #expect(command2.resolvedKeys == "cmd,alt,shift,n")

        // Test special keys
        let command3 = try HotkeyCommand.parse(["--keys", "cmd,space"])
        #expect(command3.resolvedKeys == "cmd,space")
    }

    @Test func positionalHotkeyParsing() async throws {
        let positionalComma = try HotkeyCommand.parse(["cmd,shift,t"])
        #expect(positionalComma.resolvedKeys == "cmd,shift,t")

        let positionalSpace = try HotkeyCommand.parse(["cmd shift t"])
        #expect(positionalSpace.resolvedKeys == "cmd shift t")
    }

    @Test func positionalOverridesOption() async throws {
        let command = try HotkeyCommand.parse(["cmd,space", "--keys", "cmd,c"])
        #expect(command.resolvedKeys == "cmd,space")
    }
}
