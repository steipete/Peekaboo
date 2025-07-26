import Foundation
import CoreGraphics
@preconcurrency import ScreenCaptureKit
import AppKit

// Feature flag to toggle between modern ScreenCaptureKit and legacy CGWindowList APIs
// Set to true to use modern API, false to use legacy API
// This is a workaround for SCShareableContent.current hanging on macOS beta versions
private let USE_MODERN_SCREENCAPTURE_API = ProcessInfo.processInfo.environment["PEEKABOO_USE_MODERN_CAPTURE"] != "false"

/// Default implementation of screen capture operations
public final class ScreenCaptureService: ScreenCaptureServiceProtocol {
    private let logger: CategoryLogger
    
    public init(loggingService: LoggingServiceProtocol? = nil) {
        let logging = loggingService ?? PeekabooServices.shared.logging
        self.logger = logging.logger(category: LoggingService.Category.screenCapture)
    }
    
    public func captureScreen(displayIndex: Int?) async throws -> CaptureResult {
        let correlationId = UUID().uuidString
        logger.info("Starting screen capture", metadata: ["displayIndex": displayIndex ?? "main"], correlationId: correlationId)
        
        let measurementId = logger.startPerformanceMeasurement(operation: "captureScreen", correlationId: correlationId)
        defer {
            logger.endPerformanceMeasurement(measurementId: measurementId, metadata: ["displayIndex": displayIndex ?? "main"])
        }
        
        // Check permissions first
        logger.debug("Checking screen recording permission", correlationId: correlationId)
        guard await hasScreenRecordingPermission() else {
            logger.error("Screen recording permission denied", correlationId: correlationId)
            throw PermissionError.screenRecording()
        }
        
        // Get available displays
        logger.debug("Fetching shareable content", correlationId: correlationId)
        let content = try await SCShareableContent.current
        let displays = content.displays
        
        logger.debug("Found displays", metadata: ["count": displays.count], correlationId: correlationId)
        guard !displays.isEmpty else {
            logger.error("No displays found", correlationId: correlationId)
            throw OperationError.captureFailed(reason: "No displays available for capture")
        }
        
        // Select display
        let targetDisplay: SCDisplay
        if let index = displayIndex {
            guard index >= 0 && index < displays.count else {
                throw ValidationError.invalidInput(
                    field: "displayIndex",
                    reason: "Index \(index) is out of range. Available displays: 0-\(displays.count-1)"
                )
            }
            targetDisplay = displays[index]
        } else {
            // Use main display
            targetDisplay = displays.first!
        }
        
        // Create screenshot with retry logic
        logger.debug("Creating screenshot of display", metadata: ["displayID": targetDisplay.displayID], correlationId: correlationId)
        
        let image = try await RetryHandler.withRetry(
            policy: .standard,
            operation: {
                try await self.createScreenshot(of: targetDisplay)
            }
        )
        
        let imageData: Data
        do {
            imageData = try image.pngData()
        } catch {
            throw OperationError.captureFailed(reason: "Failed to convert image to PNG format")
        }
        
        logger.debug("Screenshot created", metadata: [
            "imageSize": "\(image.width)x\(image.height)",
            "dataSize": imageData.count
        ], correlationId: correlationId)
        
        // Create metadata
        let metadata = CaptureMetadata(
            size: CGSize(width: image.width, height: image.height),
            mode: .screen,
            displayInfo: DisplayInfo(
                index: displayIndex ?? 0,
                name: targetDisplay.displayID.description,
                bounds: targetDisplay.frame,
                scaleFactor: 2.0  // Default for Retina displays
            )
        )
        
        return CaptureResult(
            imageData: imageData,
            metadata: metadata
        )
    }
    
    public func captureWindow(appIdentifier: String, windowIndex: Int?) async throws -> CaptureResult {
        let correlationId = UUID().uuidString
        logger.info("Starting window capture", metadata: [
            "appIdentifier": appIdentifier,
            "windowIndex": windowIndex ?? "frontmost"
        ], correlationId: correlationId)
        
        let measurementId = logger.startPerformanceMeasurement(operation: "captureWindow", correlationId: correlationId)
        defer {
            logger.endPerformanceMeasurement(measurementId: measurementId, metadata: [
                "appIdentifier": appIdentifier,
                "windowIndex": windowIndex ?? "frontmost"
            ])
        }
        
        // Check permissions
        logger.debug("Checking screen recording permission", correlationId: correlationId)
        guard await hasScreenRecordingPermission() else {
            logger.error("Screen recording permission denied", correlationId: correlationId)
            throw PermissionError.screenRecording()
        }
        
        // Find application
        logger.debug("Finding application", metadata: ["identifier": appIdentifier], correlationId: correlationId)
        let app = try await findApplication(matching: appIdentifier)
        logger.debug("Found application", metadata: [
            "name": app.name,
            "pid": app.processIdentifier,
            "bundleId": app.bundleIdentifier ?? "unknown"
        ], correlationId: correlationId)
        
        // Get windows for the application
        if USE_MODERN_SCREENCAPTURE_API {
            logger.debug("Using modern ScreenCaptureKit API", correlationId: correlationId)
            return try await captureWindowModernImpl(app: app, windowIndex: windowIndex, correlationId: correlationId)
        } else {
            logger.debug("Using legacy CGWindowList API", correlationId: correlationId)
            return try await captureWindowLegacy(app: app, windowIndex: windowIndex, correlationId: correlationId)
        }
    }
    
    public func captureFrontmost() async throws -> CaptureResult {
        let correlationId = UUID().uuidString
        logger.info("Starting frontmost window capture", correlationId: correlationId)
        
        let measurementId = logger.startPerformanceMeasurement(operation: "captureFrontmost", correlationId: correlationId)
        defer {
            logger.endPerformanceMeasurement(measurementId: measurementId)
        }
        
        // Check permissions
        logger.debug("Checking screen recording permission", correlationId: correlationId)
        guard await hasScreenRecordingPermission() else {
            logger.error("Screen recording permission denied", correlationId: correlationId)
            throw PermissionError.screenRecording()
        }
        
        // Get frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            logger.error("No frontmost application found", correlationId: correlationId)
            throw NotFoundError.application("frontmost")
        }
        
        let appIdentifier = frontmostApp.bundleIdentifier ?? frontmostApp.localizedName ?? "Unknown"
        logger.debug("Found frontmost application", metadata: [
            "name": frontmostApp.localizedName ?? "unknown",
            "bundleId": frontmostApp.bundleIdentifier ?? "none",
            "pid": frontmostApp.processIdentifier
        ], correlationId: correlationId)
        
        return try await captureWindow(appIdentifier: appIdentifier, windowIndex: nil)
    }
    
    public func captureArea(_ rect: CGRect) async throws -> CaptureResult {
        let correlationId = UUID().uuidString
        logger.info("Starting area capture", metadata: [
            "rect": "\(rect.origin.x),\(rect.origin.y) \(rect.width)x\(rect.height)"
        ], correlationId: correlationId)
        
        let measurementId = logger.startPerformanceMeasurement(operation: "captureArea", correlationId: correlationId)
        defer {
            logger.endPerformanceMeasurement(measurementId: measurementId, metadata: [
                "rect": "\(rect.origin.x),\(rect.origin.y) \(rect.width)x\(rect.height)"
            ])
        }
        
        // Check permissions
        logger.debug("Checking screen recording permission", correlationId: correlationId)
        guard await hasScreenRecordingPermission() else {
            logger.error("Screen recording permission denied", correlationId: correlationId)
            throw PermissionError.screenRecording()
        }
        
        // Find display containing the rect
        logger.debug("Finding display containing rect", correlationId: correlationId)
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.frame.contains(rect) }) else {
            logger.error("No display contains the specified area", metadata: [
                "rect": "\(rect.origin.x),\(rect.origin.y) \(rect.width)x\(rect.height)"
            ], correlationId: correlationId)
            throw ValidationError.invalidInput(
                field: "captureArea",
                reason: "The specified area is not within any display bounds"
            )
        }
        logger.debug("Found display for area", metadata: ["displayID": display.displayID], correlationId: correlationId)
        
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
            }
        )
        
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
                scaleFactor: 2.0  // Default for Retina displays
            )
        )
        
        return CaptureResult(
            imageData: imageData,
            metadata: metadata
        )
    }
    
    public func hasScreenRecordingPermission() async -> Bool {
        // Check if we have permission by trying to get content with timeout
        do {
            // Use excludingDesktopWindows which is more reliable
            _ = try await withTimeout(seconds: 3.0) {
                try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            }
            return true
        } catch {
            logger.warning("Permission check failed or timed out: \(error)")
            return false
        }
    }
    
    // Helper function for timeout handling
    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        let task = Task {
            try await operation()
        }
        
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            task.cancel()
        }
        
        do {
            let result = try await task.value
            timeoutTask.cancel()
            return result
        } catch {
            timeoutTask.cancel()
            if task.isCancelled {
                throw OperationError.timeout(operation: "SCShareableContent", duration: seconds)
            }
            throw error
        }
    }
    
    // MARK: - Private Helpers
    
    private func createScreenshot(of display: SCDisplay) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        
        return try await captureWithStream(filter: filter, configuration: config)
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
        
        return try await captureWithStream(filter: filter, configuration: config)
    }
    
    private func captureWithStream(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> CGImage {
        // Create a stream for single frame capture
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        
        // Add stream output
        let output = CaptureOutput()
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: nil)
        
        // Start capture
        try await stream.startCapture()
        
        // Wait for frame
        let image = try await output.waitForImage()
        
        // Stop capture
        try await stream.stopCapture()
        
        return image
    }
    
    private func findApplication(matching identifier: String) async throws -> ServiceApplicationInfo {
        let runningApps = NSWorkspace.shared.runningApplications
        logger.trace("Searching for application", metadata: [
            "identifier": identifier,
            "runningAppsCount": runningApps.count
        ])
        
        // Try exact bundle ID match first
        if let app = runningApps.first(where: { $0.bundleIdentifier == identifier }) {
            logger.trace("Found app by exact bundle ID match", metadata: ["bundleId": identifier])
            return ServiceApplicationInfo(
                processIdentifier: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier,
                name: app.localizedName ?? "Unknown",
                bundlePath: app.bundleURL?.path,
                isActive: app.isActive,
                isHidden: app.isHidden
            )
        }
        
        // Try name match (case-insensitive)
        let lowercaseIdentifier = identifier.lowercased()
        if let app = runningApps.first(where: { 
            $0.localizedName?.lowercased() == lowercaseIdentifier 
        }) {
            logger.trace("Found app by name match", metadata: ["name": app.localizedName ?? "unknown"])
            return ServiceApplicationInfo(
                processIdentifier: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier,
                name: app.localizedName ?? "Unknown",
                bundlePath: app.bundleURL?.path,
                isActive: app.isActive,
                isHidden: app.isHidden
            )
        }
        
        // Try fuzzy match
        let matches = runningApps.filter { app in
            guard let name = app.localizedName else { return false }
            return name.lowercased().contains(lowercaseIdentifier) ||
                   (app.bundleIdentifier?.lowercased().contains(lowercaseIdentifier) ?? false)
        }
        
        if matches.count == 1 {
            let app = matches[0]
            return ServiceApplicationInfo(
                processIdentifier: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier,
                name: app.localizedName ?? "Unknown",
                bundlePath: app.bundleURL?.path,
                isActive: app.isActive,
                isHidden: app.isHidden
            )
        } else if matches.count > 1 {
            let names = matches.compactMap { $0.localizedName }
            logger.warning("Ambiguous app identifier", metadata: [
                "identifier": identifier,
                "candidates": names.joined(separator: ", "),
                "count": matches.count
            ])
            throw ValidationError.ambiguousAppIdentifier(identifier, matches: names)
        }
        
        logger.warning("Application not found", metadata: ["identifier": identifier])
        throw NotFoundError.application(identifier)
    }
    
    // MARK: - Modern API Implementation
    
    private func captureWindowModernImpl(app: ServiceApplicationInfo, windowIndex: Int?, correlationId: String) async throws -> CaptureResult {
        // Get windows using ScreenCaptureKit
        let content = try await withTimeout(seconds: 5.0) {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        }
        
        let appWindows = content.windows.filter { window in
            window.owningApplication?.processID == app.processIdentifier
        }
        
        logger.debug("Found windows for application", metadata: ["count": appWindows.count], correlationId: correlationId)
        guard !appWindows.isEmpty else {
            logger.error("No windows found for application", metadata: ["appName": app.name], correlationId: correlationId)
            throw NotFoundError.window(app: app.name)
        }
        
        // Select window
        let targetWindow: SCWindow
        if let index = windowIndex {
            guard index >= 0 && index < appWindows.count else {
                throw ValidationError.invalidInput(
                    field: "windowIndex",
                    reason: "Index \(index) is out of range. Available windows: 0-\(appWindows.count-1)"
                )
            }
            targetWindow = appWindows[index]
        } else {
            // Use frontmost window
            targetWindow = appWindows.first!
        }
        
        logger.debug("Capturing window", metadata: [
            "title": targetWindow.title ?? "untitled",
            "windowID": targetWindow.windowID
        ], correlationId: correlationId)
        
        // Create screenshot with retry logic
        let image = try await RetryHandler.withRetry(
            policy: .standard,
            operation: {
                try await self.createScreenshot(of: targetWindow)
            }
        )
        
        let imageData: Data
        do {
            imageData = try image.pngData()
        } catch {
            throw OperationError.captureFailed(reason: "Failed to convert image to PNG format")
        }
        
        logger.debug("Screenshot created", metadata: [
            "imageSize": "\(image.width)x\(image.height)",
            "dataSize": imageData.count
        ], correlationId: correlationId)
        
        // Create metadata
        let metadata = CaptureMetadata(
            size: CGSize(width: image.width, height: image.height),
            mode: .window,
            applicationInfo: ServiceApplicationInfo(
                processIdentifier: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier,
                name: app.name,
                bundlePath: app.bundlePath
            ),
            windowInfo: ServiceWindowInfo(
                windowID: Int(targetWindow.windowID),
                title: targetWindow.title ?? "",
                bounds: targetWindow.frame,
                isMinimized: false,
                isMainWindow: targetWindow.isOnScreen,
                windowLevel: 0,
                alpha: 1.0,
                index: windowIndex ?? 0
            )
        )
        
        return CaptureResult(
            imageData: imageData,
            metadata: metadata
        )
    }
    
    // MARK: - Legacy API Implementation
    
    private func captureWindowLegacy(app: ServiceApplicationInfo, windowIndex: Int?, correlationId: String) async throws -> CaptureResult {
        // Get windows using CGWindowList
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        
        let appWindows = windowList.filter { windowInfo in
            guard let pid = windowInfo[kCGWindowOwnerPID as String] as? Int32 else { return false }
            return pid == app.processIdentifier
        }
        
        logger.debug("Found windows for application (legacy)", metadata: ["count": appWindows.count], correlationId: correlationId)
        guard !appWindows.isEmpty else {
            logger.error("No windows found for application (legacy)", metadata: ["appName": app.name], correlationId: correlationId)
            throw NotFoundError.window(app: app.name)
        }
        
        // Select window
        let targetWindow: [String: Any]
        if let index = windowIndex {
            guard index >= 0 && index < appWindows.count else {
                throw ValidationError.invalidInput(
                    field: "windowIndex",
                    reason: "Index \(index) is out of range. Available windows: 0-\(appWindows.count-1)"
                )
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
        logger.debug("Capturing window (legacy)", metadata: [
            "title": windowTitle,
            "windowID": windowID
        ], correlationId: correlationId)
        
        // Capture the window
        guard let image = CGWindowListCreateImage(CGRect.null, .optionIncludingWindow, windowID, [.boundsIgnoreFraming, .nominalResolution]) else {
            throw OperationError.captureFailed(reason: "Failed to create window image")
        }
        
        let imageData: Data
        do {
            imageData = try image.pngData()
        } catch {
            throw OperationError.captureFailed(reason: "Failed to convert image to PNG format")
        }
        
        logger.debug("Screenshot created (legacy)", metadata: [
            "imageSize": "\(image.width)x\(image.height)",
            "dataSize": imageData.count
        ], correlationId: correlationId)
        
        // Get window bounds
        let bounds: CGRect
        if let boundsDict = targetWindow[kCGWindowBounds as String] as? [String: Any],
           let x = boundsDict["X"] as? CGFloat,
           let y = boundsDict["Y"] as? CGFloat,
           let width = boundsDict["Width"] as? CGFloat,
           let height = boundsDict["Height"] as? CGFloat {
            bounds = CGRect(x: x, y: y, width: width, height: height)
        } else {
            bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        }
        
        // Create metadata
        let metadata = CaptureMetadata(
            size: CGSize(width: image.width, height: image.height),
            mode: .window,
            applicationInfo: ServiceApplicationInfo(
                processIdentifier: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier,
                name: app.name,
                bundlePath: app.bundlePath
            ),
            windowInfo: ServiceWindowInfo(
                windowID: Int(windowID),
                title: windowTitle,
                bounds: bounds,
                isMinimized: false,
                isMainWindow: true,
                windowLevel: 0,
                alpha: 1.0,
                index: windowIndex ?? 0
            )
        )
        
        return CaptureResult(
            imageData: imageData,
            metadata: metadata
        )
    }
}

// MARK: - Capture Output Handler

private final class CaptureOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    private var continuation: CheckedContinuation<CGImage, Error>?
    
    func waitForImage() async throws -> CGImage {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        
        guard let imageBuffer = sampleBuffer.imageBuffer else {
            continuation?.resume(throwing: OperationError.captureFailed(reason: "No image buffer in sample"))
            continuation = nil
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            continuation?.resume(throwing: OperationError.captureFailed(reason: "Failed to create CGImage from buffer"))
            continuation = nil
            return
        }
        
        continuation?.resume(returning: cgImage)
        continuation = nil
    }
}

// MARK: - Extensions

extension CGImage {
    // Width and height are already properties of CGImage
    
    func pngData() throws -> Data {
        let nsImage = NSImage(cgImage: self, size: NSSize(width: width, height: height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw OperationError.captureFailed(reason: "Failed to convert CGImage to PNG data")
        }
        return pngData
    }
}