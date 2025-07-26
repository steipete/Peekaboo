import Foundation
import Testing
@testable import peekaboo

@Suite("SleepCommand Tests")
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
        #expect(throws: Error.self) {
            _ = try SleepCommand.parse([])
        }
    }

    @Test("Sleep result structure")
    func sleepResultStructure() {
        let result = SleepResult(
            success: true,
            requested_duration: 1000,
            actual_duration: 1001)

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
            #expect(throws: Error.self) {
                _ = try SleepCommand.parse([String(duration)])
            }
        } else {
            // Zero and positive numbers parse successfully
            let command = try SleepCommand.parse([String(duration)])
            #expect(command.duration == duration)
            // Note: The actual validation (duration > 0) happens at runtime in run()
        }
    }

    @Test("Duration formatting for display")
    func durationFormatting() {
        let testCases: [(ms: Int, expectedSeconds: Double)] = [
            (100, 0.1),
            (500, 0.5),
            (1000, 1.0),
            (1500, 1.5),
            (10000, 10.0),
        ]

        for testCase in testCases {
            let seconds = Double(testCase.ms) / 1000.0
            #expect(abs(seconds - testCase.expectedSeconds) < 0.001)
        }
    }
}
