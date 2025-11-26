import CoreGraphics
import Foundation

public enum CaptureVisualizerMode: Sendable {
    case screenshotFlash
    case watchCapture
}

/// Preferred output scale for captures
public enum CaptureScalePreference: Sendable {
    /// Store images at logical 1x resolution (default)
    case logical1x
    /// Store images at the display's native pixel scale (e.g., 2x on Retina)
    case native
}

/// Protocol defining screen capture operations
@MainActor
public protocol ScreenCaptureServiceProtocol: Sendable {
    /// Capture the entire screen or a specific display
    /// - Parameter displayIndex: Optional display index (0-based). If nil, captures main display
    /// - Returns: Result containing the captured image and metadata
    func captureScreen(
        displayIndex: Int?,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult

    /// Capture a specific window from an application
    /// - Parameters:
    ///   - appIdentifier: Application name or bundle ID
    ///   - windowIndex: Optional window index (0-based). If nil, captures frontmost window
    /// - Returns: Result containing the captured image and metadata
    func captureWindow(
        appIdentifier: String,
        windowIndex: Int?,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult

    /// Capture the frontmost window of the frontmost application
    /// - Returns: Result containing the captured image and metadata
    func captureFrontmost(
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult

    /// Capture a specific area of the screen
    /// - Parameter rect: The rectangle to capture in screen coordinates
    /// - Returns: Result containing the captured image and metadata
    func captureArea(
        _ rect: CGRect,
        visualizerMode: CaptureVisualizerMode,
        scale: CaptureScalePreference) async throws -> CaptureResult

    /// Check if screen recording permission is granted
    /// - Returns: True if permission is granted
    func hasScreenRecordingPermission() async -> Bool
}

extension ScreenCaptureServiceProtocol {
    public func captureScreen(displayIndex: Int?) async throws -> CaptureResult {
        try await self.captureScreen(
            displayIndex: displayIndex,
            visualizerMode: .screenshotFlash,
            scale: .logical1x)
    }

    public func captureWindow(appIdentifier: String, windowIndex: Int?) async throws -> CaptureResult {
        try await self.captureWindow(
            appIdentifier: appIdentifier,
            windowIndex: windowIndex,
            visualizerMode: .screenshotFlash,
            scale: .logical1x)
    }

    public func captureFrontmost() async throws -> CaptureResult {
        try await self.captureFrontmost(visualizerMode: .screenshotFlash, scale: .logical1x)
    }

    public func captureArea(_ rect: CGRect) async throws -> CaptureResult {
        try await self.captureArea(rect, visualizerMode: .screenshotFlash, scale: .logical1x)
    }
}

/// Result of a capture operation
public struct CaptureResult: Sendable {
    /// The captured image data
    public let imageData: Data

    /// Path where the image was saved (if saved)
    public let savedPath: String?

    /// Metadata about the capture
    public let metadata: CaptureMetadata

    /// Optional error that occurred during capture
    public let warning: String?

    public init(
        imageData: Data,
        savedPath: String? = nil,
        metadata: CaptureMetadata,
        warning: String? = nil)
    {
        self.imageData = imageData
        self.savedPath = savedPath
        self.metadata = metadata
        self.warning = warning
    }
}

/// Metadata about a captured image
public struct CaptureMetadata: Sendable {
    /// Size of the captured image
    public let size: CGSize

    /// Capture mode used
    public let mode: CaptureMode

    /// Timestamp on the source timeline in milliseconds, when available (e.g. video ingest).
    /// Falls back to wall-clock timing elsewhere.
    public let videoTimestampMs: Int?

    /// Application information (if applicable)
    public let applicationInfo: ServiceApplicationInfo?

    /// Window information (if applicable)
    public let windowInfo: ServiceWindowInfo?

    /// Display information (if applicable)
    public let displayInfo: DisplayInfo?

    /// Timestamp of capture
    public let timestamp: Date

    public init(
        size: CGSize,
        mode: CaptureMode,
        videoTimestampMs: Int? = nil,
        applicationInfo: ServiceApplicationInfo? = nil,
        windowInfo: ServiceWindowInfo? = nil,
        displayInfo: DisplayInfo? = nil,
        timestamp: Date = Date())
    {
        self.size = size
        self.mode = mode
        self.videoTimestampMs = videoTimestampMs
        self.applicationInfo = applicationInfo
        self.windowInfo = windowInfo
        self.displayInfo = displayInfo
        self.timestamp = timestamp
    }
}

/// Information about a display
public struct DisplayInfo: Sendable {
    public let index: Int
    public let name: String?
    public let bounds: CGRect
    public let scaleFactor: CGFloat

    public init(index: Int, name: String?, bounds: CGRect, scaleFactor: CGFloat) {
        self.index = index
        self.name = name
        self.bounds = bounds
        self.scaleFactor = scaleFactor
    }
}
