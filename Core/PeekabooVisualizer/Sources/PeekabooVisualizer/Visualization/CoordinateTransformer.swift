//
import PeekabooFoundation

//  CoordinateTransformer.swift
//  PeekabooCore
//
//  Coordinate system transformations for element visualization
//

import CoreGraphics
import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Handles coordinate transformations between different spaces
@MainActor
public final class CoordinateTransformer {
    public init() {}

    // MARK: - Main Transformation Method

    /// Transform bounds from one coordinate space to another
    /// - Parameters:
    ///   - bounds: The bounds to transform
    ///   - from: Source coordinate space
    ///   - to: Target coordinate space
    /// - Returns: Transformed bounds
    public func transform(
        _ bounds: CGRect,
        from sourceSpace: CoordinateSpace,
        to targetSpace: CoordinateSpace) -> CGRect
    {
        // First convert to normalized space
        let normalized = self.normalize(bounds, from: sourceSpace)

        // Then convert from normalized to target
        return self.denormalize(normalized, to: targetSpace)
    }

    /// Transform a point from one coordinate space to another
    public func transform(
        _ point: CGPoint,
        from sourceSpace: CoordinateSpace,
        to targetSpace: CoordinateSpace) -> CGPoint
    {
        // Transform a point from one coordinate space to another
        let bounds = CGRect(origin: point, size: .zero)
        let transformed = self.transform(bounds, from: sourceSpace, to: targetSpace)
        return transformed.origin
    }

    // MARK: - Normalization

    /// Convert bounds to normalized coordinates (0.0 - 1.0)
    private func normalize(_ bounds: CGRect, from space: CoordinateSpace) -> CGRect {
        // Convert bounds to normalized coordinates (0.0 - 1.0)
        switch space {
        case .screen:
            // Assume primary screen for normalization
            #if canImport(AppKit)
            guard let screen = NSScreen.main else { return bounds }
            return CGRect(
                x: bounds.origin.x / screen.frame.width,
                y: bounds.origin.y / screen.frame.height,
                width: bounds.width / screen.frame.width,
                height: bounds.height / screen.frame.height)
            #else
            // Use default screen size when AppKit is not available
            let screenSize = CGSize(width: 1920, height: 1080)
            return CGRect(
                x: bounds.origin.x / screenSize.width,
                y: bounds.origin.y / screenSize.height,
                width: bounds.width / screenSize.width,
                height: bounds.height / screenSize.height)
            #endif

        case let .window(windowBounds):
            return CGRect(
                x: (bounds.origin.x - windowBounds.origin.x) / windowBounds.width,
                y: (bounds.origin.y - windowBounds.origin.y) / windowBounds.height,
                width: bounds.width / windowBounds.width,
                height: bounds.height / windowBounds.height)

        case let .view(containerSize):
            return CGRect(
                x: bounds.origin.x / containerSize.width,
                y: bounds.origin.y / containerSize.height,
                width: bounds.width / containerSize.width,
                height: bounds.height / containerSize.height)

        case .normalized:
            return bounds // Already normalized

        case .normalized1000:
            // Convert from 0-1000 range to 0.0-1.0 range
            // GLM-4V models return coordinates in 0-1000 range
            // Note: imageSize not needed for this conversion (divide by 1000 is sufficient)
            return CGRect(
                x: bounds.origin.x / 1000.0,
                y: bounds.origin.y / 1000.0,
                width: bounds.width / 1000.0,
                height: bounds.height / 1000.0)
        }
    }

    /// Convert from normalized coordinates to target space
    private func denormalize(_ bounds: CGRect, to space: CoordinateSpace) -> CGRect {
        // Convert from normalized coordinates to target space
        switch space {
        case .screen:
            #if canImport(AppKit)
            guard let screen = NSScreen.main else { return bounds }
            return CGRect(
                x: bounds.origin.x * screen.frame.width,
                y: bounds.origin.y * screen.frame.height,
                width: bounds.width * screen.frame.width,
                height: bounds.height * screen.frame.height)
            #else
            // Use default screen size when AppKit is not available
            let screenSize = CGSize(width: 1920, height: 1080)
            return CGRect(
                x: bounds.origin.x * screenSize.width,
                y: bounds.origin.y * screenSize.height,
                width: bounds.width * screenSize.width,
                height: bounds.height * screenSize.height)
            #endif

        case let .window(windowBounds):
            return CGRect(
                x: bounds.origin.x * windowBounds.width + windowBounds.origin.x,
                y: bounds.origin.y * windowBounds.height + windowBounds.origin.y,
                width: bounds.width * windowBounds.width,
                height: bounds.height * windowBounds.height)

        case let .view(containerSize):
            return CGRect(
                x: bounds.origin.x * containerSize.width,
                y: bounds.origin.y * containerSize.height,
                width: bounds.width * containerSize.width,
                height: bounds.height * containerSize.height)

        case .normalized:
            return bounds // Already normalized

        case .normalized1000:
            // Convert from 0.0-1.0 to 0-1000 range (reverse of normalize)
            // Note: imageSize not needed for this conversion (multiply by 1000 is sufficient)
            return CGRect(
                x: bounds.origin.x * 1000.0,
                y: bounds.origin.y * 1000.0,
                width: bounds.width * 1000.0,
                height: bounds.height * 1000.0)
        }
    }

    // MARK: - Coordinate System Conversions

    /// Convert from Accessibility API coordinates to screen coordinates
    /// AX uses top-left origin, screen coordinates may vary by platform
    public func fromAccessibilityToScreen(_ bounds: CGRect) -> CGRect {
        // On macOS, accessibility coordinates are already in screen space with top-left origin
        bounds
    }

    /// Convert from screen coordinates to SwiftUI view coordinates
    /// - Parameters:
    ///   - bounds: Bounds in screen coordinates
    ///   - viewSize: Size of the SwiftUI view
    ///   - flipY: Whether to flip Y axis (SwiftUI vs AppKit)
    public func fromScreenToView(
        _ bounds: CGRect,
        viewSize: CGSize,
        flipY: Bool = false) -> CGRect
    {
        // Convert from screen coordinates to SwiftUI view coordinates
        #if canImport(AppKit)
        guard let screen = NSScreen.main else { return bounds }
        let screenSize = screen.frame.size
        #else
        let screenSize = CGSize(width: 1920, height: 1080)
        #endif

        // First normalize to view space
        let normalized = CGRect(
            x: bounds.origin.x / screenSize.width * viewSize.width,
            y: bounds.origin.y / screenSize.height * viewSize.height,
            width: bounds.width / screenSize.width * viewSize.width,
            height: bounds.height / screenSize.height * viewSize.height)

        if flipY {
            // Flip Y coordinate for bottom-origin systems
            return CGRect(
                x: normalized.origin.x,
                y: viewSize.height - normalized.origin.y - normalized.height,
                width: normalized.width,
                height: normalized.height)
        }

        return normalized
    }

    /// Convert window-relative coordinates to screen coordinates
    public func fromWindowToScreen(_ bounds: CGRect, windowFrame: CGRect) -> CGRect {
        // Convert window-relative coordinates to screen coordinates
        CGRect(
            x: bounds.origin.x + windowFrame.origin.x,
            y: bounds.origin.y + windowFrame.origin.y,
            width: bounds.width,
            height: bounds.height)
    }

    /// Convert screen coordinates to window-relative coordinates
    public func fromScreenToWindow(_ bounds: CGRect, windowFrame: CGRect) -> CGRect {
        // Convert screen coordinates to window-relative coordinates
        CGRect(
            x: bounds.origin.x - windowFrame.origin.x,
            y: bounds.origin.y - windowFrame.origin.y,
            width: bounds.width,
            height: bounds.height)
    }

    // MARK: - AI Model Coordinate Conversions

    /// Convert normalized coordinates (0-1000 range) to pixel coordinates.
    /// Used for AI models like GLM-4V series that return bounding boxes
    /// in normalized format instead of pixel coordinates.
    ///
    /// According to GLM-4V documentation:
    /// "The output bounding box is a quadruple [x1, y1, x2, y2] composed of
    /// the coordinates of the top-left and bottom-right corners, where each
    /// value is normalized by the image width (for x) or height (for y)
    /// and scaled by 1000."
    ///
    /// - Parameters:
    ///   - bounds: Bounding box in normalized 0-1000 coordinates
    ///   - imageSize: The size of the image/screen in pixels
    /// - Returns: Bounding box in pixel coordinates
    public func fromNormalized1000ToPixels(_ bounds: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: bounds.origin.x / 1000.0 * imageSize.width,
            y: bounds.origin.y / 1000.0 * imageSize.height,
            width: bounds.width / 1000.0 * imageSize.width,
            height: bounds.height / 1000.0 * imageSize.height)
    }

    /// Convert a bounding box array [x1, y1, x2, y2] from normalized (0-1000) to pixel coordinates.
    /// - Parameters:
    ///   - box: Array of 4 values [x1, y1, x2, y2] in normalized 0-1000 format
    ///   - imageSize: The size of the image/screen in pixels
    /// - Returns: Array of 4 values [x1, y1, x2, y2] in pixel coordinates
    public func convertBoundingBox(from box: [Int], imageSize: CGSize) -> [Int] {
        guard box.count == 4 else { return box }
        return [
            Int(Double(box[0]) / 1000.0 * imageSize.width),
            Int(Double(box[1]) / 1000.0 * imageSize.height),
            Int(Double(box[2]) / 1000.0 * imageSize.width),
            Int(Double(box[3]) / 1000.0 * imageSize.height)
        ]
    }

    /// Calculate center point from a bounding box [x1, y1, x2, y2]
    /// - Parameter box: Array of 4 values [x1, y1, x2, y2]
    /// - Returns: Center point (x, y)
    public func centerPoint(from box: [Int]) -> CGPoint? {
        guard box.count == 4 else { return nil }
        return CGPoint(
            x: CGFloat(box[0] + box[2]) / 2.0,
            y: CGFloat(box[1] + box[3]) / 2.0)
    }

    /// Check if a model name indicates it uses normalized coordinates (0-1000).
    /// Currently detects GLM-4V series models.
    /// - Parameter modelName: The model name to check
    /// - Returns: true if the model uses normalized coordinates
    public static func usesNormalizedCoordinates(modelName: String) -> Bool {
        let lowercased = modelName.lowercased()
        // GLM-4V series models use normalized 0-1000 coordinates
        return lowercased.contains("glm") && (
            lowercased.contains("4v") ||
            lowercased.contains("4.5v") ||
            lowercased.contains("4.6v") ||
            lowercased.contains("4.1v"))
    }

    // MARK: - Utility Methods

    /// Scale bounds by a factor
    public func scale(_ bounds: CGRect, by factor: CGFloat) -> CGRect {
        // Scale bounds by a factor
        CGRect(
            x: bounds.origin.x * factor,
            y: bounds.origin.y * factor,
            width: bounds.width * factor,
            height: bounds.height * factor)
    }

    /// Scale bounds with different X and Y factors
    public func scale(_ bounds: CGRect, xFactor: CGFloat, yFactor: CGFloat) -> CGRect {
        // Scale bounds with different X and Y factors
        CGRect(
            x: bounds.origin.x * xFactor,
            y: bounds.origin.y * yFactor,
            width: bounds.width * xFactor,
            height: bounds.height * yFactor)
    }

    /// Offset bounds by a delta
    public func offset(_ bounds: CGRect, by delta: CGPoint) -> CGRect {
        // Offset bounds by a delta
        CGRect(
            x: bounds.origin.x + delta.x,
            y: bounds.origin.y + delta.y,
            width: bounds.width,
            height: bounds.height)
    }

    /// Clamp bounds within container
    public func clamp(_ bounds: CGRect, to container: CGRect) -> CGRect {
        // Clamp bounds within container
        let x = max(container.minX, min(bounds.origin.x, container.maxX - bounds.width))
        let y = max(container.minY, min(bounds.origin.y, container.maxY - bounds.height))

        let width = min(bounds.width, container.width)
        let height = min(bounds.height, container.height)

        return CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Screen Utilities

extension CoordinateTransformer {
    #if canImport(AppKit)
    /// Get the bounds of the primary screen
    public var primaryScreenBounds: CGRect {
        NSScreen.main?.frame ?? .zero
    }

    /// Get the bounds of all screens combined
    public var combinedScreenBounds: CGRect {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return .zero }

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for screen in screens {
            minX = min(minX, screen.frame.minX)
            minY = min(minY, screen.frame.minY)
            maxX = max(maxX, screen.frame.maxX)
            maxY = max(maxY, screen.frame.maxY)
        }

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY)
    }

    /// Find which screen contains a point
    public func screen(containing point: CGPoint) -> NSScreen? {
        // Find which screen contains a point
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    /// Find which screen contains the majority of a rect
    public func screen(containing bounds: CGRect) -> NSScreen? {
        // Find which screen contains the majority of a rect
        var bestScreen: NSScreen?
        var bestArea: CGFloat = 0

        for screen in NSScreen.screens {
            let intersection = bounds.intersection(screen.frame)
            let area = intersection.width * intersection.height

            if area > bestArea {
                bestArea = area
                bestScreen = screen
            }
        }

        return bestScreen
    }
    #else
    /// Get the bounds of the primary screen
    public var primaryScreenBounds: CGRect {
        // Return a default screen size when AppKit is not available
        CGRect(x: 0, y: 0, width: 1920, height: 1080)
    }

    /// Get the bounds of all screens combined
    public var combinedScreenBounds: CGRect {
        // Return a default screen size when AppKit is not available
        CGRect(x: 0, y: 0, width: 1920, height: 1080)
    }
    #endif
}
