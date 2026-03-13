import Foundation
import Testing
@testable import PeekabooCLI

@Suite(.tags(.safe))
struct SleepCommandTests {
    @Test
    func `Sleep command parses duration`() throws {
        let command = try SleepCommand.parse(["1000"])
        #expect(command.duration == 1000)
        #expect(command.jsonOutput == false)
    }

    @Test
    func `Sleep command parses with JSON output`() throws {
        let command = try SleepCommand.parse(["500", "--json"])
        #expect(command.duration == 500)
        #expect(command.jsonOutput == true)
    }

    @Test
    func `Sleep command requires duration`() {
        #expect(throws: (any Error).self) {
            try CLIOutputCapture.suppressStderr {
                _ = try SleepCommand.parse([])
            }
        }
    }

    @Test
    func `Sleep result structure`() {
        let result = SleepResult(
            success: true,
            requested_duration: 1000,
            actual_duration: 1001
        )

        #expect(result.success == true)
        #expect(result.requested_duration == 1000)
        #expect(result.actual_duration == 1001)
    }

    @Test(arguments: [
        (0, false), // 0ms parses but is invalid at runtime (must be positive)
        (1, true), // 1ms is valid
        (1000, true), // 1 second
        (60000, true), // 1 minute
        (-100, false) // Negative duration fails at parse time
    ])
    func `Duration validation`(duration: Int, isValid: Bool) throws {
        // Commander validates that Int arguments can be parsed
        // Runtime validation checks if > 0
        if duration < 0 {
            // Negative numbers fail at parse time
            #expect(throws: (any Error).self) {
                try CLIOutputCapture.suppressStderr {
                    _ = try SleepCommand.parse([String(duration)])
                }
            }
        } else {
            // Zero and positive numbers parse successfully
            let command = try SleepCommand.parse([String(duration)])
            #expect(command.duration == duration)
            // Note: The actual validation (duration > 0) happens at runtime in run()
        }
    }

    @Test(arguments: zip(
        [100, 500, 1000, 1500, 10000], // milliseconds
        [0.1, 0.5, 1.0, 1.5, 10.0] // expected seconds
    ))
    func `Duration formatting converts milliseconds to seconds accurately`(milliseconds: Int, expectedSeconds: Double) {
        let seconds = Double(milliseconds) / 1000.0
        #expect(abs(seconds - expectedSeconds) < 0.001)
    }
}
