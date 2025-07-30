import Foundation
import CoreGraphics
import AXorcist
import OSLog

// MARK: - Vision Tools

private let logger = Logger(subsystem: "boo.peekaboo.core", category: "VisionTools")

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
                    "app": ParameterSchema.string(
                        description: "Optional: Application name to capture (e.g., 'Safari', 'Finder'). If not specified, captures the entire screen."
                    ),
                    "format": ParameterSchema.enumeration(
                        ["full", "brief"],
                        description: "Output format - 'full' (default) for detailed element list with coordinates, or 'brief' for a summary"
                    ),
                    "filter": ParameterSchema.enumeration(
                        ["button", "text_field", "image", "link", "menu", "static_text"],
                        description: "Optional: Filter elements by type"
                    )
                ],
                required: []
            ),
            handler: { params, context in
                let appName = params.string("app", default: nil)
                let format = params.string("format", default: "full") ?? "full"
                let filterType = params.string("filter", default: nil)
                
                let startTime = Date()
                
                let captureResult: CaptureResult
                let targetDescription: String
                
                if let appName = appName {
                    // Capture specific application
                    captureResult = try await context.screenCapture.captureWindow(
                        appIdentifier: appName,
                        windowIndex: nil
                    )
                    
                    // Get more app context
                    if let app = try? await context.applications.findApplication(identifier: appName) {
                        targetDescription = app.name
                    } else {
                        targetDescription = appName
                    }
                } else {
                    // Capture entire screen
                    captureResult = try await context.screenCapture.captureScreen(displayIndex: nil)
                    
                    // Count visible apps on screen
                    let appsOutput = try await context.applications.listApplications()
                    let visibleApps = appsOutput.data.applications.filter { $0.isActive || !$0.isHidden }.count
                    targetDescription = "entire screen (with \(visibleApps) visible apps)"
                }
                
                // Detect elements in the screenshot
                let detectionResult = try await context.automation.detectElements(
                    in: captureResult.imageData,
                    sessionId: nil,
                    windowContext: nil
                )
                
                let duration = Date().timeIntervalSince(startTime)
                
                // Filter elements if requested
                var elements = detectionResult.elements
                if let filterType = filterType {
                    // Create a filtered copy
                    elements = DetectedElements(
                        buttons: filterType == "button" ? elements.buttons : [],
                        textFields: filterType == "text_field" ? elements.textFields : [],
                        links: filterType == "link" ? elements.links : [],
                        images: filterType == "image" ? elements.images : [],
                        groups: filterType == "group" ? elements.groups : [],
                        sliders: filterType == "slider" ? elements.sliders : [],
                        checkboxes: filterType == "checkbox" ? elements.checkboxes : [],
                        menus: filterType == "menu" ? elements.menus : [],
                        other: filterType == "static_text" ? elements.other : []
                    )
                }
                
                // Format output based on requested format
                if format == "brief" {
                    let totalElements = elements.buttons.count + elements.textFields.count + 
                                      elements.links.count + elements.other.count
                    
                    var summary = "Captured \(targetDescription) (\(Int(captureResult.metadata.size.width))x\(Int(captureResult.metadata.size.height)))\n"
                    summary += "Found: "
                    
                    var elementSummary: [String] = []
                    if !elements.buttons.isEmpty {
                        elementSummary.append("\(elements.buttons.count) buttons")
                    }
                    if !elements.textFields.isEmpty {
                        elementSummary.append("\(elements.textFields.count) text fields")
                    }
                    if !elements.links.isEmpty {
                        elementSummary.append("\(elements.links.count) links")
                    }
                    if !elements.other.isEmpty {
                        elementSummary.append("\(elements.other.count) text elements")
                    }
                    
                    if elementSummary.isEmpty {
                        summary += "no interactive elements"
                    } else {
                        summary += elementSummary.joined(separator: ", ")
                    }
                    
                    let savedPath = captureResult.savedPath ?? detectionResult.screenshotPath
                    summary += "\nSaved to: \(savedPath)"
                    
                    return .success(
                        summary,
                        metadata: [
                            "path": captureResult.savedPath ?? detectionResult.screenshotPath,
                            "resolution": "\(Int(captureResult.metadata.size.width))x\(Int(captureResult.metadata.size.height))",
                            "app": targetDescription,
                            "elementCount": String(totalElements),
                            "duration": String(format: "%.2fs", duration)
                        ]
                    )
                }
                
                // Full format with detailed element list
                let elementList = formatElementList(
                    elements, 
                    filterType: filterType ?? "all"
                )
                
                var fullOutput = "Captured \(targetDescription) (\(Int(captureResult.metadata.size.width))x\(Int(captureResult.metadata.size.height)))\n\n"
                fullOutput += elementList.description
                
                let savedPath = captureResult.savedPath ?? detectionResult.screenshotPath
                fullOutput += "\nSaved to: \(savedPath)"
                
                return .success(
                    fullOutput,
                    metadata: [
                        "path": captureResult.savedPath ?? detectionResult.screenshotPath,
                        "resolution": "\(Int(captureResult.metadata.size.width))x\(Int(captureResult.metadata.size.height))",
                        "elementCount": String(elementList.totalCount),
                        "app": targetDescription,
                        "duration": String(format: "%.2fs", duration)
                    ]
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
                    "path": ParameterSchema.string(description: "Path to save the screenshot (e.g., ~/Desktop/screenshot.png)"),
                    "app": ParameterSchema.string(description: "Optional: Application name to capture. If not specified, captures entire screen")
                ],
                required: ["path"]
            ),
            handler: { params, context in
                let path = try params.string("path")
                let expandedPath = path.expandedPath
                let appName = params.string("app", default: nil)
                
                let startTime = Date()
                
                let captureResult: CaptureResult
                let targetDescription: String
                
                if let appName = appName {
                    captureResult = try await context.screenCapture.captureWindow(
                        appIdentifier: appName,
                        windowIndex: nil
                    )
                    
                    // Get more app context
                    if let app = try? await context.applications.findApplication(identifier: appName) {
                        targetDescription = app.name
                    } else {
                        targetDescription = appName
                    }
                } else {
                    captureResult = try await context.screenCapture.captureScreen(displayIndex: nil)
                    
                    // Count visible apps on screen
                    let appsOutput = try await context.applications.listApplications()
                    let visibleApps = appsOutput.data.applications.filter { $0.isActive || !$0.isHidden }.count
                    targetDescription = "entire screen (with \(visibleApps) visible apps)"
                }
                
                // Save the image data to the specified path
                let fileURL = URL(fileURLWithPath: expandedPath)
                try captureResult.imageData.write(to: fileURL)
                
                let duration = Date().timeIntervalSince(startTime)
                let fileSizeKB = (try? FileManager.default.attributesOfItem(atPath: expandedPath)[.size] as? Int64)
                    .map { $0 / 1024 } ?? 0
                
                return .success(
                    "Captured \(targetDescription) → \(expandedPath) (\(Int(captureResult.metadata.size.width))x\(Int(captureResult.metadata.size.height)), \(fileSizeKB)KB)",
                    metadata: [
                        "path": expandedPath,
                        "resolution": "\(Int(captureResult.metadata.size.width))x\(Int(captureResult.metadata.size.height))",
                        "source": targetDescription,
                        "fileSize": "\(fileSizeKB)KB",
                        "duration": String(format: "%.2fs", duration)
                    ]
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
                    "title": ParameterSchema.string(description: "Window title to search for (partial match supported)"),
                    "window_id": ParameterSchema.integer(description: "Specific window ID to capture"),
                    "save_path": ParameterSchema.string(description: "Optional: Path to save the screenshot")
                ],
                required: []
            ),
            handler: { params, context in
                let title = params.string("title", default: nil)
                let windowId = params.int("window_id", default: nil).map { CGWindowID($0) }
                let savePath = params.string("save_path", default: nil)
                
                guard title != nil || windowId != nil else {
                    throw PeekabooError.invalidInput("Either 'title' or 'window_id' must be provided")
                }
                
                let startTime = Date()
                
                // Get windows efficiently
                var windows: [ServiceWindowInfo] = []
                var searchedApps = 0
                
                if let title = title {
                    // If title is specified, use title-based search
                    windows = try await context.windows.listWindows(target: .title(title))
                } else if windowId == nil {
                    // No specific criteria, get all windows with timeout protection
                    let appsOutput = try await context.applications.listApplications()
                    searchedApps = appsOutput.data.applications.count
                    
                    // Process each app sequentially to ensure main thread execution
                    for app in appsOutput.data.applications {
                        do {
                            let appWindows = try await context.windows.listWindows(target: .application(app.name))
                            windows.append(contentsOf: appWindows)
                        } catch {
                            // Skip apps that fail
                            logger.debug("Error getting windows for \(app.name): \(error)")
                        }
                    }
                } else {
                    // Window ID specified - still need to search all apps but with timeout
                    let appsOutput = try await context.applications.listApplications()
                    searchedApps = appsOutput.data.applications.count
                    
                    // Process each app sequentially to ensure main thread execution
                    for app in appsOutput.data.applications {
                        do {
                            let appWindows = try await context.windows.listWindows(target: .application(app.name))
                            windows.append(contentsOf: appWindows)
                        } catch {
                            // Skip apps that fail
                            logger.debug("Error getting windows for \(app.name): \(error)")
                        }
                    }
                }
                
                let window: ServiceWindowInfo
                let appName: String
                
                if let windowId = windowId {
                    guard let foundWindow = windows.first(where: { $0.windowID == windowId }) else {
                        throw PeekabooError.windowNotFound(criteria: "ID \(windowId)")
                    }
                    window = foundWindow
                    
                    // Find the app that owns this window
                    let appsOutput = try await context.applications.listApplications()
                    appName = appsOutput.data.applications.first { app in
                        windows.contains { w in w.windowID == windowId }
                    }?.name ?? "Unknown App"
                } else if let title = title {
                    guard let foundWindow = windows.first(where: { $0.title.lowercased().contains(title.lowercased()) }) else {
                        throw PeekabooError.windowNotFound(criteria: "title '\(title)'")
                    }
                    window = foundWindow
                    
                    // Find the app that owns this window
                    let appsOutput = try await context.applications.listApplications()
                    appName = appsOutput.data.applications.first { app in
                        windows.contains { w in w.title == foundWindow.title }
                    }?.name ?? "Unknown App"
                } else {
                    throw PeekabooError.windowNotFound(criteria: "no criteria provided")
                }
                
                // Capture the window
                let captureResult = try await context.screenCapture.captureWindow(
                    appIdentifier: appName,
                    windowIndex: nil
                )
                
                // Detect elements
                let detectionResult = try await context.automation.detectElements(
                    in: captureResult.imageData,
                    sessionId: nil,
                    windowContext: nil
                )
                
                // Save if path provided
                var savedPath: String? = nil
                if let savePath = savePath {
                    let expandedPath = savePath.expandedPath
                    let fileURL = URL(fileURLWithPath: expandedPath)
                    try captureResult.imageData.write(to: fileURL)
                    savedPath = expandedPath
                }
                
                let duration = Date().timeIntervalSince(startTime)
                let elementList = formatElementList(detectionResult.elements, filterType: "all")
                
                var output = "Captured \(appName) - \"\(window.title)\" (Window ID: \(window.windowID))\n"
                output += "Resolution: \(Int(captureResult.metadata.size.width))x\(Int(captureResult.metadata.size.height))\n"
                if searchedApps > 0 {
                    output += "Searched \(searchedApps) apps in \(String(format: "%.2fs", duration))\n"
                }
                output += "\n"
                output += elementList.description
                
                if let savedPath = savedPath {
                    output += "\nSaved to: \(savedPath)"
                }
                
                return .success(
                    output,
                    metadata: [
                        "app": appName,
                        "window": window.title,
                        "windowId": String(window.windowID),
                        "path": savedPath ?? detectionResult.screenshotPath,
                        "resolution": "\(Int(captureResult.metadata.size.width))x\(Int(captureResult.metadata.size.height))",
                        "elementCount": String(elementList.totalCount),
                        "duration": String(format: "%.2fs", duration)
                    ]
                )
            }
        )
    }
}

// MARK: - Helper Functions

/// Format detected elements into a structured list
private func formatElementList(_ elements: DetectedElements, filterType: String) -> ElementListOutput {
    var output = ""
    var totalCount = 0
    
    // Buttons
    if !elements.buttons.isEmpty && (filterType == "all" || filterType == "button") {
        output += "BUTTONS:\n"
        for button in elements.buttons {
            output += "  • \(button.label ?? "Unlabeled button") [\(Int(button.bounds.minX)),\(Int(button.bounds.minY))]"
            if button.isEnabled {
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
            output += "  • \(field.label?.isEmpty ?? true ? "Unlabeled" : field.label ?? "Unlabeled") [\(Int(field.bounds.minX)),\(Int(field.bounds.minY))]"
            if let value = field.value, !value.isEmpty {
                output += " (value: \(value))"
            }
            if field.isEnabled {
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
            output += "  • \(link.label ?? "Unlabeled link") [\(Int(link.bounds.minX)),\(Int(link.bounds.minY))]\n"
        }
        output += "\n"
        totalCount += elements.links.count
    }
    
    // Static Texts
    if !elements.other.isEmpty && (filterType == "all" || filterType == "static_text") {
        output += "TEXT ELEMENTS:\n"
        for text in elements.other {
            let truncated = if let value = text.value, value.count > 50 {
                String(value.prefix(50)) + "..."
            } else {
                text.value ?? "[no text]"
            }
            output += "  • \(truncated) [\(Int(text.bounds.minX)),\(Int(text.bounds.minY))]\n"
        }
        output += "\n"
        totalCount += elements.other.count
    }
    
    // Images
    if !elements.images.isEmpty && (filterType == "all" || filterType == "image") {
        output += "IMAGES:\n"
        for image in elements.images {
            output += "  • \(image.label?.isEmpty ?? true ? "Unlabeled image" : image.label ?? "Unlabeled image") [\(Int(image.bounds.minX)),\(Int(image.bounds.minY))]\n"
        }
        output += "\n"
        totalCount += elements.images.count
    }
    
    // Menus
    if !elements.menus.isEmpty && (filterType == "all" || filterType == "menu") {
        output += "MENUS:\n"
        for menu in elements.menus {
            output += "  • \(menu.label ?? "Unlabeled menu") [\(Int(menu.bounds.minX)),\(Int(menu.bounds.minY))]\n"
        }
        totalCount += elements.menus.count
    }
    
    if output.isEmpty {
        output = "No \(filterType == "all" ? "interactive elements" : "\(filterType) elements") found in the current view."
    }
    
    return ElementListOutput(description: output, totalCount: totalCount)
}

private struct ElementListOutput {
    let description: String
    let totalCount: Int
}