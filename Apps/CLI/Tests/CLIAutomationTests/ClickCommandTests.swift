import Foundation
import Testing
@testable import PeekabooCLI

@Suite(
    "ClickCommand Tests",
    .tags(.automation),
    .enabled(if: CLITestEnvironment.runAutomationRead)
)
struct ClickCommandTests {
    @Test("Click command  requires argument or option")
    func requiresArgumentOrOption() async throws {
        #expect(throws: (any Error).self) {
            try CLIOutputCapture.suppressStderr {
                _ = try ClickCommand.parse([])
            }
        }
    }

    @Test("Click command  parses coordinates correctly")
    func parsesCoordinates() async throws {
        var command = try ClickCommand.parse(["--coords", "100,200", "--json-output"])

        // Should execute without throwing when coordinates are provided
        try await command.run()
    }

    @Test("Click command  validates coordinate format")
    func validatesCoordinateFormat() async throws {
        #expect(throws: (any Error).self) {
            try CLIOutputCapture.suppressStderr {
                _ = try ClickCommand.parse(["--coords", "invalid", "--json-output"])
            }
        }
    }
}
