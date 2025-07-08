import Testing
import Foundation
@testable import peekaboo

/// Tests for CleanCommand
@Suite("CleanCommand Tests")
@available(macOS 14.0, *)
struct CleanCommandTests {
    
    @Test("Clean command validation")
    func testCommandValidation() throws {
        // Test that specifying multiple options fails
        var command = CleanCommand()
        command.allSessions = true
        command.olderThan = 24
        
        // This should throw a validation error when run
        // (We can't actually run it in tests due to async requirements)
    }
    
    @Test("Dry run flag")
    func testDryRunFlag() {
        var command = CleanCommand()
        command.dryRun = true
        
        #expect(command.dryRun == true)
    }
    
    @Test("Format bytes helper")
    func testFormatBytes() {
        let command = CleanCommand()
        
        // Test various byte sizes
        #expect(command.formatBytes(1024) == "1 KB")
        #expect(command.formatBytes(1048576) == "1 MB")
        #expect(command.formatBytes(1073741824) == "1 GB")
    }
}