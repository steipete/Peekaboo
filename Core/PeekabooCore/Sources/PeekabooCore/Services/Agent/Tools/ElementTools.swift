import AXorcist
import CoreGraphics
import Foundation
import Tachikoma

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
                        description: "Label or text to search for"),
                    "app": ParameterSchema.string(
                        description: "Optional: Application name to search within"),
                    "element_type": ParameterSchema.enumeration(
                        ["button", "text_field", "menu", "checkbox", "radio", "link"],
                        description: "Optional: Specific element type to find"),
                ],
                required: ["label"]),
            execute: { params, context in
                let searchLabel = try params.string("label")
                let appName = params.string("app", default: nil)
                let elementType = params.string("element_type", default: nil)

                let startTime = Date()
                let targetDescription = appName ?? "entire screen"

                // Always search by label since that's what the user is looking for
                let searchCriteria = UIElementSearchCriteria.label(searchLabel ?? "")

                do {
                    let element = try await context.automation.findElement(
                        matching: searchCriteria,
                        in: appName)

                    _ = Date().timeIntervalSince(startTime)

                    // If element type was specified, verify it matches
                    if let elementType {
                        let expectedType = mapElementTypeToElementType(elementType)
                        if element.type != expectedType {
                            var notFoundMessage = "No elements found matching '\(searchLabel)'"
                            notFoundMessage += " of type '\(elementType)'"
                            notFoundMessage += " in \(targetDescription)"
                            return .error(message: notFoundMessage)
                        }
                    }

                    // Format the result
                    let displayText = element.label ?? element.value ?? "Unlabeled \(element.type)"
                    var description = "Found element matching '\(searchLabel)'"
                    if let elementType {
                        description += " of type '\(elementType)'"
                    }
                    description += " in \(targetDescription):\n"

                    description += "\n\(displayText)"
                    description += "\n   ID: \(element.id)"
                    description += "\n   Type: \(element.type)"
                    description += "\n   Position: [\(Int(element.bounds.minX)), \(Int(element.bounds.minY))]"
                    description += "\n   Size: \(Int(element.bounds.width))×\(Int(element.bounds.height))"
                    if !element.isEnabled {
                        description += "\n   Status: Disabled"
                    }

                    return .success(description)
                } catch {
                    var notFoundMessage = "No elements found matching '\(searchLabel)'"
                    if let elementType {
                        notFoundMessage += " of type '\(elementType)'"
                    }
                    notFoundMessage += " in \(targetDescription)"
                    return .error(message: notFoundMessage)
                }
            })
    }

    /// Create the list elements tool
    func createListElementsTool() -> Tool<PeekabooServices> {
        createTool(
            name: "list_elements",
            description: "List all interactive elements in the current view",
            parameters: .object(
                properties: [
                    "app": ParameterSchema.string(
                        description: "Optional: Application name to search within"),
                    "element_type": ParameterSchema.enumeration(
                        ["button", "text_field", "menu", "checkbox", "radio", "link", "all"],
                        description: "Optional: Filter by element type"),
                ],
                required: []),
            execute: { params, context in
                let appName = params.string("app", default: nil)
                let elementType = params.string("element_type", default: "all") ?? "all"

                let startTime = Date()

                // Capture screen or app to get elements
                let captureResult: CaptureResult
                let detectionResult: ElementDetectionResult

                let targetDescription: String
                if let appName {
                    // Capture specific application
                    captureResult = try await context.screenCapture.captureWindow(
                        appIdentifier: appName,
                        windowIndex: nil)
                    targetDescription = appName
                } else {
                    // Capture entire screen
                    captureResult = try await context.screenCapture.captureScreen(displayIndex: nil)
                    targetDescription = "entire screen"
                }

                // Detect elements in the screenshot
                detectionResult = try await context.automation.detectElements(
                    in: captureResult.imageData,
                    sessionId: nil,
                    windowContext: nil)

                _ = Date().timeIntervalSince(startTime)

                // Format the element list based on type filter
                let elements = detectionResult.elements
                let filteredOutput = formatFilteredElements(elements, filterType: elementType)

                // Create a better summary
                var summary = "Found \(filteredOutput.totalCount) "
                if elementType != "all" {
                    summary += "\(elementType) "
                }
                summary += "elements in \(targetDescription)"

                // Add breakdown if showing all elements
                if elementType == "all", filteredOutput.totalCount > 0 {
                    var breakdown: [String] = []
                    if !elements.buttons.isEmpty {
                        let enabledButtons = elements.buttons.count(where: { $0.isEnabled })
                        let disabledButtons = elements.buttons.count - enabledButtons
                        if disabledButtons > 0 {
                            breakdown
                                .append(
                                    "Buttons: \(elements.buttons.count) (\(enabledButtons) enabled, \(disabledButtons) disabled)")
                        } else {
                            breakdown.append("Buttons: \(elements.buttons.count)")
                        }
                    }
                    if !elements.textFields.isEmpty {
                        breakdown.append("Text Fields: \(elements.textFields.count)")
                    }
                    if !elements.links.isEmpty {
                        breakdown.append("Links: \(elements.links.count)")
                    }
                    if !elements.other.isEmpty {
                        breakdown.append("Text: \(elements.other.count)")
                    }

                    if !breakdown.isEmpty {
                        summary = "\(summary)\n  " + breakdown.joined(separator: "\n  ")
                    }
                }

                return .success(filteredOutput.description)
            })
    }

    /// Create the focused element tool
    func createFocusedTool() -> Tool<PeekabooServices> {
        createSimpleTool(
            name: "focused",
            description: "Get information about the currently focused element",
            execute: { _, context in
                // Get focused element information
                guard let focusInfo = context.automation.getFocusedElement() else {
                    return .error(message: "No element is currently focused")
                }

                // Format the focused element information
                var description = "Focused Element: \(focusInfo.role)"
                if let title = focusInfo.title {
                    description += " - \"\(title)\""
                }
                if let value = focusInfo.value, !value.isEmpty {
                    description += "\nValue: \(value)"
                }

                description += "\nApplication: \(focusInfo.applicationName)"
                description += "\nPosition: [\(Int(focusInfo.frame.origin.x)), \(Int(focusInfo.frame.origin.y))]"
                description += "\nSize: \(Int(focusInfo.frame.size.width))×\(Int(focusInfo.frame.size.height))"

                return .success(description)
            })
    }
}

// MARK: - Helper Functions

private func mapElementTypeToRole(_ elementType: String) -> String {
    switch elementType.lowercased() {
    case "button": "AXButton"
    case "text_field": "AXTextField"
    case "menu": "AXMenu"
    case "checkbox": "AXCheckBox"
    case "radio": "AXRadioButton"
    case "link": "AXLink"
    default: elementType
    }
}

private func mapElementTypeToElementType(_ elementType: String) -> ElementType {
    switch elementType.lowercased() {
    case "button": .button
    case "text_field": .textField
    case "menu": .menu
    case "checkbox": .checkbox
    case "radio": .checkbox // Radio buttons are treated as checkboxes in ElementType
    case "link": .link
    default: .other
    }
}

private func formatFilteredElements(
    _ elements: DetectedElements,
    filterType: String) -> (description: String, totalCount: Int)
{
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
