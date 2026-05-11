import AppKit
import CoreGraphics
import Foundation
import PeekabooFoundation

extension LegacyScreenCaptureOperator {
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

        let image = try await self.captureWindowImage(windowID: windowID, correlationId: correlationId)

        let bounds = Self.windowBounds(from: targetWindow, fallbackImage: image)
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
                isOffScreen: !(targetWindow[kCGWindowIsOnscreen as String] as? Bool ?? true),
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

        let image = try await self.captureWindowImage(windowID: windowID, correlationId: correlationId)

        let bounds = Self.windowBounds(from: targetWindow, fallbackImage: image)
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

    private func captureWindowImage(
        windowID: CGWindowID,
        correlationId: String) async throws -> CGImage
    {
        let forceCoreGraphics = self.shouldUseLegacyCGCapture()
        if forceCoreGraphics {
            do {
                let image = try await self.captureWindowWithCGWindowList(
                    windowID: windowID,
                    correlationId: correlationId)
                self.logger.debug(
                    "Captured window via CGWindowList",
                    metadata: ["windowID": String(windowID)],
                    correlationId: correlationId)
                return image
            } catch {
                let explicitLegacy = ScreenCaptureService.captureEnginePreference == .legacy
                self.logger.warning(
                    explicitLegacy
                        ? "CGWindowList capture failed for explicit legacy capture engine"
                        : "CGWindowList capture failed, falling back to SCScreenshotManager",
                    metadata: ["error": String(describing: error)],
                    correlationId: correlationId)
                if explicitLegacy {
                    throw error
                }
                return try await self.captureWindowWithScreenshotManager(
                    windowID: windowID,
                    correlationId: correlationId)
            }
        }

        return try await self.captureWindowWithScreenshotManager(
            windowID: windowID,
            correlationId: correlationId)
    }

    private static func windowBounds(
        from window: [String: Any],
        fallbackImage image: CGImage) -> CGRect
    {
        if let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
           let x = boundsDict["X"] as? CGFloat,
           let y = boundsDict["Y"] as? CGFloat,
           let width = boundsDict["Width"] as? CGFloat,
           let height = boundsDict["Height"] as? CGFloat
        {
            return CGRect(x: x, y: y, width: width, height: height)
        }

        return CGRect(x: 0, y: 0, width: image.width, height: image.height)
    }
}
