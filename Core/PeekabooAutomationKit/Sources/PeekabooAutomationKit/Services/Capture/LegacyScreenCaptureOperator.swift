import Algorithms
import AppKit
import CoreGraphics
import Foundation
import PeekabooFoundation
@preconcurrency import ScreenCaptureKit

@MainActor
final class LegacyScreenCaptureOperator: LegacyScreenCaptureOperating, @unchecked Sendable {
    let logger: CategoryLogger

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
                image = try await self.captureWindowWithCGWindowList(
                    windowID: windowID,
                    correlationId: correlationId)
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

        let scalePlan = self.scalePlan(for: bounds, preference: scale)
        let imageData: Data
        let scaledImage = ScreenCaptureImageScaler.maybeDownscale(
            image,
            scale: scale,
            fallbackScale: scalePlan.nativeScale)
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
                scaleFactor: scalePlan.outputScale),
            diagnostics: ScreenCaptureScaleResolver.diagnostics(
                plan: scalePlan,
                finalPixelSize: CGSize(width: scaledImage.width, height: scaledImage.height)))

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
                image = try await self.captureWindowWithCGWindowList(
                    windowID: windowID,
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

        let scalePlan = self.scalePlan(for: bounds, preference: scale)
        let imageData: Data
        let scaledImage = ScreenCaptureImageScaler.maybeDownscale(
            image,
            scale: scale,
            fallbackScale: scalePlan.nativeScale)
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
                scaleFactor: scalePlan.outputScale),
            diagnostics: ScreenCaptureScaleResolver.diagnostics(
                plan: scalePlan,
                finalPixelSize: CGSize(width: scaledImage.width, height: scaledImage.height)))

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
        let scalePlan = ScreenCaptureScaleResolver.plan(
            preference: scale,
            screenBackingScaleFactor: targetScreen.backingScaleFactor,
            fallbackPixelWidth: Int(screenBounds.width * targetScreen.backingScaleFactor),
            frameWidth: screenBounds.width)
        let image = try self.captureDisplayWithCGDisplay(screen: targetScreen)

        let scaledImage = ScreenCaptureImageScaler.maybeDownscale(
            image,
            scale: scale,
            fallbackScale: scalePlan.nativeScale)

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
            size: CGSize(width: scaledImage.width, height: scaledImage.height),
            mode: .screen,
            displayInfo: DisplayInfo(
                index: displayIndex ?? 0,
                name: "Display \(displayIndex ?? 0)",
                bounds: screenBounds,
                scaleFactor: scalePlan.outputScale),
            diagnostics: ScreenCaptureScaleResolver.diagnostics(
                plan: scalePlan,
                finalPixelSize: CGSize(width: scaledImage.width, height: scaledImage.height)))

        return CaptureResult(
            imageData: imageData,
            metadata: metadata)
    }

    func captureArea(
        _ rect: CGRect,
        correlationId: String,
        scale: CaptureScalePreference) async throws -> CaptureResult
    {
        self.logger.debug(
            "Legacy area capture using ScreenCaptureKit screenshot manager",
            correlationId: correlationId)

        let content = try await withTimeout(seconds: 5.0) {
            try await ScreenCaptureKitCaptureGate.currentShareableContent()
        }
        guard let display = content.displays.first(where: { $0.frame.contains(rect) }) else {
            throw PeekabooError.invalidInput(
                "captureArea: The specified area is not within any display bounds")
        }

        let scalePlan = ScreenCaptureScaleResolver.plan(
            preference: scale,
            displayID: display.displayID,
            fallbackPixelWidth: display.width,
            frameWidth: display.frame.width)
        let outputScale = scalePlan.outputScale

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        // `rect` is global desktop geometry; display-bound filters need local source geometry.
        config.sourceRect = ScreenCapturePlanner.displayLocalSourceRect(
            globalRect: rect,
            displayFrame: display.frame)
        config.width = Int(rect.width * outputScale)
        config.height = Int(rect.height * outputScale)
        config.captureResolution = .best
        config.showsCursor = false

        let image = try await withTimeout(seconds: 3.0) {
            try await ScreenCaptureKitCaptureGate.captureImage(
                contentFilter: filter,
                configuration: config)
        }

        let imageData = try image.pngData()
        let metadata = CaptureMetadata(
            size: CGSize(width: image.width, height: image.height),
            mode: .area,
            displayInfo: DisplayInfo(
                index: content.displays.firstIndex(where: { $0.displayID == display.displayID }) ?? 0,
                name: display.displayID.description,
                bounds: display.frame,
                scaleFactor: outputScale),
            diagnostics: ScreenCaptureScaleResolver.diagnostics(
                plan: scalePlan,
                finalPixelSize: CGSize(width: image.width, height: image.height)))

        return CaptureResult(imageData: imageData, metadata: metadata)
    }
}
