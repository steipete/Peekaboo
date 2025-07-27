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
                    "label": .string(
                        description: "Label or text to search for",
                        required: true
                    ),
                    "app": .string(
                        description: "Optional: Application name to search within",
                        required: false
                    ),
                    "element_type": .string(
                        description: "Optional: Specific element type to find",
                        required: false,
                        enum: ["button", "text_field", "menu", "checkbox", "radio", "link"]
                    )
                ],
                required: ["label"]
            ),
            handler: { params, context in
                let label = try params.string("label")
                let appName = params.string("app")
                let elementType = params.string("element_type")
                
                // TODO: Replace with proper element finding implementation
                throw PeekabooError.notImplemented("Element finding not yet implemented")
                
                // Commented out until element finding is implemented
                /*
                let criteria: UIElementSearchCriteria = .label(label)
                
                let element = try await findElementWithRetry(
                    criteria: criteria,
                    in: appName,
                    context: context
                )
                
                let role = try await element.role()
                let bounds = try await element.frame()
                let isEnabled = try await element.isEnabled()
                let value = try? await element.value()
                */
                
                // Check if type matches if specified
                if let elementType = elementType {
                    let expectedRole = mapElementTypeToRole(elementType)
                    if role != expectedRole {
                        throw PeekabooError.elementNotFound(
                            type: elementType,
                            in: "Found element '\(label)' but it's a \(role)"
                        )
                    }
                }
                
                var output = "Found element: \(label)\n"
                output += "Type: \(role)\n"
                output += "Position: (\(Int(bounds.minX)), \(Int(bounds.minY)))\n"
                output += "Size: \(Int(bounds.width)) x \(Int(bounds.height))\n"
                output += "Enabled: \(isEnabled)\n"
                
                if let value = value as? String, !value.isEmpty {
                    output += "Value: \(value)"
                }
                
                return .success(
                    output,
                    metadata: "label", label,
                    "role", role,
                    "x", String(Int(bounds.minX)),
                    "y", String(Int(bounds.minY)),
                    "width", String(Int(bounds.width)),
                    "height", String(Int(bounds.height)),
                    "enabled", String(isEnabled)
                )
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
                    "app": .string(
                        description: "Optional: Application name to search within",
                        required: false
                    ),
                    "element_type": .string(
                        description: "Optional: Filter by element type",
                        required: false,
                        enum: ["button", "text_field", "menu", "checkbox", "radio", "link", "all"]
                    )
                ],
                required: []
            ),
            handler: { params, context in
                let appName = params.string("app")
                let elementType = params.string("element_type", default: "all") ?? "all"
                
                // Capture screen or app to get elements
                let result: CaptureResultWithElements
                if let appName = appName {
                    let windows = try await context.windowManagement.listWindows()
                    let window = try windows.findWindow(byAppName: appName)
                    
                    let windowElement = try await context.uiAutomation.findWindow(
                        matching: .title(window.title),
                        in: appName
                    )
                    let bounds = try await windowElement.frame()
                    
                    result = try await context.screenCapture.captureWindowWithElements(
                        windowID: window.windowID,
                        windowBounds: bounds
                    )
                } else {
                    result = try await context.screenCapture.captureScreenWithElements()
                }
                
                // Format the element list based on type filter
                let elements = result.elements
                let filteredOutput = formatFilteredElements(elements, filterType: elementType)
                
                return .success(
                    filteredOutput.description,
                    metadata: "elementCount", String(filteredOutput.totalCount),
                    "filter", elementType,
                    "app", appName ?? "all applications"
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
                let focusInfo = try await context.uiAutomation.getFocusedElement()
                
                var output = "Currently focused element:\n\n"
                output += "Application: \(focusInfo.app)\n"
                output += "Element: \(focusInfo.element.title ?? focusInfo.element.description ?? "Untitled")\n"
                output += "Type: \(focusInfo.element.role)\n"
                output += "Position: (\(Int(focusInfo.element.bounds.minX)), \(Int(focusInfo.element.bounds.minY)))\n"
                
                if let value = focusInfo.element.value, !value.isEmpty {
                    output += "Value: \(value)\n"
                }
                
                output += "Can type: \(focusInfo.canAcceptKeyboardInput ? "Yes" : "No")"
                
                return .success(
                    output,
                    metadata: "app", focusInfo.app,
                    "bundleId", focusInfo.bundleId,
                    "role", focusInfo.element.role,
                    "canType", String(focusInfo.canAcceptKeyboardInput)
                )
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
        return (formatElementList(elements, filterType: "all").description, 
                elements.buttons.count + elements.textFields.count + 
                elements.links.count + elements.menus.count + 
                elements.staticTexts.count + elements.images.count)
    }
    
    if output.isEmpty {
        output = "No \(filterType) elements found"
    }
    
    return (output, totalCount)
}

private func formatElement(_ element: DetectedElement) -> String {
    var output = "  • \(element.label) [\(Int(element.bounds.minX)),\(Int(element.bounds.minY))]"
    if !element.enabled {
        output += " (disabled)"
    }
    output += "\n"
    return output
}