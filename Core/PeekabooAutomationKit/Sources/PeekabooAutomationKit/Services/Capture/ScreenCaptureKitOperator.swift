import Algorithms
import AppKit
import CoreGraphics
import Foundation
import PeekabooFoundation
@preconcurrency import ScreenCaptureKit

@MainActor
final class ScreenCaptureKitOperator: ModernScreenCaptureOperating {
    private let logger: CategoryLogger
    private let feedbackClient: any AutomationFeedbackClient
    private let useFastStream: Bool
    private let frameSource: any CaptureFrameSource
    private let fallbackFrameSource: any CaptureFrameSource

    init(
        logger: CategoryLogger,
        feedbackClient: any AutomationFeedbackClient,
        frameSource: any CaptureFrameSource)
    {
        self.logger = logger
        self.feedbackClient = feedbackClient
        self.useFastStream = true
        self.frameSource = frameSource
        self.fallbackFrameSource = SingleShotFrameSource(logger: logger)
    }

    func captureScreen(
        displayIndex: Int?,
        correlationId: String,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        self.logger.debug("Fetching shareable content", correlationId: correlationId)
        let content = try await ScreenCaptureKitCaptureGate.currentShareableContent()
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

        let request = CaptureFrameRequest(
            mode: .screen,
            display: targetDisplay,
            displayIndex: displayIndex ?? 0,
            displayName: targetDisplay.displayID.description,
            displayBounds: targetDisplay.frame,
            sourceRect: CGRect(origin: .zero, size: targetDisplay.frame.size),
            scale: scale,
            correlationId: correlationId)
        let capture = try await self.captureDisplayFrame(request: request)
        let image = capture.image

        let imageData = try image.pngData()

        self.logger.debug(
            "Screenshot created",
            metadata: [
                "imageSize": "\(image.width)x\(image.height)",
                "dataSize": imageData.count,
            ],
            correlationId: correlationId)

        await self.emitVisualizer(mode: visualizerMode, rect: targetDisplay.frame)

        return CaptureResult(imageData: imageData, metadata: capture.metadata)
    }

    func captureWindow(
        app: ServiceApplicationInfo,
        windowIndex: Int?,
        correlationId: String,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        let content = try await ScreenCaptureKitCaptureGate.shareableContent(
            excludingDesktopWindows: false,
            onScreenWindowsOnly: false)

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
        let scalePlan = self.scalePlan(for: targetDisplay, preference: scale)
        let image = try await RetryHandler.withRetry(policy: .standard) {
            try await self.createScreenshot(
                of: targetWindow,
                scale: scale,
                targetScale: scalePlan.nativeScale,
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
                scaleFactor: scalePlan.outputScale),
            diagnostics: ScreenCaptureScaleResolver.diagnostics(
                plan: scalePlan,
                finalPixelSize: CGSize(width: image.width, height: image.height)))

        return CaptureResult(imageData: imageData, metadata: metadata)
    }

    func captureWindow(
        windowID: CGWindowID,
        correlationId: String,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        let content = try await ScreenCaptureKitCaptureGate.shareableContent(
            excludingDesktopWindows: false,
            onScreenWindowsOnly: false)

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
        let scalePlan = self.scalePlan(for: targetDisplay, preference: scale)

        let image = try await RetryHandler.withRetry(policy: .standard) {
            try await self.createScreenshot(
                of: targetWindow,
                scale: scale,
                targetScale: scalePlan.nativeScale,
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
                scaleFactor: scalePlan.outputScale),
            diagnostics: ScreenCaptureScaleResolver.diagnostics(
                plan: scalePlan,
                finalPixelSize: CGSize(width: image.width, height: image.height)))

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
        let content = try await ScreenCaptureKitCaptureGate.currentShareableContent()
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

        let displayIndex = content.displays.firstIndex(where: { $0.displayID == display.displayID }) ?? 0
        let localRect = ScreenCapturePlanner.displayLocalSourceRect(
            globalRect: rect,
            displayFrame: display.frame)
        let request = CaptureFrameRequest(
            mode: .area,
            display: display,
            displayIndex: displayIndex,
            displayName: display.displayID.description,
            displayBounds: rect,
            sourceRect: localRect,
            scale: scale,
            correlationId: correlationId)
        let capture = try await self.captureDisplayFrame(request: request)
        let image = capture.image

        let imageData = try image.pngData()

        return CaptureResult(imageData: imageData, metadata: capture.metadata)
    }

    private func captureDisplayFrame(
        request: CaptureFrameRequest) async throws -> (image: CGImage, metadata: CaptureMetadata)
    {
        let policy = ScreenCapturePlanner.frameSourcePolicy(for: request.mode, windowID: nil)
        if self.useFastStream, policy == .fastStream {
            do {
                try await self.frameSource.start(request: request)
                if let output = try await self.frameSource.nextFrame(maxAge: nil),
                   let image = output.cgImage
                {
                    return (image: image, metadata: output.metadata)
                }
                throw OperationError.captureFailed(reason: "Fast stream produced no image")
            } catch {
                self.logger.warning(
                    "Fast frame source failed, falling back to single-shot",
                    metadata: ["error": String(describing: error)],
                    correlationId: request.correlationId)
            }
        }

        try await self.fallbackFrameSource.start(request: request)
        guard let output = try await self.fallbackFrameSource.nextFrame(maxAge: nil),
              let image = output.cgImage
        else {
            throw OperationError.captureFailed(reason: "Single-shot produced no image")
        }

        return (image: image, metadata: output.metadata)
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
        config.sourceRect = ScreenCapturePlanner.displayLocalSourceRect(
            globalRect: window.frame,
            displayFrame: display.frame)
        config.width = width
        config.height = height
        config.captureResolution = .best
        config.showsCursor = false

        return try await ScreenCaptureKitCaptureGate.captureImage(
            contentFilter: filter,
            configuration: config)
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

    private func scalePlan(
        for display: SCDisplay,
        preference: CaptureScalePreference) -> ScreenCaptureScaleResolver.Plan
    {
        ScreenCaptureScaleResolver.plan(
            preference: preference,
            displayID: display.displayID,
            fallbackPixelWidth: display.width,
            frameWidth: display.frame.width)
    }

    private func display(for window: SCWindow, displays: [SCDisplay]) -> SCDisplay? {
        displays.first(where: { $0.frame.intersects(window.frame) })
    }
}
