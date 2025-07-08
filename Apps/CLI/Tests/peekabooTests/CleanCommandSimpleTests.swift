import Foundation
import Testing
import PeekabooCore
@testable import peekaboo

@Suite("Clean Command Simple Tests")
struct CleanCommandSimpleTests {
    @Test("Clean command parses all-sessions flag")
    func parseAllSessions() throws {
        let command = try CleanCommand.parse(["--all-sessions"])
        #expect(command.allSessions == true)
        #expect(command.olderThan == nil)
        #expect(command.session == nil)
        #expect(command.dryRun == false)
        #expect(command.jsonOutput == false)
    }

    @Test("Clean command parses older-than option")
    func parseOlderThan() throws {
        let command = try CleanCommand.parse(["--older-than", "24"])
        #expect(command.allSessions == false)
        #expect(command.olderThan == 24)
        #expect(command.session == nil)
    }

    @Test("Clean command parses session option")
    func parseSession() throws {
        let command = try CleanCommand.parse(["--session", "12345"])
        #expect(command.allSessions == false)
        #expect(command.olderThan == nil)
        #expect(command.session == "12345")
    }

    @Test("Clean command parses dry-run flag")
    func parseDryRun() throws {
        let command = try CleanCommand.parse(["--all-sessions", "--dry-run"])
        #expect(command.allSessions == true)
        #expect(command.dryRun == true)
    }

    @Test("Clean command parses json-output flag")
    func parseJsonOutput() throws {
        let command = try CleanCommand.parse(["--all-sessions", "--json-output"])
        #expect(command.allSessions == true)
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
        let sessionDetails = [
            SessionDetail(sessionId: "123", path: "/tmp/123", size: 1024, creationDate: Date()),
            SessionDetail(sessionId: "456", path: "/tmp/456", size: 2048, creationDate: Date()),
        ]

        let result = CleanResult(
            sessionsRemoved: 2,
            bytesFreed: 3072,
            sessionDetails: sessionDetails,
            executionTime: 1.5,
            success: true)

        #expect(result.sessionsRemoved == 2)
        #expect(result.bytesFreed == 3072)
        #expect(result.sessionDetails.count == 2)
        #expect(result.success == true)
    }
}
