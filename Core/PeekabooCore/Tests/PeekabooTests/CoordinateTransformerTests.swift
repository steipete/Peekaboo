import CoreGraphics
import Testing
@testable import PeekabooAgentRuntime
@testable import PeekabooAutomation
@testable import PeekabooCore
@testable import PeekabooVisualizer

@Suite("CoordinateTransformer Tests")
@MainActor
struct CoordinateTransformerTests {
    let transformer = CoordinateTransformer()

    // MARK: - Basic Transformation Tests

    @Test("Transform between normalized and screen coordinates")
    @MainActor
    func transformNormalizedToScreen() {
        let normalizedBounds = CGRect(x: 0.5, y: 0.5, width: 0.1, height: 0.1)

        // Transform from normalized to screen
        let screenBounds = self.transformer.transform(
            normalizedBounds,
            from: .normalized,
            to: .screen)

        // On macOS without a screen, it uses default 1920x1080
        #if !canImport(AppKit)
        #expect(screenBounds.origin.x == 960) // 0.5 * 1920
        #expect(screenBounds.origin.y == 540) // 0.5 * 1080
        #expect(screenBounds.width == 192) // 0.1 * 1920
        #expect(screenBounds.height == 108) // 0.1 * 1080
        #endif
    }

    @Test("Transform between window and screen coordinates")
    @MainActor
    func transformWindowToScreen() {
        let windowFrame = CGRect(x: 100, y: 200, width: 800, height: 600)
        let windowBounds = CGRect(x: 50, y: 50, width: 100, height: 100)

        let screenBounds = self.transformer.transform(
            windowBounds,
            from: .window(windowFrame),
            to: .screen)

        // First normalize: (50-100)/800 = -50/800 = -0.0625 for x
        // Then denormalize to screen (assuming 1920x1080 default)
        #if !canImport(AppKit)
        let expectedX = -0.0625 * 1920 // -120
        let expectedY = -0.25 * 1080 // -270
        #expect(screenBounds.origin.x == expectedX)
        #expect(screenBounds.origin.y == expectedY)
        #endif
    }

    @Test("Transform between view and normalized coordinates")
    @MainActor
    func transformViewToNormalized() {
        let viewSize = CGSize(width: 400, height: 300)
        let viewBounds = CGRect(x: 100, y: 75, width: 200, height: 150)

        let normalizedBounds = self.transformer.transform(
            viewBounds,
            from: .view(viewSize),
            to: .normalized)

        #expect(normalizedBounds.origin.x == 0.25) // 100 / 400
        #expect(normalizedBounds.origin.y == 0.25) // 75 / 300
        #expect(normalizedBounds.width == 0.5) // 200 / 400
        #expect(normalizedBounds.height == 0.5) // 150 / 300
    }

    @Test("Round-trip transformation")
    @MainActor
    func roundTripTransformation() {
        let originalBounds = CGRect(x: 100, y: 200, width: 300, height: 400)
        let viewSize = CGSize(width: 1000, height: 800)

        // Transform from view to normalized and back
        let normalized = self.transformer.transform(
            originalBounds,
            from: .view(viewSize),
            to: .normalized)

        let backToView = self.transformer.transform(
            normalized,
            from: .normalized,
            to: .view(viewSize))

        #expect(backToView.origin.x == originalBounds.origin.x)
        #expect(backToView.origin.y == originalBounds.origin.y)
        #expect(backToView.width == originalBounds.width)
        #expect(backToView.height == originalBounds.height)
    }

    // MARK: - Point Transformation Tests

    @Test("Transform point between coordinate spaces")
    @MainActor
    func transformPoint() {
        let point = CGPoint(x: 100, y: 200)
        let viewSize = CGSize(width: 800, height: 600)

        let normalizedPoint = self.transformer.transform(
            point,
            from: .view(viewSize),
            to: .normalized)

        #expect(normalizedPoint.x == 0.125) // 100 / 800
        #expect(abs(normalizedPoint.y - 0.333) < 0.001) // 200 / 600
    }

    // MARK: - Conversion Method Tests

    @Test("Accessibility to screen conversion")
    @MainActor
    func accessibilityToScreenConversion() {
        let axBounds = CGRect(x: 100, y: 200, width: 300, height: 400)
        let screenBounds = self.transformer.fromAccessibilityToScreen(axBounds)

        // On macOS, AX coordinates are already in screen space
        #expect(screenBounds == axBounds)
    }

    @Test("Screen to view conversion with Y-flip")
    @MainActor
    func screenToViewWithYFlip() {
        let screenBounds = CGRect(x: 100, y: 100, width: 200, height: 150)
        let viewSize = CGSize(width: 800, height: 600)

        let viewBounds = self.transformer.fromScreenToView(
            screenBounds,
            viewSize: viewSize,
            flipY: true)

        // With Y-flip, the Y coordinate should be inverted
        // Y = viewHeight - normalizedY - normalizedHeight
        #if !canImport(AppKit)
        let expectedY = 600 - (100.0 / 1080 * 600) - (150.0 / 1080 * 600)
        #expect(abs(viewBounds.origin.y - expectedY) < 0.1)
        #endif
    }

    @Test("Window to screen and back conversion")
    @MainActor
    func windowToScreenAndBack() {
        let windowFrame = CGRect(x: 200, y: 100, width: 1000, height: 800)
        let elementBounds = CGRect(x: 50, y: 50, width: 100, height: 100)

        let screenBounds = self.transformer.fromWindowToScreen(elementBounds, windowFrame: windowFrame)
        #expect(screenBounds.origin.x == 250) // 50 + 200
        #expect(screenBounds.origin.y == 150) // 50 + 100

        let backToWindow = self.transformer.fromScreenToWindow(screenBounds, windowFrame: windowFrame)
        #expect(backToWindow == elementBounds)
    }

    // MARK: - Utility Method Tests

    @Test("Scale bounds uniformly")
    @MainActor
    func scaleBoundsUniform() {
        let bounds = CGRect(x: 10, y: 20, width: 100, height: 200)
        let scaled = self.transformer.scale(bounds, by: 2.0)

        #expect(scaled.origin.x == 20)
        #expect(scaled.origin.y == 40)
        #expect(scaled.width == 200)
        #expect(scaled.height == 400)
    }

    @Test("Scale bounds with different X and Y factors")
    @MainActor
    func scaleBoundsNonUniform() {
        let bounds = CGRect(x: 10, y: 20, width: 100, height: 200)
        let scaled = self.transformer.scale(bounds, xFactor: 2.0, yFactor: 0.5)

        #expect(scaled.origin.x == 20)
        #expect(scaled.origin.y == 10)
        #expect(scaled.width == 200)
        #expect(scaled.height == 100)
    }

    @Test("Offset bounds")
    @MainActor
    func offsetBounds() {
        let bounds = CGRect(x: 100, y: 200, width: 300, height: 400)
        let delta = CGPoint(x: 50, y: -50)
        let offset = self.transformer.offset(bounds, by: delta)

        #expect(offset.origin.x == 150)
        #expect(offset.origin.y == 150)
        #expect(offset.width == 300)
        #expect(offset.height == 400)
    }

    @Test("Clamp bounds within container")
    @MainActor
    func clampBounds() {
        let container = CGRect(x: 0, y: 0, width: 800, height: 600)

        // Test bounds that extend outside container
        let oversizedBounds = CGRect(x: -50, y: -50, width: 900, height: 700)
        let clamped = self.transformer.clamp(oversizedBounds, to: container)

        #expect(clamped.origin.x == 0)
        #expect(clamped.origin.y == 0)
        #expect(clamped.width == 800)
        #expect(clamped.height == 600)

        // Test bounds that would be pushed outside
        let outsideBounds = CGRect(x: 750, y: 550, width: 100, height: 100)
        let clampedOutside = self.transformer.clamp(outsideBounds, to: container)

        #expect(clampedOutside.origin.x == 700) // 800 - 100
        #expect(clampedOutside.origin.y == 500) // 600 - 100
    }

    // MARK: - Screen Utility Tests

    @Test("Primary screen bounds")
    @MainActor
    func primaryScreenBounds() {
        let bounds = self.transformer.primaryScreenBounds

        #if canImport(AppKit)
        // With AppKit, we get actual screen bounds
        #expect(bounds.width > 0)
        #expect(bounds.height > 0)
        #else
        // Without AppKit, we get default bounds
        #expect(bounds.width == 1920)
        #expect(bounds.height == 1080)
        #endif
    }

    @Test("Combined screen bounds")
    @MainActor
    func combinedScreenBounds() {
        let bounds = self.transformer.combinedScreenBounds

        // Should at least include the primary screen
        #expect(bounds.width > 0)
        #expect(bounds.height > 0)
    }
}
