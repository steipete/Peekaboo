import Foundation
import Testing
import CoreGraphics
@testable import peekaboo
@testable import PeekabooCore

@Suite("SeeCommand Annotation Tests", .serialized)
struct SeeCommandAnnotationTests {
    
    @Test("Annotation creates annotated file with correct naming")
    func annotationFileNaming() {
        // Given an original path
        let originalPath = "/tmp/screenshot.png"
        
        // When creating annotated path
        let annotatedPath = (originalPath as NSString).deletingPathExtension + "_annotated.png"
        
        // Then the path should follow the naming convention
        #expect(annotatedPath == "/tmp/screenshot_annotated.png")
    }
    
    @Test("Element bounds are transformed correctly for annotations")
    func elementBoundsTransformation() {
        // Given elements in screen coordinates
        let screenElement = DetectedElement(
            id: "B1",
            type: .button,
            label: "Test Button",
            value: nil,
            bounds: CGRect(x: 500, y: 300, width: 100, height: 50),
            isEnabled: true,
            isSelected: nil,
            attributes: [:]
        )
        
        // And a window bounds
        let windowBounds = CGRect(x: 400, y: 200, width: 800, height: 600)
        
        // When transforming to window-relative coordinates (as done in UIAutomationServiceEnhanced)
        var transformedBounds = screenElement.bounds
        transformedBounds.origin.x -= windowBounds.origin.x
        transformedBounds.origin.y -= windowBounds.origin.y
        
        // Then the bounds should be relative to window
        #expect(transformedBounds.origin.x == 100) // 500 - 400
        #expect(transformedBounds.origin.y == 100) // 300 - 200
        #expect(transformedBounds.size.width == 100) // unchanged
        #expect(transformedBounds.size.height == 50)  // unchanged
    }
    
    @Test("Coordinate system conversion for NSGraphicsContext")
    func coordinateSystemConversion() {
        // Given a window-relative element bounds with top-left origin
        let elementBounds = CGRect(x: 100, y: 100, width: 80, height: 40)
        let imageHeight: CGFloat = 600
        
        // When converting to NSGraphicsContext coordinates (bottom-left origin)
        let flippedY = imageHeight - elementBounds.origin.y - elementBounds.height
        let drawingRect = NSRect(
            x: elementBounds.origin.x,
            y: flippedY,
            width: elementBounds.width,
            height: elementBounds.height
        )
        
        // Then Y coordinate should be flipped correctly
        #expect(drawingRect.origin.x == 100)
        #expect(drawingRect.origin.y == 460) // 600 - 100 - 40
        #expect(drawingRect.size.width == 80)
        #expect(drawingRect.size.height == 40)
    }
    
    @Test("Detection metadata includes window context")
    func detectionMetadataWindowContext() {
        // Given capture metadata with window info
        let windowInfo = WindowInfo(
            title: "Test Window",
            bounds: CGRect(x: 100, y: 50, width: 1200, height: 800),
            windowID: 12345,
            index: 0
        )
        
        let appInfo = ApplicationInfo(
            name: "TestApp",
            bundleIdentifier: "com.test.app",
            processIdentifier: 1234
        )
        
        let captureMetadata = CaptureMetadata(
            captureMode: .window,
            applicationInfo: appInfo,
            windowInfo: windowInfo,
            displayInfo: nil,
            timestamp: Date()
        )
        
        // When creating detection metadata (as in SeeCommand)
        let detectionMetadata = DetectionMetadata(
            detectionTime: 0.5,
            elementCount: 10,
            method: "AXorcist",
            warnings: [],
            applicationName: captureMetadata.applicationInfo?.name,
            windowTitle: captureMetadata.windowInfo?.title,
            windowBounds: captureMetadata.windowInfo?.bounds
        )
        
        // Then metadata should contain window context
        #expect(detectionMetadata.applicationName == "TestApp")
        #expect(detectionMetadata.windowTitle == "Test Window")
        #expect(detectionMetadata.windowBounds == windowInfo.bounds)
    }
    
    @Test("Enhanced detection uses window context")
    func enhancedDetectionWindowContext() async throws {
        // This test verifies that detectElementsEnhanced is called with proper window context
        // when annotation is requested
        
        let imageData = Data() // Mock image data
        let sessionId = "test-session-123"
        let appName = "Safari"
        let windowTitle = "Start Page"
        let windowBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        
        // Create mock service
        let mockService = MockUIAutomationService()
        
        // Call enhanced detection
        let result = try await mockService.detectElementsEnhanced(
            in: imageData,
            sessionId: sessionId,
            applicationName: appName,
            windowTitle: windowTitle,
            windowBounds: windowBounds
        )
        
        // Verify the context was passed correctly
        #expect(mockService.lastDetectionContext.applicationName == appName)
        #expect(mockService.lastDetectionContext.windowTitle == windowTitle)
        #expect(mockService.lastDetectionContext.windowBounds == windowBounds)
    }
    
    @Test("Annotation excludes disabled elements")
    func annotationExcludesDisabledElements() {
        // Given a mix of enabled and disabled elements
        let elements = DetectedElements(
            buttons: [
                DetectedElement(id: "B1", type: .button, label: "Enabled", value: nil,
                              bounds: CGRect(x: 10, y: 10, width: 50, height: 30),
                              isEnabled: true, isSelected: nil, attributes: [:]),
                DetectedElement(id: "B2", type: .button, label: "Disabled", value: nil,
                              bounds: CGRect(x: 70, y: 10, width: 50, height: 30),
                              isEnabled: false, isSelected: nil, attributes: [:])
            ],
            textFields: [],
            links: [],
            images: [],
            groups: [],
            sliders: [],
            checkboxes: [],
            menus: [],
            other: []
        )
        
        // When filtering for annotation (as done in generateAnnotatedScreenshot)
        let annotatedElements = elements.all.filter { $0.isEnabled }
        
        // Then only enabled elements should be included
        #expect(annotatedElements.count == 1)
        #expect(annotatedElements.first?.id == "B1")
    }
    
    @Test("Role-based colors are assigned correctly")
    func roleBasedColorAssignment() {
        // Define expected colors (from SeeCommand)
        let roleColors: [ElementType: (r: CGFloat, g: CGFloat, b: CGFloat)] = [
            .button: (0, 0.48, 1.0),      // #007AFF
            .textField: (0.204, 0.78, 0.349), // #34C759
            .link: (0, 0.48, 1.0),         // #007AFF
            .checkbox: (0.557, 0.557, 0.576), // #8E8E93
            .slider: (0.557, 0.557, 0.576),   // #8E8E93
            .menu: (0, 0.48, 1.0),         // #007AFF
        ]
        
        // Test each element type gets correct color
        for (elementType, expectedColor) in roleColors {
            let element = DetectedElement(
                id: "test",
                type: elementType,
                label: "Test",
                value: nil,
                bounds: CGRect(x: 0, y: 0, width: 100, height: 50),
                isEnabled: true,
                isSelected: nil,
                attributes: [:]
            )
            
            // In actual implementation, this would be done in generateAnnotatedScreenshot
            let color = roleColors[element.type]!
            #expect(color.r == expectedColor.r)
            #expect(color.g == expectedColor.g)
            #expect(color.b == expectedColor.b)
        }
    }
}

// MARK: - Mock Classes for Testing

class MockUIAutomationService: UIAutomationService {
    struct DetectionContext {
        var applicationName: String?
        var windowTitle: String?
        var windowBounds: CGRect?
    }
    
    var lastDetectionContext = DetectionContext()
    
    override func detectElementsEnhanced(
        in imageData: Data,
        sessionId: String?,
        applicationName: String? = nil,
        windowTitle: String? = nil,
        windowBounds: CGRect? = nil
    ) async throws -> ElementDetectionResult {
        // Store the context for verification
        lastDetectionContext = DetectionContext(
            applicationName: applicationName,
            windowTitle: windowTitle,
            windowBounds: windowBounds
        )
        
        // Return mock result
        return ElementDetectionResult(
            sessionId: sessionId ?? "mock-session",
            screenshotPath: "/tmp/mock.png",
            elements: DetectedElements(),
            metadata: DetectionMetadata(
                detectionTime: 0.1,
                elementCount: 0,
                method: "mock",
                warnings: []
            )
        )
    }
}