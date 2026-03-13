import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooCLI

struct SeeCommandTimeoutTests {
    @Test
    func `returns result before timeout`() async throws {
        let result = try await SeeCommand.withWallClockTimeout(seconds: 1.0) {
            "ok"
        }
        #expect(result == "ok")
    }

    @Test
    func `throws detectionTimedOut when operation exceeds deadline`() async {
        let error = await #expect(throws: CaptureError.self) {
            try await SeeCommand.withWallClockTimeout(seconds: 0.05) {
                try await Task.sleep(nanoseconds: 200_000_000)
                return "late"
            }
        }

        switch error {
        case let .detectionTimedOut(seconds):
            #expect(seconds == 0.05, "Timeout should propagate configured deadline")
        default:
            Issue.record("Unexpected capture error: \(error)")
        }
    }
}
