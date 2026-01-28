//
//  GLMCoordinateTransformTests.swift
//  PeekabooVisualizerTests
//
//  Tests for GLM-4V model coordinate normalization support
//

import CoreGraphics
import Foundation
import Testing

@testable import PeekabooVisualizer

@Suite("GLM Coordinate Transform Tests")
struct GLMCoordinateTransformTests {
    @MainActor
    @Test("Convert normalized 0-1000 coordinates to pixels")
    func testNormalized1000ToPixels() async {
        let transformer = CoordinateTransformer()
        let imageSize = CGSize(width: 1920, height: 1080)

        // Test bounding box from GLM-4V: [283, 263, 463, 295]
        let normalizedBounds = CGRect(x: 283, y: 263, width: 180, height: 32)
        let pixelBounds = transformer.fromNormalized1000ToPixels(normalizedBounds, imageSize: imageSize)

        // Expected: x = 283/1000 * 1920 = 543.36
        //           y = 263/1000 * 1080 = 284.04
        #expect(abs(pixelBounds.origin.x - 543.36) < 0.01)
        #expect(abs(pixelBounds.origin.y - 284.04) < 0.01)
    }

    @MainActor
    @Test("Convert bounding box array from normalized to pixels")
    func testConvertBoundingBoxArray() async {
        let transformer = CoordinateTransformer()
        let imageSize = CGSize(width: 1920, height: 1080)

        // GLM-4V returns: [283, 263, 463, 295]
        let normalizedBox = [283, 263, 463, 295]
        let pixelBox = transformer.convertBoundingBox(from: normalizedBox, imageSize: imageSize)

        // Expected conversions:
        // x1 = 283/1000 * 1920 = 543
        // y1 = 263/1000 * 1080 = 284
        // x2 = 463/1000 * 1920 = 888
        // y2 = 295/1000 * 1080 = 318
        #expect(pixelBox == [543, 284, 888, 318])
    }

    @MainActor
    @Test("Calculate center point from bounding box")
    func testCenterPoint() async {
        let transformer = CoordinateTransformer()

        let box = [543, 284, 888, 318]
        let center = transformer.centerPoint(from: box)

        #expect(center != nil)
        #expect(center!.x == 715.5)
        #expect(center!.y == 301.0)
    }

    @Test("Detect GLM model names")
    func testGLMModelDetection() async {
        // Should detect GLM-4V series
        #expect(CoordinateTransformer.usesNormalizedCoordinates(modelName: "glm-4.6v-flash") == true)
        #expect(CoordinateTransformer.usesNormalizedCoordinates(modelName: "GLM-4.5V") == true)
        #expect(CoordinateTransformer.usesNormalizedCoordinates(modelName: "glm-4v") == true)
        #expect(CoordinateTransformer.usesNormalizedCoordinates(modelName: "glm-4.1v-thinking") == true)

        // Should NOT detect other models
        #expect(CoordinateTransformer.usesNormalizedCoordinates(modelName: "gpt-4o") == false)
        #expect(CoordinateTransformer.usesNormalizedCoordinates(modelName: "claude-sonnet-4") == false)
        #expect(CoordinateTransformer.usesNormalizedCoordinates(modelName: "llava") == false)
    }

    @MainActor
    @Test("Transform from normalized1000 space to screen")
    func testNormalized1000ToScreen() async {
        let transformer = CoordinateTransformer()
        let imageSize = CGSize(width: 1920, height: 1080)

        // Bounding box in 0-1000 format: center at (500, 500)
        let normalizedBounds = CGRect(x: 400, y: 400, width: 200, height: 200)

        let screenBounds = transformer.transform(
            normalizedBounds,
            from: .normalized1000(imageSize),
            to: .screen)

        // After normalization: (0.4, 0.4, 0.2, 0.2)
        // After denormalization to screen (assuming 1920x1080):
        // x = 0.4 * 1920 = 768, y = 0.4 * 1080 = 432
        // width = 0.2 * 1920 = 384, height = 0.2 * 1080 = 216
        #expect(abs(screenBounds.origin.x - 768) < 1)
        #expect(abs(screenBounds.origin.y - 432) < 1)
    }

    @MainActor
    @Test("Invalid bounding box array returns unchanged")
    func testInvalidBoundingBox() async {
        let transformer = CoordinateTransformer()
        let imageSize = CGSize(width: 1920, height: 1080)

        // Invalid: only 3 elements
        let invalidBox = [100, 200, 300]
        let result = transformer.convertBoundingBox(from: invalidBox, imageSize: imageSize)

        #expect(result == invalidBox) // Should return unchanged
    }
}
