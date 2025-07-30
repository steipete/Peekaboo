import AppKit
import CoreGraphics
import Foundation
@preconcurrency import ScreenCaptureKit

// Feature flag to toggle between modern ScreenCaptureKit and legacy CGWindowList APIs
// Set to true to use modern API, false to use legacy API
// This is a workaround for SCShareableContent.current hanging on macOS beta versions
private let USE_MODERN_SCREENCAPTURE_API = ProcessInfo.processInfo.environment["PEEKABOO_USE_MODERN_CAPTURE"] != "false"

/// Default implementation of screen capture operations
@MainActor
public final class ScreenCaptureService: ScreenCaptureServiceProtocol {
    private let logger: CategoryLogger
    private let visualizerClient = VisualizationClient.shared

    public init(loggingService: LoggingServiceProtocol) {
        self.logger = loggingService.logger(category: LoggingService.Category.screenCapture)
        // Connect to visualizer if available
        self.visualizerClient.connect()
    }

    public func captureScreen(displayIndex: Int?) async throws -> CaptureResult {
        let correlationId = UUID().uuidString
        self.logger.info(
            "Starting screen capture",
            metadata: ["displayIndex": displayIndex ?? "main"],
            correlationId: correlationId)

        let measurementId = self.logger.startPerformanceMeasurement(
            operation: "captureScreen",
            correlationId: correlationId)
        defer {
            logger.endPerformanceMeasurement(
                measurementId: measurementId,
                metadata: ["displayIndex": displayIndex ?? "main"])
        }

        // Check permissions first
        self.logger.debug("Checking screen recording permission", correlationId: correlationId)
        guard await self.hasScreenRecordingPermission() else {
            self.logger.error("Screen recording permission denied", correlationId: correlationId)
            throw PermissionError.screenRecording()
        }

        // Try modern API first if enabled
        if USE_MODERN_SCREENCAPTURE_API {
            do {
                // Get available displays
                self.logger.debug("Fetching shareable content", correlationId: correlationId)
                let content = try await SCShareableContent.current
                let displays = content.displays

                self.logger.debug("Found displays", metadata: ["count": displays.count], correlationId: correlationId)
                guard !displays.isEmpty else {
                    self.logger.error("No displays found", correlationId: correlationId)
                    throw OperationError.captureFailed(reason: "No displays available for capture")
                }

                // Select display
                let targetDisplay: SCDisplay
                if let index = displayIndex {
                    guard index >= 0, index < displays.count else {
                        throw PeekabooError.invalidInput(
                            "displayIndex: Index \(index) is out of range. Available displays: 0-\(displays.count - 1)")
                    }
                    targetDisplay = displays[index]
                } else {
                    // Use main display
                    targetDisplay = displays.first!
                }

                // Create screenshot with retry logic
                self.logger.debug(
                    "Creating screenshot of display",
                    metadata: ["displayID": targetDisplay.displayID],
                    correlationId: correlationId)

                let image = try await RetryHandler.withRetry(
                    policy: .standard,
                    operation: {
                        try await self.createScreenshot(of: targetDisplay)
                    })

                let imageData: Data
                do {
                    imageData = try image.pngData()
                } catch {
                    throw OperationError.captureFailed(reason: "Failed to convert image to PNG format")
                }

                self.logger.debug("Screenshot created", metadata: [
                    "imageSize": "\(image.width)x\(image.height)",
                    "dataSize": imageData.count,
                ], correlationId: correlationId)

                // Show screenshot flash animation if available
                _ = await self.visualizerClient.showScreenshotFlash(in: targetDisplay.frame)

                // Create metadata
                let metadata = CaptureMetadata(
                    size: CGSize(width: image.width, height: image.height),
                    mode: .screen,
                    displayInfo: DisplayInfo(
                        index: displayIndex ?? 0,
                        name: targetDisplay.displayID.description,
                        bounds: targetDisplay.frame,
                        scaleFactor: 2.0 // Default for Retina displays
                    ))

                return CaptureResult(
                    imageData: imageData,
                    metadata: metadata)
            } catch {
                // If modern API fails with timeout, try legacy API as fallback
                if case OperationError.timeout = error {
                    self.logger.warning(
                        "Modern screen capture timed out, falling back to legacy API",
                        metadata: ["error": String(describing: error)],
                        correlationId: correlationId)
                    return try await self.captureScreenLegacy(displayIndex: displayIndex, correlationId: correlationId)
                } else {
                    throw error
                }
            }
        } else {
            // Use legacy API directly
            return try await self.captureScreenLegacy(displayIndex: displayIndex, correlationId: correlationId)
        }
    }

    public func captureWindow(appIdentifier: String, windowIndex: Int?) async throws -> CaptureResult {
        let correlationId = UUID().uuidString
        self.logger.info("Starting window capture", metadata: [
            "appIdentifier": appIdentifier,
            "windowIndex": windowIndex ?? "frontmost",
        ], correlationId: correlationId)

        let measurementId = self.logger.startPerformanceMeasurement(
            operation: "captureWindow",
            correlationId: correlationId)
        defer {
            logger.endPerformanceMeasurement(measurementId: measurementId, metadata: [
                "appIdentifier": appIdentifier,
                "windowIndex": windowIndex ?? "frontmost",
            ])
        }

        // Check permissions
        self.logger.debug("Checking screen recording permission", correlationId: correlationId)
        guard await self.hasScreenRecordingPermission() else {
            self.logger.error("Screen recording permission denied", correlationId: correlationId)
            throw PermissionError.screenRecording()
        }

        // Find application
        self.logger.debug("Finding application", metadata: ["identifier": appIdentifier], correlationId: correlationId)
        let app = try await findApplication(matching: appIdentifier)
        self.logger.debug("Found application", metadata: [
            "name": app.name,
            "pid": app.processIdentifier,
            "bundleId": app.bundleIdentifier ?? "unknown",
        ], correlationId: correlationId)

        // Get windows for the application
        if USE_MODERN_SCREENCAPTURE_API {
            self.logger.debug("Using modern ScreenCaptureKit API", correlationId: correlationId)
            do {
                return try await self.captureWindowModernImpl(
                    app: app,
                    windowIndex: windowIndex,
                    correlationId: correlationId)
            } catch {
                // If modern API fails with timeout, try legacy API as fallback
                if case OperationError.timeout = error {
                    self.logger.warning(
                        "Modern capture timed out, falling back to legacy API",
                        metadata: ["error": String(describing: error)],
                        correlationId: correlationId)
                    return try await self.captureWindowLegacy(
                        app: app,
                        windowIndex: windowIndex,
                        correlationId: correlationId)
                } else {
                    throw error
                }
            }
        } else {
            self.logger.debug("Using legacy CGWindowList API", correlationId: correlationId)
            return try await self.captureWindowLegacy(app: app, windowIndex: windowIndex, correlationId: correlationId)
        }
    }

    public func captureFrontmost() async throws -> CaptureResult {
        let correlationId = UUID().uuidString
        self.logger.info("Starting frontmost window capture", correlationId: correlationId)

        let measurementId = self.logger.startPerformanceMeasurement(
            operation: "captureFrontmost",
            correlationId: correlationId)
        defer {
            logger.endPerformanceMeasurement(measurementId: measurementId)
        }

        // Check permissions
        self.logger.debug("Checking screen recording permission", correlationId: correlationId)
        guard await self.hasScreenRecordingPermission() else {
            self.logger.error("Screen recording permission denied", correlationId: correlationId)
            throw PermissionError.screenRecording()
        }

        // Get frontmost application - already on main thread due to @MainActor
        guard let app = NSWorkspace.shared.frontmostApplication else {
            self.logger.error("No frontmost application found", correlationId: correlationId)
            throw NotFoundError.application("frontmost")
        }

        let appIdentifier = app.bundleIdentifier ?? app.localizedName ?? "Unknown"
        self.logger.debug("Found frontmost application", metadata: [
            "name": app.localizedName ?? "unknown",
            "bundleId": app.bundleIdentifier ?? "none",
            "pid": app.processIdentifier,
        ], correlationId: correlationId)

        return try await self.captureWindow(appIdentifier: appIdentifier, windowIndex: nil)
    }

    public func captureArea(_ rect: CGRect) async throws -> CaptureResult {
        let correlationId = UUID().uuidString
        self.logger.info("Starting area capture", metadata: [
            "rect": "\(rect.origin.x),\(rect.origin.y) \(rect.width)x\(rect.height)",
        ], correlationId: correlationId)

        let measurementId = self.logger.startPerformanceMeasurement(
            operation: "captureArea",
            correlationId: correlationId)
        defer {
            logger.endPerformanceMeasurement(measurementId: measurementId, metadata: [
                "rect": "\(rect.origin.x),\(rect.origin.y) \(rect.width)x\(rect.height)",
            ])
        }

        // Check permissions
        self.logger.debug("Checking screen recording permission", correlationId: correlationId)
        guard await self.hasScreenRecordingPermission() else {
            self.logger.error("Screen recording permission denied", correlationId: correlationId)
            throw PermissionError.screenRecording()
        }

        // Find display containing the rect
        self.logger.debug("Finding display containing rect", correlationId: correlationId)
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.frame.contains(rect) }) else {
            self.logger.error("No display contains the specified area", metadata: [
                "rect": "\(rect.origin.x),\(rect.origin.y) \(rect.width)x\(rect.height)",
            ], correlationId: correlationId)
            throw PeekabooError.invalidInput(
                "captureArea: The specified area is not within any display bounds")
        }
        self.logger.debug(
            "Found display for area",
            metadata: ["displayID": display.displayID],
            correlationId: correlationId)

        // Create content filter for the area
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Configure stream for single frame capture
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int(rect.width)
        config.height = Int(rect.height)
        config.showsCursor = false

        // Capture the area with retry logic
        let image = try await RetryHandler.withRetry(
            policy: .standard,
            operation: {
                try await self.captureWithStream(filter: filter, configuration: config)
            })

        let imageData: Data
        do {
            imageData = try image.pngData()
        } catch {
            throw OperationError.captureFailed(reason: "Failed to convert image to PNG format")
        }

        // Create metadata
        let metadata = CaptureMetadata(
            size: CGSize(width: image.width, height: image.height),
            mode: .area,
            displayInfo: DisplayInfo(
                index: 0,
                name: display.displayID.description,
                bounds: display.frame,
                scaleFactor: 2.0 // Default for Retina displays
            ))

        return CaptureResult(
            imageData: imageData,
            metadata: metadata)
    }

    public func hasScreenRecordingPermission() async -> Bool {
        // Check if we have permission by trying to get content with timeout
        do {
            // Use excludingDesktopWindows which is more reliable
            _ = try await self.withTimeout(seconds: 3.0) {
                try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            }
            return true
        } catch {
            self.logger.warning("Permission check failed or timed out: \(error)")
            return false
        }
    }

    // Helper function for timeout handling
    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T) async throws -> T
    {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }

            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw OperationError.timeout(operation: "SCShareableContent", duration: seconds)
            }

            // Wait for the first task to complete
            guard let result = try await group.next() else {
                throw OperationError.timeout(operation: "SCShareableContent", duration: seconds)
            }

            // Cancel remaining tasks
            group.cancelAll()

            return result
        }
    }

    // MARK: - Private Helpers

    private func createScreenshot(of display: SCDisplay) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)

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
        // Delegate to ApplicationService for consistent app resolution
        try await PeekabooServices.shared.applications.findApplication(identifier: identifier)
    }

    // MARK: - Modern API Implementation

    private func captureWindowModernImpl(
        app: ServiceApplicationInfo,
        windowIndex: Int?,
        correlationId: String) async throws -> CaptureResult
    {
        // Get windows using ScreenCaptureKit
        let content = try await withTimeout(seconds: 5.0) {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
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

        // Select window
        let targetWindow: SCWindow
        if let index = windowIndex {
            guard index >= 0, index < appWindows.count else {
                throw PeekabooError.invalidInput(
                    "windowIndex: Index \(index) is out of range. Available windows: 0-\(appWindows.count - 1)")
            }
            targetWindow = appWindows[index]
        } else {
            // Use frontmost window
            targetWindow = appWindows.first!
        }

        self.logger.debug("Capturing window", metadata: [
            "title": targetWindow.title ?? "untitled",
            "windowID": targetWindow.windowID,
        ], correlationId: correlationId)

        // Create screenshot with retry logic
        let image = try await RetryHandler.withRetry(
            policy: .standard,
            operation: {
                try await self.createScreenshot(of: targetWindow)
            })

        let imageData: Data
        do {
            imageData = try image.pngData()
        } catch {
            throw OperationError.captureFailed(reason: "Failed to convert image to PNG format")
        }

        self.logger.debug("Screenshot created", metadata: [
            "imageSize": "\(image.width)x\(image.height)",
            "dataSize": imageData.count,
        ], correlationId: correlationId)

        // Show screenshot flash animation if available
        _ = await self.visualizerClient.showScreenshotFlash(in: targetWindow.frame)

        // Create metadata
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
                index: windowIndex ?? 0))

        return CaptureResult(
            imageData: imageData,
            metadata: metadata)
    }

    // MARK: - Legacy API Implementation

    private func captureWindowLegacy(
        app: ServiceApplicationInfo,
        windowIndex: Int?,
        correlationId: String) async throws -> CaptureResult
    {
        // Get windows using CGWindowList
        let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
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

        // Select window
        let targetWindow: [String: Any]
        if let index = windowIndex {
            guard index >= 0, index < appWindows.count else {
                throw PeekabooError.invalidInput(
                    "windowIndex: Index \(index) is out of range. Available windows: 0-\(appWindows.count - 1)")
            }
            targetWindow = appWindows[index]
        } else {
            // Use frontmost window (first in list)
            targetWindow = appWindows.first!
        }

        guard let windowID = targetWindow[kCGWindowNumber as String] as? CGWindowID else {
            throw OperationError.captureFailed(reason: "Failed to get window ID")
        }

        let windowTitle = targetWindow[kCGWindowName as String] as? String ?? "untitled"
        self.logger.debug("Capturing window (legacy)", metadata: [
            "title": windowTitle,
            "windowID": windowID,
        ], correlationId: correlationId)

        // Capture the window
        // Note: CGWindowListCreateImage is deprecated but we intentionally use it here as a fallback
        // when ScreenCaptureKit hangs on certain macOS versions (controlled by PEEKABOO_USE_MODERN_CAPTURE env var)
        // TODO: Migrate to ScreenCaptureKit when ready
        let image = CGWindowListCreateImage(
            CGRect.null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .nominalResolution])

        guard let image = image else {
            throw OperationError.captureFailed(reason: "Failed to create window image")
        }

        let imageData: Data
        do {
            imageData = try image.pngData()
        } catch {
            throw OperationError.captureFailed(reason: "Failed to convert image to PNG format")
        }

        self.logger.debug("Screenshot created (legacy)", metadata: [
            "imageSize": "\(image.width)x\(image.height)",
            "dataSize": imageData.count,
        ], correlationId: correlationId)

        // Get window bounds
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

        // Create metadata
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
                index: windowIndex ?? 0))

        return CaptureResult(
            imageData: imageData,
            metadata: metadata)
    }

    // MARK: - Legacy Screen Capture

    private func captureScreenLegacy(displayIndex: Int?, correlationId: String) async throws -> CaptureResult {
        self.logger.debug("Using legacy CGWindowList API for screen capture", correlationId: correlationId)

        // Get screen bounds
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
            // Use main screen
            targetScreen = screens.first!
        }

        let screenBounds = targetScreen.frame

        // Capture using legacy API
        // TODO: Migrate to ScreenCaptureKit when ready
        let image = CGWindowListCreateImage(screenBounds, .optionOnScreenBelowWindow, kCGNullWindowID, .nominalResolution)

        guard let image = image else {
            throw OperationError.captureFailed(reason: "Failed to create screen image using legacy API")
        }

        let imageData: Data
        do {
            imageData = try image.pngData()
        } catch {
            throw OperationError.captureFailed(reason: "Failed to convert image to PNG format")
        }

        self.logger.debug("Legacy screenshot created", metadata: [
            "imageSize": "\(image.width)x\(image.height)",
            "dataSize": imageData.count,
        ], correlationId: correlationId)

        // Create metadata
        let metadata = CaptureMetadata(
            size: CGSize(width: image.width, height: image.height),
            mode: .screen,
            displayInfo: DisplayInfo(
                index: displayIndex ?? 0,
                name: "Display \(displayIndex ?? 0)",
                bounds: screenBounds,
                scaleFactor: targetScreen.backingScaleFactor))

        return CaptureResult(
            imageData: imageData,
            metadata: metadata)
    }
}

// MARK: - Stream Delegate

private final class StreamDelegate: NSObject, SCStreamDelegate, @unchecked Sendable {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        // Log the error but don't need to do anything else since CaptureOutput handles errors
        print("SCStream stopped with error: \(error)")
    }
}

// MARK: - Capture Output Handler

private final class CaptureOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    private var continuation: CheckedContinuation<CGImage, Error>?
    private var timeoutTask: Task<Void, Never>?

    deinit {
        // Ensure continuation is resumed if object is deallocated
        if let continuation {
            continuation
                .resume(throwing: OperationError
                    .captureFailed(reason: "CaptureOutput deallocated before frame captured"))
            self.continuation = nil
        }
        timeoutTask?.cancel()
    }

    func waitForImage() async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            // Add a timeout to ensure the continuation is always resumed
            // Reduced from 10 seconds to 3 seconds for faster failure detection
            self.timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                if let cont = self.continuation {
                    cont.resume(throwing: OperationError.timeout(
                        operation: "CaptureOutput.waitForImage",
                        duration: 3.0))
                    self.continuation = nil
                }
            }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        // Cancel timeout task since we received a frame
        self.timeoutTask?.cancel()
        self.timeoutTask = nil

        guard let imageBuffer = sampleBuffer.imageBuffer else {
            self.continuation?.resume(throwing: OperationError.captureFailed(reason: "No image buffer in sample"))
            self.continuation = nil
            return
        }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            self.continuation?
                .resume(throwing: OperationError.captureFailed(reason: "Failed to create CGImage from buffer"))
            self.continuation = nil
            return
        }

        self.continuation?.resume(returning: cgImage)
        self.continuation = nil
    }
}

// MARK: - Extensions

extension CGImage {
    // Width and height are already properties of CGImage

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
