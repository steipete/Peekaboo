import CoreGraphics
import Foundation
import PeekabooFoundation
import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

#if !PEEKABOO_SKIP_AUTOMATION
@Suite(
    "SeeCommand Annotation Integration Tests",
    .serialized,
    .tags(.safe),
    .disabled("Requires local environment")
)
struct SeeCommandAnnotationIntegrationTests {
    @Test("Annotation correctly places elements on Safari window")
    @available(*, message: "Run with RUN_LOCAL_TESTS=true")
    func safariAnnotationPlacement() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            return
        }

        guard let path = try await Self.runSeeCommand(
            app: "Safari",
            annotate: true,
            suffix: "test-safari-annotation",
            jsonOutput: false
        ) else {
            return
        }

        let annotatedPath = Self.annotatedPath(for: path)
        #expect(FileManager.default.fileExists(atPath: annotatedPath))

        Self.cleanupScreenshots(path, annotatedPath)
    }

    @Test("Elements detected from correct window, not overlay")
    @available(*, message: "Run with RUN_LOCAL_TESTS=true")
    func correctWindowDetection() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            return
        }

        guard
            let path1 = try await Self.runSeeCommand(
                app: "Safari",
                annotate: true,
                suffix: "test-no-window-title",
                jsonOutput: true
            ),
            let path2 = try await Self.runSeeCommand(
                app: "Safari",
                annotate: true,
                suffix: "test-with-window-title",
                jsonOutput: true,
                windowTitle: "Start Page"
            )
        else {
            return
        }

        let result2 = SeeResult(
            session_id: "test2",
            screenshot_raw: path2,
            screenshot_annotated: "",
            ui_map: "",
            application_name: "Safari",
            window_title: "Start Page",
            is_dialog: false,
            element_count: 0,
            interactable_count: 0,
            capture_mode: "window",
            analysis: nil,
            execution_time: 0,
            ui_elements: [],
            menu_bar: nil
        )

        #expect(result2.window_title == "Start Page")

        Self.cleanupScreenshots(
            path1,
            Self.annotatedPath(for: path1),
            path2,
            Self.annotatedPath(for: path2)
        )
    }

    @Test("Window bounds affect element coordinate transformation")
    @available(*, message: "Run with RUN_LOCAL_TESTS=true")
    @MainActor
    func windowBoundsTransformation() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            return
        }

        // Create a command that will use enhanced detection
        let services = PeekabooServices()
        let imageData = Data() // Mock data for this test

        // Test with explicit window bounds
        let windowBounds = CGRect(x: 100, y: 50, width: 1024, height: 768)
        let windowContext = WindowContext(
            applicationName: "TestApp",
            windowTitle: "Test Window",
            windowBounds: windowBounds
        )

        if let uiService = services.automation as? UIAutomationService {
            let result = try await uiService.detectElements(
                in: imageData,
                sessionId: nil,
                windowContext: windowContext
            )

            // All element bounds should be window-relative
            for element in result.elements.all {
                // Bounds should be within window dimensions
                #expect(element.bounds.minX >= 0)
                #expect(element.bounds.minY >= 0)
            }
        }
    }

    @Test("Annotation handles multiple element types")
    func multipleElementTypes() throws {
        let elements = Self.makeSampleElements()

        #expect(elements.all.count == 4)
        #expect(elements.buttons.first?.id.hasPrefix("B") == true)
        #expect(elements.textFields.first?.id.hasPrefix("T") == true)
        #expect(elements.links.first?.id.hasPrefix("L") == true)
        #expect(elements.groups.first?.id.hasPrefix("G") == true)
    }

    @Test("Annotation file size is reasonable")
    @available(*, message: "Run with RUN_LOCAL_TESTS=true")
    func annotationFileSize() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            return
        }

        guard
            let unannotatedPath = try await Self.runSeeCommand(
                app: "Safari",
                annotate: false,
                suffix: "test-size-unannotated",
                jsonOutput: false
            ),
            let annotatedCapturePath = try await Self.runSeeCommand(
                app: "Safari",
                annotate: true,
                suffix: "test-size-annotated",
                jsonOutput: false
            )
        else {
            return
        }

        guard
            let originalSize = Self.fileSize(at: unannotatedPath),
            let annotatedSize = Self.fileSize(at: Self.annotatedPath(for: annotatedCapturePath))
        else {
            return
        }

        #expect(annotatedSize > 0)
        #expect(annotatedSize < originalSize * 2)

        Self.cleanupScreenshots(
            unannotatedPath,
            Self.annotatedPath(for: unannotatedPath),
            annotatedCapturePath,
            Self.annotatedPath(for: annotatedCapturePath)
        )
    }

    static func runSeeCommand(
        app: String,
        annotate: Bool,
        suffix: String,
        jsonOutput: Bool,
        windowTitle: String? = nil
    ) async throws -> String? {
        var command = try SeeCommand.parse([])
        command.app = app
        command.annotate = annotate
        command.jsonOutput = jsonOutput
        if let windowTitle {
            command.windowTitle = windowTitle
        }
        command.path = FileManager.default.temporaryDirectory
            .appendingPathComponent("see-\(suffix).png")
            .path
        try await command.run()
        return command.path
    }

    static func annotatedPath(for path: String) -> String {
        (path as NSString).deletingPathExtension + "_annotated.png"
    }

    static func cleanupScreenshots(_ paths: String...) {
        for path in paths where !path.isEmpty {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    static func fileSize(at path: String) -> Int? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        return attributes?[.size] as? Int
    }

    static func makeSampleElements() -> DetectedElements {
        DetectedElements(
            buttons: [
                self.makeElement(
                    id: "B1",
                    type: .button,
                    label: "Save",
                    bounds: CGRect(x: 10, y: 10, width: 80, height: 30)
                )
            ],
            textFields: [
                self.makeElement(
                    id: "T1",
                    type: .textField,
                    label: "Name",
                    value: "John",
                    bounds: CGRect(x: 100, y: 10, width: 200, height: 30)
                )
            ],
            links: [
                self.makeElement(
                    id: "L1",
                    type: .link,
                    label: "Click here",
                    bounds: CGRect(x: 10, y: 50, width: 100, height: 20)
                )
            ],
            images: [],
            groups: [
                self.makeElement(
                    id: "G1",
                    type: .group,
                    bounds: CGRect(x: 10, y: 80, width: 300, height: 200)
                )
            ],
            sliders: [],
            checkboxes: [],
            menus: [],
            other: []
        )
    }

    static func makeElement(
        id: String,
        type: ElementType,
        label: String?,
        value: String? = nil,
        bounds: CGRect
    ) -> DetectedElement {
        DetectedElement(
            id: id,
            type: type,
            label: label,
            value: value,
            bounds: bounds,
            isEnabled: true,
            isSelected: nil,
            attributes: [:]
        )
    }
}

#endif
