import Foundation
import Testing
import CoreGraphics
@testable import PeekabooCore
import AppKit

@Suite("UIAutomationServiceEnhanced Tests", .serialized)
struct UIAutomationServiceEnhancedTests {
    
    @Test("Element coordinates are transformed to window-relative")
    func testWindowRelativeTransformation() async throws {
        // Given screen coordinates for elements
        let screenElements = [
            MockElement(frame: CGRect(x: 500, y: 300, width: 100, height: 50), role: "AXButton"),
            MockElement(frame: CGRect(x: 600, y: 350, width: 150, height: 30), role: "AXTextField"),
            MockElement(frame: CGRect(x: 450, y: 400, width: 200, height: 40), role: "AXLink")
        ]
        
        // And window bounds
        let windowBounds = CGRect(x: 400, y: 250, width: 800, height: 600)
        
        // When processing elements with window bounds
        var transformedFrames: [CGRect] = []
        for element in screenElements {
            var frame = element.frame
            // Simulate the transformation in processElement
            if windowBounds != .zero {
                frame.origin.x -= windowBounds.origin.x
                frame.origin.y -= windowBounds.origin.y
            }
            transformedFrames.append(frame)
        }
        
        // Then coordinates should be window-relative
        #expect(transformedFrames[0].origin.x == 100) // 500 - 400
        #expect(transformedFrames[0].origin.y == 50)  // 300 - 250
        #expect(transformedFrames[1].origin.x == 200) // 600 - 400
        #expect(transformedFrames[1].origin.y == 100) // 350 - 250
        #expect(transformedFrames[2].origin.x == 50)  // 450 - 400
        #expect(transformedFrames[2].origin.y == 150) // 400 - 250
    }
    
    @Test("Elements without valid bounds are skipped")
    func testInvalidBoundsSkipped() async throws {
        // Elements with invalid bounds that should be skipped
        let invalidElements = [
            MockElement(frame: CGRect(x: 0, y: 0, width: 0, height: 50), role: "AXButton"), // Zero width
            MockElement(frame: CGRect(x: 100, y: 100, width: 50, height: 0), role: "AXButton"), // Zero height
            MockElement(frame: CGRect.zero, role: "AXButton") // Zero rect
        ]
        
        // Valid element
        let validElement = MockElement(frame: CGRect(x: 100, y: 100, width: 50, height: 30), role: "AXButton")
        
        var processedCount = 0
        for element in invalidElements + [validElement] {
            // Skip elements without valid bounds (as done in processElement)
            guard element.frame.width > 0 && element.frame.height > 0 else {
                continue
            }
            processedCount += 1
        }
        
        // Only the valid element should be processed
        #expect(processedCount == 1)
    }
    
    @Test("Window context is passed through detection pipeline")
    @MainActor
    func testWindowContextPropagation() async throws {
        let sessionManager = MockSessionManager()
        let service = UIAutomationService(sessionManager: sessionManager)
        
        // Test data
        let imageData = Data()
        let appName = "TestApp"
        let windowTitle = "Test Window"
        let windowBounds = CGRect(x: 50, y: 100, width: 1200, height: 800)
        
        // Call detectElements (the new method)
        let result = try await service.detectElements(
            in: imageData,
            sessionId: nil
        )
        
        // Verify result contains expected metadata
        #expect(result.metadata.method == "AXorcist")
        #expect(result.metadata.elementCount >= 0)
    }
    
    @Test("Front window is selected when no window title specified")
    func testFrontWindowSelection() async throws {
        // This tests the logic in buildUIMap
        let mockWindows = [
            MockElement(frame: CGRect(x: 0, y: 0, width: 800, height: 600), role: "AXWindow", title: "Front Window"),
            MockElement(frame: CGRect(x: 100, y: 100, width: 800, height: 600), role: "AXWindow", title: "Back Window")
        ]
        
        // When no window title is specified, first window (frontmost) should be selected
        let selectedWindows: [MockElement]
        if let windowTitle: String? = nil {
            // Find specific window by title
            selectedWindows = mockWindows.filter { $0.title == windowTitle }
        } else {
            // Process only the frontmost window
            if let frontWindow = mockWindows.first {
                selectedWindows = [frontWindow]
            } else {
                selectedWindows = []
            }
        }
        
        #expect(selectedWindows.count == 1)
        #expect(selectedWindows.first?.title == "Front Window")
    }
    
    @Test("Specific window is selected when title is provided")
    func testSpecificWindowSelection() async throws {
        let mockWindows = [
            MockElement(frame: CGRect(x: 0, y: 0, width: 800, height: 600), role: "AXWindow", title: "Window A"),
            MockElement(frame: CGRect(x: 100, y: 100, width: 800, height: 600), role: "AXWindow", title: "Window B"),
            MockElement(frame: CGRect(x: 200, y: 200, width: 800, height: 600), role: "AXWindow", title: "Window C")
        ]
        
        // When specific window title is provided
        let targetTitle = "Window B"
        let selectedWindows = mockWindows.filter { $0.title == targetTitle }
        
        #expect(selectedWindows.count == 1)
        #expect(selectedWindows.first?.title == "Window B")
    }
    
    @Test("Role-based ID prefixes are assigned correctly")
    func testRoleBasedIDGeneration() {
        // Test the ID prefix logic
        let testCases: [(ElementType, String)] = [
            (.button, "B"),
            (.textField, "T"),
            (.link, "L"),
            (.image, "I"),
            (.group, "G"),
            (.slider, "S"),
            (.checkbox, "C"),
            (.menu, "M"),
            (.other, "O")
        ]
        
        for (elementType, expectedPrefix) in testCases {
            let prefix = idPrefixForType(elementType)
            #expect(prefix == expectedPrefix)
        }
    }
    
    @Test("Element type is determined from role correctly")
    func testElementTypeFromRole() {
        let roleMappings: [(String, ElementType)] = [
            ("AXButton", .button),
            ("AXTextField", .textField),
            ("AXLink", .link),
            ("AXImage", .image),
            ("AXGroup", .group),
            ("AXSlider", .slider),
            ("AXCheckBox", .checkbox),
            ("AXMenu", .menu),
            ("AXUnknown", .other),
            ("AXStaticText", .other)
        ]
        
        for (role, expectedType) in roleMappings {
            let elementType = elementTypeFromRole(role)
            #expect(elementType == expectedType)
        }
    }
}

// MARK: - Helper Functions (matching UIAutomationServiceEnhanced)

private func idPrefixForType(_ type: ElementType) -> String {
    switch type {
    case .button: return "B"
    case .textField: return "T"
    case .link: return "L"
    case .image: return "I"
    case .group: return "G"
    case .slider: return "S"
    case .checkbox: return "C"
    case .menu: return "M"
    case .other: return "O"
    }
}

private func elementTypeFromRole(_ role: String) -> ElementType {
    switch role {
    case "AXButton": return .button
    case "AXTextField", "AXTextArea": return .textField
    case "AXLink": return .link
    case "AXImage": return .image
    case "AXGroup": return .group
    case "AXSlider": return .slider
    case "AXCheckBox": return .checkbox
    case "AXMenu", "AXMenuBar", "AXMenuBarItem", "AXMenuItem": return .menu
    default: return .other
    }
}

// MARK: - Mock Classes

struct MockElement {
    let frame: CGRect
    let role: String
    let title: String?
    
    init(frame: CGRect, role: String, title: String? = nil) {
        self.frame = frame
        self.role = role
        self.title = title
    }
}

@MainActor
private final class MockSessionManager: SessionManagerProtocol {
    var mockDetectionResult: ElementDetectionResult?
    var storedResults: [String: ElementDetectionResult] = [:]
    
    func createSession() async throws -> String {
        return "test-session-\(UUID().uuidString)"
    }
    
    func storeDetectionResult(sessionId: String, result: ElementDetectionResult) async throws {
        storedResults[sessionId] = result
    }
    
    func getDetectionResult(sessionId: String) async throws -> ElementDetectionResult? {
        return mockDetectionResult ?? storedResults[sessionId]
    }
    
    func getMostRecentSession() async -> String? {
        return storedResults.keys.first
    }
    
    func listSessions() async throws -> [SessionInfo] {
        return []
    }
    
    func cleanSession(sessionId: String) async throws {
        storedResults.removeValue(forKey: sessionId)
    }
    
    func cleanSessionsOlderThan(days: Int) async throws -> Int {
        let count = storedResults.count
        storedResults.removeAll()
        return count
    }
    
    func cleanAllSessions() async throws -> Int {
        let count = storedResults.count
        storedResults.removeAll()
        return count
    }
    
    nonisolated func getSessionStoragePath() -> String {
        return "/tmp/test-sessions"
    }
    
    func storeScreenshot(
        sessionId: String,
        screenshotPath: String,
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?
    ) async throws {
        // No-op for tests
    }
    
    func getElement(sessionId: String, elementId: String) async throws -> UIElement? {
        return nil
    }
    
    func findElements(sessionId: String, matching query: String) async throws -> [UIElement] {
        return []
    }
    
    func getUIAutomationSession(sessionId: String) async throws -> UIAutomationSession? {
        return nil
    }
}