import AppKit
import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

@Suite("SmartLabelPlacer Tests", .serialized, .tags(.fast))
@MainActor
struct SmartLabelPlacerTests {
    @Test("Scoring expands candidate rects with padding")
    func scoringExpandsRectForCalmerPlacement() {
        let imageSize = NSSize(width: 200, height: 200)
        let image = Self.makeImage(size: imageSize)
        let detector = RecordingTextDetector()

        let placer = SmartLabelPlacer(
            image: image,
            fontSize: 10,
            debugMode: false,
            logger: .shared,
            textDetector: detector
        )

        let element = DetectedElement.make(id: "elem-top")
        let elementRect = NSRect(x: 50, y: 50, width: 30, height: 20)
        let labelSize = NSSize(width: 30, height: 10)

        let result = placer.findBestLabelPosition(
            for: element,
            elementRect: elementRect,
            labelSize: labelSize,
            existingLabels: [],
            allElements: [(element: element, rect: elementRect)]
        )

        #expect(result != nil)

        let expected = Self.expectedScoringRect(
            from: result!.labelRect,
            imageSize: imageSize
        )

        #expect(detector.recordedRects.first != nil)
        Self.expect(detector.recordedRects.first!, equals: expected)
    }

    @Test("Scoring rects clamp to image bounds")
    func scoringRectsClampWithinImage() {
        let imageSize = NSSize(width: 200, height: 200)
        let image = Self.makeImage(size: imageSize)
        let detector = RecordingTextDetector()

        let placer = SmartLabelPlacer(
            image: image,
            fontSize: 10,
            debugMode: false,
            logger: .shared,
            textDetector: detector
        )

        // Position element close enough to the bottom that the expanded sampling
        // rect would extend beyond the image bounds.
        let element = DetectedElement.make(id: "elem-bottom")
        let elementRect = NSRect(x: 40, y: 95, width: 30, height: 15)
        let labelSize = NSSize(width: 32, height: 12)

        let result = placer.findBestLabelPosition(
            for: element,
            elementRect: elementRect,
            labelSize: labelSize,
            existingLabels: [],
            allElements: [(element: element, rect: elementRect)]
        )

        #expect(result != nil)

        let expected = Self.expectedScoringRect(
            from: result!.labelRect,
            imageSize: imageSize
        )

        #expect(detector.recordedRects.first != nil)
        Self.expect(detector.recordedRects.first!, equals: expected)
        #expect(detector.recordedRects.first!.minY >= 0)
    }
}

// MARK: - Helpers

private extension SmartLabelPlacerTests {
    static func makeImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }

    static func expectedScoringRect(from labelRect: NSRect, imageSize: NSSize) -> NSRect {
        let imageRect = NSRect(
            x: labelRect.origin.x,
            y: imageSize.height - labelRect.origin.y - labelRect.height,
            width: labelRect.width,
            height: labelRect.height
        )

        // Mirror the SmartLabelPlacer logic: expand by the padding and clamp to bounds.
        let expanded = imageRect.insetBy(
            dx: -SmartLabelPlacer.defaultScoreRegionPadding,
            dy: -SmartLabelPlacer.defaultScoreRegionPadding
        )

        return clamp(expanded, within: NSRect(origin: .zero, size: imageSize))
    }

    static func clamp(_ rect: NSRect, within bounds: NSRect) -> NSRect {
        let minX = max(bounds.minX, rect.minX)
        let maxX = min(bounds.maxX, rect.maxX)
        let minY = max(bounds.minY, rect.minY)
        let maxY = min(bounds.maxY, rect.maxY)
        return NSRect(
            x: minX,
            y: minY,
            width: max(0, maxX - minX),
            height: max(0, maxY - minY)
        )
    }

    static func expect(_ lhs: NSRect, equals rhs: NSRect, accuracy: CGFloat = 0.001) {
        #expect(abs(lhs.origin.x - rhs.origin.x) < accuracy)
        #expect(abs(lhs.origin.y - rhs.origin.y) < accuracy)
        #expect(abs(lhs.size.width - rhs.size.width) < accuracy)
        #expect(abs(lhs.size.height - rhs.size.height) < accuracy)
    }
}

// MARK: - Test Doubles

private final class RecordingTextDetector: SmartLabelPlacerTextDetecting {
    var recordedRects: [NSRect] = []

    func scoreRegionForLabelPlacement(_ rect: NSRect, in image: NSImage) -> Float {
        self.recordedRects.append(rect)
        return 0.5
    }

    func analyzeRegion(_ rect: NSRect, in image: NSImage) -> AcceleratedTextDetector.EdgeDensityResult {
        AcceleratedTextDetector.EdgeDensityResult(density: 0, hasText: false)
    }
}

private extension DetectedElement {
    static func make(id: String) -> DetectedElement {
        DetectedElement(
            id: id,
            type: .button,
            label: id,
            value: nil,
            bounds: .zero,
            isEnabled: true,
            isSelected: nil,
            attributes: [:]
        )
    }
}
