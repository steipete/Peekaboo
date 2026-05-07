//
//  ScreenCaptureService+Support.swift
//  PeekabooCore
//

import AppKit
import ApplicationServices
@preconcurrency import AXorcist
import CoreGraphics
import Darwin
import Foundation
import PeekabooFoundation
@preconcurrency import ScreenCaptureKit

extension SCShareableContent: @retroactive @unchecked Sendable {}
extension SCDisplay: @retroactive @unchecked Sendable {}
extension SCWindow: @retroactive @unchecked Sendable {}

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

@_spi(Testing) public enum ScreenCaptureScaleResolver {
    public enum ScaleSource: String, Sendable, Equatable {
        case screenBackingScaleFactor
        case displayPixelRatio
        case fallback1x
    }

    public struct Plan: Sendable, Equatable {
        public let preference: CaptureScalePreference
        public let nativeScale: CGFloat
        public let outputScale: CGFloat
        public let source: ScaleSource

        public init(
            preference: CaptureScalePreference,
            nativeScale: CGFloat,
            outputScale: CGFloat,
            source: ScaleSource)
        {
            self.preference = preference
            self.nativeScale = nativeScale
            self.outputScale = outputScale
            self.source = source
        }
    }

    public static func plan(
        preference: CaptureScalePreference,
        displayID: CGDirectDisplayID,
        fallbackPixelWidth: Int,
        frameWidth: CGFloat,
        screens: [NSScreen] = NSScreen.screens) -> Plan
    {
        self.plan(
            preference: preference,
            screenBackingScaleFactor: self.screenBackingScaleFactor(displayID: displayID, screens: screens),
            fallbackPixelWidth: fallbackPixelWidth,
            frameWidth: frameWidth)
    }

    public static func plan(
        preference: CaptureScalePreference,
        screenBackingScaleFactor: CGFloat?,
        fallbackPixelWidth: Int,
        frameWidth: CGFloat) -> Plan
    {
        let native = self.nativeScaleWithSource(
            screenBackingScaleFactor: screenBackingScaleFactor,
            fallbackPixelWidth: fallbackPixelWidth,
            frameWidth: frameWidth)
        let outputScale: CGFloat = switch preference {
        case .native: native.scale
        case .logical1x: 1.0
        }

        return Plan(
            preference: preference,
            nativeScale: native.scale,
            outputScale: outputScale,
            source: native.source)
    }

    public static func nativeScale(
        displayID: CGDirectDisplayID,
        fallbackPixelWidth: Int,
        frameWidth: CGFloat,
        screens: [NSScreen] = NSScreen.screens) -> CGFloat
    {
        self.plan(
            preference: .native,
            displayID: displayID,
            fallbackPixelWidth: fallbackPixelWidth,
            frameWidth: frameWidth,
            screens: screens).nativeScale
    }

    public static func nativeScale(
        screenBackingScaleFactor: CGFloat?,
        fallbackPixelWidth: Int,
        frameWidth: CGFloat) -> CGFloat
    {
        self.nativeScaleWithSource(
            screenBackingScaleFactor: screenBackingScaleFactor,
            fallbackPixelWidth: fallbackPixelWidth,
            frameWidth: frameWidth).scale
    }

    private static func nativeScaleWithSource(
        screenBackingScaleFactor: CGFloat?,
        fallbackPixelWidth: Int,
        frameWidth: CGFloat) -> (scale: CGFloat, source: ScaleSource)
    {
        if let screenScale = screenBackingScaleFactor, screenScale > 0 {
            return (screenScale, .screenBackingScaleFactor)
        }

        guard frameWidth > 0 else { return (1.0, .fallback1x) }
        let scale = CGFloat(fallbackPixelWidth) / frameWidth
        return scale > 0 ? (scale, .displayPixelRatio) : (1.0, .fallback1x)
    }

    private static func screenBackingScaleFactor(displayID: CGDirectDisplayID, screens: [NSScreen]) -> CGFloat? {
        let targetID = NSNumber(value: displayID)
        guard let screen = screens.first(where: { screen in
            screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber == targetID
        }) else {
            return nil
        }

        return screen.backingScaleFactor > 0 ? screen.backingScaleFactor : nil
    }
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
}

@MainActor
@_spi(Testing) public protocol ScreenRecordingPermissionEvaluating: Sendable {
    func hasPermission(logger: CategoryLogger) async -> Bool
}

struct ScreenRecordingPermissionChecker: ScreenRecordingPermissionEvaluating {
    func hasPermission(logger: CategoryLogger) async -> Bool {
        let preflightResult = CGPreflightScreenCaptureAccess()
        if preflightResult {
            return true
        }

        // CGPreflightScreenCaptureAccess is unreliable for CLI tools — it often
        // returns false even when permission is granted (TCC tracks by code signature
        // and the check can fail after rebuilds or for non-.app bundles).
        // Fall back to probing ScreenCaptureKit which gives the ground-truth answer.
        logger.debug("CGPreflightScreenCaptureAccess returned false, probing SCShareableContent")
        do {
            _ = try await ScreenCaptureKitCaptureGate.currentShareableContent()
            logger.info("Screen recording permission granted (SCShareableContent probe)")
            return true
        } catch {
            logger.warning("Screen recording permission not granted (SCShareableContent probe failed: \(error))")
            return false
        }
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
            // Explicit engine selection is a hard request; do not silently fall back to the other stack.
            [.modern]
        case .legacy:
            // `classic`/`cg` are used for targeted repros and workarounds, so keep the path deterministic.
            [.legacy]
        }
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
    func findApplication(identifier: String) async throws -> ServiceApplicationInfo {
        let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let runningApps = NSWorkspace.shared.runningApplications.filter { app in
            !app.isTerminated
        }

        if let pid = Self.parsePID(trimmedIdentifier),
           let app = runningApps.first(where: { $0.processIdentifier == pid })
        {
            return Self.applicationInfo(from: app)
        }

        if let bundleMatch = runningApps.first(where: { $0.bundleIdentifier == trimmedIdentifier }) {
            return Self.applicationInfo(from: bundleMatch)
        }

        if let exactName = runningApps.first(where: {
            guard let name = $0.localizedName else { return false }
            return name.compare(trimmedIdentifier, options: .caseInsensitive) == .orderedSame
        }) {
            return Self.applicationInfo(from: exactName)
        }

        let fuzzyMatches = runningApps.compactMap { app -> (app: NSRunningApplication, score: Int)? in
            guard app.activationPolicy != .prohibited,
                  let name = app.localizedName,
                  name.localizedCaseInsensitiveContains(trimmedIdentifier)
            else { return nil }

            var score = 0
            if name.compare(trimmedIdentifier, options: .caseInsensitive) == .orderedSame {
                score += 1000
            }
            if name.lowercased().hasPrefix(trimmedIdentifier.lowercased()) {
                score += 100
            }
            if app.activationPolicy == .regular {
                score += 50
            }
            score -= name.count
            return (app, score)
        }

        if let bestMatch = fuzzyMatches.max(by: { $0.score < $1.score }) {
            return Self.applicationInfo(from: bestMatch.app)
        }

        throw PeekabooError.appNotFound(identifier)
    }

    private static func parsePID(_ identifier: String) -> Int32? {
        guard identifier.uppercased().hasPrefix("PID:") else { return nil }
        return Int32(identifier.dropFirst(4))
    }

    private static func applicationInfo(from app: NSRunningApplication) -> ServiceApplicationInfo {
        ServiceApplicationInfo(
            processIdentifier: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            name: app.localizedName ?? app.bundleIdentifier ?? "Unknown",
            bundlePath: app.bundleURL?.path,
            isActive: app.isActive,
            isHidden: app.isHidden,
            windowCount: 0)
    }
}

func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T) async throws -> T
{
    try await AXTimeoutHelper.withTimeout(seconds: seconds, operation: operation)
}

enum ScreenCaptureKitCaptureGate {
    /// Protects concurrent SCK calls within one process. ScreenCaptureKit can leak
    /// continuations instead of returning an error when re-entered under load.
    @MainActor private static var isCaptureActive = false

    @MainActor
    static func captureImage(
        contentFilter: SCContentFilter,
        configuration: SCStreamConfiguration) async throws -> CGImage
    {
        try await self.withExclusiveCapture {
            try await self
                .withScreenCaptureKitTimeout(seconds: 3.0, operationName: "SCScreenshotManager.captureImage") {
                    try await SCScreenshotManager.captureImage(
                        contentFilter: contentFilter,
                        configuration: configuration)
                }
        }
    }

    @MainActor
    static func currentShareableContent() async throws -> SCShareableContent {
        try await self.withExclusiveCapture {
            try await self.withScreenCaptureKitTimeout(seconds: 5.0, operationName: "SCShareableContent.current") {
                try await SCShareableContent.current
            }
        }
    }

    @MainActor
    static func shareableContent(
        excludingDesktopWindows: Bool,
        onScreenWindowsOnly: Bool) async throws -> SCShareableContent
    {
        try await self.withExclusiveCapture {
            try await self.withScreenCaptureKitTimeout(
                seconds: 5.0,
                operationName: "SCShareableContent.excludingDesktopWindows")
            {
                try await SCShareableContent.excludingDesktopWindows(
                    excludingDesktopWindows,
                    onScreenWindowsOnly: onScreenWindowsOnly)
            }
        }
    }

    @MainActor
    private static func withExclusiveCapture<T: Sendable>(
        _ operation: () async throws -> T) async throws -> T
    {
        while self.isCaptureActive {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        self.isCaptureActive = true
        defer { self.isCaptureActive = false }

        // Also serialize across separate `peekaboo` CLI invocations; the underlying
        // replayd/ScreenCaptureKit service is shared system-wide.
        let path = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("boo.peekaboo.sckit-capture.lock")
        let fd = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else {
            return try await operation()
        }
        defer { close(fd) }

        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK || errno == EAGAIN || errno == EINTR else {
                // Locking is defensive. If it fails unexpectedly, keep capture functional.
                return try await operation()
            }

            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        defer { flock(fd, LOCK_UN) }

        return try await operation()
    }

    @MainActor
    private static func withScreenCaptureKitTimeout<T: Sendable>(
        seconds: TimeInterval,
        operationName: String,
        operation: @escaping @MainActor @Sendable () async throws -> T) async throws -> T
    {
        let race = ScreenCaptureKitTimeoutRace<T>()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                race.setContinuation(continuation)

                let operationTask = Task { @MainActor in
                    do {
                        let value = try await operation()
                        race.resume(.success(value))
                    } catch {
                        race.resume(.failure(error))
                    }
                }
                let timeoutTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: Self.timeoutNanoseconds(for: seconds))
                    } catch {
                        return
                    }
                    operationTask.cancel()
                    race.resume(.failure(OperationError.timeout(operation: operationName, duration: seconds)))
                }

                race.setTasks(operationTask: operationTask, timeoutTask: timeoutTask)
            }
        } onCancel: {
            race.cancel()
        }
    }

    private nonisolated static func timeoutNanoseconds(for seconds: TimeInterval) -> UInt64 {
        UInt64(max(seconds, 0) * 1_000_000_000)
    }
}

private final class ScreenCaptureKitTimeoutRace<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, any Error>?
    private var operationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var didFinish = false

    func setContinuation(_ continuation: CheckedContinuation<T, any Error>) {
        self.lock.withLock {
            self.continuation = continuation
        }
    }

    func setTasks(operationTask: Task<Void, Never>, timeoutTask: Task<Void, Never>) {
        var shouldCancel = false
        self.lock.withLock {
            shouldCancel = self.didFinish
            if !self.didFinish {
                self.operationTask = operationTask
                self.timeoutTask = timeoutTask
            }
        }

        if shouldCancel {
            operationTask.cancel()
            timeoutTask.cancel()
        }
    }

    func resume(_ result: Result<T, any Error>) {
        let continuation: CheckedContinuation<T, any Error>?
        let operationTask: Task<Void, Never>?
        let timeoutTask: Task<Void, Never>?

        self.lock.lock()
        guard !self.didFinish else {
            self.lock.unlock()
            return
        }

        self.didFinish = true
        continuation = self.continuation
        operationTask = self.operationTask
        timeoutTask = self.timeoutTask
        self.continuation = nil
        self.operationTask = nil
        self.timeoutTask = nil
        self.lock.unlock()

        // SCK sometimes leaks its own continuation after cancellation; this wrapper intentionally
        // returns to the caller without waiting for that child task to unwind.
        operationTask?.cancel()
        timeoutTask?.cancel()

        switch result {
        case let .success(value):
            continuation?.resume(returning: value)
        case let .failure(error):
            continuation?.resume(throwing: error)
        }
    }

    func cancel() {
        self.resume(.failure(CancellationError()))
    }
}
