import Algorithms
import CoreGraphics
import Foundation
import PeekabooFoundation

protocol ScreenCaptureMetricsObserving: Sendable {
    func record(
        operation: String,
        api: ScreenCaptureAPI,
        duration: TimeInterval,
        success: Bool,
        error: (any Error)?)
}

struct NullScreenCaptureMetricsObserver: ScreenCaptureMetricsObserving {
    func record(
        operation _: String,
        api _: ScreenCaptureAPI,
        duration _: TimeInterval,
        success _: Bool,
        error _: (any Error)?)
    {}
}

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
    func captureArea(_ rect: CGRect, correlationId: String, scale: CaptureScalePreference) async throws -> CaptureResult
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
        if let value = environment["PEEKABOO_CAPTURE_ENGINE"]?.lowercased() {
            return self.postProcess(
                apis: self.resolveValue(value),
                environment: environment)
        }

        if let value = environment["PEEKABOO_USE_MODERN_CAPTURE"]?.lowercased() {
            return Self.postProcess(
                apis: Self.resolveValue(value),
                environment: environment)
        }

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
        apis overrideAPIs: [ScreenCaptureAPI]? = nil,
        attempt: @escaping @MainActor @Sendable (ScreenCaptureAPI) async throws -> T) async throws -> T
    {
        var lastError: (any Error)?
        let selectedAPIs = overrideAPIs ?? self.apis
        precondition(!selectedAPIs.isEmpty, "At least one API must be provided")

        for (index, api) in selectedAPIs.indexed() {
            do {
                logger.debug(
                    "Attempting \(operationName) via \(api.description)",
                    correlationId: correlationId)
                let start = Date()
                let result = try await attempt(api)
                let duration = Date().timeIntervalSince(start)
                logger.info(
                    "\(operationName) succeeded via \(api.description)",
                    metadata: [
                        "engine": api.description,
                        "duration": String(format: "%.2f", duration),
                    ],
                    correlationId: correlationId)
                self.observer?(operationName, api, duration, true, nil)
                return result
            } catch {
                lastError = error
                self.observer?(operationName, api, 0, false, error)
                let hasFallback = index < (selectedAPIs.count - 1)
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

    func apis(for preference: CaptureEnginePreference) -> [ScreenCaptureAPI] {
        switch preference {
        case .auto:
            self.apis
        case .modern:
            [.modern]
        case .legacy:
            [.legacy]
        }
    }

    private func shouldFallback(after _: any Error, api: ScreenCaptureAPI, hasFallback: Bool) -> Bool {
        guard hasFallback, api == .modern else { return false }
        return true
    }
}
