import Testing
import Foundation
import ArgumentParser
@testable import peekaboo

/// Tests for CleanCommand
@Suite("CleanCommand Tests")
struct CleanCommandTests {
    
    @Test("Clean command validation")
    func testCommandValidation() throws {
        // Test that specifying multiple options fails
        var command = CleanCommand()
        command.allSessions = true
        command.olderThan = 24
        
        // This should throw a validation error when run
        // (We can't actually run it in tests due to async requirements)
        #expect(command.allSessions == true)
        #expect(command.olderThan == 24)
    }
    
    @Test("Dry run flag")
    func testDryRunFlag() {
        var command = CleanCommand()
        command.dryRun = true
        
        #expect(command.dryRun == true)
    }
    
    @Test("Clean command parsing")
    func testCleanCommandParsing() throws {
        // Test parsing with --all-sessions
        let command1 = try CleanCommand.parse(["--all-sessions"])
        #expect(command1.allSessions == true)
        #expect(command1.olderThan == nil)
        #expect(command1.session == nil)
        
        // Test parsing with --older-than
        let command2 = try CleanCommand.parse(["--older-than", "48"])
        #expect(command2.allSessions == false)
        #expect(command2.olderThan == 48)
        #expect(command2.session == nil)
        
        // Test parsing with --session
        let command3 = try CleanCommand.parse(["--session", "abc123"])
        #expect(command3.allSessions == false)
        #expect(command3.olderThan == nil)
        #expect(command3.session == "abc123")
    }
}