import AppKit
import CoreGraphics
import Foundation
import ImageIO
import ObjectiveC
import PeekabooFoundation
@preconcurrency import ScreenCaptureKit

extension LegacyScreenCaptureOperator {
    func captureDisplayWithScreenshotManager(
        screen: NSScreen,
        displayIndex: Int,
        correlationId: String) async throws -> CGImage
    {
        let content = try await ScreenCaptureKitCaptureGate.currentShareableContent()
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

        return try await ScreenCaptureKitCaptureGate.captureImage(
            contentFilter: filter,
            configuration: self.makeScreenshotConfiguration())
    }

    func captureDisplayWithCGDisplay(screen: NSScreen) throws -> CGImage {
        let resolvedID = self.displayID(for: screen) ?? CGMainDisplayID()
        guard let image = CGDisplayCreateImage(resolvedID) else {
            throw OperationError.captureFailed(reason: "CGDisplayCreateImage returned nil")
        }
        return image
    }

    func resolveDisplay(
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

    func captureWindowWithScreenshotManager(
        windowID: CGWindowID,
        correlationId: String) async throws -> CGImage
    {
        let content = try await ScreenCaptureKitCaptureGate.shareableContent(
            excludingDesktopWindows: false,
            onScreenWindowsOnly: false)
        guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
            throw OperationError.captureFailed(
                reason: "Failed to locate window \(windowID) in ScreenCaptureKit shareable content")
        }
        guard let display = content.displays.first(where: { $0.frame.intersects(scWindow.frame) }) else {
            throw OperationError.captureFailed(
                reason: "Window \(windowID) is not on any available display")
        }

        let nativeScale = ScreenCaptureScaleResolver.plan(
            preference: .native,
            displayID: display.displayID,
            fallbackPixelWidth: display.width,
            frameWidth: display.frame.width).nativeScale

        let filter = SCContentFilter(display: display, including: [scWindow])
        let config = self.makeScreenshotConfiguration()
        // Display-bound filters expect display-local geometry. This mirrors the reliable modern path and keeps
        // single-shot captures crisp without relying on the obsolete CoreGraphics window API.
        config.sourceRect = ScreenCapturePlanner.displayLocalSourceRect(
            globalRect: scWindow.frame,
            displayFrame: display.frame)
        config.width = max(Int(scWindow.frame.width * nativeScale), 1)
        config.height = max(Int(scWindow.frame.height * nativeScale), 1)
        config.captureResolution = .best
        config.ignoreShadowsSingleWindow = true
        if #available(macOS 14.2, *) {
            config.includeChildWindows = false
        }

        self.logger.debug(
            "Capturing window via display-bound SCScreenshotManager",
            metadata: [
                "windowID": windowID,
                "displayID": display.displayID,
            ],
            correlationId: correlationId)

        return try await ScreenCaptureKitCaptureGate.captureImage(
            contentFilter: filter,
            configuration: config)
    }

    @MainActor
    func captureWindowWithCGWindowList(
        windowID: CGWindowID,
        correlationId: String) async throws -> CGImage
    {
        do {
            return try await self.captureWindowWithPrivateScreenCaptureKit(
                windowID: windowID,
                correlationId: correlationId)
        } catch {
            self.logger.warning(
                "Private ScreenCaptureKit window capture failed, falling back to system screencapture",
                metadata: [
                    "windowID": String(windowID),
                    "error": String(describing: error),
                ],
                correlationId: correlationId)
        }

        do {
            return try self.captureWindowWithSystemScreencapture(
                windowID: windowID,
                correlationId: correlationId)
        } catch {
            self.logger.warning(
                "System screencapture window capture failed, falling back to SCScreenshotManager",
                metadata: [
                    "windowID": String(windowID),
                    "error": String(describing: error),
                ],
                correlationId: correlationId)
            return try await self.captureWindowWithScreenshotManager(
                windowID: windowID,
                correlationId: correlationId)
        }
    }

    private func captureWindowWithPrivateScreenCaptureKit(
        windowID: CGWindowID,
        correlationId: String) async throws -> CGImage
    {
        let scWindow = try await self.fetchWindowWithPrivateScreenCaptureKit(windowID: windowID)
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let config = self.makeScreenshotConfiguration()
        config.captureResolution = .best
        config.ignoreShadowsSingleWindow = true
        if #available(macOS 14.2, *) {
            config.includeChildWindows = false
        }

        self.logger.debug(
            "Capturing window via private ScreenCaptureKit window-id lookup",
            metadata: [
                "windowID": String(windowID),
                "windowFrame": "\(scWindow.frame)",
            ],
            correlationId: correlationId)

        return try await ScreenCaptureKitCaptureGate.captureImage(
            contentFilter: filter,
            configuration: config)
    }

    private func fetchWindowWithPrivateScreenCaptureKit(windowID: CGWindowID) async throws -> SCWindow {
        guard let privateWindowID = UInt32(exactly: windowID) else {
            throw OperationError.captureFailed(reason: "Window ID \(windowID) is outside UInt32 range")
        }

        let selector = NSSelectorFromString("fetchWindowForWindowID:withCompletionHandler:")
        guard let method = class_getClassMethod(SCShareableContent.self, selector) else {
            throw OperationError.captureFailed(
                reason: "Private SCShareableContent.fetchWindowForWindowID selector is unavailable")
        }

        let implementation = method_getImplementation(method)
        typealias Completion = @convention(block) (AnyObject?) -> Void
        typealias FetchWindow = @convention(c) (AnyClass, Selector, UInt32, Completion) -> Void
        let fetchWindow = unsafeBitCast(implementation, to: FetchWindow.self)
        let result = PrivateScreenCaptureKitWindowFetchResult()

        // Private API, intentionally isolated: Hopper shows `/usr/sbin/screencapture -l` resolving a
        // WindowServer ID through `SCShareableContent` before building a desktop-independent window filter.
        // Public `SCShareableContent.windows` enumeration can miss windows that this lookup still captures.
        // If Apple removes this selector, callers fall back to `/usr/sbin/screencapture -l` and then public SCK.
        let completion: Completion = { object in
            guard let window = object as? SCWindow else {
                result.finish(.failure(OperationError.captureFailed(
                    reason: "Private SCShareableContent lookup did not return window \(windowID)")))
                return
            }
            result.finish(.success(window))
        }
        fetchWindow(SCShareableContent.self, selector, privateWindowID, completion)

        return try await Task.detached(priority: .userInitiated) {
            try result.wait(timeout: .now() + 1.0)
        }.value
    }

    private func captureWindowWithSystemScreencapture(
        windowID: CGWindowID,
        correlationId: String) throws -> CGImage
    {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("peekaboo-window-\(windowID)-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // Match Apple's native window capture path; Hopper shows `screencapture -l` using
        // private window-id lookup before building its SCScreenshotManager content filter.
        process.arguments = [
            "-l",
            String(windowID),
            "-o",
            "-x",
            url.path,
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw OperationError.captureFailed(reason: "screencapture exited with \(process.terminationStatus)")
        }

        let data = try Data(contentsOf: url)
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw OperationError.captureFailed(reason: "Failed to decode screencapture output")
        }

        self.logger.debug(
            "Captured window via system screencapture",
            metadata: [
                "windowID": String(windowID),
                "imageSize": "\(image.width)x\(image.height)",
            ],
            correlationId: correlationId)
        return image
    }

    nonisolated static func windowIndexError(requestedIndex: Int, totalWindows: Int) -> String {
        let lastIndex = max(totalWindows - 1, 0)
        return "windowIndex: Index \(requestedIndex) is out of range. Valid windows: 0-\(lastIndex)"
    }

    nonisolated static func firstRenderableWindowIndex(
        in windows: [[String: Any]]) -> Int?
    {
        windows.indexed().first { indexWindow in
            guard let info = self.makeFilteringInfo(from: indexWindow.element, index: indexWindow.index) else {
                return false
            }
            return WindowFiltering.isRenderable(info)
        }?.index
    }

    nonisolated static func makeFilteringInfo(
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
            isOffScreen: !isOnScreen,
            layer: layer,
            isOnScreen: isOnScreen,
            sharingState: sharingState)
    }

    func shouldUseLegacyCGCapture() -> Bool {
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

    func scaleFactor(for bounds: CGRect) -> CGFloat {
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(bounds) }) {
            return screen.backingScaleFactor
        }
        return NSScreen.main?.backingScaleFactor ?? 1.0
    }

    func scalePlan(
        for bounds: CGRect,
        preference: CaptureScalePreference) -> ScreenCaptureScaleResolver.Plan
    {
        let scaleFactor = self.scaleFactor(for: bounds)
        return ScreenCaptureScaleResolver.plan(
            preference: preference,
            screenBackingScaleFactor: scaleFactor,
            fallbackPixelWidth: Int(bounds.width * scaleFactor),
            frameWidth: bounds.width)
    }

    func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    func makeScreenshotConfiguration() -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.backgroundColor = .clear
        configuration.shouldBeOpaque = true
        configuration.showsCursor = false
        configuration.capturesAudio = false
        return configuration
    }
}

private final class PrivateScreenCaptureKitWindowFetchResult: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var result: Result<SCWindow, any Error>?

    func finish(_ result: Result<SCWindow, any Error>) {
        self.lock.lock()
        guard self.result == nil else {
            self.lock.unlock()
            return
        }
        self.result = result
        self.lock.unlock()
        self.semaphore.signal()
    }

    func wait(timeout: DispatchTime) throws -> SCWindow {
        guard self.semaphore.wait(timeout: timeout) == .success else {
            throw OperationError.timeout(operation: "SCShareableContent.fetchWindowForWindowID", duration: 1.0)
        }

        self.lock.lock()
        let result = self.result
        self.lock.unlock()
        guard let result else {
            throw OperationError.captureFailed(reason: "Private SCShareableContent lookup returned no result")
        }
        return try result.get()
    }
}
