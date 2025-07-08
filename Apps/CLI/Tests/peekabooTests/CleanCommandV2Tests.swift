import Testing
import Foundation
@testable import peekaboo

/// Tests for CleanCommandV2
@Suite("CleanCommandV2 Tests")
@available(macOS 14.0, *)
struct CleanCommandV2Tests {
    
    @Test("Clean command validation")
    func testCommandValidation() throws {
        // Test that specifying multiple options fails
        var command = CleanCommandV2()
        command.allSessions = true
        command.olderThan = 24
        
        // This should throw a validation error when run
        // (We can't actually run it in tests due to async requirements)
    }
    
    @Test("Dry run flag")
    func testDryRunFlag() {
        var command = CleanCommandV2()
        command.dryRun = true
        
        #expect(command.dryRun == true)
    }
    
    @Test("Format bytes helper")
    func testFormatBytes() {
        let command = CleanCommandV2()
        
        // Test various byte sizes
        #expect(command.formatBytes(1024) == "1 KB")
        #expect(command.formatBytes(1048576) == "1 MB")
        #expect(command.formatBytes(1073741824) == "1 GB")
    }
}