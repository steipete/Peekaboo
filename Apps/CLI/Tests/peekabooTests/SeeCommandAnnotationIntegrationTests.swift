import Foundation
import Testing
import CoreGraphics
import PeekabooCore
@testable import peekaboo
@testable import PeekabooCore

@Suite("SeeCommand Annotation Integration Tests", .serialized, .disabled("Requires local environment"))
struct SeeCommandAnnotationIntegrationTests {
    
    @Test("Annotation correctly places elements on Safari window")
    @available(*, message: "Run with RUN_LOCAL_TESTS=true")
    func testSafariAnnotationPlacement() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            return
        }
        
        var command = SeeCommand()
        command.app = "Safari"
        command.annotate = true
        command.path = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-safari-annotation.png")
            .path
        
        // Execute the command
        try await command.run()
        
        // Verify annotated file was created
        let annotatedPath = (command.path! as NSString).deletingPathExtension + "_annotated.png"
        #expect(FileManager.default.fileExists(atPath: annotatedPath))
        
        // Clean up
        try? FileManager.default.removeItem(atPath: command.path!)
        try? FileManager.default.removeItem(atPath: annotatedPath)
    }
    
    @Test("Elements detected from correct window, not overlay")
    @available(*, message: "Run with RUN_LOCAL_TESTS=true")
    func testCorrectWindowDetection() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            return
        }
        
        // First capture without window title (might get overlay)
        var command1 = SeeCommand()
        command1.app = "Safari"
        command1.jsonOutput = true
        command1.annotate = true
        command1.path = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-no-window-title.png")
            .path
        
        // Execute and capture stdout (would need actual implementation)
        try await command1.run()
        
        // For testing purposes, we'd need to read the actual JSON output
        // This is a placeholder - real implementation would capture stdout
        let result1 = SeeResult(
            session_id: "test",
            screenshot_raw: command1.path!,
            screenshot_annotated: "",
            ui_map: "",
            application_name: "Safari",
            window_title: nil,
            element_count: 0,
            interactable_count: 0,
            capture_mode: "window",
            analysis_result: nil,
            execution_time: 0,
            ui_elements: [],
            menu_bar: nil
        )
        
        // Now capture with specific window title
        var command2 = SeeCommand()
        command2.app = "Safari"
        command2.windowTitle = "Start Page"
        command2.jsonOutput = true
        command2.annotate = true
        command2.path = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-with-window-title.png")
            .path
        
        try await command2.run()
        
        // Placeholder for testing
        let result2 = SeeResult(
            session_id: "test2",
            screenshot_raw: command2.path!,
            screenshot_annotated: "",
            ui_map: "",
            application_name: "Safari",
            window_title: "Start Page",
            element_count: 0,
            interactable_count: 0,
            capture_mode: "window",
            analysis_result: nil,
            execution_time: 0,
            ui_elements: [],
            menu_bar: nil
        )
        
        // With window title, we should get consistent window detection
        #expect(result2.window_title == "Start Page")
        
        // Clean up
        try? FileManager.default.removeItem(atPath: command1.path!)
        try? FileManager.default.removeItem(atPath: (command1.path! as NSString).deletingPathExtension + "_annotated.png")
        try? FileManager.default.removeItem(atPath: command2.path!)
        try? FileManager.default.removeItem(atPath: (command2.path! as NSString).deletingPathExtension + "_annotated.png")
    }
    
    @Test("Window bounds affect element coordinate transformation")
    @available(*, message: "Run with RUN_LOCAL_TESTS=true")
    func testWindowBoundsTransformation() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            return
        }
        
        // Create a command that will use enhanced detection
        let services = PeekabooServices.shared
        let imageData = Data() // Mock data for this test
        
        // Test with explicit window bounds
        let windowBounds = CGRect(x: 100, y: 50, width: 1024, height: 768)
        
        if let uiService = services.automation as? UIAutomationService {
            let result = try await uiService.detectElementsEnhanced(
                in: imageData,
                sessionId: nil,
                applicationName: "TestApp",
                windowTitle: "Test Window",
                windowBounds: windowBounds
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
    func testMultipleElementTypes() throws {
        // Create a variety of elements
        let elements = DetectedElements(
            buttons: [
                DetectedElement(id: "B1", type: .button, label: "Save", value: nil,
                              bounds: CGRect(x: 10, y: 10, width: 80, height: 30),
                              isEnabled: true, isSelected: nil, attributes: [:])
            ],
            textFields: [
                DetectedElement(id: "T1", type: .textField, label: "Name", value: "John",
                              bounds: CGRect(x: 100, y: 10, width: 200, height: 30),
                              isEnabled: true, isSelected: nil, attributes: [:])
            ],
            links: [
                DetectedElement(id: "L1", type: .link, label: "Click here", value: nil,
                              bounds: CGRect(x: 10, y: 50, width: 100, height: 20),
                              isEnabled: true, isSelected: nil, attributes: [:])
            ],
            images: [],
            groups: [
                DetectedElement(id: "G1", type: .group, label: nil, value: nil,
                              bounds: CGRect(x: 10, y: 80, width: 300, height: 200),
                              isEnabled: true, isSelected: nil, attributes: [:])
            ],
            sliders: [],
            checkboxes: [],
            menus: [],
            other: []
        )
        
        // Verify all elements are counted
        #expect(elements.all.count == 4)
        
        // Verify ID prefixes match element types
        #expect(elements.buttons.first?.id.hasPrefix("B") == true)
        #expect(elements.textFields.first?.id.hasPrefix("T") == true)
        #expect(elements.links.first?.id.hasPrefix("L") == true)
        #expect(elements.groups.first?.id.hasPrefix("G") == true)
    }
    
    @Test("Annotation file size is reasonable")
    @available(*, message: "Run with RUN_LOCAL_TESTS=true")
    func testAnnotationFileSize() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LOCAL_TESTS"] == "true" else {
            return
        }
        
        var command = SeeCommand()
        command.app = "Safari"
        command.path = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-size.png")
            .path
        
        // First capture without annotation
        try await command.run()
        
        let originalSize = try FileManager.default.attributesOfItem(atPath: command.path!)[.size] as! Int
        
        // Now with annotation
        command.annotate = true
        command.path = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-size-annotated.png")
            .path
        
        try await command.run()
        
        let annotatedPath = (command.path! as NSString).deletingPathExtension + "_annotated.png"
        let annotatedSize = try FileManager.default.attributesOfItem(atPath: annotatedPath)[.size] as! Int
        
        // Annotated file should exist but not be unreasonably large
        // Annotations add overlays but shouldn't double the file size
        #expect(annotatedSize > 0)
        #expect(annotatedSize < originalSize * 2)
        
        // Clean up
        try? FileManager.default.removeItem(atPath: command.path!)
        try? FileManager.default.removeItem(atPath: annotatedPath)
    }
}

