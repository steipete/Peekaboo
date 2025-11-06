//
//  PixelAnalyzer.swift
//  PeekabooCore
//

import AppKit
import Foundation

/// Analyzes pixel regions to find uniform (boring) areas for optimal label placement
struct PixelAnalyzer {
    private let image: NSImage
    private let bitmapRep: NSBitmapImageRep?
    private let textDetector: AcceleratedTextDetector

    init?(image: NSImage) {
        self.image = image
        self.textDetector = AcceleratedTextDetector()

        // Get bitmap representation for fallback pixel access
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData) {
            self.bitmapRep = bitmap
        } else {
            self.bitmapRep = nil
        }
    }

    /// Scores a region based on absence of text/edges (higher score = better for labels)
    func scoreRegion(_ rect: NSRect) -> Float {
        // Clamp rect to image bounds
        let imageRect = NSRect(origin: .zero, size: image.size)
        let clampedRect = rect.intersection(imageRect)

        // If rect is outside image, return low score
        guard !clampedRect.isEmpty else { return 0 }

        // Use Accelerated Sobel edge detection to find text
        return self.textDetector.scoreRegionForLabelPlacement(clampedRect, in: self.image)
    }

    /// Scores a region using simple variance (fallback method)
    func scoreRegionSimple(_ rect: NSRect) -> Float {
        // Scores a region using simple variance (fallback method)
        guard self.bitmapRep != nil else { return 0 }

        // Clamp rect to image bounds
        let imageRect = NSRect(origin: .zero, size: image.size)
        let clampedRect = rect.intersection(imageRect)

        // If rect is outside image, return low score
        guard !clampedRect.isEmpty else { return 0 }

        // Sample pixels in a 7x7 grid for better coverage
        let samples = self.samplePixels(in: clampedRect, gridSize: 7)

        // Calculate contrast instead of variance
        let contrast = self.calculateContrast(samples)

        // Convert to score: lower contrast = higher score (more uniform)
        // Add small epsilon to avoid division by zero
        return 1.0 / (contrast + 0.001)
    }

    /// Finds the best position from candidates based on background uniformity
    func findBestPosition(from candidates: [NSRect]) -> (rect: NSRect, score: Float)? {
        // Finds the best position from candidates based on background uniformity
        var bestPosition: (rect: NSRect, score: Float)?

        for candidate in candidates {
            let score = self.scoreRegion(candidate)

            if bestPosition == nil || score > bestPosition!.score {
                bestPosition = (rect: candidate, score: score)
            }
        }

        return bestPosition
    }

    // MARK: - Private Methods

    private func samplePixels(in rect: NSRect, gridSize: Int) -> [NSColor] {
        var colors: [NSColor] = []

        let stepX = rect.width / CGFloat(gridSize - 1)
        let stepY = rect.height / CGFloat(gridSize - 1)

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let x = rect.minX + CGFloat(col) * stepX
                let y = rect.minY + CGFloat(row) * stepY

                if let color = getPixelColor(at: CGPoint(x: x, y: y)) {
                    colors.append(color)
                }
            }
        }

        return colors
    }

    private func getPixelColor(at point: CGPoint) -> NSColor? {
        guard let bitmap = bitmapRep else { return nil }

        // Convert to bitmap coordinates (flip Y if needed)
        let x = Int(point.x)
        let y = Int(image.size.height - point.y - 1) // Flip Y coordinate

        // Check bounds
        guard x >= 0, x < bitmap.pixelsWide,
              y >= 0, y < bitmap.pixelsHigh else {
            return nil
        }

        return bitmap.colorAt(x: x, y: y)
    }

    private func calculateBrightnessVariance(_ colors: [NSColor]) -> Float {
        guard !colors.isEmpty else { return 0 }

        // Calculate brightness for each color
        let brightnesses = colors.map { color -> Float in
            // Convert to RGB color space if needed
            guard let rgbColor = color.usingColorSpace(.deviceRGB) else {
                return 0.5 // Default middle brightness
            }

            // Calculate luminance using standard formula
            return Float(rgbColor.redComponent) * 0.299 +
                Float(rgbColor.greenComponent) * 0.587 +
                Float(rgbColor.blueComponent) * 0.114
        }

        // Calculate mean brightness
        let mean = brightnesses.reduce(0, +) / Float(brightnesses.count)

        // Calculate variance
        let squaredDiffs = brightnesses.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Float(brightnesses.count)

        return variance
    }

    private func calculateContrast(_ colors: [NSColor]) -> Float {
        guard !colors.isEmpty else { return 0 }

        // Calculate brightness for each color
        let brightnesses = colors.map { color -> Float in
            guard let rgbColor = color.usingColorSpace(.deviceRGB) else {
                return 0.5
            }

            return Float(rgbColor.redComponent) * 0.299 +
                Float(rgbColor.greenComponent) * 0.587 +
                Float(rgbColor.blueComponent) * 0.114
        }

        // Calculate contrast as difference between min and max brightness
        let minBrightness = brightnesses.min() ?? 0
        let maxBrightness = brightnesses.max() ?? 0

        return maxBrightness - minBrightness
    }
}

// Extension for checking if a region has high contrast (text, edges)
extension PixelAnalyzer {
    /// Quick check if region likely contains text or edges
    func hasHighContrast(in rect: NSRect) -> Bool {
        // Sample just 5 pixels in a cross pattern
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = [
            center,
            CGPoint(x: rect.minX + rect.width * 0.25, y: rect.midY),
            CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.midY),
            CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.25),
            CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.25)
        ]

        let colors = points.compactMap { self.getPixelColor(at: $0) }
        guard colors.count >= 2 else { return false }

        // Check if colors vary significantly
        let brightnesses = colors.map { color -> Float in
            guard let rgbColor = color.usingColorSpace(.deviceRGB) else { return 0.5 }
            return Float(rgbColor.redComponent) * 0.299 +
                Float(rgbColor.greenComponent) * 0.587 +
                Float(rgbColor.blueComponent) * 0.114
        }

        let minBrightness = brightnesses.min() ?? 0
        let maxBrightness = brightnesses.max() ?? 0

        // If brightness range > 0.3, we likely have text or edges
        return (maxBrightness - minBrightness) > 0.3
    }
}
