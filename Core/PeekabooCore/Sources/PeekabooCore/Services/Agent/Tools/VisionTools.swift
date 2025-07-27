import Foundation
import CoreGraphics
import AXorcist

// MARK: - Vision Tools

/// Vision-related tools for screen capture and analysis
@available(macOS 14.0, *)
extension PeekabooAgentService {
    
    /// Create the primary 'see' tool for capturing and analyzing UI
    func createSeeTool() -> Tool<PeekabooServices> {
        createTool(
            name: "see",
            description: "Capture and analyze the screen or a specific application window. This is your primary tool for understanding the current UI state.",
            parameters: .object(
                properties: [
                    "app": .string(
                        description: "Optional: Application name to capture (e.g., 'Safari', 'Finder'). If not specified, captures the entire screen.",
                        required: false
                    ),
                    "format": .string(
                        description: "Output format - 'full' (default) for detailed element list with coordinates, or 'brief' for a summary",
                        required: false,
                        enum: ["full", "brief"]
                    ),
                    "filter": .string(
                        description: "Optional: Filter elements by type (button, text_field, image, link, menu, static_text)",
                        required: false,
                        enum: ["button", "text_field", "image", "link", "menu", "static_text"]
                    )
                ],
                required: []
            ),
            handler: { params, context in
                let appName = params.string("app")
                let format = params.string("format", default: "full") ?? "full"
                let filterType = params.string("filter")
                
                let result: CaptureResultWithElements
                
                if let appName = appName {
                    // Capture specific application
                    let windows = try await context.windowManagement.listWindows()
                    let window = try windows.findWindow(byAppName: appName)
                    
                    // Get window bounds for element detection
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
                    // Capture entire screen
                    result = try await context.screenCapture.captureScreenWithElements()
                }
                
                // Filter elements if requested
                var elements = result.elements
                if let filterType = filterType {
                    elements.buttons = filterType == "button" ? elements.buttons : []
                    elements.textFields = filterType == "text_field" ? elements.textFields : []
                    elements.images = filterType == "image" ? elements.images : []
                    elements.links = filterType == "link" ? elements.links : []
                    elements.menus = filterType == "menu" ? elements.menus : []
                    elements.staticTexts = filterType == "static_text" ? elements.staticTexts : []
                }
                
                // Format output based on requested format
                if format == "brief" {
                    var summary = "Screen captured successfully.\n\n"
                    summary += "UI Elements Found:\n"
                    if !elements.buttons.isEmpty {
                        summary += "- \(elements.buttons.count) buttons\n"
                    }
                    if !elements.textFields.isEmpty {
                        summary += "- \(elements.textFields.count) text fields\n"
                    }
                    if !elements.links.isEmpty {
                        summary += "- \(elements.links.count) links\n"
                    }
                    if !elements.staticTexts.isEmpty {
                        summary += "- \(elements.staticTexts.count) text elements\n"
                    }
                    
                    return .success(
                        summary,
                        metadata: "path", result.imagePath,
                        "resolution", "\(result.width)x\(result.height)",
                        "app", appName ?? "entire screen"
                    )
                }
                
                // Full format with detailed element list
                let elementList = formatElementList(
                    elements, 
                    filterType: filterType ?? "all"
                )
                
                return .success(
                    elementList.description,
                    metadata: "path", result.imagePath,
                    "resolution", "\(result.width)x\(result.height)",
                    "elementCount", String(elementList.totalCount),
                    "app", appName ?? "entire screen"
                )
            }
        )
    }
    
    /// Create the screenshot tool for saving screen captures
    func createScreenshotTool() -> Tool<PeekabooServices> {
        createTool(
            name: "screenshot",
            description: "Take a screenshot and save it to a file",
            parameters: .object(
                properties: [
                    "path": .string(
                        description: "Path to save the screenshot (e.g., ~/Desktop/screenshot.png)",
                        required: true
                    ),
                    "app": .string(
                        description: "Optional: Application name to capture. If not specified, captures entire screen",
                        required: false
                    )
                ],
                required: ["path"]
            ),
            handler: { params, context in
                let path = try params.string("path")
                let expandedPath = path.expandedPath
                let appName = params.string("app")
                
                let captureResult: CaptureResult
                
                if let appName = appName {
                    // Find the window
                    let windows = try await context.windowManagement.listWindows()
                    let window = try windows.findWindow(byAppName: appName)
                    
                    captureResult = try await context.screenCapture.captureWindow(windowID: window.windowID)
                } else {
                    captureResult = try await context.screenCapture.captureScreen()
                }
                
                // Save to the specified path
                try await context.file.saveScreenshot(captureResult.imagePath, to: expandedPath)
                
                return .success(
                    "Screenshot saved to \(expandedPath)",
                    metadata: "path", expandedPath,
                    "resolution", "\(captureResult.width)x\(captureResult.height)",
                    "source", appName ?? "entire screen"
                )
            }
        )
    }
    
    /// Create the window capture tool
    func createWindowCaptureTool() -> Tool<PeekabooServices> {
        createTool(
            name: "window_capture",
            description: "Capture a specific window by title or window ID",
            parameters: .object(
                properties: [
                    "title": .string(
                        description: "Window title to search for (partial match supported)",
                        required: false
                    ),
                    "window_id": .integer(
                        description: "Specific window ID to capture",
                        required: false
                    ),
                    "save_path": .string(
                        description: "Optional: Path to save the screenshot",
                        required: false
                    )
                ],
                required: []
            ),
            handler: { params, context in
                let title = params.string("title")
                let windowId = params.int("window_id").map { CGWindowID($0) }
                let savePath = params.string("save_path")
                
                guard title != nil || windowId != nil else {
                    throw PeekabooError.invalidInput("Either 'title' or 'window_id' must be provided")
                }
                
                let windows = try await context.windowManagement.listWindows()
                
                let window: WindowInfo
                if let windowId = windowId {
                    window = try windows.findWindow(byID: windowId)
                } else if let title = title {
                    window = try windows.findWindow(byTitle: title)
                } else {
                    throw PeekabooError.windowNotFound(criteria: "no criteria provided")
                }
                
                let result = try await context.screenCapture.captureWindowWithElements(
                    windowID: window.windowID,
                    windowBounds: CGRect(origin: window.position, size: window.size)
                )
                
                // Save if path provided
                if let savePath = savePath {
                    let expandedPath = savePath.expandedPath
                    try await context.file.saveScreenshot(result.imagePath, to: expandedPath)
                }
                
                return .success(
                    formatElementList(result.elements, filterType: "all").description,
                    metadata: "window", window.title,
                    "app", window.applicationName,
                    "path", savePath?.expandedPath ?? result.imagePath,
                    "resolution", "\(result.width)x\(result.height)"
                )
            }
        )
    }
}

// MARK: - Helper Functions

/// Format detected elements into a structured list
private func formatElementList(_ elements: DetectedElements, filterType: String) -> ToolOutput {
    var output = ""
    var totalCount = 0
    
    // Buttons
    if !elements.buttons.isEmpty && (filterType == "all" || filterType == "button") {
        output += "BUTTONS:\n"
        for button in elements.buttons {
            output += "  • \(button.label) [\(Int(button.bounds.minX)),\(Int(button.bounds.minY))]"
            if button.enabled {
                output += " (enabled)"
            } else {
                output += " (disabled)"
            }
            output += "\n"
        }
        output += "\n"
        totalCount += elements.buttons.count
    }
    
    // Text Fields
    if !elements.textFields.isEmpty && (filterType == "all" || filterType == "text_field") {
        output += "TEXT FIELDS:\n"
        for field in elements.textFields {
            output += "  • \(field.label.isEmpty ? "Unlabeled" : field.label) [\(Int(field.bounds.minX)),\(Int(field.bounds.minY))]"
            if !field.value.isEmpty {
                output += " (value: \(field.value))"
            }
            if field.enabled {
                output += " (enabled)"
            } else {
                output += " (disabled)"
            }
            output += "\n"
        }
        output += "\n"
        totalCount += elements.textFields.count
    }
    
    // Links
    if !elements.links.isEmpty && (filterType == "all" || filterType == "link") {
        output += "LINKS:\n"
        for link in elements.links {
            output += "  • \(link.label) [\(Int(link.bounds.minX)),\(Int(link.bounds.minY))]\n"
        }
        output += "\n"
        totalCount += elements.links.count
    }
    
    // Static Texts
    if !elements.staticTexts.isEmpty && (filterType == "all" || filterType == "static_text") {
        output += "TEXT ELEMENTS:\n"
        for text in elements.staticTexts {
            let truncated = text.value.count > 50 ? String(text.value.prefix(50)) + "..." : text.value
            output += "  • \(truncated) [\(Int(text.bounds.minX)),\(Int(text.bounds.minY))]\n"
        }
        output += "\n"
        totalCount += elements.staticTexts.count
    }
    
    // Images
    if !elements.images.isEmpty && (filterType == "all" || filterType == "image") {
        output += "IMAGES:\n"
        for image in elements.images {
            output += "  • \(image.label.isEmpty ? "Unlabeled image" : image.label) [\(Int(image.bounds.minX)),\(Int(image.bounds.minY))]\n"
        }
        output += "\n"
        totalCount += elements.images.count
    }
    
    // Menus
    if !elements.menus.isEmpty && (filterType == "all" || filterType == "menu") {
        output += "MENUS:\n"
        for menu in elements.menus {
            output += "  • \(menu.label) [\(Int(menu.bounds.minX)),\(Int(menu.bounds.minY))]\n"
        }
        totalCount += elements.menus.count
    }
    
    if output.isEmpty {
        output = "No \(filterType == "all" ? "interactive elements" : "\(filterType) elements") found in the current view."
    }
    
    return ToolOutput(description: output, totalCount: totalCount)
}

private struct ToolOutput {
    let description: String
    let totalCount: Int
}