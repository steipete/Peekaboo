import AppKit
import Foundation
import Testing
@testable import PeekabooCLI

private typealias WindowsSubcommand = ListCommand.WindowsSubcommand

@Suite("PID Windows Subcommand Tests", .serialized, .tags(.safe))
struct PIDWindowsSubcommandTests {
    @Test("Parse windows subcommand with PID")
    func parseWindowsSubcommandWithPID() throws {
        // Test parsing windows subcommand with PID
        let command = try WindowsSubcommand.parse([
            "--app", "PID:1234",
            "--json-output",
        ])

        #expect(command.app == "PID:1234")
        #expect(command.jsonOutput == true)
    }

    @Test("Parse windows subcommand with PID and details")
    func parseWindowsSubcommandWithPIDAndDetails() throws {
        // Test windows subcommand with PID and window details
        let command = try WindowsSubcommand.parse([
            "--app", "PID:5678",
            "--include-details", "ids,bounds,off_screen",
            "--json-output",
        ])

        #expect(command.app == "PID:5678")
        #expect(command.includeDetails == "ids,bounds,off_screen")
        #expect(command.jsonOutput == true)
    }

    @Test("Various PID formats in windows subcommand")
    func variousPIDFormatsInWindowsSubcommand() throws {
        let pidFormats = [
            "PID:1", // Single digit
            "PID:123", // Three digits
            "PID:99999", // Large PID
        ]

        for pidFormat in pidFormats {
            let command = try WindowsSubcommand.parse([
                "--app", pidFormat,
            ])

            #expect(command.app == pidFormat)
        }
    }
}
