import Foundation
import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite("Clean Command Simple Tests", .tags(.safe))
struct CleanCommandSimpleTests {
    @Test("Clean command parses all-sessions flag")
    func parseAllSessions() throws {
        let command = try CleanCommand.parse(["--all-snapshots"])
        #expect(command.allSnapshots == true)
        #expect(command.olderThan == nil)
        #expect(command.snapshot == nil)
        #expect(command.dryRun == false)
        #expect(command.jsonOutput == false)
    }

    @Test("Clean command parses older-than option")
    func parseOlderThan() throws {
        let command = try CleanCommand.parse(["--older-than", "24"])
        #expect(command.allSnapshots == false)
        #expect(command.olderThan == 24)
        #expect(command.snapshot == nil)
    }

    @Test("Clean command parses snapshot option")
    func parseSession() throws {
        let command = try CleanCommand.parse(["--snapshot", "12345"])
        #expect(command.allSnapshots == false)
        #expect(command.olderThan == nil)
        #expect(command.snapshot == "12345")
    }

    @Test("Clean command parses dry-run flag")
    func parseDryRun() throws {
        let command = try CleanCommand.parse(["--all-snapshots", "--dry-run"])
        #expect(command.allSnapshots == true)
        #expect(command.dryRun == true)
    }

    @Test("Clean command parses json-output flag")
    func parseJsonOutput() throws {
        let command = try CleanCommand.parse(["--all-snapshots", "--json-output"])
        #expect(command.allSnapshots == true)
        #expect(command.jsonOutput == true)
    }

    @Test("Clean command parses multiple options")
    func parseMultipleOptions() throws {
        let command = try CleanCommand.parse([
            "--older-than", "48",
            "--dry-run",
            "--json-output",
        ])
        #expect(command.olderThan == 48)
        #expect(command.dryRun == true)
        #expect(command.jsonOutput == true)
    }

    @Test("Clean result structure")
    func cleanResultStructure() {
        let snapshotDetails = [
            SnapshotDetail(snapshotId: "123", path: "/tmp/123", size: 1024, creationDate: Date()),
            SnapshotDetail(snapshotId: "456", path: "/tmp/456", size: 2048, creationDate: Date()),
        ]

        let result = SnapshotCleanResult(
            snapshotsRemoved: 2,
            bytesFreed: 3072,
            snapshotDetails: snapshotDetails,
            dryRun: false,
            executionTime: 1.5
        )

        #expect(result.snapshotsRemoved == 2)
        #expect(result.bytesFreed == 3072)
        #expect(result.snapshotDetails.count == 2)
        #expect(result.dryRun == false)
    }
}
