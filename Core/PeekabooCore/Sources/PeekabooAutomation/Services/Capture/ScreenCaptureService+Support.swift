//
//  ScreenCaptureService+Support.swift
//  PeekabooCore
//

import CoreGraphics
import Foundation
import PeekabooFoundation
import PeekabooVisualizer
@preconcurrency import AXorcist
@preconcurrency import ScreenCaptureKit

extension SCShareableContent: @retroactive @unchecked Sendable {}
extension SCDisplay: @retroactive @unchecked Sendable {}
extension SCWindow: @retroactive @unchecked Sendable {}

@MainActor
protocol ModernScreenCaptureOperating: Sendable {
    func captureScreen(
        displayIndex: Int?,
        correlationId: String,
        visualizerMode: CaptureVisualizerMode) async throws -> CaptureResult
    func captureWindow(
        app: ServiceApplicationInfo,
        windowIndex: Int?,
        correlationId: String,
        visualizerMode: CaptureVisualizerMode) async throws
        -> CaptureResult
    func captureArea(_ rect: CGRect, correlationId: String) async throws -> CaptureResult
}

@MainActor
protocol LegacyScreenCaptureOperating: Sendable {
    func captureScreen(
        displayIndex: Int?,
        correlationId: String,
        visualizerMode: CaptureVisualizerMode) async throws -> CaptureResult
    func captureWindow(
        app: ServiceApplicationInfo,
        windowIndex: Int?,
        correlationId: String,
        visualizerMode: CaptureVisualizerMode) async throws
        -> CaptureResult
}

@MainActor
protocol VisualizationClientProtocol: Sendable {
    func connect()
    func showScreenshotFlash(in rect: CGRect) async -> Bool
    func showWatchCapture(in rect: CGRect) async -> Bool
}

extension VisualizationClient: VisualizationClientProtocol {}

@MainActor
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
        // New selector (preferred): PEEKABOO_CAPTURE_ENGINE
        if let value = environment["PEEKABOO_CAPTURE_ENGINE"]?.lowercased() {
            return Self.postProcess(
                apis: Self.resolveValue(value),
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
            return [.modern, .legacy]
        case "modern", "modern-only", "sckit", "sc", "screen-capture-kit", "sck":
            return [.modern]
        case "classic", "cg", "legacy", "legacy-only", "false", "0", "no":
            return [.legacy]
        case "true", "1", "yes":
            return [.modern, .legacy]
        default:
            return [.modern, .legacy]
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
                        "duration": String(format: "%.2f", duration)
                    ],
                    correlationId: correlationId)
                return result
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
        guard hasFallback, api == .modern else { return false }
        // Any modern failure should attempt the legacy stack so agents keep moving even if ScreenCaptureKit flakes.
        return true
    }
}

protocol ApplicationResolving: Sendable {
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
