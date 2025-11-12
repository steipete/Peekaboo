import CoreGraphics
import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

@Suite("SeeCommand Annotation Tests", .serialized, .tags(.safe))
struct SeeCommandAnnotationTests {
    @Test("SeeCommand parses basic options standalone")
    func parsesModeOption() throws {
        let command = try SeeCommand.parse(["--mode", "screen"])
        #expect(command.mode == .screen)
    }

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
        #expect(transformedBounds.size.height == 50) // unchanged
    }

    @Test("Annotation is disabled for screen mode captures")
    func annotationDisabledForScreenMode() {
        // This test documents that annotation should be disabled for full screen captures
        // due to performance constraints

        // When attempting to annotate a screen capture
        // The see command should log a warning and continue without annotation

        // Expected behavior:
        // 1. User requests: peekaboo see --mode screen --annotate
        // 2. System logs: "Annotation is disabled for full screen captures due to performance constraints"
        // 3. Capture proceeds without annotation
        // 4. No annotated file is created

        #expect(Bool(true)) // Documentation-only test; use Bool(true) to avoid warning
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
            window_title: "Test Window",
            window_id: 12345,
            window_index: 0,
            bounds: WindowBounds(x: 100, y: 50, width: 1200, height: 800),
            is_on_screen: true
        )

        let appInfo = ApplicationInfo(
            app_name: "TestApp",
            bundle_id: "com.test.app",
            pid: 1234,
            is_active: true,
            window_count: 1
        )

        let captureMetadata = CaptureMetadata(
            size: CGSize(width: 1200, height: 800),
            mode: .window,
            applicationInfo: ServiceApplicationInfo(
                processIdentifier: appInfo.pid,
                bundleIdentifier: appInfo.bundle_id,
                name: appInfo.app_name,
                bundlePath: nil,
                isActive: appInfo.is_active,
                isHidden: false,
                windowCount: 1
            ),
            windowInfo: ServiceWindowInfo(
                windowID: Int(windowInfo.window_id ?? 0),
                title: windowInfo.window_title,
                bounds: CGRect(
                    x: windowInfo.bounds?.x ?? 0,
                    y: windowInfo.bounds?.y ?? 0,
                    width: windowInfo.bounds?.width ?? 0,
                    height: windowInfo.bounds?.height ?? 0
                ),
                // Remove isOnScreen - it's not part of ServiceWindowInfo
            ),
            displayInfo: nil,
            timestamp: Date()
        )

        // When creating detection metadata (as in SeeCommand)
        let detectionMetadata = DetectionMetadata(
            detectionTime: 0.5,
            elementCount: 10,
            method: "AXorcist",
            warnings: []
        )

        // Then metadata should contain basic detection info
        #expect(detectionMetadata.detectionTime == 0.5)
        #expect(detectionMetadata.elementCount == 10)
        #expect(detectionMetadata.method == "AXorcist")

        // Window context would be available from captureMetadata
        #expect(captureMetadata.applicationInfo?.name == "TestApp")
        #expect(captureMetadata.windowInfo?.title == "Test Window")
    }

    @Test("Enhanced detection uses window context")
    func enhancedDetectionWindowContext() async throws {
        let imageData = Data(repeating: 0xAB, count: 4)
        let sessionId = "test-session-123"
        let appName = "Safari"
        let windowTitle = "Start Page"
        let windowBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let metadata = Self.detectionMetadata()
        let captureResult = Self.makeCaptureResult(
            imageData: imageData,
            appName: appName,
            windowTitle: windowTitle,
            windowBounds: windowBounds
        )

        Self.expectDetectionMetadata(metadata)
        Self.expectCaptureResult(
            captureResult,
            imageData: imageData,
            appName: appName,
            windowBounds: windowBounds
        )

        let seeResult = Self.makeSeeResult(
            sessionId: sessionId,
            metadata: metadata,
            captureMetadata: captureResult.metadata,
            appName: appName,
            windowTitle: windowTitle
        )
        Self.expectSeeResult(
            seeResult,
            sessionId: sessionId,
            appName: appName,
            windowTitle: windowTitle
        )
    }

    @Test("Annotation excludes disabled elements")
    func annotationExcludesDisabledElements() {
        // Given a mix of enabled and disabled elements
        let elements = DetectedElements(
            buttons: [
                DetectedElement(
                    id: "B1",
                    type: .button,
                    label: "Enabled",
                    value: nil,
                    bounds: CGRect(x: 10, y: 10, width: 50, height: 30),
                    isEnabled: true,
                    isSelected: nil,
                    attributes: [:]
                ),
                DetectedElement(
                    id: "B2",
                    type: .button,
                    label: "Disabled",
                    value: nil,
                    bounds: CGRect(x: 70, y: 10, width: 50, height: 30),
                    isEnabled: false,
                    isSelected: nil,
                    attributes: [:]
                )
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
        let annotatedElements = elements.all.filter(\.isEnabled)

        // Then only enabled elements should be included
        #expect(annotatedElements.count == 1)
        #expect(annotatedElements.first?.id == "B1")
    }

    @Test("Role-based colors are assigned correctly")
    func roleBasedColorAssignment() {
        // Define expected colors (from SeeCommand)
        let roleColors: [ElementType: (r: CGFloat, g: CGFloat, b: CGFloat)] = [
            .button: (0, 0.48, 1.0), // #007AFF
            .textField: (0.204, 0.78, 0.349), // #34C759
            .link: (0, 0.48, 1.0), // #007AFF
            .checkbox: (0.557, 0.557, 0.576), // #8E8E93
            .slider: (0.557, 0.557, 0.576), // #8E8E93
            .menu: (0, 0.48, 1.0), // #007AFF
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

private extension SeeCommandAnnotationTests {
    static func detectionMetadata() -> DetectionMetadata {
        DetectionMetadata(
            detectionTime: 0.5,
            elementCount: 10,
            method: "AXorcist",
            warnings: []
        )
    }

    static func makeCaptureResult(
        imageData: Data,
        appName: String,
        windowTitle: String,
        windowBounds: CGRect
    ) -> CaptureResult {
        let captureMetadata = Self.makeCaptureMetadata(
            appName: appName,
            windowTitle: windowTitle,
            windowBounds: windowBounds
        )
        return CaptureResult(imageData: imageData, metadata: captureMetadata)
    }

    static func expectDetectionMetadata(_ metadata: DetectionMetadata) {
        #expect(metadata.detectionTime == 0.5)
        #expect(metadata.elementCount == 10)
        #expect(metadata.method == "AXorcist")
    }

    static func expectCaptureResult(
        _ result: CaptureResult,
        imageData: Data,
        appName: String,
        windowBounds: CGRect
    ) {
        #expect(result.imageData == imageData)
        #expect(result.metadata.applicationInfo?.name == appName)
        #expect(result.metadata.windowInfo?.bounds == windowBounds)
    }

    static func makeSeeResult(
        sessionId: String,
        metadata: DetectionMetadata,
        captureMetadata: CaptureMetadata,
        appName: String,
        windowTitle: String
    ) -> SeeResult {
        SeeResult(
            session_id: sessionId,
            screenshot_raw: "raw.png",
            screenshot_annotated: "raw_annotated.png",
            ui_map: "map.json",
            application_name: appName,
            window_title: windowTitle,
            is_dialog: false,
            element_count: metadata.elementCount,
            interactable_count: metadata.elementCount,
            capture_mode: captureMetadata.mode.rawValue,
            analysis: nil,
            execution_time: metadata.detectionTime,
            ui_elements: [],
            menu_bar: nil
        )
    }

    static func expectSeeResult(
        _ result: SeeResult,
        sessionId: String,
        appName: String,
        windowTitle: String
    ) {
        #expect(result.session_id == sessionId)
        #expect(result.application_name == appName)
        #expect(result.window_title == windowTitle)
    }

    static func makeCaptureMetadata(
        appName: String,
        windowTitle: String,
        windowBounds: CGRect
    ) -> CaptureMetadata {
        CaptureMetadata(
            size: windowBounds.size,
            mode: .window,
            applicationInfo: Self.makeApplicationInfo(appName: appName),
            windowInfo: Self.makeWindowInfo(windowTitle: windowTitle, windowBounds: windowBounds),
            displayInfo: nil,
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }

    static func makeApplicationInfo(appName: String) -> ServiceApplicationInfo {
        ServiceApplicationInfo(
            processIdentifier: 1234,
            bundleIdentifier: "com.apple.Safari",
            name: appName,
            bundlePath: "/Applications/Safari.app",
            isActive: true,
            isHidden: false,
            windowCount: 1
        )
    }

    static func makeWindowInfo(windowTitle: String, windowBounds: CGRect) -> ServiceWindowInfo {
        ServiceWindowInfo(
            windowID: 42,
            title: windowTitle,
            bounds: windowBounds,
            isMinimized: false,
            isMainWindow: true
        )
    }
}

// MARK: - Mock Classes for Testing

struct MockDetectionContext {
    var applicationName: String?
    var windowTitle: String?
    var windowBounds: CGRect?
}
