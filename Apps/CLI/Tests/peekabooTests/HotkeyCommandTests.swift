import Testing
import Foundation
@testable import peekaboo
import PeekabooCore

@available(macOS 14.0, *)
@Suite struct HotkeyCommandTests {
    
    @Test func testHotkeyParsing() async throws {
        // Test comma-separated format
        let command1 = try HotkeyCommand.parse(["hotkey", "--keys", "cmd,c"])
        #expect(command1.keys == "cmd,c")
        #expect(command1.holdDuration == 50) // Default
        
        // Test space-separated format
        let command2 = try HotkeyCommand.parse(["hotkey", "--keys", "cmd a"])
        #expect(command2.keys == "cmd a")
        
        // Test with custom hold duration
        let command3 = try HotkeyCommand.parse(["hotkey", "--keys", "cmd,v", "--hold-duration", "100"])
        #expect(command3.keys == "cmd,v")
        #expect(command3.holdDuration == 100)
        
        // Test with session ID
        let command4 = try HotkeyCommand.parse(["hotkey", "--keys", "cmd,z", "--session", "test-session"])
        #expect(command4.session == "test-session")
        
        // Test JSON output flag
        let command5 = try HotkeyCommand.parse(["hotkey", "--keys", "escape", "--json-output"])
        #expect(command5.jsonOutput == true)
    }
    
    @Test func testInvalidInputHandling() async throws {
        // Test missing keys
        #expect(throws: Error.self) {
            _ = try HotkeyCommand.parse(["hotkey"])
        }
        
        // Test empty keys
        #expect(throws: Error.self) {
            _ = try HotkeyCommand.parse(["hotkey", "--keys", ""])
        }
    }
    
    @Test func testKeyFormatNormalization() async throws {
        // Test that both formats work
        let command1 = try HotkeyCommand.parse(["hotkey", "--keys", "cmd,shift,t"])
        #expect(command1.keys == "cmd,shift,t")
        
        let command2 = try HotkeyCommand.parse(["hotkey", "--keys", "cmd shift t"])
        #expect(command2.keys == "cmd shift t")
        
        // Test mixed case handling
        let command3 = try HotkeyCommand.parse(["hotkey", "--keys", "CMD,C"])
        #expect(command3.keys == "CMD,C") // Original case preserved
    }
    
    @Test func testComplexHotkeys() async throws {
        // Test function keys
        let command1 = try HotkeyCommand.parse(["hotkey", "--keys", "f1"])
        #expect(command1.keys == "f1")
        
        // Test multiple modifiers
        let command2 = try HotkeyCommand.parse(["hotkey", "--keys", "cmd,alt,shift,n"])
        #expect(command2.keys == "cmd,alt,shift,n")
        
        // Test special keys
        let command3 = try HotkeyCommand.parse(["hotkey", "--keys", "cmd,space"])
        #expect(command3.keys == "cmd,space")
    }
}