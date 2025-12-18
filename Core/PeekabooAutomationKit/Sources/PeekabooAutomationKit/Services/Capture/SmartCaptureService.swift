//
//  SmartCaptureService.swift
//  PeekabooAutomation
//
//  Enhancement #3: Smart Screenshot Strategy
//  Provides diff-aware and region-focused screenshot capture.
//

import AppKit
import CoreGraphics
import Foundation
import os.log

/// Service that provides intelligent screenshot capture with:
/// - Diff-aware capture: Skip if screen unchanged
/// - Region-focused capture: Capture area around action target
/// - Change detection: Identify what changed between captures
@available(macOS 14.0, *)
@MainActor
public final class SmartCaptureService {
    private let captureService: any ScreenCaptureServiceProtocol
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "SmartCapture")

    /// Last captured state for diff comparison.
    private var lastCaptureState: CaptureState?

    /// Time after which we force a new capture regardless of diff.
    private let forceRefreshInterval: TimeInterval = 5.0

    public init(captureService: any ScreenCaptureServiceProtocol) {
        self.captureService = captureService
    }

    // MARK: - Diff-Aware Capture

    /// Capture the screen only if it has changed significantly since the last capture.
    /// Returns nil image if screen is unchanged.
    public func captureIfChanged(
        threshold: Float = 0.05) async throws -> SmartCaptureResult
    {
        let now = Date()

        // Force capture if too much time has passed
        if let lastState = lastCaptureState,
           now.timeIntervalSince(lastState.timestamp) > forceRefreshInterval
        {
            self.logger.debug("Force refresh: \(self.forceRefreshInterval)s elapsed since last capture")
            return try await self.captureAndUpdateState()
        }

        // Quick check: has focused app changed?
        let currentApp = NSWorkspace.shared.frontmostApplication?.localizedName
        if currentApp != self.lastCaptureState?.focusedApp {
            self.logger
                .debug("App changed from \(self.lastCaptureState?.focusedApp ?? "nil") to \(currentApp ?? "nil")")
            return try await self.captureAndUpdateState()
        }

        // Capture current frame
        let captureResult = try await captureService.captureScreen(displayIndex: nil)
        guard let currentImage = cgImage(from: captureResult) else {
            throw SmartCaptureError.imageConversionFailed
        }

        // Compare with last capture using perceptual hash
        if let lastHash = lastCaptureState?.hash {
            let currentHash = self.perceptualHash(currentImage)
            let distance = self.hammingDistance(lastHash, currentHash)
            let similarity = 1.0 - (Float(distance) / 64.0)

            if similarity > (1.0 - threshold) {
                // Screen unchanged
                self.logger.debug("Screen unchanged (similarity: \(similarity), threshold: \(1.0 - threshold))")
                return SmartCaptureResult(
                    image: nil,
                    changed: false,
                    metadata: .unchanged(since: self.lastCaptureState!.timestamp))
            }
        }

        // Screen changed - update state and return
        return try await self.captureAndUpdateState(image: currentImage)
    }

    // MARK: - Region-Focused Capture

    /// Capture a region around a specific point, useful after actions.
    public func captureAroundPoint(
        _ center: CGPoint,
        radius: CGFloat = 300,
        includeContextThumbnail: Bool = true) async throws -> SmartCaptureResult
    {
        // Calculate capture rect
        var rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2)

        // Clamp to screen bounds
        if let screenBounds = NSScreen.main?.frame {
            rect = rect.intersection(screenBounds)
        }

        // Capture the region
        let regionResult = try await captureService.captureArea(rect)
        guard let regionImage = cgImage(from: regionResult) else {
            throw SmartCaptureError.imageConversionFailed
        }

        // Optionally capture a thumbnail of full screen for context
        var contextThumbnail: CGImage?
        if includeContextThumbnail {
            let fullScreenResult = try await captureService.captureScreen(displayIndex: nil)
            if let fullScreen = cgImage(from: fullScreenResult) {
                contextThumbnail = self.resizeImage(fullScreen, to: CGSize(width: 400, height: 250))
            }
        }

        return SmartCaptureResult(
            image: regionImage,
            changed: true,
            metadata: .region(
                center: center,
                radius: radius,
                bounds: rect,
                contextThumbnail: contextThumbnail))
    }

    /// Capture around an action target, inferring appropriate radius.
    public func captureAfterAction(
        toolName: String,
        targetPoint: CGPoint?) async throws -> SmartCaptureResult
    {
        guard let point = targetPoint else {
            // No specific target - use diff-aware full capture
            return try await self.captureIfChanged()
        }

        // Determine appropriate radius based on action type
        let radius: CGFloat = switch toolName {
        case "click":
            200 // Buttons, menus - smaller area
        case "type":
            300 // Text fields, forms - medium area
        case "scroll":
            400 // Scrolling affects larger content area
        case "drag":
            350 // Drag might affect broader area
        default:
            250 // Default medium radius
        }

        return try await self.captureAroundPoint(point, radius: radius)
    }

    // MARK: - State Management

    /// Clear cached state, forcing next capture to be fresh.
    public func invalidateCache() {
        self.lastCaptureState = nil
    }

    // MARK: - Private Helpers

    private func captureAndUpdateState(image: CGImage? = nil) async throws -> SmartCaptureResult {
        let capturedImage: CGImage
        if let existingImage = image {
            capturedImage = existingImage
        } else {
            let result = try await captureService.captureScreen(displayIndex: nil)
            guard let img = cgImage(from: result) else {
                throw SmartCaptureError.imageConversionFailed
            }
            capturedImage = img
        }

        let hash = self.perceptualHash(capturedImage)
        let focusedApp = NSWorkspace.shared.frontmostApplication?.localizedName

        self.lastCaptureState = CaptureState(
            hash: hash,
            timestamp: Date(),
            focusedApp: focusedApp)

        return SmartCaptureResult(
            image: capturedImage,
            changed: true,
            metadata: .fresh(capturedAt: Date()))
    }

    /// Convert CaptureResult image data to CGImage.
    private func cgImage(from result: CaptureResult) -> CGImage? {
        guard let dataProvider = CGDataProvider(data: result.imageData as CFData),
              let cgImage = CGImage(
                  pngDataProviderSource: dataProvider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent)
        else {
            return nil
        }
        return cgImage
    }

    /// Compute a perceptual hash (dHash) of an image.
    /// Returns a 64-bit hash representing visual content.
    private func perceptualHash(_ image: CGImage) -> UInt64 {
        // Resize to 9x8 for difference hash
        guard let resized = resizeImage(image, to: CGSize(width: 9, height: 8)) else {
            return 0
        }

        // Get grayscale pixel values
        guard let pixels = getGrayscalePixels(resized) else {
            return 0
        }

        // Compute difference hash
        var hash: UInt64 = 0
        for row in 0..<8 {
            for col in 0..<8 {
                let left = pixels[row * 9 + col]
                let right = pixels[row * 9 + col + 1]
                if left > right {
                    hash |= (1 << UInt64(row * 8 + col))
                }
            }
        }
        return hash
    }

    /// Compute Hamming distance between two hashes.
    private func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }

    /// Resize an image to target size.
    private func resizeImage(_ image: CGImage, to size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// Extract grayscale pixel values from an image.
    private func getGrayscalePixels(_ image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else {
            return nil
        }

        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var grayscale: [UInt8] = []

        for i in 0..<(width * height) {
            let r = Float(pixels[i * 4])
            let g = Float(pixels[i * 4 + 1])
            let b = Float(pixels[i * 4 + 2])
            // Standard luminance conversion
            let gray = UInt8(0.299 * r + 0.587 * g + 0.114 * b)
            grayscale.append(gray)
        }

        return grayscale
    }
}

// MARK: - Supporting Types

/// Internal state for diff tracking.
private struct CaptureState {
    let hash: UInt64
    let timestamp: Date
    let focusedApp: String?
}

/// Result of a smart capture operation.
public struct SmartCaptureResult: Sendable {
    /// The captured image, or nil if screen was unchanged.
    public let image: CGImage?

    /// Whether the screen changed since last capture.
    public let changed: Bool

    /// Metadata about the capture.
    public let metadata: SmartCaptureMetadata

    public init(image: CGImage?, changed: Bool, metadata: SmartCaptureMetadata) {
        self.image = image
        self.changed = changed
        self.metadata = metadata
    }
}

/// Metadata about a smart capture.
public enum SmartCaptureMetadata: Sendable {
    /// Fresh capture at given time.
    case fresh(capturedAt: Date)

    /// Screen unchanged since given time.
    case unchanged(since: Date)

    /// Region capture around a point.
    case region(center: CGPoint, radius: CGFloat, bounds: CGRect, contextThumbnail: CGImage?)

    /// Capture with detected change areas.
    case changed(areas: [ChangeArea])
}

/// An area of the screen that changed.
public struct ChangeArea: Sendable {
    public let rect: CGRect
    public let changeType: ChangeType
    public let confidence: Float

    public init(rect: CGRect, changeType: ChangeType, confidence: Float) {
        self.rect = rect
        self.changeType = changeType
        self.confidence = confidence
    }
}

/// Type of change detected in a region.
public enum ChangeType: Sendable {
    case contentAdded
    case contentRemoved
    case contentModified
    case windowMoved
    case dialogAppeared
}

/// Errors that can occur during smart capture operations.
public enum SmartCaptureError: Error, LocalizedError {
    case imageConversionFailed

    public var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            "Failed to convert capture result to CGImage"
        }
    }
}
