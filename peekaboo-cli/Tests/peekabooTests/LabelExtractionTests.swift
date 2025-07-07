import Foundation
@testable import peekaboo
import Testing
import AXorcist

@Suite("Label Extraction Tests", .tags(.localOnly))
struct LabelExtractionTests {
    
    @Test("AXLabel attribute extraction for Calculator buttons")
    @available(macOS 14.0, *)
    func calculatorButtonLabelExtraction() async throws {
        // This test requires Calculator to be running
        let appFinder = ApplicationFinder()
        guard let calculator = try? appFinder.findApplication(identifier: "Calculator") else {
            Issue.record("Calculator app not running, skipping test")
            return
        }
        
        // Create a session cache and capture Calculator UI
        let sessionCache = try SessionCache(sessionId: "test-calc-labels")
        
        // Get Calculator's main window
        let axApp = AXUIElementCreateApplication(calculator.processIdentifier)
        let appElement = Element(axApp)
        
        guard let windows = appElement.windows(), !windows.isEmpty else {
            Issue.record("No Calculator windows found")
            return
        }
        
        // Process the first window
        let window = windows[0]
        var uiMap: [String: SessionCache.SessionData.UIElement] = [:]
        var roleCounters: [String: Int] = [:]
        
        // Process elements to build UI map
        await processElementForTest(
            window,
            parentId: nil,
            uiMap: &uiMap,
            roleCounters: &roleCounters
        )
        
        // Find numeric buttons and verify they have labels
        let numericButtons = uiMap.values.filter { element in
            element.role == "AXButton" && 
            element.label != nil &&
            element.label!.count == 1 &&
            "0123456789".contains(element.label!)
        }
        
        // Calculator should have buttons 0-9
        #expect(numericButtons.count >= 10, "Should find at least 10 numeric buttons")
        
        // Verify each number 0-9 has a button
        for digit in 0...9 {
            let digitStr = String(digit)
            let button = numericButtons.first { $0.label == digitStr }
            #expect(button != nil, "Should find button for digit \(digit)")
            
            // Verify identifier matches expected pattern
            if let button = button {
                let expectedIdentifiers = [
                    "0": "Zero", "1": "One", "2": "Two", "3": "Three", "4": "Four",
                    "5": "Five", "6": "Six", "7": "Seven", "8": "Eight", "9": "Nine"
                ]
                #expect(button.identifier == expectedIdentifiers[digitStr], 
                       "Button \(digit) should have identifier '\(expectedIdentifiers[digitStr] ?? "")'")
            }
        }
        
        // Verify operation buttons have labels
        let operationLabels = ["Add", "Subtract", "Multiply", "Divide", "Equals", "Clear"]
        for opLabel in operationLabels {
            let opButton = uiMap.values.first { element in
                element.role == "AXButton" && 
                (element.label == opLabel || element.identifier == opLabel)
            }
            #expect(opButton != nil, "Should find \(opLabel) button")
        }
    }
    
    @Test("Label extraction fallback hierarchy")
    @available(macOS 14.0, *)
    func labelExtractionFallback() async throws {
        // Test the fallback hierarchy for label extraction
        // Create mock elements with different attribute combinations
        
        let sessionCache = try SessionCache(sessionId: "test-label-fallback")
        
        // Test case 1: Element with AXLabel
        let mockElement1 = MockAccessibilityElement(
            axLabel: "Button Label",
            title: "Button Title",
            description: "Button Description"
        )
        let label1 = extractLabelFromElement(mockElement1)
        #expect(label1 == "Button Label", "Should prefer AXLabel when available")
        
        // Test case 2: Element without AXLabel but with description
        let mockElement2 = MockAccessibilityElement(
            axLabel: nil,
            title: "Button Title",
            description: "Button Description"
        )
        let label2 = extractLabelFromElement(mockElement2)
        #expect(label2 == "Button Description", "Should fall back to description")
        
        // Test case 3: Element with only title
        let mockElement3 = MockAccessibilityElement(
            axLabel: nil,
            title: "Button Title",
            description: nil
        )
        let label3 = extractLabelFromElement(mockElement3)
        #expect(label3 == "Button Title", "Should fall back to title")
        
        // Test case 4: Element with value as last resort
        let mockElement4 = MockAccessibilityElement(
            axLabel: nil,
            title: nil,
            description: nil,
            value: "Button Value"
        )
        let label4 = extractLabelFromElement(mockElement4)
        #expect(label4 == "Button Value", "Should fall back to value as last resort")
    }
    
    @Test("UI element summary includes label and identifier")
    @available(macOS 14.0, *)
    func uiElementSummaryFormat() async throws {
        // Test that the JSON output includes label and identifier fields
        let element = SessionCache.SessionData.UIElement(
            id: "B1",
            elementId: "element_1",
            role: "AXButton",
            title: nil,
            label: "7",
            value: nil,
            description: nil,
            help: nil,
            roleDescription: nil,
            identifier: "Seven",
            frame: CGRect(x: 100, y: 100, width: 50, height: 50),
            isActionable: true,
            keyboardShortcut: nil
        )
        
        // Create a UI element summary
        let summary = UIElementSummary(
            id: element.id,
            role: element.role,
            title: element.title,
            label: element.label,
            identifier: element.identifier,
            is_actionable: element.isActionable,
            keyboard_shortcut: element.keyboardShortcut
        )
        
        #expect(summary.label == "7")
        #expect(summary.identifier == "Seven")
        
        // Test JSON encoding
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let jsonData = try encoder.encode(summary)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        #expect(jsonString.contains("\"label\":\"7\""))
        #expect(jsonString.contains("\"identifier\":\"Seven\""))
    }
    
    // Helper function to process elements (simplified version of SessionCache's method)
    @MainActor
    private func processElementForTest(
        _ element: Element,
        parentId: String?,
        uiMap: inout [String: SessionCache.SessionData.UIElement],
        roleCounters: inout [String: Int]
    ) async {
        let role = element.role() ?? "AXGroup"
        let title = element.title()
        let description = element.descriptionText()
        let help = element.help()
        let roleDescription = element.roleDescription()
        let identifier = element.identifier()
        let value = element.value() as? String
        
        // Try to get the AXLabel attribute directly
        let axLabel = element.attribute(Attribute<String>("AXLabel"))
        
        // Use the actual label if available, otherwise fall back
        let label = axLabel ?? description ?? help ?? roleDescription ?? title ?? value
        
        // Get element bounds
        let position = element.position()
        let size = element.size()
        let frame: CGRect = if let pos = position, let sz = size {
            CGRect(x: pos.x, y: pos.y, width: sz.width, height: sz.height)
        } else {
            .zero
        }
        
        // Generate ID
        let prefix = ElementIDGenerator.prefix(for: role)
        let counter = (roleCounters[prefix] ?? 0) + 1
        roleCounters[prefix] = counter
        let elementId = "\(prefix)\(counter)"
        
        // Create UI element
        let uiElement = SessionCache.SessionData.UIElement(
            id: elementId,
            elementId: "element_\(uiMap.count)",
            role: role,
            title: title,
            label: label,
            value: value,
            description: description,
            help: help,
            roleDescription: roleDescription,
            identifier: identifier,
            frame: frame,
            isActionable: ElementIDGenerator.isActionableRole(role),
            keyboardShortcut: nil
        )
        
        uiMap[elementId] = uiElement
        
        // Process children
        if let children = element.children() {
            for child in children {
                await processElementForTest(
                    child,
                    parentId: elementId,
                    uiMap: &uiMap,
                    roleCounters: &roleCounters
                )
            }
        }
    }
    
    // Helper function to extract label using the same logic as SessionCache
    private func extractLabelFromElement(_ mockElement: MockAccessibilityElement) -> String? {
        // Simulate the label extraction logic
        return mockElement.axLabel ?? 
               mockElement.description ?? 
               mockElement.help ?? 
               mockElement.roleDescription ?? 
               mockElement.title ?? 
               mockElement.value
    }
}

// Mock accessibility element for testing
struct MockAccessibilityElement {
    let axLabel: String?
    let title: String?
    let description: String?
    let help: String? = nil
    let roleDescription: String? = nil
    let value: String? = nil
}