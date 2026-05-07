import CoreGraphics
import Foundation
import PeekabooFoundation

/**
 * Screen and window capture service with dual API support.
 *
 * Provides fast screen capture using ScreenCaptureKit (modern) or CGWindowList (legacy) APIs.
 * Automatically handles API selection, permission management, and retry logic with visual
 * feedback integration.
 *
 * ## Core Capabilities
 * - Screen capture for specific displays or main display
 * - Window capture with application targeting
 * - Dual API architecture with automatic fallback
 * - Built-in retry logic and permission validation
 *
 * ## Usage Example
 * ```swift
 * let captureService = ScreenCaptureService(loggingService: logger)
 *
 * // Capture main screen
 * let screenResult = try await captureService.captureScreen(displayIndex: nil)
 *
 * // Capture application window
 * let windowResult = try await captureService.captureWindow(
 *     appIdentifier: "Safari",
 *     windowIndex: 0
 * )
 * ```
 *
 * ## API Control
 * Use `PEEKABOO_CAPTURE_ENGINE=auto|modern|sckit|classic|cg` (preferred) or
 * `PEEKABOO_USE_MODERN_CAPTURE=true/false` (legacy) to control engine selection.
 *
 * - Important: Requires Screen Recording permission
 * - Note: Performance 20-150ms depending on operation and display size
 * - Since: PeekabooCore 1.0.0
 */
@MainActor
public final class ScreenCaptureService: ScreenCaptureServiceProtocol, EngineAwareScreenCaptureServiceProtocol {
    @_spi(Testing) public struct Dependencies {
        let feedbackClient: any AutomationFeedbackClient
        let permissionEvaluator: any ScreenRecordingPermissionEvaluating
        let fallbackRunner: ScreenCaptureFallbackRunner
        let applicationResolver: any ApplicationResolving
        let makeFrameSource: @MainActor @Sendable (CategoryLogger) -> any CaptureFrameSource
        let makeModernOperator: @MainActor @Sendable (CategoryLogger, any AutomationFeedbackClient)
            -> any ModernScreenCaptureOperating
        let makeLegacyOperator: @MainActor @Sendable (CategoryLogger)
            -> any LegacyScreenCaptureOperating
        public init(
            feedbackClient: any AutomationFeedbackClient,
            permissionEvaluator: any ScreenRecordingPermissionEvaluating,
            fallbackRunner: ScreenCaptureFallbackRunner,
            applicationResolver: any ApplicationResolving,
            makeFrameSource: @escaping @MainActor @Sendable (CategoryLogger) -> any CaptureFrameSource,
            makeModernOperator: @escaping @MainActor @Sendable (CategoryLogger, any AutomationFeedbackClient)
                -> any ModernScreenCaptureOperating,
            makeLegacyOperator: @escaping @MainActor @Sendable (CategoryLogger)
                -> any LegacyScreenCaptureOperating)
        {
            self.feedbackClient = feedbackClient
            self.permissionEvaluator = permissionEvaluator
            self.fallbackRunner = fallbackRunner
            self.applicationResolver = applicationResolver
            self.makeFrameSource = makeFrameSource
            self.makeModernOperator = makeModernOperator
            self.makeLegacyOperator = makeLegacyOperator
        }

        @MainActor
        static func live(
            environment: [String: String] = ProcessInfo.processInfo.environment,
            applicationResolver: (any ApplicationResolving)? = nil,
            metricsObserver: (any ScreenCaptureMetricsObserving)? = nil) -> Dependencies
        {
            let resolver = applicationResolver ?? PeekabooApplicationResolver()
            let captureObserver: (@Sendable (String, ScreenCaptureAPI, TimeInterval, Bool, (any Error)?) -> Void)? =
                if let metricsObserver {
                    { operation, api, duration, success, error in
                        metricsObserver.record(
                            operation: operation,
                            api: api,
                            duration: duration,
                            success: success,
                            error: error)
                    }
                } else {
                    nil
                }
            let frameSourceFactory: @MainActor @Sendable (CategoryLogger) -> any CaptureFrameSource = { logger in
                ScreenCaptureKitFrameSource(logger: logger)
            }
            return Dependencies(
                feedbackClient: NoopAutomationFeedbackClient(),
                permissionEvaluator: ScreenRecordingPermissionChecker(),
                fallbackRunner: ScreenCaptureFallbackRunner(
                    apis: ScreenCaptureAPIResolver.resolve(environment: environment),
                    observer: captureObserver),
                applicationResolver: resolver,
                makeFrameSource: frameSourceFactory,
                makeModernOperator: { logger, visualizer in
                    ScreenCaptureKitOperator(
                        logger: logger,
                        feedbackClient: visualizer,
                        frameSource: frameSourceFactory(logger))
                },
                makeLegacyOperator: { logger in
                    LegacyScreenCaptureOperator(logger: logger)
                })
        }
    }

    private let logger: CategoryLogger
    private let feedbackClient: any AutomationFeedbackClient
    private let permissionGate: ScreenCapturePermissionGate
    private let fallbackRunner: ScreenCaptureFallbackRunner
    private let applicationResolver: any ApplicationResolving
    private let modernOperator: any ModernScreenCaptureOperating
    private let legacyOperator: any LegacyScreenCaptureOperating
    @TaskLocal private static var captureEnginePreference: CaptureEnginePreference = .auto

    private typealias Metadata = [String: Any]

    private enum CaptureOperation {
        case screen
        case window
        case frontmost
        case area

        var metricName: String {
            switch self {
            case .screen: "captureScreen"
            case .window: "captureWindow"
            case .frontmost: "captureFrontmost"
            case .area: "captureArea"
            }
        }

        var logLabel: String {
            switch self {
            case .screen: "screen capture"
            case .window: "window capture"
            case .frontmost: "frontmost window capture"
            case .area: "area capture"
            }
        }
    }

    private struct WindowCaptureOptions {
        let visualizerMode: CaptureVisualizerMode
        let scale: CaptureScalePreference
    }

    private struct CaptureInvocationContext {
        let operation: CaptureOperation
        let correlationId: String
    }

    public convenience init(loggingService: any LoggingServiceProtocol) {
        self.init(loggingService: loggingService, dependencies: .live())
    }

    @_spi(Testing) public init(
        loggingService: any LoggingServiceProtocol,
        dependencies: Dependencies)
    {
        self.logger = loggingService.logger(category: LoggingService.Category.screenCapture)
        self.feedbackClient = dependencies.feedbackClient
        self.permissionGate = ScreenCapturePermissionGate(evaluator: dependencies.permissionEvaluator)
        self.fallbackRunner = dependencies.fallbackRunner
        self.applicationResolver = dependencies.applicationResolver
        self.modernOperator = dependencies.makeModernOperator(self.logger, self.feedbackClient)
        self.legacyOperator = dependencies.makeLegacyOperator(self.logger)

        // Only connect to visualizer if we're not running inside the Mac app
        // The Mac app provides the visualizer service, not consumes it
        let isMacApp = Bundle.main.bundleIdentifier?.hasPrefix("boo.peekaboo.mac") == true
        if !isMacApp {
            self.logger.debug("Connecting to visualizer service (running as CLI/external tool)")
            self.feedbackClient.connect()
        } else {
            self.logger.debug("Skipping visualizer connection (running inside Mac app)")
        }
    }

    func withCaptureEngine<T: Sendable>(
        _ engine: CaptureEnginePreference,
        operation: @MainActor () async throws -> T) async rethrows -> T
    {
        try await Self.$captureEnginePreference.withValue(engine, operation: operation)
    }

    private func performOperation<T: Sendable>(
        _ operation: CaptureOperation,
        metadata: Metadata = [:],
        requiresPermission: Bool = true,
        body: @escaping @MainActor @Sendable (_ correlationId: String) async throws -> T) async throws -> T
    {
        let correlationId = UUID().uuidString
        self.logger.info(
            "Starting \(operation.logLabel)",
            metadata: metadata,
            correlationId: correlationId)

        // Start the logger's perf counter so tools can emit duration metrics even if we bail early.
        // Must capture the opaque ID up front—endPerformanceMeasurement needs the exact token.
        let measurementId = self.logger.startPerformanceMeasurement(
            operation: operation.metricName,
            correlationId: correlationId)
        defer {
            logger.endPerformanceMeasurement(
                measurementId: measurementId,
                metadata: metadata)
        }

        if requiresPermission {
            try await self.permissionGate.requirePermission(logger: self.logger, correlationId: correlationId)
        }

        return try await ScreenCaptureKitCaptureGate.withExclusiveCaptureOperation(
            operationName: operation.metricName)
        {
            try await body(correlationId)
        }
    }

    public func captureScreen(
        displayIndex: Int?,
        visualizerMode: CaptureVisualizerMode = .screenshotFlash,
        scale: CaptureScalePreference = .logical1x) async throws -> CaptureResult
    {
        let metadata: Metadata = ["displayIndex": displayIndex ?? "main"]
        let apis = self.fallbackRunner.apis(for: Self.captureEnginePreference)
        return try await self.performOperation(.screen, metadata: metadata) { correlationId in
            try await self.fallbackRunner.runCapture(
                operationName: CaptureOperation.screen.metricName,
                logger: self.logger,
                correlationId: correlationId,
                apis: apis)
            { api in
                switch api {
                case .modern:
                    try await self.modernOperator.captureScreen(
                        displayIndex: displayIndex,
                        correlationId: correlationId,
                        visualizerMode: visualizerMode,
                        scale: scale)
                case .legacy:
                    try await self.legacyOperator.captureScreen(
                        displayIndex: displayIndex,
                        correlationId: correlationId,
                        visualizerMode: visualizerMode,
                        scale: scale)
                }
            }
        }
    }

    /**
     * Capture a specific application window with precise targeting.
     *
     * - Parameters:
     *   - appIdentifier: Application identifier (name, bundle ID, or "PID:1234" format)
     *   - windowIndex: Window index within app (nil for frontmost window, 0-based indexing)
     * - Returns: `CaptureResult` containing image data, metadata, and optional saved path
     * - Throws: `PeekabooError` if application not found, window index invalid, or capture fails
     *
     * ## Window Selection
     * - `windowIndex: nil` - Captures the frontmost/active window of the application
     * - `windowIndex: 0` - Captures the first window (topmost in window list)
     * - `windowIndex: 1` - Captures the second window, etc.
     *
     * ## Examples
     * ```swift
     * // Capture Safari's frontmost window
     * let result = try await captureService.captureWindow(
     *     appIdentifier: "Safari",
     *     windowIndex: nil
     * )
     *
     * // Capture specific Chrome window by index
     * let chromeWindow = try await captureService.captureWindow(
     *     appIdentifier: "com.google.Chrome",
     *     windowIndex: 1
     * )
     *
     * // Capture by process ID
     * let processWindow = try await captureService.captureWindow(
     *     appIdentifier: "PID:1234",
     *     windowIndex: 0
     * )
     * ```
     */
    public func captureWindow(
        appIdentifier: String,
        windowIndex: Int?,
        visualizerMode: CaptureVisualizerMode = .screenshotFlash,
        scale: CaptureScalePreference = .logical1x) async throws -> CaptureResult
    {
        let metadata: Metadata = [
            "appIdentifier": appIdentifier,
            "windowIndex": windowIndex ?? "frontmost",
        ]

        return try await self.performOperation(.window, metadata: metadata) { correlationId in
            self.logger.debug(
                "Finding application",
                metadata: ["identifier": appIdentifier],
                correlationId: correlationId)
            let app = try await self.findApplication(matching: appIdentifier)
            self.logger.debug(
                "Found application",
                metadata: [
                    "name": app.name,
                    "pid": app.processIdentifier,
                    "bundleId": app.bundleIdentifier ?? "unknown",
                ],
                correlationId: correlationId)

            return try await self.captureWindow(
                app: app,
                windowIndex: windowIndex,
                options: WindowCaptureOptions(visualizerMode: visualizerMode, scale: scale),
                context: CaptureInvocationContext(operation: .window, correlationId: correlationId))
        }
    }

    public func captureWindow(
        windowID: CGWindowID,
        visualizerMode: CaptureVisualizerMode = .screenshotFlash,
        scale: CaptureScalePreference = .logical1x) async throws -> CaptureResult
    {
        let metadata: Metadata = [
            "windowID": Int(windowID),
        ]

        return try await self.performOperation(.window, metadata: metadata) { correlationId in
            try await self.captureWindow(
                windowID: windowID,
                options: WindowCaptureOptions(visualizerMode: visualizerMode, scale: scale),
                context: CaptureInvocationContext(operation: .window, correlationId: correlationId))
        }
    }

    private func captureWindow(
        app: ServiceApplicationInfo,
        windowIndex: Int?,
        options: WindowCaptureOptions,
        context: CaptureInvocationContext) async throws -> CaptureResult
    {
        try await self.fallbackRunner.runCapture(
            operationName: context.operation.metricName,
            logger: self.logger,
            correlationId: context.correlationId,
            apis: self.fallbackRunner.apis(for: Self.captureEnginePreference))
        { api in
            switch api {
            case .modern:
                self.logger.debug(
                    "Using ScreenCaptureKit window capture path",
                    correlationId: context.correlationId)
                return try await self.modernOperator.captureWindow(
                    app: app,
                    windowIndex: windowIndex,
                    correlationId: context.correlationId,
                    visualizerMode: options.visualizerMode,
                    scale: options.scale)
            case .legacy:
                self.logger.debug("Using legacy CGWindowList API", correlationId: context.correlationId)
                return try await self.legacyOperator.captureWindow(
                    app: app,
                    windowIndex: windowIndex,
                    correlationId: context.correlationId,
                    visualizerMode: options.visualizerMode,
                    scale: options.scale)
            }
        }
    }

    private func captureWindow(
        windowID: CGWindowID,
        options: WindowCaptureOptions,
        context: CaptureInvocationContext) async throws -> CaptureResult
    {
        try await self.fallbackRunner.runCapture(
            operationName: context.operation.metricName,
            logger: self.logger,
            correlationId: context.correlationId,
            apis: self.fallbackRunner.apis(for: Self.captureEnginePreference))
        { api in
            switch api {
            case .modern:
                self.logger.debug(
                    "Using ScreenCaptureKit window-id capture path",
                    correlationId: context.correlationId)
                return try await self.modernOperator.captureWindow(
                    windowID: windowID,
                    correlationId: context.correlationId,
                    visualizerMode: options.visualizerMode,
                    scale: options.scale)
            case .legacy:
                self.logger.debug(
                    "Using legacy CGWindowList API window-id capture path",
                    correlationId: context.correlationId)
                return try await self.legacyOperator.captureWindow(
                    windowID: windowID,
                    correlationId: context.correlationId,
                    visualizerMode: options.visualizerMode,
                    scale: options.scale)
            }
        }
    }

    public func captureFrontmost(
        visualizerMode: CaptureVisualizerMode = .screenshotFlash,
        scale: CaptureScalePreference = .logical1x) async throws -> CaptureResult
    {
        try await self.performOperation(.frontmost) { correlationId in
            let serviceApp = try await self.frontmostApplication()

            self.logger.debug(
                "Found frontmost application",
                metadata: [
                    "name": serviceApp.name,
                    "bundleId": serviceApp.bundleIdentifier ?? "none",
                    "pid": serviceApp.processIdentifier,
                ],
                correlationId: correlationId)

            return try await self.captureWindow(
                app: serviceApp,
                windowIndex: nil,
                options: WindowCaptureOptions(visualizerMode: visualizerMode, scale: scale),
                context: CaptureInvocationContext(operation: .frontmost, correlationId: correlationId))
        }
    }

    public func captureArea(
        _ rect: CGRect,
        visualizerMode _: CaptureVisualizerMode = .screenshotFlash,
        scale: CaptureScalePreference = .logical1x) async throws -> CaptureResult
    {
        let metadata: Metadata = [
            "rect": "\(rect.origin.x),\(rect.origin.y) \(rect.width)x\(rect.height)",
        ]
        let apis = self.fallbackRunner.apis(for: Self.captureEnginePreference)

        return try await self.performOperation(.area, metadata: metadata) { correlationId in
            try await self.fallbackRunner.runCapture(
                operationName: CaptureOperation.area.metricName,
                logger: self.logger,
                correlationId: correlationId,
                apis: apis)
            { api in
                switch api {
                case .modern:
                    try await self.modernOperator.captureArea(
                        rect,
                        correlationId: correlationId,
                        scale: scale)
                case .legacy:
                    try await self.legacyOperator.captureArea(
                        rect,
                        correlationId: correlationId,
                        scale: scale)
                }
            }
        }
    }

    public func hasScreenRecordingPermission() async -> Bool {
        await self.permissionGate.hasPermission(logger: self.logger)
    }

    // MARK: - Private Helpers

    private func findApplication(matching identifier: String) async throws -> ServiceApplicationInfo {
        try await self.applicationResolver.findApplication(identifier: identifier)
    }

    private func frontmostApplication() async throws -> ServiceApplicationInfo {
        do {
            return try await self.applicationResolver.frontmostApplication()
        } catch {
            self.logger.error("No frontmost application found")
            throw error
        }
    }
}
