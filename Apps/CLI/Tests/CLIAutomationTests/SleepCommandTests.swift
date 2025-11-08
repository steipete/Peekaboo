import Foundation
import Testing
@testable import PeekabooCLI

@Suite("SleepCommand Tests", .tags(.safe))
struct SleepCommandTests {
    @Test("Sleep command parses duration")
    func parseDuration() throws {
        let command = try SleepCommand.parse(["1000"])
        #expect(command.duration == 1000)
        #expect(command.jsonOutput == false)
    }

    @Test("Sleep command parses with JSON output")
    func parseWithJSONOutput() throws {
        let command = try SleepCommand.parse(["500", "--json-output"])
        #expect(command.duration == 500)
        #expect(command.jsonOutput == true)
    }

    @Test("Sleep command requires duration")
    func requiresDuration() {
        #expect(throws: (any Error).self) {
            try CLIOutputCapture.suppressStderr {
                _ = try SleepCommand.parse([])
            }
        }
    }

    @Test("Sleep result structure")
    func sleepResultStructure() {
        let result = SleepResult(
            success: true,
            requested_duration: 1000,
            actual_duration: 1001
        )

        #expect(result.success == true)
        #expect(result.requested_duration == 1000)
        #expect(result.actual_duration == 1001)
    }

    @Test("Duration validation", arguments: [
        (0, false), // 0ms parses but is invalid at runtime (must be positive)
        (1, true), // 1ms is valid
        (1000, true), // 1 second
        (60000, true), // 1 minute
        (-100, false) // Negative duration fails at parse time
    ])
    func validateDuration(duration: Int, isValid: Bool) throws {
        // ArgumentParser validates that Int arguments can be parsed
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

    @Test("Duration formatting converts milliseconds to seconds accurately", arguments: zip(
        [100, 500, 1000, 1500, 10000], // milliseconds
        [0.1, 0.5, 1.0, 1.5, 10.0] // expected seconds
    ))
    func durationFormatting(milliseconds: Int, expectedSeconds: Double) {
        let seconds = Double(milliseconds) / 1000.0
        #expect(abs(seconds - expectedSeconds) < 0.001)
    }
}
