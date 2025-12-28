//
//  ScreenCaptureService+Support.swift
//  PeekabooCore
//

import ApplicationServices
@preconcurrency import AXorcist
import CoreGraphics
import Foundation
import PeekabooFoundation
@preconcurrency import ScreenCaptureKit

extension SCShareableContent: @retroactive @unchecked Sendable {}
extension SCDisplay: @retroactive @unchecked Sendable {}
extension SCWindow: @retroactive @unchecked Sendable {}

@MainActor
@_spi(Testing) public protocol ModernScreenCaptureOperating: Sendable {
    func captureScreen(
        displayIndex: Int?,
        correlationId: String,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    func captureWindow(
        app: ServiceApplicationInfo,
        windowIndex: Int?,
        correlationId: String,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws
        -> CaptureResult
    func captureWindow(
        windowID: CGWindowID,
        correlationId: String,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws
        -> CaptureResult
    func captureArea(_ rect: CGRect, correlationId: String, scale: CaptureScalePreference) async throws -> CaptureResult
}

@MainActor
@_spi(Testing) public protocol LegacyScreenCaptureOperating: Sendable {
    func captureScreen(
        displayIndex: Int?,
        correlationId: String,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    func captureWindow(
        app: ServiceApplicationInfo,
        windowIndex: Int?,
        correlationId: String,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws
        -> CaptureResult
    func captureWindow(
        windowID: CGWindowID,
        correlationId: String,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws
        -> CaptureResult
}

@MainActor
@_spi(Testing) public protocol ScreenRecordingPermissionEvaluating: Sendable {
    func hasPermission(logger: CategoryLogger) async -> Bool
}

struct ScreenRecordingPermissionChecker: ScreenRecordingPermissionEvaluating {
    func hasPermission(logger: CategoryLogger) async -> Bool {
        let hasPermission = CGPreflightScreenCaptureAccess()
        if !hasPermission {
            logger.warning("Screen recording permission not granted")
        }
        return hasPermission
    }
}

@_spi(Testing) public enum ScreenCaptureAPI: String, Sendable, CaseIterable {
    case modern
    case legacy

    var description: String {
        switch self {
        case .modern: "ScreenCaptureKit"
        case .legacy: "CGWindowList"
        }
    }
}

@_spi(Testing) public enum ScreenCaptureAPIResolver {
    @_spi(Testing) public static func resolve(environment: [String: String]) -> [ScreenCaptureAPI] {
        // New selector (preferred): PEEKABOO_CAPTURE_ENGINE
        if let value = environment["PEEKABOO_CAPTURE_ENGINE"]?.lowercased() {
            return self.postProcess(
                apis: self.resolveValue(value),
                environment: environment)
        }

        // Back-compat selector: PEEKABOO_USE_MODERN_CAPTURE (bool-ish)
        if let value = environment["PEEKABOO_USE_MODERN_CAPTURE"]?.lowercased() {
            return Self.postProcess(
                apis: Self.resolveValue(value),
                environment: environment)
        }

        // Default: modern then legacy
        return Self.postProcess(
            apis: [.modern, .legacy],
            environment: environment)
    }

    private static func resolveValue(_ value: String) -> [ScreenCaptureAPI] {
        switch value {
        case "auto":
            [.modern, .legacy]
        case "modern", "modern-only", "sckit", "sc", "screen-capture-kit", "sck":
            [.modern]
        case "classic", "cg", "legacy", "legacy-only", "false", "0", "no":
            [.legacy]
        case "true", "1", "yes":
            [.modern, .legacy]
        default:
            [.modern, .legacy]
        }
    }

    /// Apply global disables (e.g., SC-only dogfooding), but honor explicit classic choices.
    private static func postProcess(
        apis: [ScreenCaptureAPI],
        environment: [String: String]) -> [ScreenCaptureAPI]
    {
        if let value = environment["PEEKABOO_DISABLE_CGWINDOWLIST"]?.lowercased(),
           ["1", "true", "yes"].contains(value)
        {
            let filtered = apis.filter { $0 != .legacy }
            return filtered.isEmpty ? [.modern] : filtered
        }
        return apis
    }
}

@_spi(Testing) public struct ScreenCaptureFallbackRunner {
    let apis: [ScreenCaptureAPI]
    let observer: ((String, ScreenCaptureAPI, TimeInterval, Bool, (any Error)?) -> Void)?

    public init(
        apis: [ScreenCaptureAPI],
        observer: (@Sendable (String, ScreenCaptureAPI, TimeInterval, Bool, (any Error)?) -> Void)? = nil)
    {
        precondition(!apis.isEmpty, "At least one API must be provided")
        self.apis = apis
        self.observer = observer
    }

    @MainActor
    @_spi(Testing) public func run<T: Sendable>(
        operationName: String,
        logger: CategoryLogger,
        correlationId: String,
        attempt: @escaping @MainActor @Sendable (ScreenCaptureAPI) async throws -> T) async throws -> T
    {
        var lastError: (any Error)?

        for (index, api) in self.apis.indexed() {
            do {
                logger.debug(
                    "Attempting \(operationName) via \(api.description)",
                    correlationId: correlationId)
                let start = Date()
                let result = try await attempt(api)
                let duration = Date().timeIntervalSince(start)
                let message = "\(operationName) succeeded via \(api.description)"
                logger.info(
                    message,
                    metadata: [
                        "engine": api.description,
                        "duration": String(format: "%.2f", duration),
                    ],
                    correlationId: correlationId)
                self.observer?(operationName, api, duration, true, nil)
                return result
            } catch {
                lastError = error
                // We don't have a scoped start time here; treat duration as 0 for failed attempts.
                self.observer?(operationName, api, 0, false, error)
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
        guard hasFallback, api == .modern else { return false }
        // Any modern failure should attempt the legacy stack so agents keep moving even if ScreenCaptureKit flakes.
        return true
    }
}

@_spi(Testing) public protocol ApplicationResolving: Sendable {
    func findApplication(identifier: String) async throws -> ServiceApplicationInfo
}

struct PeekabooApplicationResolver: ApplicationResolving {
    private let applicationService: any ApplicationServiceProtocol

    init(applicationService: any ApplicationServiceProtocol) {
        self.applicationService = applicationService
    }

    func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        try await self.applicationService.findApplication(identifier: identifier)
    }
}

func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T) async throws -> T
{
    try await AXTimeoutHelper.withTimeout(seconds: seconds, operation: operation)
}
