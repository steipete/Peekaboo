//
//  ScreenCaptureServicePlanTests.swift
//  PeekabooCore
//

import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooCore

@Suite("ScreenCaptureService planning helpers")
struct ScreenCaptureServicePlanTests {
    @Test("Resolver defaults to legacy APIs when flag is unset")
    func resolverDefaultsToLegacy() {
        let order = ScreenCaptureAPIResolver.resolve(environment: [:])
        #expect(order == [.legacy])
    }

    @Test("Resolver prefers modern APIs when flag is true")
    func resolverPrefersModern() {
        let order = ScreenCaptureAPIResolver.resolve(environment: ["PEEKABOO_USE_MODERN_CAPTURE": "true"])
        #expect(order == [.modern, .legacy])
    }

    @Test("Fallback runner retries on timeout errors")
    func fallbackRetriesOnTimeout() async throws {
        let runner = ScreenCaptureFallbackRunner(apis: [.modern, .legacy])
        let logger = MockLoggingService().logger(category: LoggingService.Category.screenCapture)
        var attempts: [ScreenCaptureAPI] = []

        let result = try await runner.run(
            operationName: "captureScreen",
            logger: logger,
            correlationId: UUID().uuidString)
        { api in
            attempts.append(api)
            if api == .modern {
                throw OperationError.timeout(operation: "modern", duration: 1.0)
            }
            return api
        }

        #expect(result == .legacy)
        #expect(attempts == [.modern, .legacy])
    }

    @Test("Fallback runner surfaces non-timeout failures")
    func fallbackStopsOnNonTimeout() async {
        let runner = ScreenCaptureFallbackRunner(apis: [.modern, .legacy])
        let logger = MockLoggingService().logger(category: LoggingService.Category.screenCapture)
        var attempts: [ScreenCaptureAPI] = []

        do {
            _ = try await runner.run(
                operationName: "captureWindow",
                logger: logger,
                correlationId: UUID().uuidString)
            { api in
                attempts.append(api)
                throw OperationError.captureFailed(reason: "boom")
            }
            Issue.record("Expected captureFailed to throw")
        } catch OperationError.captureFailed {
            #expect(attempts == [.modern])
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
