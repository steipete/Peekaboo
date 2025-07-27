import Foundation
import CoreGraphics
import AXorcist

// MARK: - Element Tools

/// Element-focused tools for finding and listing UI elements
@available(macOS 14.0, *)
extension PeekabooAgentService {
    
    /// Create the find element tool
    func createFindElementTool() -> Tool<PeekabooServices> {
        createTool(
            name: "find_element",
            description: "Find a specific UI element by label or identifier",
            parameters: .object(
                properties: [
                    "label": ParameterSchema.string(
                        description: "Label or text to search for"
                    ),
                    "app": ParameterSchema.string(
                        description: "Optional: Application name to search within"
                    ),
                    "element_type": ParameterSchema.enumeration(
                        ["button", "text_field", "menu", "checkbox", "radio", "link"],
                        description: "Optional: Specific element type to find"
                    )
                ],
                required: ["label"]
            ),
            handler: { params, context in
                let label = try params.string("label")
                let appName = params.string("app", default: nil)
                let elementType = params.string("element_type", default: nil)
                
                // TODO: Replace with proper element finding implementation
                throw PeekabooError.serviceUnavailable("Element finding not yet implemented")
            }
        )
    }
    
    /// Create the list elements tool
    func createListElementsTool() -> Tool<PeekabooServices> {
        createTool(
            name: "list_elements",
            description: "List all interactive elements in the current view",
            parameters: .object(
                properties: [
                    "app": ParameterSchema.string(
                        description: "Optional: Application name to search within"
                    ),
                    "element_type": ParameterSchema.enumeration(
                        ["button", "text_field", "menu", "checkbox", "radio", "link", "all"],
                        description: "Optional: Filter by element type"
                    )
                ],
                required: []
            ),
            handler: { params, context in
                let appName = params.string("app", default: nil)
                let elementType = params.string("element_type", default: "all") ?? "all"
                
                // Capture screen or app to get elements
                let captureResult: CaptureResult
                let detectionResult: ElementDetectionResult
                
                if let appName = appName {
                    // Capture specific application
                    captureResult = try await context.screenCapture.captureWindow(
                        appIdentifier: appName,
                        windowIndex: nil
                    )
                } else {
                    // Capture entire screen
                    captureResult = try await context.screenCapture.captureScreen(displayIndex: nil)
                }
                
                // Detect elements in the screenshot
                detectionResult = try await context.automation.detectElements(
                    in: captureResult.imageData,
                    sessionId: nil
                )
                
                // Format the element list based on type filter
                let elements = detectionResult.elements
                let filteredOutput = formatFilteredElements(elements, filterType: elementType)
                
                return .success(
                    filteredOutput.description,
                    metadata: [
                        "elementCount": String(filteredOutput.totalCount),
                        "filter": elementType,
                        "app": appName ?? "all applications"
                    ]
                )
            }
        )
    }
    
    /// Create the focused element tool
    func createFocusedTool() -> Tool<PeekabooServices> {
        createSimpleTool(
            name: "focused",
            description: "Get information about the currently focused element",
            handler: { context in
                // TODO: Replace with proper focused element implementation
                throw PeekabooError.serviceUnavailable("Focused element detection not yet implemented")
            }
        )
    }
}

// MARK: - Helper Functions

private func mapElementTypeToRole(_ elementType: String) -> String {
    switch elementType.lowercased() {
    case "button": return "AXButton"
    case "text_field": return "AXTextField"
    case "menu": return "AXMenu"
    case "checkbox": return "AXCheckBox"
    case "radio": return "AXRadioButton"
    case "link": return "AXLink"
    default: return elementType
    }
}

private func formatFilteredElements(_ elements: DetectedElements, filterType: String) -> (description: String, totalCount: Int) {
    var output = ""
    var totalCount = 0
    
    switch filterType.lowercased() {
    case "button":
        if !elements.buttons.isEmpty {
            output += "BUTTONS:\n"
            for button in elements.buttons {
                output += formatElement(button)
            }
            totalCount = elements.buttons.count
        }
        
    case "text_field":
        if !elements.textFields.isEmpty {
            output += "TEXT FIELDS:\n"
            for field in elements.textFields {
                output += formatElement(field)
            }
            totalCount = elements.textFields.count
        }
        
    case "link":
        if !elements.links.isEmpty {
            output += "LINKS:\n"
            for link in elements.links {
                output += formatElement(link)
            }
            totalCount = elements.links.count
        }
        
    case "menu":
        if !elements.menus.isEmpty {
            output += "MENUS:\n"
            for menu in elements.menus {
                output += formatElement(menu)
            }
            totalCount = elements.menus.count
        }
        
    default: // "all"
        // Count all elements
        let totalCount = elements.buttons.count + elements.textFields.count + 
                        elements.links.count + elements.menus.count + 
                        elements.other.count + elements.images.count +
                        elements.checkboxes.count + elements.sliders.count + 
                        elements.groups.count
        
        // Format all elements
        var output = ""
        if !elements.buttons.isEmpty {
            output += "BUTTONS:\n"
            for button in elements.buttons {
                output += formatElement(button)
            }
            output += "\n"
        }
        if !elements.textFields.isEmpty {
            output += "TEXT FIELDS:\n"
            for field in elements.textFields {
                output += formatElement(field)
            }
            output += "\n"
        }
        if !elements.links.isEmpty {
            output += "LINKS:\n"
            for link in elements.links {
                output += formatElement(link)
            }
            output += "\n"
        }
        if !elements.menus.isEmpty {
            output += "MENUS:\n"
            for menu in elements.menus {
                output += formatElement(menu)
            }
            output += "\n"
        }
        if !elements.other.isEmpty {
            output += "OTHER ELEMENTS:\n"
            for element in elements.other {
                output += formatElement(element)
            }
            output += "\n"
        }
        
        if output.isEmpty {
            output = "No interactive elements found"
        }
        
        return (output, totalCount)
    }
    
    if output.isEmpty {
        output = "No \(filterType) elements found"
    }
    
    return (output, totalCount)
}

private func formatElement(_ element: DetectedElement) -> String {
    let displayText = element.label ?? element.value ?? "Unlabeled \(element.type)"
    var output = "  • \(displayText) [\(Int(element.bounds.minX)),\(Int(element.bounds.minY))]"
    if !element.isEnabled {
        output += " (disabled)"
    }
    output += "\n"
    return output
}