import AppKit
import CoreGraphics
import Foundation
import PeekabooFoundation
import PeekabooVisualizer
@preconcurrency import ScreenCaptureKit

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
 * Use `PEEKABOO_USE_MODERN_CAPTURE=true` to prefer ScreenCaptureKit with automatic legacy fallback.
 *
 * - Important: Requires Screen Recording permission
 * - Note: Performance 20-150ms depending on operation and display size
 * - Since: PeekabooCore 1.0.0
 */
@MainActor
// swiftlint:disable type_body_length
public final class ScreenCaptureService: ScreenCaptureServiceProtocol {
    struct Dependencies: Sendable {
        let visualizerClient: any VisualizationClientProtocol
        let permissionEvaluator: any ScreenRecordingPermissionEvaluating
        let fallbackRunner: ScreenCaptureFallbackRunner
        let applicationResolver: any ApplicationResolving
        let makeModernOperator: @MainActor @Sendable (CategoryLogger, any VisualizationClientProtocol)
            -> any ModernScreenCaptureOperating
        let makeLegacyOperator: @MainActor @Sendable (CategoryLogger)
            -> any LegacyScreenCaptureOperating

        init(
            visualizerClient: any VisualizationClientProtocol,
            permissionEvaluator: any ScreenRecordingPermissionEvaluating,
            fallbackRunner: ScreenCaptureFallbackRunner,
            applicationResolver: any ApplicationResolving,
            makeModernOperator: @escaping @MainActor @Sendable (CategoryLogger, any VisualizationClientProtocol)
                -> any ModernScreenCaptureOperating,
            makeLegacyOperator: @escaping @MainActor @Sendable (CategoryLogger)
                -> any LegacyScreenCaptureOperating)
        {
            self.visualizerClient = visualizerClient
            self.permissionEvaluator = permissionEvaluator
            self.fallbackRunner = fallbackRunner
            self.applicationResolver = applicationResolver
            self.makeModernOperator = makeModernOperator
            self.makeLegacyOperator = makeLegacyOperator
        }

        @MainActor
        static func live(
            environment: [String: String] = ProcessInfo.processInfo.environment,
            applicationResolver: (any ApplicationResolving)? = nil) -> Dependencies
        {
            let resolver = applicationResolver ?? PeekabooApplicationResolver(applicationService: ApplicationService())
            return Dependencies(
                visualizerClient: VisualizationClient.shared,
                permissionEvaluator: ScreenRecordingPermissionChecker(),
                fallbackRunner: ScreenCaptureFallbackRunner(apis: ScreenCaptureAPIResolver
                    .resolve(environment: environment)),
                applicationResolver: resolver,
                makeModernOperator: { logger, visualizer in
                    ScreenCaptureKitOperator(logger: logger, visualizerClient: visualizer)
                },
                makeLegacyOperator: { logger in
                    LegacyScreenCaptureOperator(logger: logger)
                })
        }
    }

    private let logger: CategoryLogger
    private let visualizerClient: any VisualizationClientProtocol
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

    public convenience init(loggingService: any LoggingServiceProtocol) {
        self.init(loggingService: loggingService, dependencies: .live())
    }

    init(
        loggingService: any LoggingServiceProtocol,
        dependencies: Dependencies)
    {
        self.logger = loggingService.logger(category: LoggingService.Category.screenCapture)
        self.visualizerClient = dependencies.visualizerClient
        self.permissionEvaluator = dependencies.permissionEvaluator
        self.fallbackRunner = dependencies.fallbackRunner
        self.applicationResolver = dependencies.applicationResolver
        self.modernOperator = dependencies.makeModernOperator(self.logger, self.visualizerClient)
        self.legacyOperator = dependencies.makeLegacyOperator(self.logger)

        // Only connect to visualizer if we're not running inside the Mac app
        // The Mac app provides the visualizer service, not consumes it
        let isMacApp = Bundle.main.bundleIdentifier?.hasPrefix("boo.peekaboo.mac") == true
        if !isMacApp {
            self.logger.debug("Connecting to visualizer service (running as CLI/external tool)")
            self.visualizerClient.connect()
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

    public func captureScreen(displayIndex: Int?) async throws -> CaptureResult {
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
                        correlationId: correlationId)
                case .legacy:
                    try await self.legacyOperator.captureScreen(
                        displayIndex: displayIndex,
                        correlationId: correlationId)
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
    public func captureWindow(appIdentifier: String, windowIndex: Int?) async throws -> CaptureResult {
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
                operation: .window,
                correlationId: correlationId)
        }
    }

    private func captureWindow(
        app: ServiceApplicationInfo,
        windowIndex: Int?,
        operation: CaptureOperation,
        correlationId: String) async throws -> CaptureResult
    {
        try await self.fallbackRunner.run(
            operationName: operation.metricName,
            logger: self.logger,
            correlationId: correlationId)
        { api in
            switch api {
            case .modern:
                self.logger.debug(
                    "Bypassing modern ScreenCaptureKit path; using legacy fallback",
                    correlationId: correlationId)
                return try await self.legacyOperator.captureWindow(
                    app: app,
                    windowIndex: windowIndex,
                    correlationId: correlationId)
            case .legacy:
                self.logger.debug("Using legacy CGWindowList API", correlationId: correlationId)
                return try await self.legacyOperator.captureWindow(
                    app: app,
                    windowIndex: windowIndex,
                    correlationId: correlationId)
            }
        }
    }

    public func captureFrontmost() async throws -> CaptureResult {
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
                operation: .frontmost,
                correlationId: correlationId)
        }
    }

    public func captureArea(_ rect: CGRect) async throws -> CaptureResult {
        let metadata: Metadata = [
            "rect": "\(rect.origin.x),\(rect.origin.y) \(rect.width)x\(rect.height)",
        ]

        return try await self.performOperation(.area, metadata: metadata) { correlationId in
            try await self.modernOperator.captureArea(rect, correlationId: correlationId)
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
        // Create a stream delegate to handle errors
        let streamDelegate = StreamDelegate()

        // Create a stream for single frame capture
        let stream = SCStream(filter: filter, configuration: configuration, delegate: streamDelegate)

        // Add stream output
        let output = CaptureOutput()
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: nil)

        // Start capture
        try await stream.startCapture()

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
        private let visualizerClient: any VisualizationClientProtocol

        init(logger: CategoryLogger, visualizerClient: any VisualizationClientProtocol) {
            self.logger = logger
            self.visualizerClient = visualizerClient
        }

        func captureScreen(displayIndex: Int?, correlationId: String) async throws -> CaptureResult {
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
                try await self.createScreenshot(of: targetDisplay)
            }

            let imageData = try image.pngData()

            self.logger.debug(
                "Screenshot created",
                metadata: [
                    "imageSize": "\(image.width)x\(image.height)",
                    "dataSize": imageData.count,
                ],
                correlationId: correlationId)

            _ = await self.visualizerClient.showScreenshotFlash(in: targetDisplay.frame)

            let metadata = CaptureMetadata(
                size: CGSize(width: image.width, height: image.height),
                mode: .screen,
                displayInfo: DisplayInfo(
                    index: displayIndex ?? 0,
                    name: targetDisplay.displayID.description,
                    bounds: targetDisplay.frame,
                    scaleFactor: 2.0))

            return CaptureResult(imageData: imageData, metadata: metadata)
        }

        func captureWindow(
            app: ServiceApplicationInfo,
            windowIndex: Int?,
            correlationId: String) async throws -> CaptureResult
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

            let image = try await RetryHandler.withRetry(policy: .standard) {
                try await self.createScreenshot(of: targetWindow)
            }

            let imageData = try image.pngData()

            self.logger.debug(
                "Screenshot created",
                metadata: [
                    "imageSize": "\(image.width)x\(image.height)",
                    "dataSize": imageData.count,
                ],
                correlationId: correlationId)

            _ = await self.visualizerClient.showScreenshotFlash(in: targetWindow.frame)

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
                    isOnScreen: targetWindow.isOnScreen))

            return CaptureResult(imageData: imageData, metadata: metadata)
        }

        private nonisolated static func firstRenderableWindowIndex(in windows: [SCWindow]) -> Int? {
            for (index, window) in windows.enumerated() {
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

        func captureArea(_ rect: CGRect, correlationId: String) async throws -> CaptureResult {
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
            config.sourceRect = rect
            config.width = Int(rect.width)
            config.height = Int(rect.height)
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
                    scaleFactor: 2.0))

            return CaptureResult(imageData: imageData, metadata: metadata)
        }

        private func createScreenshot(of display: SCDisplay) async throws -> CGImage {
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = Int(display.width)
            config.height = Int(display.height)
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

            return try await self.captureWithStream(filter: filter, configuration: config)
        }

        private func captureWithStream(
            filter: SCContentFilter,
            configuration: SCStreamConfiguration) async throws -> CGImage
        {
            let streamDelegate = StreamDelegate()
            let stream = SCStream(filter: filter, configuration: configuration, delegate: streamDelegate)
            let output = CaptureOutput()
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: nil)
            do {
                try await stream.startCapture()
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

        private nonisolated static func windowIndexError(requestedIndex: Int, totalWindows: Int) -> String {
            let lastIndex = max(totalWindows - 1, 0)
            return "windowIndex: Index \(requestedIndex) is out of range. Valid windows: 0-\(lastIndex)"
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
            correlationId: String) async throws -> CaptureResult
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
            do {
                image = try await self.captureWindowWithCGWindowList(windowID: windowID)
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

            let imageData: Data
            do {
                imageData = try image.pngData()
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

            let metadata = CaptureMetadata(
                size: CGSize(width: image.width, height: image.height),
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
                    }
                ))

            return CaptureResult(
                imageData: imageData,
                metadata: metadata)
        }

        func captureScreen(displayIndex: Int?, correlationId: String) async throws -> CaptureResult {
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

            let imageData: Data
            do {
                imageData = try image.pngData()
            } catch {
                throw OperationError.captureFailed(reason: "Failed to convert image to PNG format")
            }

            self.logger.debug(
                "Legacy screenshot created",
                metadata: [
                    "imageSize": "\(image.width)x\(image.height)",
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
                    scaleFactor: scaleFactor))

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

        @MainActor
        private func captureWindowWithCGWindowList(windowID: CGWindowID) throws -> CGImage {
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

        private nonisolated static func windowIndexError(requestedIndex: Int, totalWindows: Int) -> String {
            let lastIndex = max(totalWindows - 1, 0)
            return "windowIndex: Index \(requestedIndex) is out of range. Valid windows: 0-\(lastIndex)"
        }

        private nonisolated static func firstRenderableWindowIndex(
            in windows: [[String: Any]]) -> Int?
        {
            for (index, window) in windows.enumerated() {
                guard let info = self.makeFilteringInfo(from: window, index: index) else { continue }
                guard WindowFiltering.isRenderable(info) else { continue }
                return index
            }
            return nil
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

// MARK: - Stream Delegate

private final class StreamDelegate: NSObject, SCStreamDelegate, @unchecked Sendable {
    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        // Log the error but don't need to do anything else since CaptureOutput handles errors
        print("SCStream stopped with error: \(error)")
    }
}

// MARK: - Capture Output Handler

@MainActor
private final class CaptureOutput: NSObject, @unchecked Sendable {
    private var continuation: CheckedContinuation<CGImage, any Error>?
    private var timeoutTask: Task<Void, Never>?
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
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            // Add a timeout to ensure the continuation is always resumed
            // Reduced from 10 seconds to 3 seconds for faster failure detection
            self.timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                await MainActor.run {
                    guard let self else { return }
                    if let cont = self.continuation {
                        cont.resume(throwing: OperationError.timeout(
                            operation: "CaptureOutput.waitForImage",
                            duration: 3.0))
                        self.continuation = nil
                    }
                }
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
                if let cont = self.continuation {
                    cont.resume(throwing: OperationError.captureFailed(reason: "No image buffer in sample"))
                    self.continuation = nil
                }
            }
            return
        }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let cont = self.continuation {
                    cont.resume(
                        throwing: OperationError.captureFailed(
                            reason: "Failed to create CGImage from buffer"))
                    self.continuation = nil
                }
            }
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            // Cancel timeout task since we received a frame
            self.timeoutTask?.cancel()
            self.timeoutTask = nil

            if let cont = self.continuation {
                cont.resume(returning: cgImage)
                self.continuation = nil
            }
        }
    }
}


extension CaptureOutput: SCStreamOutput {}

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
