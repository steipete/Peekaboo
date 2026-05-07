//
//  ScreenCaptureServicePlanTests.swift
//  PeekabooCore
//

import CoreGraphics
import Foundation
import PeekabooFoundation
import Testing
@_spi(Testing) import PeekabooAutomationKit

private enum CaptureTestError: Error {
    case modernFailure
    case legacyFailure
}

@MainActor
struct ScreenCaptureServicePlanTests {
    @Test
    func `Resolver defaults to modern first when flag is unset`() {
        let order = ScreenCaptureAPIResolver.resolve(environment: [:])
        #expect(order == [.modern, .legacy])
    }

    @Test
    func `Resolver prefers modern APIs when flag is true`() {
        let order = ScreenCaptureAPIResolver.resolve(environment: ["PEEKABOO_USE_MODERN_CAPTURE": "true"])
        #expect(order == [.modern, .legacy])
    }

    @Test
    func `Resolver forces modern only when explicitly requested`() {
        let order = ScreenCaptureAPIResolver.resolve(environment: ["PEEKABOO_USE_MODERN_CAPTURE": "modern-only"])
        #expect(order == [.modern])
    }

    @Test
    func `Resolver forces legacy when flag is false`() {
        let order = ScreenCaptureAPIResolver.resolve(environment: ["PEEKABOO_USE_MODERN_CAPTURE": "false"])
        #expect(order == [.legacy])
    }

    @Test
    func `Fallback runner retries on timeout errors`() async throws {
        let runner = ScreenCaptureFallbackRunner(apis: [.modern, .legacy])
        let logger = MockLoggingService().logger(category: "screenCapture")
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

    @Test
    func `Fallback runner retries even on unknown errors`() async throws {
        let runner = ScreenCaptureFallbackRunner(apis: [.modern, .legacy])
        let logger = MockLoggingService().logger(category: "screenCapture")
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

    @Test
    func `Fallback runner surfaces the final error when all APIs fail`() async {
        let runner = ScreenCaptureFallbackRunner(apis: [.modern, .legacy])
        let logger = MockLoggingService().logger(category: "screenCapture")
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

    @Test
    func `Frame source policy uses stream for screen/area and single-shot for windows`() {
        #expect(ScreenCapturePlanner.frameSourcePolicy(for: .screen, windowID: nil) == .fastStream)
        #expect(ScreenCapturePlanner.frameSourcePolicy(for: .area, windowID: nil) == .fastStream)
        #expect(ScreenCapturePlanner.frameSourcePolicy(for: .multi, windowID: nil) == .fastStream)
        #expect(ScreenCapturePlanner.frameSourcePolicy(for: .window, windowID: CGWindowID(42)) == .singleShot)
        #expect(ScreenCapturePlanner.frameSourcePolicy(for: .frontmost, windowID: nil) == .singleShot)
    }
}
