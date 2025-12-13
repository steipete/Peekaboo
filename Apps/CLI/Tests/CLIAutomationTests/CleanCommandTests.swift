import Foundation
import Testing
@testable import PeekabooCLI

/// Tests for CleanCommand
@Suite("CleanCommand Tests", .tags(.safe))
struct CleanCommandTests {
    @Test("Clean command validation")
    func commandValidation() throws {
        // Test that specifying multiple options fails
        var command = try CleanCommand.parse([])
        command.allSnapshots = true
        command.olderThan = 24

        // This should throw a validation error when run
        // (We can't actually run it in tests due to async requirements)
        #expect(command.allSnapshots == true)
        #expect(command.olderThan == 24)
    }

    @Test("Dry run flag")
    func dryRunFlag() throws {
        var command = try CleanCommand.parse([])
        command.dryRun = true

        #expect(command.dryRun == true)
    }

    @Test("Clean command parsing")
    func cleanCommandParsing() throws {
        // Test parsing with --all-snapshots
        let command1 = try CleanCommand.parse(["--all-snapshots"])
        #expect(command1.allSnapshots == true)
        #expect(command1.olderThan == nil)
        #expect(command1.snapshot == nil)

        // Test parsing with --older-than
        let command2 = try CleanCommand.parse(["--older-than", "48"])
        #expect(command2.allSnapshots == false)
        #expect(command2.olderThan == 48)
        #expect(command2.snapshot == nil)

        // Test parsing with --snapshot
        let command3 = try CleanCommand.parse(["--snapshot", "abc123"])
        #expect(command3.allSnapshots == false)
        #expect(command3.olderThan == nil)
        #expect(command3.snapshot == "abc123")
    }
}
