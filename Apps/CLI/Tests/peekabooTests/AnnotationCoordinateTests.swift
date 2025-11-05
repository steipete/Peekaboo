import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation
import Testing
@testable import peekaboo

@Suite("Annotation Coordinate Tests")
struct AnnotationCoordinateTests {
    @Test("Window-relative coordinate transformation")
    func windowRelativeTransformation() {
        // Given screen coordinates
        let screenBounds = CGRect(x: 500, y: 300, width: 100, height: 50)
        let windowBounds = CGRect(x: 400, y: 200, width: 800, height: 600)

        // When transforming to window-relative (as done in UIAutomationServiceEnhanced)
        var windowRelativeBounds = screenBounds
        windowRelativeBounds.origin.x -= windowBounds.origin.x
        windowRelativeBounds.origin.y -= windowBounds.origin.y

        // Then coordinates should be relative to window origin
        #expect(windowRelativeBounds.origin.x == 100) // 500 - 400
        #expect(windowRelativeBounds.origin.y == 100) // 300 - 200
        #expect(windowRelativeBounds.size == screenBounds.size) // Size unchanged
    }

    @Test("Y-coordinate flip for NSGraphicsContext")
    func yCoordinateFlip() {
        // Given window-relative bounds with top-left origin
        let elementBounds = CGRect(x: 100, y: 150, width: 80, height: 40)
        let imageHeight: CGFloat = 600

        // When converting to NSGraphicsContext coordinates (bottom-left origin)
        let flippedY = imageHeight - elementBounds.origin.y - elementBounds.height
        let drawingBounds = NSRect(
            x: elementBounds.origin.x,
            y: flippedY,
            width: elementBounds.width,
            height: elementBounds.height
        )

        // Then Y should be flipped correctly
        #expect(drawingBounds.origin.x == 100) // X unchanged
        #expect(drawingBounds.origin.y == 410) // 600 - 150 - 40
        #expect(drawingBounds.size == elementBounds.size) // Size unchanged
    }

    @Test("Complete transformation pipeline")
    func completeTransformationPipeline() {
        // Given: Element in screen coordinates
        let screenElement = CGRect(x: 600, y: 250, width: 120, height: 60)
        let windowBounds = CGRect(x: 450, y: 150, width: 1000, height: 700)
        let imageHeight: CGFloat = 700 // Same as window height

        // Step 1: Transform to window-relative (done in UIAutomationServiceEnhanced)
        var windowRelative = screenElement
        windowRelative.origin.x -= windowBounds.origin.x
        windowRelative.origin.y -= windowBounds.origin.y

        // Verify window-relative coordinates
        #expect(windowRelative.origin.x == 150) // 600 - 450
        #expect(windowRelative.origin.y == 100) // 250 - 150

        // Step 2: Flip Y for drawing (done in SeeCommand annotation)
        let flippedY = imageHeight - windowRelative.origin.y - windowRelative.height
        let finalDrawingRect = NSRect(
            x: windowRelative.origin.x,
            y: flippedY,
            width: windowRelative.width,
            height: windowRelative.height
        )

        // Verify final drawing coordinates
        #expect(finalDrawingRect.origin.x == 150) // X unchanged
        #expect(finalDrawingRect.origin.y == 540) // 700 - 100 - 60
        #expect(finalDrawingRect.width == 120)
        #expect(finalDrawingRect.height == 60)
    }

    @Test("Annotation file path generation")
    func annotationFilePathGeneration() {
        let testPaths = [
            ("/tmp/screenshot.png", "/tmp/screenshot_annotated.png"),
            ("/Users/test/image.png", "/Users/test/image_annotated.png"),
            ("screenshot.png", "screenshot_annotated.png"),
            ("/path/with spaces/file.png", "/path/with spaces/file_annotated.png")
        ]

        for (original, expected) in testPaths {
            let annotatedPath = (original as NSString).deletingPathExtension + "_annotated.png"
            #expect(annotatedPath == expected)
        }
    }

    @Test("Element filtering for annotation")
    func elementFilteringForAnnotation() {
        // Create test elements
        let enabledButton = self.createTestElement(id: "B1", isEnabled: true)
        let disabledButton = self.createTestElement(id: "B2", isEnabled: false)
        let enabledTextField = self.createTestElement(id: "T1", isEnabled: true, type: .textField)
        let disabledLink = self.createTestElement(id: "L1", isEnabled: false, type: .link)

        let allElements = [enabledButton, disabledButton, enabledTextField, disabledLink]

        // Filter as done in annotation code
        let annotatedElements = allElements.filter(\.isEnabled)

        // Only enabled elements should be annotated
        #expect(annotatedElements.count == 2)
        #expect(annotatedElements.contains { $0.id == "B1" })
        #expect(annotatedElements.contains { $0.id == "T1" })
        #expect(!annotatedElements.contains { $0.id == "B2" })
        #expect(!annotatedElements.contains { $0.id == "L1" })
    }

    // Helper function to create test elements
    private func createTestElement(
        id: String,
        isEnabled: Bool,
        type: ElementType = .button
    ) -> DetectedElement {
        DetectedElement(
            id: id,
            type: type,
            label: "Test \(type)",
            value: nil,
            bounds: CGRect(x: 10, y: 10, width: 100, height: 50),
            isEnabled: isEnabled,
            isSelected: nil,
            attributes: [:]
        )
    }
}
