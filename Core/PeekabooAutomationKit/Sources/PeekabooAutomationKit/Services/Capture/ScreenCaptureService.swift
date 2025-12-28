import Algorithms
import AppKit
import CoreGraphics
import Foundation
import PeekabooFoundation
@preconcurrency import ScreenCaptureKit

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
// swiftlint:disable type_body_length
public final class ScreenCaptureService: ScreenCaptureServiceProtocol {
    /// Convert a global desktop-space rectangle to a display-local `sourceRect`.
    ///
    /// ScreenCaptureKit expects `SCStreamConfiguration.sourceRect` in **display-local logical coordinates**.
    ///
    /// `SCWindow.frame` and `SCDisplay.frame` returned from `SCShareableContent` are in **global desktop
    /// coordinates** (same space as `NSScreen.frame`, including non-zero / negative origins for secondary
    /// displays).
    ///
    /// When using a display-bound filter (`SCContentFilter(display:...)`), passing a global rect directly can
    /// crop the wrong region or fail with an “invalid parameter” error on non-primary displays.
    @_spi(Testing) public static func displayLocalSourceRect(globalRect: CGRect, displayFrame: CGRect) -> CGRect {
        globalRect.offsetBy(dx: -displayFrame.origin.x, dy: -displayFrame.origin.y)
    }

    @_spi(Testing) public struct Dependencies {
        let feedbackClient: any AutomationFeedbackClient
        let permissionEvaluator: any ScreenRecordingPermissionEvaluating
        let fallbackRunner: ScreenCaptureFallbackRunner
        let applicationResolver: any ApplicationResolving
        let makeModernOperator: @MainActor @Sendable (CategoryLogger, any AutomationFeedbackClient)
            -> any ModernScreenCaptureOperating
        let makeLegacyOperator: @MainActor @Sendable (CategoryLogger)
            -> any LegacyScreenCaptureOperating
        public init(
            feedbackClient: any AutomationFeedbackClient,
            permissionEvaluator: any ScreenRecordingPermissionEvaluating,
            fallbackRunner: ScreenCaptureFallbackRunner,
            applicationResolver: any ApplicationResolving,
            makeModernOperator: @escaping @MainActor @Sendable (CategoryLogger, any AutomationFeedbackClient)
                -> any ModernScreenCaptureOperating,
            makeLegacyOperator: @escaping @MainActor @Sendable (CategoryLogger)
                -> any LegacyScreenCaptureOperating)
        {
            self.feedbackClient = feedbackClient
            self.permissionEvaluator = permissionEvaluator
            self.fallbackRunner = fallbackRunner
            self.applicationResolver = applicationResolver
            self.makeModernOperator = makeModernOperator
            self.makeLegacyOperator = makeLegacyOperator
        }

        @MainActor
        static func live(
            environment: [String: String] = ProcessInfo.processInfo.environment,
            applicationResolver: (any ApplicationResolving)? = nil,
            metricsObserver: (any ScreenCaptureMetricsObserving)? = nil) -> Dependencies
        {
            let resolver = applicationResolver ?? PeekabooApplicationResolver(applicationService: ApplicationService())
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
            return Dependencies(
                feedbackClient: NoopAutomationFeedbackClient(),
                permissionEvaluator: ScreenRecordingPermissionChecker(),
                fallbackRunner: ScreenCaptureFallbackRunner(
                    apis: ScreenCaptureAPIResolver.resolve(environment: environment),
                    observer: captureObserver),
                applicationResolver: resolver,
                makeModernOperator: { logger, visualizer in
                    ScreenCaptureKitOperator(logger: logger, feedbackClient: visualizer)
                },
                makeLegacyOperator: { logger in
                    LegacyScreenCaptureOperator(logger: logger)
                })
        }
    }

    private let logger: CategoryLogger
    private let feedbackClient: any AutomationFeedbackClient
    private let permissionEvaluator: any ScreenRecordingPermissionEvaluating
    private let fallbackRunner: ScreenCaptureFallbackRunner
    private let applicationResolver: any ApplicationResolving
    private let modernOperator: any ModernScreenCaptureOperating
    private let legacyOperator: any LegacyScreenCaptureOperating

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
        self.permissionEvaluator = dependencies.permissionEvaluator
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
            self.logger.debug("Checking screen recording permission", correlationId: correlationId)
            guard await self.hasScreenRecordingPermission() else {
                self.logger.error("Screen recording permission denied", correlationId: correlationId)
                throw PermissionError.screenRecording()
            }
        }

        return try await body(correlationId)
    }

    public func captureScreen(
        displayIndex: Int?,
        visualizerMode: CaptureVisualizerMode = .screenshotFlash,
        scale: CaptureScalePreference = .logical1x) async throws -> CaptureResult
    {
        let metadata: Metadata = ["displayIndex": displayIndex ?? "main"]
        return try await self.performOperation(.screen, metadata: metadata) { correlationId in
            try await self.fallbackRunner.run(
                operationName: CaptureOperation.screen.metricName,
                logger: self.logger,
                correlationId: correlationId)
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
        try await self.fallbackRunner.run(
            operationName: context.operation.metricName,
            logger: self.logger,
            correlationId: context.correlationId)
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
        try await self.fallbackRunner.run(
            operationName: context.operation.metricName,
            logger: self.logger,
            correlationId: context.correlationId)
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
            guard let frontmost = NSWorkspace.shared.frontmostApplication else {
                self.logger.error("No frontmost application found", correlationId: correlationId)
                throw NotFoundError.application("frontmost")
            }

            self.logger.debug(
                "Found frontmost application",
                metadata: [
                    "name": frontmost.localizedName ?? "unknown",
                    "bundleId": frontmost.bundleIdentifier ?? "none",
                    "pid": frontmost.processIdentifier,
                ],
                correlationId: correlationId)

            let serviceApp = self.serviceApplicationInfo(from: frontmost)
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

        return try await self.performOperation(.area, metadata: metadata) { correlationId in
            try await self.modernOperator.captureArea(rect, correlationId: correlationId, scale: scale)
        }
    }

    public func hasScreenRecordingPermission() async -> Bool {
        await self.permissionEvaluator.hasPermission(logger: self.logger)
    }

    // Helper function for timeout handling
    @MainActor

    // MARK: - Private Helpers

    private func createScreenshot(of display: SCDisplay) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        // Explicitly set the source rect to capture the full display
        config.sourceRect = CGRect(x: 0, y: 0, width: CGFloat(display.width), height: CGFloat(display.height))
        config.captureResolution = .best
        config.showsCursor = false

        return try await self.captureWithStream(filter: filter, configuration: config)
    }

    private func createScreenshot(of window: SCWindow) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.captureResolution = .best
        config.showsCursor = false

        // Configure for best quality
        config.showsCursor = false

        return try await self.captureWithStream(filter: filter, configuration: config)
    }

    private func captureWithStream(
        filter: SCContentFilter,
        configuration: SCStreamConfiguration) async throws -> CGImage
    {
        // Create a stream for single frame capture
        let output = CaptureOutput()
        let stream = SCStream(filter: filter, configuration: configuration, delegate: output)

        // Add stream output
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: nil)

        // Start capture with a bounded timeout so ScreenCaptureKit stalls can fall back.
        do {
            try await withTimeout(seconds: 3.0) {
                try await stream.startCapture()
            }
        } catch {
            try? await stream.stopCapture()
            throw OperationError.captureFailed(reason: error.localizedDescription)
        }

        // Wait for frame with error handling
        let image: CGImage
        do {
            image = try await output.waitForImage()
        } catch {
            // If we failed to get an image, stop the stream before re-throwing
            try? await stream.stopCapture()
            throw error
        }

        // Stop capture
        try await stream.stopCapture()

        return image
    }

    private func findApplication(matching identifier: String) async throws -> ServiceApplicationInfo {
        try await self.applicationResolver.findApplication(identifier: identifier)
    }

    private func serviceApplicationInfo(from application: NSRunningApplication) -> ServiceApplicationInfo {
        ServiceApplicationInfo(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier,
            name: application.localizedName ?? application.bundleIdentifier ?? "Unknown",
            bundlePath: application.bundleURL?.path,
            isActive: application.isActive,
            isHidden: application.isHidden,
            windowCount: 0)
    }

    @MainActor
    private final class ScreenCaptureKitOperator: ModernScreenCaptureOperating {
        private let logger: CategoryLogger
        private let feedbackClient: any AutomationFeedbackClient

        init(logger: CategoryLogger, feedbackClient: any AutomationFeedbackClient) {
            self.logger = logger
            self.feedbackClient = feedbackClient
        }

        func captureScreen(
            displayIndex: Int?,
            correlationId: String,
            visualizerMode: CaptureVisualizerMode,
            scale: CaptureScalePreference) async throws -> CaptureResult
        {
            self.logger.debug("Fetching shareable content", correlationId: correlationId)
            let content = try await withTimeout(seconds: 5.0) {
                try await SCShareableContent.current
            }
            let displays = content.displays

            self.logger.debug(
                "Found displays",
                metadata: ["count": displays.count],
                correlationId: correlationId)
            guard !displays.isEmpty else {
                self.logger.error("No displays found", correlationId: correlationId)
                throw OperationError.captureFailed(reason: "No displays available for capture")
            }

            let targetDisplay: SCDisplay
            if let index = displayIndex {
                guard index >= 0, index < displays.count else {
                    throw PeekabooError.invalidInput(
                        "displayIndex: Index \(index) is out of range. Available displays: 0-\(displays.count - 1)")
                }
                targetDisplay = displays[index]
            } else {
                targetDisplay = displays.first!
            }

            self.logger.debug(
                "Creating screenshot of display",
                metadata: ["displayID": targetDisplay.displayID],
                correlationId: correlationId)

            let image = try await RetryHandler.withRetry(policy: .standard) {
                try await self.createScreenshot(of: targetDisplay, scale: scale)
            }

            let imageData = try image.pngData()

            self.logger.debug(
                "Screenshot created",
                metadata: [
                    "imageSize": "\(image.width)x\(image.height)",
                    "dataSize": imageData.count,
                ],
                correlationId: correlationId)

            await self.emitVisualizer(mode: visualizerMode, rect: targetDisplay.frame)

            let metadata = CaptureMetadata(
                size: CGSize(width: image.width, height: image.height),
                mode: .screen,
                displayInfo: DisplayInfo(
                    index: displayIndex ?? 0,
                    name: targetDisplay.displayID.description,
                    bounds: targetDisplay.frame,
                    scaleFactor: self.outputScale(for: targetDisplay, preference: scale)))

            return CaptureResult(imageData: imageData, metadata: metadata)
        }

        func captureWindow(
            app: ServiceApplicationInfo,
            windowIndex: Int?,
            correlationId: String,
            visualizerMode: CaptureVisualizerMode,
            scale: CaptureScalePreference) async throws -> CaptureResult
        {
            let content = try await withTimeout(seconds: 5.0) {
                try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            }

            let appWindows = content.windows.filter { window in
                window.owningApplication?.processID == app.processIdentifier
            }

            self.logger.debug(
                "Found windows for application",
                metadata: ["count": appWindows.count],
                correlationId: correlationId)
            guard !appWindows.isEmpty else {
                self.logger.error(
                    "No windows found for application",
                    metadata: ["appName": app.name],
                    correlationId: correlationId)
                throw NotFoundError.window(app: app.name)
            }

            let resolvedIndex: Int
            if let requestedIndex = windowIndex {
                guard requestedIndex >= 0, requestedIndex < appWindows.count else {
                    let message = Self.windowIndexError(
                        requestedIndex: requestedIndex,
                        totalWindows: appWindows.count)
                    throw PeekabooError.invalidInput(message)
                }
                resolvedIndex = requestedIndex
            } else if let candidateIndex = Self.firstRenderableWindowIndex(in: appWindows) {
                if candidateIndex != 0 {
                    self.logger.debug(
                        "Auto-selected visible SCWindow",
                        metadata: ["index": candidateIndex],
                        correlationId: correlationId)
                }
                resolvedIndex = candidateIndex
            } else {
                self.logger.warning(
                    "Falling back to first SCWindow; no renderable windows detected",
                    metadata: ["app": app.name],
                    correlationId: correlationId)
                resolvedIndex = 0
            }

            let targetWindow = appWindows[resolvedIndex]

            self.logger.debug(
                "Capturing window",
                metadata: [
                    "title": targetWindow.title ?? "untitled",
                    "windowID": targetWindow.windowID,
                ],
                correlationId: correlationId)

            guard let targetDisplay = self.display(for: targetWindow, displays: content.displays) else {
                throw OperationError.captureFailed(
                    reason: "Window is not on any available display")
            }
            let targetScale = self.nativeScale(for: targetDisplay)
            let image = try await RetryHandler.withRetry(policy: .standard) {
                try await self.createScreenshot(
                    of: targetWindow,
                    scale: scale,
                    targetScale: targetScale,
                    display: targetDisplay)
            }

            let imageData = try image.pngData()

            self.logger.debug(
                "Screenshot created",
                metadata: [
                    "imageSize": "\(image.width)x\(image.height)",
                    "dataSize": imageData.count,
                ],
                correlationId: correlationId)

            await self.emitVisualizer(mode: visualizerMode, rect: targetWindow.frame)

            let metadata = CaptureMetadata(
                size: CGSize(width: image.width, height: image.height),
                mode: .window,
                applicationInfo: ServiceApplicationInfo(
                    processIdentifier: app.processIdentifier,
                    bundleIdentifier: app.bundleIdentifier,
                    name: app.name,
                    bundlePath: app.bundlePath),
                windowInfo: ServiceWindowInfo(
                    windowID: Int(targetWindow.windowID),
                    title: targetWindow.title ?? "",
                    bounds: targetWindow.frame,
                    isMinimized: false,
                    isMainWindow: targetWindow.isOnScreen,
                    windowLevel: 0,
                    alpha: 1.0,
                    index: resolvedIndex,
                    layer: 0,
                    isOnScreen: targetWindow.isOnScreen),
                displayInfo: DisplayInfo(
                    index: content.displays.firstIndex(where: { $0.displayID == targetDisplay.displayID }) ?? 0,
                    name: targetDisplay.displayID.description,
                    bounds: targetDisplay.frame,
                    scaleFactor: scale == .native ? self.nativeScale(for: targetDisplay) : 1.0))

            return CaptureResult(imageData: imageData, metadata: metadata)
        }

        func captureWindow(
            windowID: CGWindowID,
            correlationId: String,
            visualizerMode: CaptureVisualizerMode,
            scale: CaptureScalePreference) async throws -> CaptureResult
        {
            let content = try await withTimeout(seconds: 5.0) {
                try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            }

            guard let targetWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                throw PeekabooError.windowNotFound(criteria: "window_id \(windowID)")
            }

            let owningPid = targetWindow.owningApplication?.processID
            let appWindows: [SCWindow] = if let owningPid {
                content.windows.filter { $0.owningApplication?.processID == owningPid }
            } else {
                [targetWindow]
            }

            let resolvedIndex = appWindows.firstIndex(where: { $0.windowID == windowID }) ?? 0

            self.logger.debug(
                "Capturing window by id",
                metadata: [
                    "title": targetWindow.title ?? "untitled",
                    "windowID": targetWindow.windowID,
                ],
                correlationId: correlationId)

            guard let targetDisplay = self.display(for: targetWindow, displays: content.displays) else {
                throw OperationError.captureFailed(reason: "Window is not on any available display")
            }
            let targetScale = self.nativeScale(for: targetDisplay)

            let image = try await RetryHandler.withRetry(policy: .standard) {
                try await self.createScreenshot(
                    of: targetWindow,
                    scale: scale,
                    targetScale: targetScale,
                    display: targetDisplay)
            }

            let imageData = try image.pngData()

            await self.emitVisualizer(mode: visualizerMode, rect: targetWindow.frame)

            let applicationInfo: ServiceApplicationInfo? = if let owningPid,
                                                              let runningApplication =
                                                              NSRunningApplication(processIdentifier: owningPid)
            {
                ServiceApplicationInfo(
                    processIdentifier: runningApplication.processIdentifier,
                    bundleIdentifier: runningApplication.bundleIdentifier,
                    name: runningApplication.localizedName ?? runningApplication.bundleIdentifier ?? "Unknown",
                    bundlePath: runningApplication.bundleURL?.path,
                    isActive: runningApplication.isActive,
                    isHidden: runningApplication.isHidden,
                    windowCount: appWindows.count)
            } else {
                nil
            }

            let metadata = CaptureMetadata(
                size: CGSize(width: image.width, height: image.height),
                mode: .window,
                applicationInfo: applicationInfo,
                windowInfo: ServiceWindowInfo(
                    windowID: Int(targetWindow.windowID),
                    title: targetWindow.title ?? "",
                    bounds: targetWindow.frame,
                    isMinimized: false,
                    isMainWindow: targetWindow.isOnScreen,
                    windowLevel: 0,
                    alpha: 1.0,
                    index: resolvedIndex,
                    layer: 0,
                    isOnScreen: targetWindow.isOnScreen),
                displayInfo: DisplayInfo(
                    index: content.displays.firstIndex(where: { $0.displayID == targetDisplay.displayID }) ?? 0,
                    name: targetDisplay.displayID.description,
                    bounds: targetDisplay.frame,
                    scaleFactor: scale == .native ? self.nativeScale(for: targetDisplay) : 1.0))

            return CaptureResult(imageData: imageData, metadata: metadata)
        }

        private nonisolated static func firstRenderableWindowIndex(in windows: [SCWindow]) -> Int? {
            for (index, window) in windows.indexed() {
                guard let info = self.makeFilteringInfo(from: window, index: index) else { continue }
                guard WindowFiltering.isRenderable(info) else { continue }
                return index
            }
            return nil
        }

        private nonisolated static func makeFilteringInfo(from window: SCWindow, index: Int) -> ServiceWindowInfo? {
            ServiceWindowInfo(
                windowID: Int(window.windowID),
                title: window.title ?? "",
                bounds: window.frame,
                isMinimized: false,
                isMainWindow: window.isOnScreen,
                windowLevel: 0,
                alpha: 1.0,
                index: index,
                layer: 0,
                isOnScreen: window.isOnScreen)
        }

        func captureArea(
            _ rect: CGRect,
            correlationId: String,
            scale: CaptureScalePreference) async throws -> CaptureResult
        {
            self.logger.debug("Finding display containing rect", correlationId: correlationId)
            let content = try await SCShareableContent.current
            guard let display = content.displays.first(where: { $0.frame.contains(rect) }) else {
                self.logger.error(
                    "No display contains the specified area",
                    metadata: [
                        "rect": "\(rect.origin.x),\(rect.origin.y) \(rect.width)x\(rect.height)",
                    ],
                    correlationId: correlationId)
                throw PeekabooError.invalidInput(
                    "captureArea: The specified area is not within any display bounds")
            }

            self.logger.debug(
                "Found display for area",
                metadata: ["displayID": display.displayID],
                correlationId: correlationId)

            let filter = SCContentFilter(display: display, excludingWindows: [])

            let config = SCStreamConfiguration()
            let scaleFactor = self.outputScale(for: display, preference: scale)
            // `rect` is in global desktop coordinates (often derived from `NSScreen.frame`).
            // For display-bound capture, ScreenCaptureKit expects `sourceRect` in display-local coordinates.
            config.sourceRect = ScreenCaptureService.displayLocalSourceRect(
                globalRect: rect,
                displayFrame: display.frame)
            config.width = Int(rect.width * scaleFactor)
            config.height = Int(rect.height * scaleFactor)
            config.showsCursor = false

            let image = try await RetryHandler.withRetry(policy: .standard) {
                try await self.captureWithStream(filter: filter, configuration: config)
            }

            let imageData = try image.pngData()

            let metadata = CaptureMetadata(
                size: CGSize(width: image.width, height: image.height),
                mode: .area,
                displayInfo: DisplayInfo(
                    index: 0,
                    name: display.displayID.description,
                    bounds: display.frame,
                    scaleFactor: scaleFactor))

            return CaptureResult(imageData: imageData, metadata: metadata)
        }

        private func createScreenshot(of display: SCDisplay, scale: CaptureScalePreference) async throws -> CGImage {
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            let nativeScale = self.nativeScale(for: display)
            let targetScale = scale == .native ? nativeScale : 1.0
            let logicalSize = display.frame.size
            config.width = Int(logicalSize.width * targetScale)
            config.height = Int(logicalSize.height * targetScale)
            config.sourceRect = CGRect(origin: .zero, size: logicalSize)
            config.captureResolution = .best
            config.showsCursor = false

            return try await self.captureWithStream(filter: filter, configuration: config)
        }

        /// Capture a window screenshot using display-based capture.
        /// This method uses SCContentFilter(display:including:) which works reliably
        /// for all windows including GPU-rendered ones like iOS Simulator.
        /// The desktopIndependentWindow approach fails for such windows because they
        /// render through Metal/GPU compositing that bypasses the window backing store.
        private func createScreenshot(
            of window: SCWindow,
            scale: CaptureScalePreference,
            targetScale: CGFloat,
            display: SCDisplay) async throws -> CGImage
        {
            let scaleValue = scale == .native ? targetScale : 1.0
            let width = Int(window.frame.width * scaleValue)
            let height = Int(window.frame.height * scaleValue)

            let filter = SCContentFilter(display: display, including: [window])
            let config = SCStreamConfiguration()
            // `window.frame` is in global desktop coordinates. `sourceRect` must be display-local when the filter
            // is display-bound, otherwise captures can fail on secondary displays (non-zero/negative origins).
            config.sourceRect = ScreenCaptureService.displayLocalSourceRect(
                globalRect: window.frame,
                displayFrame: display.frame)
            config.width = width
            config.height = height
            config.captureResolution = .best
            config.showsCursor = false

            return try await self.captureWithStream(filter: filter, configuration: config)
        }

        private func captureWithStream(
            filter: SCContentFilter,
            configuration: SCStreamConfiguration) async throws -> CGImage
        {
            let output = CaptureOutput()
            let stream = SCStream(filter: filter, configuration: configuration, delegate: output)
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: nil)
            do {
                try await withTimeout(seconds: 3.0) {
                    try await stream.startCapture()
                }
            } catch {
                try? await stream.stopCapture()
                throw OperationError.captureFailed(reason: error.localizedDescription)
            }

            let image: CGImage
            do {
                image = try await output.waitForImage()
            } catch {
                try? await stream.stopCapture()
                throw error
            }

            try await stream.stopCapture()
            return image
        }

        private func emitVisualizer(mode: CaptureVisualizerMode, rect: CGRect) async {
            switch mode {
            case .screenshotFlash:
                _ = await self.feedbackClient.showScreenshotFlash(in: rect)
            case .watchCapture:
                _ = await self.feedbackClient.showWatchCapture(in: rect)
            }
        }

        private nonisolated static func windowIndexError(requestedIndex: Int, totalWindows: Int) -> String {
            let lastIndex = max(totalWindows - 1, 0)
            return "windowIndex: Index \(requestedIndex) is out of range. Valid windows: 0-\(lastIndex)"
        }

        private func outputScale(for display: SCDisplay, preference: CaptureScalePreference) -> CGFloat {
            let nativeScale = self.nativeScale(for: display)
            switch preference {
            case .native:
                return nativeScale
            case .logical1x:
                return 1.0
            }
        }

        private func nativeScale(for display: SCDisplay) -> CGFloat {
            let width = CGFloat(display.width)
            let frameWidth = display.frame.width
            guard frameWidth > 0 else { return 1.0 }
            let scale = width / frameWidth
            return scale > 0 ? scale : 1.0
        }

        private func scaleFactor(for window: SCWindow, displays: [SCDisplay]) -> CGFloat {
            self.display(for: window, displays: displays).map { self.nativeScale(for: $0) } ?? 1.0
        }

        private func display(for window: SCWindow, displays: [SCDisplay]) -> SCDisplay? {
            displays.first(where: { $0.frame.intersects(window.frame) })
        }
    }

    @MainActor
    private final class LegacyScreenCaptureOperator: LegacyScreenCaptureOperating, @unchecked Sendable {
        private let logger: CategoryLogger

        init(logger: CategoryLogger) {
            self.logger = logger
        }

        func captureWindow(
            app: ServiceApplicationInfo,
            windowIndex: Int?,
            correlationId: String,
            visualizerMode _: CaptureVisualizerMode,
            scale: CaptureScalePreference) async throws -> CaptureResult
        {
            let windowList = CGWindowListCopyWindowInfo(
                [.optionAll, .excludeDesktopElements],
                kCGNullWindowID) as? [[String: Any]] ?? []

            let appWindows = windowList.filter { windowInfo in
                guard let pid = windowInfo[kCGWindowOwnerPID as String] as? Int32 else { return false }
                return pid == app.processIdentifier
            }

            self.logger.debug(
                "Found windows for application (legacy)",
                metadata: ["count": appWindows.count],
                correlationId: correlationId)
            guard !appWindows.isEmpty else {
                self.logger.error(
                    "No windows found for application (legacy)",
                    metadata: ["appName": app.name],
                    correlationId: correlationId)
                throw NotFoundError.window(app: app.name)
            }

            let resolvedIndex: Int
            if let requestedIndex = windowIndex {
                guard requestedIndex >= 0, requestedIndex < appWindows.count else {
                    let message = Self.windowIndexError(
                        requestedIndex: requestedIndex,
                        totalWindows: appWindows.count)
                    throw PeekabooError.invalidInput(message)
                }
                resolvedIndex = requestedIndex
            } else if let candidateIndex = Self.firstRenderableWindowIndex(in: appWindows) {
                if candidateIndex != 0 {
                    self.logger.debug(
                        "Auto-selected visible CGWindow",
                        metadata: ["index": candidateIndex],
                        correlationId: correlationId)
                }
                resolvedIndex = candidateIndex
            } else {
                self.logger.warning(
                    "Falling back to first CGWindow; no renderable windows detected",
                    metadata: ["app": app.name],
                    correlationId: correlationId)
                resolvedIndex = 0
            }

            let targetWindow = appWindows[resolvedIndex]

            guard let windowID = targetWindow[kCGWindowNumber as String] as? CGWindowID else {
                throw OperationError.captureFailed(reason: "Failed to get window ID")
            }

            let windowTitle = targetWindow[kCGWindowName as String] as? String ?? "untitled"
            self.logger.debug(
                "Capturing window (legacy)",
                metadata: [
                    "title": windowTitle,
                    "windowID": windowID,
                ],
                correlationId: correlationId)

            let image: CGImage
            if self.shouldUseLegacyCGCapture() {
                do {
                    image = try self.captureWindowWithCGWindowList(windowID: windowID)
                    self.logger.debug(
                        "Captured window via CGWindowList",
                        metadata: ["windowID": String(windowID)],
                        correlationId: correlationId)
                } catch {
                    self.logger.warning(
                        "CGWindowList capture failed, falling back to SCScreenshotManager",
                        metadata: ["error": String(describing: error)],
                        correlationId: correlationId)
                    image = try await self.captureWindowWithScreenshotManager(
                        windowID: windowID,
                        correlationId: correlationId)
                }
            } else {
                image = try await self.captureWindowWithScreenshotManager(
                    windowID: windowID,
                    correlationId: correlationId)
            }

            let bounds = if let boundsDict = targetWindow[kCGWindowBounds as String] as? [String: Any],
                            let x = boundsDict["X"] as? CGFloat,
                            let y = boundsDict["Y"] as? CGFloat,
                            let width = boundsDict["Width"] as? CGFloat,
                            let height = boundsDict["Height"] as? CGFloat
            {
                CGRect(x: x, y: y, width: width, height: height)
            } else {
                CGRect(x: 0, y: 0, width: image.width, height: image.height)
            }

            let imageData: Data
            let scaledImage = self.maybeDownscale(image, scale: scale, fallbackScale: self.scaleFactor(for: bounds))
            do {
                imageData = try scaledImage.pngData()
            } catch {
                throw OperationError.captureFailed(reason: "Failed to convert image to PNG format")
            }

            self.logger.debug(
                "Screenshot created (legacy)",
                metadata: [
                    "imageSize": "\(image.width)x\(image.height)",
                    "dataSize": imageData.count,
                ],
                correlationId: correlationId)

            let metadata = CaptureMetadata(
                size: CGSize(width: scaledImage.width, height: scaledImage.height),
                mode: .window,
                applicationInfo: ServiceApplicationInfo(
                    processIdentifier: app.processIdentifier,
                    bundleIdentifier: app.bundleIdentifier,
                    name: app.name,
                    bundlePath: app.bundlePath),
                windowInfo: ServiceWindowInfo(
                    windowID: Int(windowID),
                    title: windowTitle,
                    bounds: bounds,
                    isMinimized: false,
                    isMainWindow: true,
                    windowLevel: 0,
                    alpha: 1.0,
                    index: resolvedIndex,
                    layer: targetWindow[kCGWindowLayer as String] as? Int ?? 0,
                    isOnScreen: targetWindow[kCGWindowIsOnscreen as String] as? Bool ?? true,
                    sharingState: (targetWindow[kCGWindowSharingState as String] as? Int).flatMap {
                        WindowSharingState(rawValue: $0)
                    }),
                displayInfo: DisplayInfo(
                    index: resolvedIndex,
                    name: nil,
                    bounds: bounds,
                    scaleFactor: self.outputScale(for: scale, fallback: self.scaleFactor(for: bounds))))

            return CaptureResult(
                imageData: imageData,
                metadata: metadata)
        }

        func captureWindow(
            windowID: CGWindowID,
            correlationId: String,
            visualizerMode _: CaptureVisualizerMode,
            scale: CaptureScalePreference) async throws -> CaptureResult
        {
            let windowList = CGWindowListCopyWindowInfo(
                [.optionAll, .excludeDesktopElements],
                kCGNullWindowID) as? [[String: Any]] ?? []

            guard let targetWindow = windowList.first(where: { windowInfo in
                (windowInfo[kCGWindowNumber as String] as? CGWindowID) == windowID
            }) else {
                throw PeekabooError.windowNotFound(criteria: "window_id \(windowID)")
            }

            guard let owningPid = targetWindow[kCGWindowOwnerPID as String] as? Int32 else {
                throw OperationError.captureFailed(reason: "Failed to resolve owning PID for window \(windowID)")
            }

            let appWindows = windowList.filter { windowInfo in
                guard let pid = windowInfo[kCGWindowOwnerPID as String] as? Int32 else { return false }
                return pid == owningPid
            }

            let resolvedIndex = appWindows.firstIndex(where: { windowInfo in
                (windowInfo[kCGWindowNumber as String] as? CGWindowID) == windowID
            }) ?? 0

            let windowTitle = targetWindow[kCGWindowName as String] as? String ?? "untitled"
            self.logger.debug(
                "Capturing window by id (legacy)",
                metadata: [
                    "title": windowTitle,
                    "windowID": windowID,
                ],
                correlationId: correlationId)

            let image: CGImage
            if self.shouldUseLegacyCGCapture() {
                do {
                    image = try self.captureWindowWithCGWindowList(windowID: windowID)
                } catch {
                    self.logger.warning(
                        "CGWindowList capture failed, falling back to SCScreenshotManager",
                        metadata: ["error": String(describing: error)],
                        correlationId: correlationId)
                    image = try await self.captureWindowWithScreenshotManager(
                        windowID: windowID,
                        correlationId: correlationId)
                }
            } else {
                image = try await self.captureWindowWithScreenshotManager(
                    windowID: windowID,
                    correlationId: correlationId)
            }

            let bounds = if let boundsDict = targetWindow[kCGWindowBounds as String] as? [String: Any],
                            let x = boundsDict["X"] as? CGFloat,
                            let y = boundsDict["Y"] as? CGFloat,
                            let width = boundsDict["Width"] as? CGFloat,
                            let height = boundsDict["Height"] as? CGFloat
            {
                CGRect(x: x, y: y, width: width, height: height)
            } else {
                CGRect(x: 0, y: 0, width: image.width, height: image.height)
            }

            let imageData: Data
            let scaledImage = self.maybeDownscale(image, scale: scale, fallbackScale: self.scaleFactor(for: bounds))
            do {
                imageData = try scaledImage.pngData()
            } catch {
                throw OperationError.captureFailed(reason: "Failed to convert image to PNG format")
            }

            let applicationInfo: ServiceApplicationInfo? = if let runningApplication = NSRunningApplication(
                processIdentifier: owningPid)
            {
                ServiceApplicationInfo(
                    processIdentifier: runningApplication.processIdentifier,
                    bundleIdentifier: runningApplication.bundleIdentifier,
                    name: runningApplication.localizedName ?? runningApplication.bundleIdentifier ?? "Unknown",
                    bundlePath: runningApplication.bundleURL?.path,
                    isActive: runningApplication.isActive,
                    isHidden: runningApplication.isHidden,
                    windowCount: appWindows.count)
            } else {
                nil
            }

            let metadata = CaptureMetadata(
                size: CGSize(width: scaledImage.width, height: scaledImage.height),
                mode: .window,
                applicationInfo: applicationInfo,
                windowInfo: ServiceWindowInfo(
                    windowID: Int(windowID),
                    title: windowTitle,
                    bounds: bounds,
                    isMinimized: false,
                    isMainWindow: true,
                    windowLevel: 0,
                    alpha: 1.0,
                    index: resolvedIndex,
                    layer: targetWindow[kCGWindowLayer as String] as? Int ?? 0,
                    isOnScreen: targetWindow[kCGWindowIsOnscreen as String] as? Bool ?? true,
                    sharingState: (targetWindow[kCGWindowSharingState as String] as? Int).flatMap {
                        WindowSharingState(rawValue: $0)
                    }),
                displayInfo: DisplayInfo(
                    index: 0,
                    name: nil,
                    bounds: bounds,
                    scaleFactor: self.outputScale(for: scale, fallback: self.scaleFactor(for: bounds))))

            return CaptureResult(
                imageData: imageData,
                metadata: metadata)
        }

        func captureScreen(
            displayIndex: Int?,
            correlationId: String,
            visualizerMode _: CaptureVisualizerMode,
            scale: CaptureScalePreference) async throws -> CaptureResult
        {
            self.logger.debug("Using legacy CGWindowList API for screen capture", correlationId: correlationId)

            let screens = NSScreen.screens
            guard !screens.isEmpty else {
                throw OperationError.captureFailed(reason: "No displays available")
            }

            let targetScreen: NSScreen
            if let index = displayIndex {
                guard index >= 0, index < screens.count else {
                    throw PeekabooError.invalidInput(
                        "displayIndex: Index \(index) is out of range. Available displays: 0-\(screens.count - 1)")
                }
                targetScreen = screens[index]
            } else {
                targetScreen = screens.first!
            }

            let screenBounds = targetScreen.frame
            let scaleFactor = targetScreen.backingScaleFactor
            let image = try await self.captureDisplayWithScreenshotManager(
                screen: targetScreen,
                displayIndex: displayIndex ?? 0,
                correlationId: correlationId)

            let scaledImage = self.maybeDownscale(image, scale: scale, fallbackScale: scaleFactor)

            let imageData: Data
            do {
                imageData = try scaledImage.pngData()
            } catch {
                throw OperationError.captureFailed(reason: "Failed to convert image to PNG format")
            }

            self.logger.debug(
                "Legacy screenshot created",
                metadata: [
                    "imageSize": "\(scaledImage.width)x\(scaledImage.height)",
                    "dataSize": imageData.count,
                ],
                correlationId: correlationId)

            let metadata = CaptureMetadata(
                size: CGSize(width: image.width, height: image.height),
                mode: .screen,
                displayInfo: DisplayInfo(
                    index: displayIndex ?? 0,
                    name: "Display \(displayIndex ?? 0)",
                    bounds: screenBounds,
                    scaleFactor: self.outputScale(for: scale, fallback: scaleFactor)))

            return CaptureResult(
                imageData: imageData,
                metadata: metadata)
        }

        private func captureDisplayWithScreenshotManager(
            screen: NSScreen,
            displayIndex: Int,
            correlationId: String) async throws -> CGImage
        {
            let content = try await SCShareableContent.current
            let displays = content.displays
            guard !displays.isEmpty else {
                throw OperationError.captureFailed(reason: "No ScreenCaptureKit displays available")
            }

            let display = try self.resolveDisplay(
                for: screen,
                displayIndex: displayIndex,
                availableDisplays: displays)

            let filter = SCContentFilter(display: display, excludingWindows: [])
            self.logger.debug(
                "Capturing display via SCScreenshotManager",
                metadata: [
                    "displayIndex": displayIndex,
                    "displayID": display.displayID,
                ],
                correlationId: correlationId)

            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: self.makeScreenshotConfiguration())
        }

        private func resolveDisplay(
            for screen: NSScreen,
            displayIndex: Int,
            availableDisplays: [SCDisplay]) throws -> SCDisplay
        {
            if let displayID = self.displayID(for: screen),
               let display = availableDisplays.first(where: { $0.displayID == displayID })
            {
                return display
            }

            guard displayIndex >= 0, displayIndex < availableDisplays.count else {
                throw PeekabooError
                    .invalidInput("displayIndex \(displayIndex) is out of range for ScreenCaptureKit displays")
            }

            return availableDisplays[displayIndex]
        }

        private func captureWindowWithScreenshotManager(
            windowID: CGWindowID,
            correlationId: String) async throws -> CGImage
        {
            let content = try await SCShareableContent.current
            guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                throw OperationError.captureFailed(
                    reason: "Failed to locate window \(windowID) in ScreenCaptureKit shareable content")
            }

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            self.logger.debug(
                "Capturing window via SCScreenshotManager",
                metadata: ["windowID": windowID],
                correlationId: correlationId)

            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: self.makeScreenshotConfiguration())
        }

        @available(macOS, obsoleted: 15.0)
        @MainActor
        private func captureWindowWithCGWindowList(windowID: CGWindowID) throws -> CGImage {
            if #unavailable(macOS 14.0) {
                let imageOptions: CGWindowImageOption = [
                    .boundsIgnoreFraming,
                    .bestResolution,
                ]
                guard
                    let image = CGWindowListCreateImage(
                        .infinite,
                        [.optionIncludingWindow],
                        windowID,
                        imageOptions)
                else {
                    throw OperationError.captureFailed(reason: "CGWindowListCreateImage returned nil")
                }
                return image
            }

            throw OperationError.captureFailed(
                reason: "CGWindowListCreateImage is deprecated; use ScreenCaptureKit instead")
        }

        private nonisolated static func windowIndexError(requestedIndex: Int, totalWindows: Int) -> String {
            let lastIndex = max(totalWindows - 1, 0)
            return "windowIndex: Index \(requestedIndex) is out of range. Valid windows: 0-\(lastIndex)"
        }

        private nonisolated static func firstRenderableWindowIndex(
            in windows: [[String: Any]]) -> Int?
        {
            windows.indexed().first { indexWindow in
                guard let info = self.makeFilteringInfo(from: indexWindow.element, index: indexWindow.index) else {
                    return false
                }
                return WindowFiltering.isRenderable(info)
            }?.index
        }

        private nonisolated static func makeFilteringInfo(
            from window: [String: Any],
            index: Int) -> ServiceWindowInfo?
        {
            guard
                let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                let width = boundsDict["Width"] as? CGFloat,
                let height = boundsDict["Height"] as? CGFloat,
                let x = boundsDict["X"] as? CGFloat,
                let y = boundsDict["Y"] as? CGFloat
            else {
                return nil
            }

            let bounds = CGRect(x: x, y: y, width: width, height: height)
            let windowID = window[kCGWindowNumber as String] as? Int ?? index
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            let alpha = window[kCGWindowAlpha as String] as? CGFloat ?? 1.0
            let isOnScreen = window[kCGWindowIsOnscreen as String] as? Bool ?? true
            let sharingRaw = window[kCGWindowSharingState as String] as? Int
            let sharingState = sharingRaw.flatMap { WindowSharingState(rawValue: $0) }

            return ServiceWindowInfo(
                windowID: windowID,
                title: (window[kCGWindowName as String] as? String) ?? "",
                bounds: bounds,
                isMinimized: false,
                isMainWindow: index == 0,
                windowLevel: layer,
                alpha: alpha,
                index: index,
                layer: layer,
                isOnScreen: isOnScreen,
                sharingState: sharingState)
        }

        private func shouldUseLegacyCGCapture() -> Bool {
            #if os(macOS)
            if #available(macOS 14.0, *) {
                let env = ProcessInfo.processInfo.environment["PEEKABOO_ALLOW_LEGACY_CAPTURE"]?.lowercased()
                return env.map { ["1", "true", "yes"].contains($0) } ?? false
            }
            return true
            #else
            return false
            #endif
        }

        private func maybeDownscale(
            _ image: CGImage,
            scale: CaptureScalePreference,
            fallbackScale: CGFloat) -> CGImage
        {
            guard scale == .logical1x, fallbackScale > 1 else {
                return image
            }

            let targetSize = CGSize(
                width: CGFloat(image.width) / fallbackScale,
                height: CGFloat(image.height) / fallbackScale)
            let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil,
                width: Int(targetSize.width.rounded()),
                height: Int(targetSize.height.rounded()),
                bitsPerComponent: image.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: image.bitmapInfo.rawValue)
            else {
                return image
            }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(origin: .zero, size: targetSize))
            return context.makeImage() ?? image
        }

        private func outputScale(for preference: CaptureScalePreference, fallback: CGFloat) -> CGFloat {
            switch preference {
            case .native: fallback
            case .logical1x: 1.0
            }
        }

        private func scaleFactor(for bounds: CGRect) -> CGFloat {
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(bounds) }) {
                return screen.backingScaleFactor
            }
            return NSScreen.main?.backingScaleFactor ?? 1.0
        }

        private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            guard let number = screen.deviceDescription[key] as? NSNumber else {
                return nil
            }
            return CGDirectDisplayID(number.uint32Value)
        }

        private func makeScreenshotConfiguration() -> SCStreamConfiguration {
            let configuration = SCStreamConfiguration()
            configuration.backgroundColor = .clear
            configuration.shouldBeOpaque = true
            configuration.showsCursor = false
            configuration.capturesAudio = false
            return configuration
        }
    }
}

// swiftlint:enable type_body_length

// MARK: - Capture Output Handler

@MainActor
final class CaptureOutput: NSObject, @unchecked Sendable {
    private var continuation: CheckedContinuation<CGImage, any Error>?
    private var timeoutTask: Task<Void, Never>?
    private var pendingCancellation = false

    @MainActor
    fileprivate func finish(_ result: Result<CGImage, any Error>) {
        // Single exit hatch for all completion paths: ensures timeout is canceled and continuation
        // is resumed exactly once, eliminating the racey scatter of resumes that existed before.
        // Cancel any pending timeout
        self.pendingCancellation = false
        self.timeoutTask?.cancel()
        self.timeoutTask = nil

        guard let cont = self.continuation else { return }
        self.continuation = nil
        switch result {
        case let .success(image):
            cont.resume(returning: image)
        case let .failure(error):
            cont.resume(throwing: error)
        }
    }

    @MainActor
    fileprivate func setContinuation(_ cont: CheckedContinuation<CGImage, any Error>) {
        // Tests inject their own continuation; production uses waitForImage().
        self.continuation = cont
        if self.pendingCancellation {
            self.pendingCancellation = false
            self.finish(.failure(CancellationError()))
        }
    }

    deinit {
        // Cancel timeout task first to prevent race condition
        timeoutTask?.cancel()

        // Ensure continuation is resumed if object is deallocated
        if let continuation = self.continuation {
            continuation.resume(throwing: OperationError.captureFailed(
                reason: "CaptureOutput deallocated before frame captured"))
            self.continuation = nil
        }
    }

    /// Suspend until the next captured frame arrives, throwing if the stream stalls.
    func waitForImage() async throws -> CGImage {
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.setContinuation(continuation)

                // Add a timeout to ensure the continuation is always resumed.
                self.timeoutTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                    await MainActor.run {
                        guard let self else { return }
                        self.finish(.failure(OperationError.timeout(
                            operation: "CaptureOutput.waitForImage",
                            duration: 3.0)))
                    }
                }
            }
        } onCancel: { [weak self] in
            Task.detached { @MainActor [weak self] in
                guard let self else { return }
                self.pendingCancellation = true
                self.finish(.failure(CancellationError()))
            }
        }
    }

    /// Feed new screen samples into the pending continuation, delivering captured frames.
    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType)
    {
        guard type == .screen else { return }

        guard let imageBuffer = sampleBuffer.imageBuffer else {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.finish(.failure(OperationError.captureFailed(reason: "No image buffer in sample")))
            }
            return
        }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.finish(.failure(OperationError.captureFailed(
                    reason: "Failed to create CGImage from buffer")))
            }
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.finish(.success(cgImage))
        }
    }
}

extension CaptureOutput: SCStreamOutput {}

extension CaptureOutput: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.finish(.failure(error))
        }
    }
}

#if DEBUG
extension CaptureOutput {
    /// Test-only hook to inject the continuation used by `waitForImage()`.
    @MainActor
    func injectContinuation(_ cont: CheckedContinuation<CGImage, any Error>) {
        self.setContinuation(cont)
    }

    /// Test-only hook to drive completion of the continuation.
    @MainActor
    func injectFinish(_ result: Result<CGImage, any Error>) {
        self.finish(result)
    }
}
#endif

// MARK: - Extensions

extension CGImage {
    func pngData() throws -> Data {
        let nsImage = NSImage(cgImage: self, size: NSSize(width: width, height: height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:])
        else {
            throw OperationError.captureFailed(reason: "Failed to convert CGImage to PNG data")
        }
        return pngData
    }
}
