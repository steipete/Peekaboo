//
//  AcceleratedTextDetector.swift
//  PeekabooCore
//

import Accelerate
import AppKit
import CoreGraphics
import Foundation

/// High-performance text detection using Accelerate framework's vImage convolution
final class AcceleratedTextDetector {
    // MARK: - Types

    struct EdgeDensityResult {
        let density: Float // 0.0 = no edges, 1.0 = all edges
        let hasText: Bool // Quick decision based on threshold
    }

    // MARK: - Properties

    // Sobel kernels as Int16 for vImage convolution
    private let sobelXKernel: [Int16] = [
        -1, 0, 1,
        -2, 0, 2,
        -1, 0, 1
    ]

    private let sobelYKernel: [Int16] = [
        -1, -2, -1,
        0, 0, 0,
        1, 2, 1
    ]

    // Pre-allocated buffers for performance
    private var sourceBuffer: vImage_Buffer = .init()
    private var gradientXBuffer: vImage_Buffer = .init()
    private var gradientYBuffer: vImage_Buffer = .init()
    private var magnitudeBuffer: vImage_Buffer = .init()

    // Buffer dimensions
    private let maxBufferWidth: Int = 200
    private let maxBufferHeight: Int = 100

    // Edge detection threshold (0-255 scale)
    private let edgeThreshold: UInt8 = 30

    // MARK: - Initialization

    init() {
        self.allocateBuffers()
    }

    deinit {
        deallocateBuffers()
    }

    // MARK: - Public Methods

    /// Analyzes a region for text presence using Sobel edge detection
    func analyzeRegion(_ rect: NSRect, in image: NSImage) -> EdgeDensityResult {
        // Quick contrast check first
        if let quickResult = performQuickCheck(rect, in: image) {
            return quickResult
        }

        // Extract region as grayscale buffer
        guard let buffer = extractRegionAsBuffer(rect, from: image) else {
            return EdgeDensityResult(density: 0, hasText: false)
        }

        // Apply Sobel operators
        let (gradX, gradY) = self.applySobelOperators(to: buffer)

        // Calculate gradient magnitude
        let magnitude = self.calculateGradientMagnitude(gradX: gradX, gradY: gradY)

        // Calculate edge density
        let density = self.calculateEdgeDensity(magnitude: magnitude)

        // Free temporary buffer
        free(buffer.data)

        // Determine if region has text (high edge density)
        // Lower threshold to be more sensitive to text
        let hasText = density > 0.03 // 3% of pixels are edges = likely text (lowered from 8%)

        return EdgeDensityResult(density: density, hasText: hasText)
    }

    /// Scores a region for label placement (higher = better)
    func scoreRegionForLabelPlacement(_ rect: NSRect, in image: NSImage) -> Float {
        let result = self.analyzeRegion(rect, in: image)

        // Log edge detection results when verbose mode is enabled
        Logger.shared.verbose("Edge detection for region", category: "LabelPlacement", metadata: [
            "rect": "\(rect)",
            "density": result.density,
            "hasText": result.hasText
        ])

        // More aggressive scoring to avoid text
        // Areas with ANY significant edges should score very low
        if result.hasText || result.density > 0.05 { // Lower threshold from 0.1 to 0.05
            return 0.0 // Definitely avoid
        } else if result.density < 0.01 { // Lower threshold from 0.02 to 0.01
            return 1.0 // Perfect - almost no edges
        } else {
            // Exponential decay for intermediate values
            return exp(-result.density * 100.0) // Increase penalty from 50 to 100
        }
    }

    // MARK: - Private Methods

    private func allocateBuffers() {
        let bytesPerPixel = 1 // Grayscale
        let bufferSize = self.maxBufferWidth * self.maxBufferHeight * bytesPerPixel

        // Allocate source buffer
        self.sourceBuffer.data = malloc(bufferSize)
        self.sourceBuffer.width = vImagePixelCount(self.maxBufferWidth)
        self.sourceBuffer.height = vImagePixelCount(self.maxBufferHeight)
        self.sourceBuffer.rowBytes = self.maxBufferWidth * bytesPerPixel

        // Allocate gradient buffers
        self.gradientXBuffer.data = malloc(bufferSize)
        self.gradientXBuffer.width = vImagePixelCount(self.maxBufferWidth)
        self.gradientXBuffer.height = vImagePixelCount(self.maxBufferHeight)
        self.gradientXBuffer.rowBytes = self.maxBufferWidth * bytesPerPixel

        self.gradientYBuffer.data = malloc(bufferSize)
        self.gradientYBuffer.width = vImagePixelCount(self.maxBufferWidth)
        self.gradientYBuffer.height = vImagePixelCount(self.maxBufferHeight)
        self.gradientYBuffer.rowBytes = self.maxBufferWidth * bytesPerPixel

        // Allocate magnitude buffer
        self.magnitudeBuffer.data = malloc(bufferSize)
        self.magnitudeBuffer.width = vImagePixelCount(self.maxBufferWidth)
        self.magnitudeBuffer.height = vImagePixelCount(self.maxBufferHeight)
        self.magnitudeBuffer.rowBytes = self.maxBufferWidth * bytesPerPixel
    }

    private func deallocateBuffers() {
        free(self.sourceBuffer.data)
        free(self.gradientXBuffer.data)
        free(self.gradientYBuffer.data)
        free(self.magnitudeBuffer.data)
    }

    private func performQuickCheck(_ rect: NSRect, in image: NSImage) -> EdgeDensityResult? {
        // Sample 5 points: corners + center
        let points = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.midX, y: rect.midY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]

        guard let bitmap = getBitmapRep(from: image) else { return nil }

        var brightnesses: [Float] = []
        for point in points {
            if let color = getPixelColor(at: point, from: bitmap) {
                brightnesses.append(self.calculateBrightness(color))
            }
        }

        guard !brightnesses.isEmpty else { return nil }

        let minBrightness = brightnesses.min() ?? 0
        let maxBrightness = brightnesses.max() ?? 0
        let contrast = maxBrightness - minBrightness

        // Very low contrast = definitely no text
        if contrast < 0.1 {
            return EdgeDensityResult(density: 0.0, hasText: false)
        }

        // Very high contrast = definitely has text
        if contrast > 0.6 {
            return EdgeDensityResult(density: 1.0, hasText: true)
        }

        // Intermediate contrast = need full analysis
        return nil
    }

    private func extractRegionAsBuffer(_ rect: NSRect, from image: NSImage) -> vImage_Buffer? {
        guard let bitmap = getBitmapRep(from: image) else { return nil }

        // Calculate actual region to extract (clamp to image bounds)
        let imageRect = NSRect(origin: .zero, size: image.size)
        let clampedRect = rect.intersection(imageRect)

        guard !clampedRect.isEmpty else { return nil }

        // Determine if we need to downsample
        let shouldDownsample = clampedRect.width > CGFloat(self.maxBufferWidth) ||
            clampedRect.height > CGFloat(self.maxBufferHeight)

        let targetWidth = shouldDownsample ? self.maxBufferWidth : Int(clampedRect.width)
        let targetHeight = shouldDownsample ? self.maxBufferHeight : Int(clampedRect.height)

        // Allocate buffer for this specific region
        let bufferSize = targetWidth * targetHeight
        guard let bufferData = malloc(bufferSize) else { return nil }

        var buffer = vImage_Buffer()
        buffer.data = bufferData
        buffer.width = vImagePixelCount(targetWidth)
        buffer.height = vImagePixelCount(targetHeight)
        buffer.rowBytes = targetWidth

        // Fill buffer with grayscale pixel data
        let pixelData = bufferData.assumingMemoryBound(to: UInt8.self)

        for y in 0..<targetHeight {
            for x in 0..<targetWidth {
                // Map to source coordinates
                let sourceX = Int(clampedRect.minX) + (x * Int(clampedRect.width)) / targetWidth
                let sourceY = Int(clampedRect.minY) + (y * Int(clampedRect.height)) / targetHeight

                // Get pixel color and convert to grayscale
                if let color = bitmap.colorAt(x: sourceX, y: Int(image.size.height) - sourceY - 1) {
                    let brightness = self.calculateBrightness(color)
                    pixelData[y * targetWidth + x] = UInt8(brightness * 255)
                } else {
                    pixelData[y * targetWidth + x] = 128 // Default gray
                }
            }
        }

        return buffer
    }

    private func applySobelOperators(to buffer: vImage_Buffer) -> (gradX: vImage_Buffer, gradY: vImage_Buffer) {
        // Create properly sized output buffers
        var gradX = vImage_Buffer()
        gradX.data = malloc(Int(buffer.width * buffer.height))
        gradX.width = buffer.width
        gradX.height = buffer.height
        gradX.rowBytes = Int(buffer.width)

        var gradY = vImage_Buffer()
        gradY.data = malloc(Int(buffer.width * buffer.height))
        gradY.width = buffer.width
        gradY.height = buffer.height
        gradY.rowBytes = Int(buffer.width)

        // Apply Sobel X kernel
        var sourceBuffer = buffer
        vImageConvolve_Planar8(
            &sourceBuffer,
            &gradX,
            nil,
            0, 0,
            self.sobelXKernel,
            3, 3,
            1, // Divisor
            128, // Bias (to keep values positive)
            vImage_Flags(kvImageEdgeExtend)
        )

        // Apply Sobel Y kernel
        vImageConvolve_Planar8(
            &sourceBuffer,
            &gradY,
            nil,
            0, 0,
            self.sobelYKernel,
            3, 3,
            1, // Divisor
            128, // Bias (to keep values positive)
            vImage_Flags(kvImageEdgeExtend)
        )

        return (gradX, gradY)
    }

    private func calculateGradientMagnitude(gradX: vImage_Buffer, gradY: vImage_Buffer) -> vImage_Buffer {
        // Create magnitude buffer
        var magnitude = vImage_Buffer()
        magnitude.data = malloc(Int(gradX.width * gradX.height))
        magnitude.width = gradX.width
        magnitude.height = gradX.height
        magnitude.rowBytes = Int(gradX.width)

        // Calculate magnitude for each pixel
        // Using Manhattan distance for speed: |gradX| + |gradY|
        let gradXData = gradX.data.assumingMemoryBound(to: UInt8.self)
        let gradYData = gradY.data.assumingMemoryBound(to: UInt8.self)
        let magnitudeData = magnitude.data.assumingMemoryBound(to: UInt8.self)

        let pixelCount = Int(gradX.width * gradX.height)

        for i in 0..<pixelCount {
            // Remove bias and get absolute values
            let gx = abs(Int(gradXData[i]) - 128)
            let gy = abs(Int(gradYData[i]) - 128)

            // Manhattan distance approximation
            let mag = min(gx + gy, 255)
            magnitudeData[i] = UInt8(mag)
        }

        // Free gradient buffers
        free(gradX.data)
        free(gradY.data)

        return magnitude
    }

    private func calculateEdgeDensity(magnitude: vImage_Buffer) -> Float {
        let magnitudeData = magnitude.data.assumingMemoryBound(to: UInt8.self)
        let pixelCount = Int(magnitude.width * magnitude.height)

        var edgePixelCount = 0
        for i in 0..<pixelCount {
            if magnitudeData[i] > self.edgeThreshold {
                edgePixelCount += 1
            }
        }

        // Free magnitude buffer
        free(magnitude.data)

        return Float(edgePixelCount) / Float(pixelCount)
    }

    // MARK: - Helper Methods

    private func getBitmapRep(from image: NSImage) -> NSBitmapImageRep? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap
    }

    private func getPixelColor(at point: CGPoint, from bitmap: NSBitmapImageRep) -> NSColor? {
        let x = Int(point.x)
        let y = Int(bitmap.size.height - point.y - 1) // Flip Y coordinate

        guard x >= 0, x < bitmap.pixelsWide,
              y >= 0, y < bitmap.pixelsHigh else {
            return nil
        }

        return bitmap.colorAt(x: x, y: y)
    }

    private func calculateBrightness(_ color: NSColor) -> Float {
        guard let rgbColor = color.usingColorSpace(.deviceRGB) else {
            return 0.5
        }

        // Standard luminance formula
        return Float(rgbColor.redComponent) * 0.299 +
            Float(rgbColor.greenComponent) * 0.587 +
            Float(rgbColor.blueComponent) * 0.114
    }
}
