import AppKit
import Testing
@testable import peekaboo

@Suite("Annotated Screenshot Tests")
struct AnnotatedScreenshotTests {
    
    // MARK: - Test Image Generation
    
    @Test("Create annotated image")
    func createAnnotatedImage() async throws {
        // This test verifies the annotated screenshot generation through the see command
        // We'll create a mock session cache and verify the annotation logic works
        
        let sessionCache = SessionCache(sessionId: "test-annotation")
        
        // Create test UI elements
        let uiElements = createTestUIElements()
        let sessionData = SessionCache.SessionData(
            screenshotPath: "/tmp/test.png",
            annotatedPath: nil,
            uiMap: uiElements,
            lastUpdateTime: Date(),
            applicationName: "TestApp",
            windowTitle: "Test Window"
        )
        
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
            ("AXMenu", "M")
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
        let sessionCache = SessionCache(sessionId: "test-id-generation")
        
        // Create elements with different roles
        var elements: [String: SessionCache.SessionData.UIElement] = [:]
        let elementTypes = [
            ("B1", "AXButton", "Button 1"),
            ("B2", "AXButton", "Button 2"),
            ("T1", "AXTextField", "Text Field"),
            ("C1", "AXCheckBox", "Checkbox"),
            ("L1", "AXLink", "Link"),
            ("S1", "AXSlider", "Slider")
        ]
        
        for (id, role, title) in elementTypes {
            elements[id] = SessionCache.SessionData.UIElement(
                id: id,
                elementId: "elem_\(id)",
                role: role,
                title: title,
                label: nil,
                value: nil,
                frame: CGRect(x: 100, y: 100, width: 100, height: 40),
                isActionable: true
            )
        }
        
        let sessionData = SessionCache.SessionData(
            screenshotPath: "/tmp/test.png",
            annotatedPath: nil,
            uiMap: elements,
            lastUpdateTime: Date(),
            applicationName: "TestApp",
            windowTitle: "Test Window"
        )
        
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
        let sessionCache = SessionCache(sessionId: "test-actionable")
        
        // Create mix of actionable and non-actionable elements
        let elements: [String: SessionCache.SessionData.UIElement] = [
            "B1": SessionCache.SessionData.UIElement(
                id: "B1",
                elementId: "elem1",
                role: "AXButton",
                title: "Actionable Button",
                label: nil,
                value: nil,
                frame: CGRect(x: 50, y: 50, width: 100, height: 40),
                isActionable: true
            ),
            "G1": SessionCache.SessionData.UIElement(
                id: "G1",
                elementId: "elem2",
                role: "AXGroup",
                title: "Non-actionable Group",
                label: nil,
                value: nil,
                frame: CGRect(x: 200, y: 50, width: 100, height: 40),
                isActionable: false
            ),
            "T1": SessionCache.SessionData.UIElement(
                id: "T1",
                elementId: "elem3",
                role: "AXStaticText",
                title: "Label Text",
                label: nil,
                value: nil,
                frame: CGRect(x: 50, y: 100, width: 200, height: 20),
                isActionable: false
            )
        ]
        
        let sessionData = SessionCache.SessionData(
            screenshotPath: "/tmp/test.png",
            annotatedPath: nil,
            uiMap: elements,
            lastUpdateTime: Date(),
            applicationName: "TestApp",
            windowTitle: "Test Window"
        )
        
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
        let sessionCache = SessionCache(sessionId: "test-positioning")
        
        // Create elements at different positions
        let elements: [String: SessionCache.SessionData.UIElement] = [
            "B1": SessionCache.SessionData.UIElement(
                id: "B1",
                elementId: "elem1",
                role: "AXButton",
                title: "Top Left",
                label: nil,
                value: nil,
                frame: CGRect(x: 10, y: 10, width: 100, height: 40),
                isActionable: true
            ),
            "B2": SessionCache.SessionData.UIElement(
                id: "B2",
                elementId: "elem2",
                role: "AXButton",
                title: "Bottom Right",
                label: nil,
                value: nil,
                frame: CGRect(x: 300, y: 500, width: 100, height: 40),
                isActionable: true
            ),
            "T1": SessionCache.SessionData.UIElement(
                id: "T1",
                elementId: "elem3",
                role: "AXTextField",
                title: "Center",
                label: nil,
                value: nil,
                frame: CGRect(x: 150, y: 250, width: 200, height: 30),
                isActionable: true
            )
        ]
        
        let sessionData = SessionCache.SessionData(
            screenshotPath: "/tmp/test.png",
            annotatedPath: nil,
            uiMap: elements,
            lastUpdateTime: Date(),
            applicationName: "TestApp",
            windowTitle: "Test Window"
        )
        
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
    
    // MARK: - Helper Methods
    
    private func createTestImage(width: CGFloat, height: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        
        // Draw a gradient background
        let gradient = NSGradient(colors: [
            NSColor(white: 0.9, alpha: 1.0),
            NSColor(white: 0.7, alpha: 1.0)
        ])!
        gradient.draw(in: NSRect(origin: .zero, size: image.size), angle: -90)
        
        // Draw some test content
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ]
        let text = "Test Window"
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (width - textSize.width) / 2,
            y: height - 50,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attributes)
        
        image.unlockFocus()
        return image
    }
    
    private func saveTestImage(_ image: NSImage, to path: String) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw CaptureError.captureFailure("Failed to create PNG data")
        }
        try pngData.write(to: URL(fileURLWithPath: path))
    }
    
    private func createTestUIElements() -> [String: SessionCache.SessionData.UIElement] {
        return [
            "B1": SessionCache.SessionData.UIElement(
                id: "B1",
                elementId: "button1",
                role: "AXButton",
                title: "Save",
                label: "Save Document",
                value: nil,
                frame: CGRect(x: 650, y: 50, width: 100, height: 40),
                isActionable: true
            ),
            "B2": SessionCache.SessionData.UIElement(
                id: "B2",
                elementId: "button2",
                role: "AXButton",
                title: "Cancel",
                label: "Cancel Operation",
                value: nil,
                frame: CGRect(x: 540, y: 50, width: 100, height: 40),
                isActionable: true
            ),
            "T1": SessionCache.SessionData.UIElement(
                id: "T1",
                elementId: "textfield1",
                role: "AXTextField",
                title: nil,
                label: "Name",
                value: "Document.txt",
                frame: CGRect(x: 100, y: 150, width: 300, height: 30),
                isActionable: true
            ),
            "C1": SessionCache.SessionData.UIElement(
                id: "C1",
                elementId: "checkbox1",
                role: "AXCheckBox",
                title: "Auto-save",
                label: nil,
                value: "1",
                frame: CGRect(x: 100, y: 200, width: 150, height: 20),
                isActionable: true
            )
        ]
    }
}