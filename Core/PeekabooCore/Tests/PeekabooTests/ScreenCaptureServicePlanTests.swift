//
//  ScreenCaptureServicePlanTests.swift
//  PeekabooCore
//

import Foundation
import PeekabooAutomation
import PeekabooFoundation
import Testing
@testable import PeekabooAutomation

private enum CaptureTestError: Error {
    case modernFailure
    case legacyFailure
}

@Suite("ScreenCaptureService planning helpers")
@MainActor
struct ScreenCaptureServicePlanTests {
    @Test("Resolver defaults to modern first when flag is unset")
    func resolverDefaultsToModern() {
        let order = ScreenCaptureAPIResolver.resolve(environment: [:])
        #expect(order == [.modern, .legacy])
    }

    @Test("Resolver prefers modern APIs when flag is true")
    func resolverPrefersModern() {
        let order = ScreenCaptureAPIResolver.resolve(environment: ["PEEKABOO_USE_MODERN_CAPTURE": "true"])
        #expect(order == [.modern, .legacy])
    }

    @Test("Resolver forces modern only when explicitly requested")
    func resolverModernOnly() {
        let order = ScreenCaptureAPIResolver.resolve(environment: ["PEEKABOO_USE_MODERN_CAPTURE": "modern-only"])
        #expect(order == [.modern])
    }

    @Test("Resolver forces legacy when flag is false")
    func resolverLegacyOnly() {
        let order = ScreenCaptureAPIResolver.resolve(environment: ["PEEKABOO_USE_MODERN_CAPTURE": "false"])
        #expect(order == [.legacy])
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

    @Test("Fallback runner retries even on unknown errors")
    func fallbackRetriesOnUnknownErrors() async throws {
        let runner = ScreenCaptureFallbackRunner(apis: [.modern, .legacy])
        let logger = MockLoggingService().logger(category: LoggingService.Category.screenCapture)
        var attempts: [ScreenCaptureAPI] = []

        let result = try await runner.run(
            operationName: "captureWindow",
            logger: logger,
            correlationId: UUID().uuidString)
        { api in
            attempts.append(api)
            if api == .modern {
                throw CaptureTestError.modernFailure
            }
            return api
        }

        #expect(result == .legacy)
        #expect(attempts == [.modern, .legacy])
    }

    @Test("Fallback runner surfaces the final error when all APIs fail")
    func fallbackSurfacesLastError() async {
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
                if api == .modern {
                    throw CaptureTestError.modernFailure
                }
                throw CaptureTestError.legacyFailure
            }
            Issue.record("Expected legacy failure to throw")
        } catch CaptureTestError.legacyFailure {
            #expect(attempts == [.modern, .legacy])
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
