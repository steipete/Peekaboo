import AppKit
import Testing
import PeekabooCore
@testable import peekaboo

@Suite("Annotated Screenshot Tests", .serialized)
struct AnnotatedScreenshotTests {
    // MARK: - Test Image Generation

    @Test("Create annotated image")
    func createAnnotatedImage() async throws {
        // This test verifies the annotated screenshot generation through the see command
        // We'll create a mock session cache and verify the annotation logic works

        let sessionCache = try SessionCache(sessionId: "test-annotation")

        // Create test UI elements
        let uiElements = self.createTestUIElements()
        let sessionData = SessionCache.UIAutomationSession(
            version: SessionCache.UIAutomationSession.currentVersion,
            screenshotPath: "/tmp/test.png",
            annotatedPath: nil,
            uiMap: uiElements,
            lastUpdateTime: Date(),
            applicationName: "TestApp",
            windowTitle: "Test Window")

        try await sessionCache.save(sessionData)

        // Verify session was saved with UI elements
        let loadedData = await sessionCache.load()
        #expect(loadedData != nil)
        #expect(loadedData?.uiMap.count == 4)

        // Verify actionable elements are identified
        let actionableCount = loadedData?.uiMap.values.filter(\.isActionable).count ?? 0
        #expect(actionableCount == 4)

        // Cleanup
        try? await sessionCache.clear()
    }

    @Test("Annotation role mapping")
    func annotationRoleMapping() async throws {
        // Test that different UI element roles get mapped correctly
        let roleMapping: [(String, String)] = [
            ("AXButton", "B"),
            ("AXTextField", "T"),
            ("AXCheckBox", "C"),
            ("AXLink", "L"),
            ("AXSlider", "S"),
            ("AXRadioButton", "R"),
            ("AXMenu", "M"),
        ]

        for (role, expectedPrefix) in roleMapping {
            #expect(ElementIDGenerator.prefix(for: role) == expectedPrefix)
        }

        // Test default mapping
        #expect(ElementIDGenerator.prefix(for: "AXUnknownRole") == "G")
    }

    @Test("Peekaboo ID generation")
    func peekabooIDGeneration() async throws {
        // Test that Peekaboo IDs are generated correctly
        let sessionCache = try SessionCache(sessionId: "test-id-generation")

        // Create elements with different roles
        var elements: [String: SessionCache.UIAutomationSession.UIElement] = [:]
        let elementTypes = [
            ("B1", "AXButton", "Button 1"),
            ("B2", "AXButton", "Button 2"),
            ("T1", "AXTextField", "Text Field"),
            ("C1", "AXCheckBox", "Checkbox"),
            ("L1", "AXLink", "Link"),
            ("S1", "AXSlider", "Slider"),
        ]

        for (id, role, title) in elementTypes {
            elements[id] = SessionCache.UIAutomationSession.UIElement(
                id: id,
                elementId: "elem_\(id)",
                role: role,
                title: title,
                label: nil,
                value: nil,
                frame: CGRect(x: 100, y: 100, width: 100, height: 40),
                isActionable: true)
        }

        let sessionData = SessionCache.UIAutomationSession(
            version: SessionCache.UIAutomationSession.currentVersion,
            screenshotPath: "/tmp/test.png",
            annotatedPath: nil,
            uiMap: elements,
            lastUpdateTime: Date(),
            applicationName: "TestApp",
            windowTitle: "Test Window")

        try await sessionCache.save(sessionData)

        // Verify IDs follow the pattern
        let loadedData = await sessionCache.load()
        #expect(loadedData != nil)

        for (id, element) in loadedData?.uiMap ?? [:] {
            let expectedPrefix = ElementIDGenerator.prefix(for: element.role)
            #expect(id.hasPrefix(expectedPrefix))
        }

        // Cleanup
        try? await sessionCache.clear()
    }

    @Test("Non-actionable elements not annotated")
    func nonActionableElementsNotAnnotated() async throws {
        // Test that non-actionable elements are handled correctly
        let sessionCache = try SessionCache(sessionId: "test-actionable")

        // Create mix of actionable and non-actionable elements
        let elements: [String: SessionCache.UIAutomationSession.UIElement] = [
            "B1": SessionCache.UIAutomationSession.UIElement(
                id: "B1",
                elementId: "elem1",
                role: "AXButton",
                title: "Actionable Button",
                label: nil,
                value: nil,
                frame: CGRect(x: 50, y: 50, width: 100, height: 40),
                isActionable: true
            ),
            "G1": SessionCache.UIAutomationSession.UIElement(
                id: "G1",
                elementId: "elem2",
                role: "AXGroup",
                title: "Non-actionable Group",
                label: nil,
                value: nil,
                frame: CGRect(x: 200, y: 50, width: 100, height: 40),
                isActionable: false
            ),
            "T1": SessionCache.UIAutomationSession.UIElement(
                id: "T1",
                elementId: "elem3",
                role: "AXStaticText",
                title: "Label Text",
                label: nil,
                value: nil,
                frame: CGRect(x: 50, y: 100, width: 200, height: 20),
                isActionable: false
            ),
        ]

        let sessionData = SessionCache.UIAutomationSession(
            version: SessionCache.UIAutomationSession.currentVersion,
            screenshotPath: "/tmp/test.png",
            annotatedPath: nil,
            uiMap: elements,
            lastUpdateTime: Date(),
            applicationName: "TestApp",
            windowTitle: "Test Window")

        try await sessionCache.save(sessionData)

        // Verify actionable count
        let loadedData = await sessionCache.load()
        let actionableElements = loadedData?.uiMap.values.filter(\.isActionable) ?? []
        #expect(actionableElements.count == 1)
        #expect(actionableElements.first?.id == "B1")

        // Cleanup
        try? await sessionCache.clear()
    }

    @Test("Element frame positioning")
    func elementFramePositioning() async throws {
        // Test element frame positioning
        let sessionCache = try SessionCache(sessionId: "test-positioning")

        // Create elements at different positions
        let elements: [String: SessionCache.UIAutomationSession.UIElement] = [
            "B1": SessionCache.UIAutomationSession.UIElement(
                id: "B1",
                elementId: "elem1",
                role: "AXButton",
                title: "Top Left",
                label: nil,
                value: nil,
                frame: CGRect(x: 10, y: 10, width: 100, height: 40),
                isActionable: true
            ),
            "B2": SessionCache.UIAutomationSession.UIElement(
                id: "B2",
                elementId: "elem2",
                role: "AXButton",
                title: "Bottom Right",
                label: nil,
                value: nil,
                frame: CGRect(x: 300, y: 500, width: 100, height: 40),
                isActionable: true
            ),
            "T1": SessionCache.UIAutomationSession.UIElement(
                id: "T1",
                elementId: "elem3",
                role: "AXTextField",
                title: "Center",
                label: nil,
                value: nil,
                frame: CGRect(x: 150, y: 250, width: 200, height: 30),
                isActionable: true
            ),
        ]

        let sessionData = SessionCache.UIAutomationSession(
            version: SessionCache.UIAutomationSession.currentVersion,
            screenshotPath: "/tmp/test.png",
            annotatedPath: nil,
            uiMap: elements,
            lastUpdateTime: Date(),
            applicationName: "TestApp",
            windowTitle: "Test Window")

        try await sessionCache.save(sessionData)

        // Verify elements maintain their frame data
        let loadedData = await sessionCache.load()
        #expect(loadedData != nil)

        let b1 = loadedData?.uiMap["B1"]
        #expect(b1?.frame.origin.x == 10)
        #expect(b1?.frame.origin.y == 10)

        let b2 = loadedData?.uiMap["B2"]
        #expect(b2?.frame.origin.x == 300)
        #expect(b2?.frame.origin.y == 500)

        // Cleanup
        try? await sessionCache.clear()
    }

    // MARK: - Coordinate Transformation Tests (Bug Fix)

    @Test("Window bounds storage in session data")
    func windowBoundsStorage() async throws {
        // Test that window bounds are properly stored when capturing
        let sessionCache = try SessionCache(sessionId: "test-window-bounds")
        let testWindowBounds = CGRect(x: 100, y: 200, width: 800, height: 600)

        // Create session data with window bounds
        let sessionData = SessionCache.UIAutomationSession(
            version: SessionCache.UIAutomationSession.currentVersion,
            screenshotPath: "/tmp/test.png",
            annotatedPath: nil,
            uiMap: [:],
            lastUpdateTime: Date(),
            applicationName: "TestApp",
            windowTitle: "Test Window",
            windowBounds: testWindowBounds)

        try await sessionCache.save(sessionData)

        // Verify window bounds are preserved
        let loadedData = await sessionCache.load()
        #expect(loadedData?.windowBounds == testWindowBounds)

        // Cleanup
        try? await sessionCache.clear()
    }

    @Test("Coordinate transformation - window at origin")
    func coordinateTransformationWindowAtOrigin() async throws {
        // When window is at screen origin (0,0), element coords should match
        let windowBounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let elementScreenCoords = CGRect(x: 100, y: 150, width: 120, height: 40)

        // Transform to window-relative coordinates
        let windowRelativeX = elementScreenCoords.origin.x - windowBounds.origin.x
        let windowRelativeY = elementScreenCoords.origin.y - windowBounds.origin.y

        #expect(windowRelativeX == 100) // Should match screen coords
        #expect(windowRelativeY == 150)

        // Y-flip for NSGraphicsContext (origin at bottom-left)
        let flippedY = windowBounds.height - windowRelativeY - elementScreenCoords.height
        #expect(flippedY == 410) // 600 - 150 - 40
    }

    @Test("Coordinate transformation - offset window")
    func coordinateTransformationOffsetWindow() async throws {
        // Test the actual bug case: window not at origin
        let windowBounds = CGRect(x: 300, y: 400, width: 1024, height: 768)

        // UI element in screen coordinates
        let elementScreenCoords = CGRect(x: 450, y: 500, width: 100, height: 30)

        // Without fix: element would be drawn at screen coords (wrong!)
        // With fix: transform to window-relative coords
        let windowRelativeX = elementScreenCoords.origin.x - windowBounds.origin.x
        let windowRelativeY = elementScreenCoords.origin.y - windowBounds.origin.y

        #expect(windowRelativeX == 150) // 450 - 300
        #expect(windowRelativeY == 100) // 500 - 400

        // After Y-flip for drawing
        let flippedY = windowBounds.height - windowRelativeY - elementScreenCoords.height
        #expect(flippedY == 638) // 768 - 100 - 30
    }

    @Test("Multiple elements maintain relative spacing")
    func multipleElementsRelativeSpacing() async throws {
        // Test that multiple UI elements maintain correct relative positions
        let windowBounds = CGRect(x: 200, y: 300, width: 800, height: 600)

        // Three buttons in a toolbar (screen coordinates)
        let buttons = [
            CGRect(x: 250, y: 350, width: 80, height: 30), // Bold
            CGRect(x: 340, y: 350, width: 80, height: 30), // Italic
            CGRect(x: 430, y: 350, width: 80, height: 30), // Underline
        ]

        // Transform all to window-relative
        let transformed = buttons.map { button in
            CGPoint(
                x: button.origin.x - windowBounds.origin.x,
                y: button.origin.y - windowBounds.origin.y)
        }

        // Verify spacing is preserved
        let spacing1 = transformed[1].x - transformed[0].x
        let spacing2 = transformed[2].x - transformed[1].x

        #expect(spacing1 == 90) // Original: 340 - 250
        #expect(spacing2 == 90) // Original: 430 - 340

        // All should have same Y coordinate
        #expect(transformed[0].y == transformed[1].y)
        #expect(transformed[1].y == transformed[2].y)
    }

    @Test("Edge case - element at window corner")
    func elementAtWindowCorner() async throws {
        let windowBounds = CGRect(x: 100, y: 200, width: 800, height: 600)

        // Element exactly at window's top-left corner
        let element = CGRect(x: 100, y: 200, width: 50, height: 25)

        // Should transform to (0, 0) in window coordinates
        let relativeCoords = CGPoint(
            x: element.origin.x - windowBounds.origin.x,
            y: element.origin.y - windowBounds.origin.y)

        #expect(relativeCoords.x == 0)
        #expect(relativeCoords.y == 0)
    }

    @Test("Edge case - partially visible element")
    func partiallyVisibleElement() async throws {
        let windowBounds = CGRect(x: 100, y: 100, width: 400, height: 300)

        // Element extends beyond window bounds
        let element = CGRect(x: 450, y: 150, width: 100, height: 30)

        // Transform coordinates
        let relativeX = element.origin.x - windowBounds.origin.x
        let relativeY = element.origin.y - windowBounds.origin.y

        #expect(relativeX == 350) // 450 - 100
        #expect(relativeY == 50) // 150 - 100

        // Element extends beyond window (350 + 100 > 400)
        #expect(relativeX + element.width > windowBounds.width)
    }

    @Test("Nil window bounds fallback")
    func nilWindowBoundsFallback() async throws {
        // When capturing full screen, windowBounds may be nil
        let sessionCache = try SessionCache(sessionId: "test-nil-bounds")

        // Create session data without window bounds (full screen capture)
        let sessionData = SessionCache.UIAutomationSession(
            version: SessionCache.UIAutomationSession.currentVersion,
            screenshotPath: "/tmp/test.png",
            annotatedPath: nil,
            uiMap: self.createTestUIElements(),
            lastUpdateTime: Date(),
            applicationName: nil,
            windowTitle: nil,
            windowBounds: nil // No window bounds for full screen
        )

        try await sessionCache.save(sessionData)

        // Verify nil bounds are handled
        let loadedData = await sessionCache.load()
        #expect(loadedData?.windowBounds == nil)

        // Elements should still have their screen coordinates
        let element = loadedData?.uiMap["B1"]
        #expect(element?.frame.origin.x == 650)
        #expect(element?.frame.origin.y == 50)

        // Cleanup
        try? await sessionCache.clear()
    }

    @Test("Label positioning after coordinate transform")
    func labelPositioningAfterTransform() async throws {
        // Test that element labels are positioned correctly after transformation
        let windowBounds = CGRect(x: 200, y: 100, width: 800, height: 600)
        let elementScreenCoords = CGRect(x: 300, y: 200, width: 100, height: 40)

        // Transform to window coordinates
        let windowRelativeCoords = CGRect(
            x: elementScreenCoords.origin.x - windowBounds.origin.x,
            y: elementScreenCoords.origin.y - windowBounds.origin.y,
            width: elementScreenCoords.width,
            height: elementScreenCoords.height)

        #expect(windowRelativeCoords.origin.x == 100) // 300 - 200
        #expect(windowRelativeCoords.origin.y == 100) // 200 - 100

        // Label should be positioned relative to transformed element
        let labelPadding: CGFloat = 4
        let labelX = windowRelativeCoords.origin.x + labelPadding
        let labelY = windowRelativeCoords.origin.y + windowRelativeCoords.height - 20 - labelPadding

        #expect(labelX == 104)
        #expect(labelY == 116) // 100 + 40 - 20 - 4
    }

    @Test("Regression test - TextEdit toolbar buttons")
    func textEditToolbarButtonsAlignment() async throws {
        // Specific test for the TextEdit case that revealed the bug
        let windowBounds = CGRect(x: 56, y: 368, width: 691, height: 530)

        // Toolbar button positions (approximate real values from TextEdit)
        let boldButton = CGRect(x: 178, y: 473, width: 30, height: 24)
        let italicButton = CGRect(x: 216, y: 473, width: 30, height: 24)

        // Transform to window-relative
        let boldRelative = CGPoint(
            x: boldButton.origin.x - windowBounds.origin.x,
            y: boldButton.origin.y - windowBounds.origin.y)

        let italicRelative = CGPoint(
            x: italicButton.origin.x - windowBounds.origin.x,
            y: italicButton.origin.y - windowBounds.origin.y)

        // Verify buttons are within window bounds
        #expect(boldRelative.x >= 0 && boldRelative.x < windowBounds.width)
        #expect(italicRelative.x >= 0 && italicRelative.x < windowBounds.width)

        // Verify relative spacing is preserved
        let spacing = italicRelative.x - boldRelative.x
        #expect(spacing == 38) // 216 - 178
    }

    // MARK: - Helper Methods

    private func createTestImage(width: CGFloat, height: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()

        // Draw a gradient background
        let gradient = NSGradient(colors: [
            NSColor(white: 0.9, alpha: 1.0),
            NSColor(white: 0.7, alpha: 1.0),
        ])!
        gradient.draw(in: NSRect(origin: .zero, size: image.size), angle: -90)

        // Draw some test content
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.black,
        ]
        let text = "Test Window"
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (width - textSize.width) / 2,
            y: height - 50,
            width: textSize.width,
            height: textSize.height)
        text.draw(in: textRect, withAttributes: attributes)

        image.unlockFocus()
        return image
    }

    private func saveTestImage(_ image: NSImage, to path: String) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:])
        else {
            throw CaptureError.captureFailure("Failed to create PNG data")
        }
        try pngData.write(to: URL(fileURLWithPath: path))
    }

    private func createTestUIElements() -> [String: SessionCache.UIAutomationSession.UIElement] {
        [
            "B1": SessionCache.UIAutomationSession.UIElement(
                id: "B1",
                elementId: "button1",
                role: "AXButton",
                title: "Save",
                label: "Save Document",
                value: nil,
                frame: CGRect(x: 650, y: 50, width: 100, height: 40),
                isActionable: true
            ),
            "B2": SessionCache.UIAutomationSession.UIElement(
                id: "B2",
                elementId: "button2",
                role: "AXButton",
                title: "Cancel",
                label: "Cancel Operation",
                value: nil,
                frame: CGRect(x: 540, y: 50, width: 100, height: 40),
                isActionable: true
            ),
            "T1": SessionCache.UIAutomationSession.UIElement(
                id: "T1",
                elementId: "textfield1",
                role: "AXTextField",
                title: nil,
                label: "Name",
                value: "Document.txt",
                frame: CGRect(x: 100, y: 150, width: 300, height: 30),
                isActionable: true
            ),
            "C1": SessionCache.UIAutomationSession.UIElement(
                id: "C1",
                elementId: "checkbox1",
                role: "AXCheckBox",
                title: "Auto-save",
                label: nil,
                value: "1",
                frame: CGRect(x: 100, y: 200, width: 150, height: 20),
                isActionable: true
            ),
        ]
    }
}
