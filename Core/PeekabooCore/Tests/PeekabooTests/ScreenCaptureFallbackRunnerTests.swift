import CoreGraphics
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

struct ScreenCaptureFallbackRunnerTests {
    @MainActor
    @Test
    func `success on first engine records observer`() async throws {
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
    @Test
    func `fallback to legacy records both events`() async throws {
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

    @MainActor
    @Test
    func `capture runner stamps engine and fallback reason`() async throws {
        enum Dummy: Error { case fail }
        let logger = LoggingService(subsystem: "test.logger").logger(category: "test")
        let runner = ScreenCaptureFallbackRunner(apis: [.modern, .legacy])
        var calls: [ScreenCaptureAPI] = []

        let result = try await runner.runCapture(
            operationName: "captureScreen",
            logger: logger,
            correlationId: "c3")
        { api in
            calls.append(api)
            if api == .modern {
                throw Dummy.fail
            }
            return CaptureResult(
                imageData: Data(),
                metadata: CaptureMetadata(
                    size: CGSize(width: 20, height: 10),
                    mode: .screen,
                    diagnostics: CaptureDiagnostics(
                        requestedScale: .native,
                        nativeScale: 2,
                        outputScale: 2,
                        scaleSource: "test",
                        finalPixelSize: CGSize(width: 20, height: 10))))
        }

        #expect(calls == [.modern, .legacy])
        #expect(result.metadata.diagnostics?.engine == "CGWindowList")
        #expect(result.metadata.diagnostics?.fallbackReason?.contains("ScreenCaptureKit failed") == true)
        #expect(result.metadata.diagnostics?.finalPixelSize == CGSize(width: 20, height: 10))
    }

    @MainActor
    @Test
    func `transient ScreenCaptureKit denial retries before fallback`() async throws {
        let logger = LoggingService(subsystem: "test.logger").logger(category: "test")
        let runner = ScreenCaptureFallbackRunner(apis: [.modern, .legacy])
        var calls: [ScreenCaptureAPI] = []

        let value: String = try await runner.run(
            operationName: "test",
            logger: logger,
            correlationId: "c4")
        { api in
            calls.append(api)
            if calls.count == 1 {
                throw NSError(
                    domain: "com.apple.ScreenCaptureKit.SCStreamErrorDomain",
                    code: -3801,
                    userInfo: [
                        NSLocalizedDescriptionKey: "The user declined TCCs for application, window, display capture",
                    ])
            }
            return "ok_\(api.rawValue)"
        }

        #expect(value == "ok_modern")
        #expect(calls == [.modern, .modern])
    }
}
