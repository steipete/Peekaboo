import Testing
@testable import peekaboo
import Foundation

#if os(macOS) && swift(>=5.9)
@available(macOS 14.0, *)
@Suite("SleepCommand Tests")
struct SleepCommandTests {
    
    @Test("Sleep command parses duration")
    func parseDuration() throws {
        let command = try SleepCommand.parse(["--duration", "1000"])
        #expect(command.duration == 1000)
        #expect(command.jsonOutput == false)
    }
    
    @Test("Sleep command parses with JSON output")
    func parseWithJSONOutput() throws {
        let command = try SleepCommand.parse(["--duration", "500", "--json-output"])
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
            requestedDuration: 1000,
            actualDuration: 1001.5
        )
        
        #expect(result.success == true)
        #expect(result.requestedDuration == 1000)
        #expect(result.actualDuration == 1001.5)
    }
    
    @Test("Duration validation", arguments: [
        (0, true),      // 0ms is valid (no-op)
        (1, true),      // 1ms is valid
        (1000, true),   // 1 second
        (60000, true),  // 1 minute
        (-100, false),  // Negative duration should fail
    ])
    func validateDuration(duration: Int, isValid: Bool) {
        if isValid {
            #expect(throws: Never.self) {
                _ = try SleepCommand.parse(["--duration", String(duration)])
            }
        } else {
            #expect(throws: Error.self) {
                _ = try SleepCommand.parse(["--duration", String(duration)])
            }
        }
    }
    
    @Test("Duration formatting for display")
    func durationFormatting() {
        let testCases: [(ms: Int, expectedSeconds: Double)] = [
            (100, 0.1),
            (500, 0.5),
            (1000, 1.0),
            (1500, 1.5),
            (10000, 10.0)
        ]
        
        for testCase in testCases {
            let seconds = Double(testCase.ms) / 1000.0
            #expect(abs(seconds - testCase.expectedSeconds) < 0.001)
        }
    }
}
#endif