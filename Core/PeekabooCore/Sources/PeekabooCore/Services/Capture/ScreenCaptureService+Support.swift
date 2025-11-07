//
//  ScreenCaptureService+Support.swift
//  PeekabooCore
//

import CoreGraphics
import Foundation
import PeekabooFoundation
@preconcurrency import ScreenCaptureKit

extension SCShareableContent: @retroactive @unchecked Sendable {}
extension SCDisplay: @retroactive @unchecked Sendable {}
extension SCWindow: @retroactive @unchecked Sendable {}

protocol ModernScreenCaptureOperating: Sendable {
    func captureScreen(displayIndex: Int?, correlationId: String) async throws -> CaptureResult
    func captureWindow(app: ServiceApplicationInfo, windowIndex: Int?, correlationId: String) async throws
        -> CaptureResult
    func captureArea(_ rect: CGRect, correlationId: String) async throws -> CaptureResult
}

protocol LegacyScreenCaptureOperating: Sendable {
    func captureScreen(displayIndex: Int?, correlationId: String) async throws -> CaptureResult
    func captureWindow(app: ServiceApplicationInfo, windowIndex: Int?, correlationId: String) async throws
        -> CaptureResult
}

@MainActor
protocol VisualizationClientProtocol: Sendable {
    func connect()
    func showScreenshotFlash(in rect: CGRect) async -> Bool
}

extension VisualizationClient: VisualizationClientProtocol {}

protocol ScreenRecordingPermissionEvaluating: Sendable {
    func hasPermission(logger: CategoryLogger) async -> Bool
}

struct ScreenRecordingPermissionChecker: ScreenRecordingPermissionEvaluating {
    func hasPermission(logger: CategoryLogger) async -> Bool {
        do {
            _ = try await withTimeout(seconds: 3.0) {
                try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            }
            return true
        } catch {
            logger.warning("Permission check failed or timed out: \(error)")
            return false
        }
    }
}

enum ScreenCaptureAPI: String, Sendable, CaseIterable {
    case modern
    case legacy

    var description: String {
        switch self {
        case .modern: "ScreenCaptureKit"
        case .legacy: "CGWindowList"
        }
    }
}

enum ScreenCaptureAPIResolver {
    static func resolve(environment: [String: String]) -> [ScreenCaptureAPI] {
        guard let value = environment["PEEKABOO_USE_MODERN_CAPTURE"]?.lowercased() else {
            return [.legacy]
        }

        switch value {
        case "true", "1", "yes", "modern":
            return [.modern, .legacy]
        default:
            return [.legacy]
        }
    }
}

struct ScreenCaptureFallbackRunner: Sendable {
    let apis: [ScreenCaptureAPI]

    init(apis: [ScreenCaptureAPI]) {
        precondition(!apis.isEmpty, "At least one API must be provided")
        self.apis = apis
    }

    @MainActor
    func run<T: Sendable>(
        operationName: String,
        logger: CategoryLogger,
        correlationId: String,
        attempt: @escaping @MainActor @Sendable (ScreenCaptureAPI) async throws -> T) async throws -> T
    {
        var lastError: (any Error)?

        for (index, api) in self.apis.enumerated() {
            do {
                logger.debug(
                    "Attempting \(operationName) via \(api.description)",
                    correlationId: correlationId)
                return try await attempt(api)
            } catch {
                lastError = error
                let hasFallback = index < (self.apis.count - 1)
                if self.shouldFallback(after: error, api: api, hasFallback: hasFallback) {
                    logger.warning(
                        "\(api.description) capture failed, retrying with fallback API",
                        metadata: ["error": String(describing: error)],
                        correlationId: correlationId)
                    continue
                }
                throw error
            }
        }

        throw lastError ?? OperationError.captureFailed(reason: "\(operationName) failed")
    }

    private func shouldFallback(after error: any Error, api: ScreenCaptureAPI, hasFallback: Bool) -> Bool {
        guard hasFallback else { return false }
        guard api == .modern else { return false }
        if case OperationError.timeout = error {
            return true
        }
        return false
    }
}

protocol ApplicationResolving: Sendable {
    func findApplication(identifier: String) async throws -> ServiceApplicationInfo
}

struct PeekabooApplicationResolver: ApplicationResolving {
    func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        try await PeekabooServices.shared.applications.findApplication(identifier: identifier)
    }
}

func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T) async throws -> T
{
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw OperationError.timeout(operation: "SCShareableContent", duration: seconds)
        }

        guard let result = try await group.next() else {
            throw OperationError.timeout(operation: "SCShareableContent", duration: seconds)
        }

        group.cancelAll()
        return result
    }
}
