import Foundation
import Testing
@_spi(Testing) import PeekabooAutomationKit

private struct FallbackEvent {
    let operation: String
    let api: ScreenCaptureAPI
    let duration: TimeInterval
    let success: Bool
    let error: (any Error)?
}

@Suite("ScreenCaptureFallbackRunner")
struct ScreenCaptureFallbackRunnerTests {
    @MainActor
    @Test("success on first engine records observer")
    func successFirstEngine() async throws {
        let logger = LoggingService(subsystem: "test.logger").logger(category: "test")
        var events: [FallbackEvent] = []
        let runner = ScreenCaptureFallbackRunner(apis: [.modern, .legacy]) { op, api, duration, success, error in
            // Observer may run off the actor executor; hop explicitly so array mutation stays deterministic.
            MainActor.assumeIsolated {
                events.append(
                    FallbackEvent(
                        operation: op,
                        api: api,
                        duration: duration,
                        success: success,
                        error: error))
            }
        }

        let value: Int = try await runner.run(
            operationName: "test",
            logger: logger,
            correlationId: "c1")
        { _ in
            42
        }

        #expect(value == 42)
        #expect(events.count == 1)
        #expect(events.first?.api == .modern)
        #expect(events.first?.success == true)
        #expect(events.first?.error == nil)
        #expect((events.first?.duration ?? 0) >= 0)
    }

    @MainActor
    @Test("fallback to legacy records both events")
    func fallbackRecordsEvents() async throws {
        enum Dummy: Error { case fail }
        let logger = LoggingService(subsystem: "test.logger").logger(category: "test")
        var call = 0
        var events: [FallbackEvent] = []
        let runner = ScreenCaptureFallbackRunner(apis: [.modern, .legacy]) { op, api, duration, success, error in
            // Observer may run off the actor executor; hop explicitly so array mutation stays deterministic.
            MainActor.assumeIsolated {
                events.append(
                    FallbackEvent(
                        operation: op,
                        api: api,
                        duration: duration,
                        success: success,
                        error: error))
            }
        }

        let value: String = try await runner.run(
            operationName: "test",
            logger: logger,
            correlationId: "c2")
        { api in
            call += 1
            if call == 1 { throw Dummy.fail }
            return "ok_\(api.rawValue)"
        }

        #expect(value == "ok_legacy")
        #expect(events.count == 2)
        #expect(events[0].api == .modern)
        #expect(events[0].success == false)
        #expect(events[0].error is Dummy)
        #expect(events[1].api == .legacy)
        #expect(events[1].success == true)
    }
}
