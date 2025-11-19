import Testing
@testable import PeekabooAutomation

@Suite("ScreenCaptureFallbackRunner")
struct ScreenCaptureFallbackRunnerTests {
    @MainActor
    @Test("success on first engine records observer")
    func successFirstEngine() async throws {
        var events: [(String, ScreenCaptureAPI, TimeInterval, Bool, Error?)] = []
        let runner = ScreenCaptureFallbackRunner(apis: [.modern, .legacy]) { op, api, duration, success, error in
            events.append((op, api, duration, success, error))
        }

        let value: Int = try await runner.run(
            operationName: "test",
            logger: CategoryLogger(service: LoggingService.shared, category: "test"),
            correlationId: "c1") { _ in
                42
            }

        #expect(value == 42)
        #expect(events.count == 1)
        #expect(events.first?.1 == .modern)
        #expect(events.first?.3 == true)
        #expect(events.first?.4 == nil)
        #expect(events.first?.2 >= 0)
    }

    @MainActor
    @Test("fallback to legacy records both events")
    func fallbackRecordsEvents() async throws {
        enum Dummy: Error { case fail }
        var call = 0
        var events: [(String, ScreenCaptureAPI, TimeInterval, Bool, Error?)] = []
        let runner = ScreenCaptureFallbackRunner(apis: [.modern, .legacy]) { op, api, duration, success, error in
            events.append((op, api, duration, success, error))
        }

        let value: String = try await runner.run(
            operationName: "test",
            logger: CategoryLogger(service: LoggingService.shared, category: "test"),
            correlationId: "c2") { api in
                call += 1
                if call == 1 { throw Dummy.fail }
                return "ok_\(api.rawValue)"
            }

        #expect(value == "ok_legacy")
        #expect(events.count == 2)
        #expect(events[0].1 == .modern)
        #expect(events[0].3 == false)
        #expect(events[0].4 is Dummy)
        #expect(events[1].1 == .legacy)
        #expect(events[1].3 == true)
    }
}
