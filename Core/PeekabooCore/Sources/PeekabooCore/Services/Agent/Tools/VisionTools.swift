import AXorcist
import CoreGraphics
import Foundation
import OSLog
import TachikomaCore

// MARK: - Vision Tools

private let logger = Logger(subsystem: "boo.peekaboo.core", category: "VisionTools")

// MARK: - Tool Definitions

@available(macOS 14.0, *)
public struct VisionToolDefinitions {
    public static let see = UnifiedToolDefinition(
        name: "see",
        commandName: nil,
        abstract: "Capture screen and map UI elements",
        discussion: """
            The 'see' command captures a screenshot and analyzes the UI hierarchy,
            creating an interactive map that subsequent commands can use.

            SPECIAL APP VALUES:
              • menubar   - Capture just the menu bar area (24px height)
              • frontmost - Capture the currently active window

            EXAMPLES:
              peekaboo see                           # Capture frontmost window
              peekaboo see --app Safari              # Capture Safari window
              peekaboo see --app menubar             # Capture menu bar only
              peekaboo see --app frontmost           # Capture active window
              peekaboo see --pid 12345                # Capture by process ID
              peekaboo see --mode screen             # Capture all screens (multi-screen)
              peekaboo see --mode screen --screen-index 0  # Capture primary screen only
              peekaboo see --mode screen --screen-index 1  # Capture second screen only
              peekaboo see --window-title "GitHub"   # Capture specific window
              peekaboo see --annotate                # Generate annotated screenshot
              peekaboo see --analyze "Find login"    # Capture and analyze

            MULTI-SCREEN SUPPORT:
              When capturing without --screen-index, all screens are captured and saved:
              • Primary screen: screenshot.png
              • Additional screens: screenshot_screen1.png, screenshot_screen2.png, etc.
              Display information (name, resolution) is shown for each captured screen.
              Note: Annotation is disabled for full screen captures due to performance.

            OUTPUT:
              Returns a session ID that can be used with click, type, and other
              interaction commands. Also outputs the screenshot path and UI analysis.
        """,
        category: .vision,
        parameters: [
            ParameterDefinition(
                name: "app",
                type: .string,
                description: "Application name to capture, or special values: 'menubar', 'frontmost'",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "pid",
                type: .integer,
                description: "Target application by process ID",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option, longName: "pid")),
            ParameterDefinition(
                name: "window-title",
                type: .string,
                description: "Specific window title to capture",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "mode",
                type: .enumeration,
                description: "Capture mode (screen, window, frontmost)",
                required: false,
                defaultValue: nil,
                options: ["screen", "window", "frontmost"],
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "path",
                type: .string,
                description: "Output path for screenshot",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "screen-index",
                type: .integer,
                description: "Specific screen index to capture (0-based). If not specified, captures all screens when in screen mode",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option, longName: "screen-index")),
            ParameterDefinition(
                name: "annotate",
                type: .boolean,
                description: "Generate annotated screenshot with interaction markers",
                required: false,
                defaultValue: "false",
                options: nil,
                cliOptions: CLIOptions(argumentType: .flag)),
            ParameterDefinition(
                name: "analyze",
                type: .string,
                description: "Analyze captured content with AI",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "format",
                type: .enumeration,
                description: "Output format - 'full' (default) for detailed element list with coordinates, or 'brief' for a summary",
                required: false,
                defaultValue: "full",
                options: ["full", "brief"],
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "filter",
                type: .enumeration,
                description: "Filter elements by type",
                required: false,
                defaultValue: nil,
                options: ["button", "text_field", "image", "link", "menu", "static_text"],
                cliOptions: CLIOptions(argumentType: .option)),
        ],
        examples: [
            #"{"app": "Safari"}"#,
            #"{"format": "brief"}"#,
            #"{"app": "Finder", "filter": "button"}"#,
        ],
        agentGuidance: """
            AGENT TIPS:
            - Always use 'see' before any UI interaction to understand current state
            - For menu bar items, capture with --app menubar
            - Element detection is disabled for full screen captures (too expensive)
            - Use app-specific capture for better performance
            - Annotated screenshots help verify element detection accuracy
            - **Background capture**: 'see' can capture apps in the background - no need to focus first!
            - **Focus + capture**: You can combine operations: 'see --app Safari' will both focus AND capture
            - This means you don't need separate focus_window + see commands in most cases
        """)

    public static let screenshot = UnifiedToolDefinition(
        name: "screenshot",
        commandName: nil,
        abstract: "Take a screenshot and save it to a file",
        discussion: """
            Captures a screenshot of the entire screen or a specific application
            and saves it to the specified file path.

            EXAMPLES:
              peekaboo screenshot ~/Desktop/screen.png
              peekaboo screenshot --app Safari ~/Documents/safari.png
              peekaboo screenshot --window-title "GitHub" /tmp/github.png
        """,
        category: .vision,
        parameters: [
            ParameterDefinition(
                name: "path",
                type: .string,
                description: "Path to save the screenshot (e.g., ~/Desktop/screenshot.png)",
                required: true,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .argument)),
            ParameterDefinition(
                name: "app",
                type: .string,
                description: "Application name to capture. If not specified, captures entire screen",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
            ParameterDefinition(
                name: "window-title",
                type: .string,
                description: "Specific window title to capture",
                required: false,
                defaultValue: nil,
                options: nil,
                cliOptions: CLIOptions(argumentType: .option)),
        ],
        examples: [
            #"{"path": "~/Desktop/screenshot.png"}"#,
            #"{"path": "/tmp/safari.png", "app": "Safari"}"#,
        ])
}

/// Vision-related tools for screen capture and analysis
@available(macOS 14.0, *)
extension PeekabooAgentService {
    /// Create the primary 'see' tool for capturing and analyzing UI
    func createSeeTool() -> Tool<PeekabooServices> {
        let definition = VisionToolDefinitions.see

        return createTool(
            name: definition.name,
            description: definition.agentDescription,
            parameters: definition.toAgentParameters(),
            execute: { params, context in
                let appName = params.stringValue("app", default: nil as String?)
                let format = params.stringValue("format", default: "full" as String?) ?? "full"
                let filterType = params.stringValue("filter", default: nil as String?)

                let startTime = Date()

                let captureResult: CaptureResult
                let targetDescription: String
                let detectionResult: ElementDetectionResult
                let skipElementDetection: Bool

                if let appName {
                    // Capture specific application
                    captureResult = try await context.screenCapture.captureWindow(
                        appIdentifier: appName,
                        windowIndex: nil as Int?)

                    // Get more app context
                    if let app = try? await context.applications.findApplication(identifier: appName) {
                        targetDescription = app.name
                    } else {
                        targetDescription = appName
                    }

                    // Only detect elements for specific app captures
                    detectionResult = try await context.automation.detectElements(
                        in: captureResult.imageData,
                        sessionId: nil as String?,
                        windowContext: WindowContext(applicationName: appName, windowTitle: nil))
                    skipElementDetection = false

                    // Show annotated screenshot visualization for agents
                    if let windowBounds = captureResult.metadata.windowInfo?.bounds {
                        logger.info("🎯 VisionTools: Showing annotated screenshot visualization")
                        _ = await VisualizationClient.shared.showAnnotatedScreenshot(
                            imageData: captureResult.imageData,
                            elements: detectionResult.elements.all,
                            windowBounds: windowBounds,
                            duration: 3.0)
                    }
                } else {
                    // Capture entire screen
                    captureResult = try await context.screenCapture.captureScreen(displayIndex: nil as Int?)

                    // Count visible apps on screen
                    let appsOutput = try await context.applications.listApplications()
                    let visibleApps = appsOutput.data.applications.count(where: { $0.isActive || !$0.isHidden })
                    targetDescription = "entire screen (with \(visibleApps) visible apps)"

                    // SKIP element detection for entire screen - too expensive!
                    // Create an empty result instead
                    detectionResult = ElementDetectionResult(
                        sessionId: UUID().uuidString,
                        screenshotPath: captureResult.savedPath ?? "",
                        elements: DetectedElements(
                            buttons: [],
                            textFields: [],
                            links: [],
                            images: [],
                            groups: [],
                            sliders: [],
                            checkboxes: [],
                            menus: [],
                            other: []),
                        metadata: DetectionMetadata(
                            detectionTime: 0.0,
                            elementCount: 0,
                            method: "Skipped - entire screen capture",
                            warnings: [
                                "Element detection is disabled for entire screen captures to prevent UI freezing",
                            ],
                            windowContext: nil,
                            isDialog: false))
                    skipElementDetection = true
                }

                let duration = Date().timeIntervalSince(startTime)

                // Filter elements if requested
                var elements = detectionResult.elements
                if let filterType {
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
                        other: filterType == "static_text" ? elements.other : [])
                }

                // Format output based on requested format
                if format == "brief" {
                    let totalElements = elements.buttons.count + elements.textFields.count +
                        elements.links.count + elements.other.count

                    var summary = "Captured \(targetDescription) (\(Int(captureResult.metadata.size.width))x\(Int(captureResult.metadata.size.height)))\n"

                    if skipElementDetection {
                        summary += "Note: Element detection skipped for entire screen captures (too expensive)\n"
                    } else {
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
                    }

                    let savedPath = captureResult.savedPath ?? detectionResult.screenshotPath
                    summary += "\nSaved to: \(savedPath)"

                    return ToolOutput.success(summary)
                }

                // Full format with detailed element list
                var fullOutput = "Captured \(targetDescription) (\(Int(captureResult.metadata.size.width))x\(Int(captureResult.metadata.size.height)))\n\n"

                if skipElementDetection {
                    fullOutput += "Note: Element detection is disabled for entire screen captures to prevent UI freezing.\n"
                    fullOutput += "To analyze UI elements, please capture a specific application instead.\n"
                } else {
                    let elementList = formatElementList(
                        elements,
                        filterType: filterType ?? "all")
                    fullOutput += elementList.description
                }

                let savedPath = captureResult.savedPath ?? detectionResult.screenshotPath
                fullOutput += "\nSaved to: \(savedPath)"

                return ToolOutput.success(fullOutput)
            })
    }

    /// Create the screenshot tool for saving screen captures
    func createScreenshotTool() -> Tool<PeekabooServices> {
        let definition = VisionToolDefinitions.screenshot

        return createTool(
            name: definition.name,
            description: definition.agentDescription,
            parameters: definition.toAgentParameters(),
            execute: { params, context in
                let path = try params.stringValue("path")
                let expandedPath = path.expandedPath
                let appName = params.stringValue("app", default: nil)

                let startTime = Date()

                let captureResult: CaptureResult
                let targetDescription: String

                if let appName {
                    captureResult = try await context.screenCapture.captureWindow(
                        appIdentifier: appName,
                        windowIndex: nil as Int?)

                    // Get more app context
                    if let app = try? await context.applications.findApplication(identifier: appName) {
                        targetDescription = app.name
                    } else {
                        targetDescription = appName
                    }
                } else {
                    captureResult = try await context.screenCapture.captureScreen(displayIndex: nil as Int?)

                    // Count visible apps on screen
                    let appsOutput = try await context.applications.listApplications()
                    let visibleApps = appsOutput.data.applications.count(where: { $0.isActive || !$0.isHidden })
                    targetDescription = "entire screen (with \(visibleApps) visible apps)"
                }

                // Save the image data to the specified path
                let fileURL = URL(fileURLWithPath: expandedPath)
                try captureResult.imageData.write(to: fileURL)

                let duration = Date().timeIntervalSince(startTime)
                let fileSizeKB = (try? FileManager.default.attributesOfItem(atPath: expandedPath)[.size] as? Int64)
                    .map { $0 / 1024 } ?? 0

                return ToolOutput.success(
                    "Captured \(targetDescription) → \(expandedPath) (\(Int(captureResult.metadata.size.width))x\(Int(captureResult.metadata.size.height)), \(fileSizeKB)KB)")
            })
    }

    /// Create the window capture tool
    func createWindowCaptureTool() -> Tool<PeekabooServices> {
        createTool(
            name: "window_capture",
            description: "Capture a specific window by title or window ID",
            parameters: ToolParameters(
                properties: [
                    "title": ToolParameterProperty(
                        type: .string,
                        description: "Window title to search for (partial match supported)"),
                    "window_id": ToolParameterProperty(
                        type: .integer,
                        description: "Specific window ID to capture"),
                    "save_path": ToolParameterProperty(
                        type: .string,
                        description: "Optional: Path to save the screenshot"),
                ],
                required: []),
            execute: { params, context in
                let title = params.stringValue("title", default: nil as String?)
                let windowId = params.intValue("window_id", default: nil as Int?).map { CGWindowID($0) }
                let savePath = params.stringValue("save_path", default: nil as String?)

                guard title != nil || windowId != nil else {
                    throw PeekabooError.invalidInput("Either 'title' or 'window_id' must be provided")
                }

                let startTime = Date()

                // Get windows efficiently
                var windows: [ServiceWindowInfo] = []
                var searchedApps = 0

                if let title {
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

                if let windowId {
                    guard let foundWindow = windows.first(where: { $0.windowID == windowId }) else {
                        throw PeekabooError.windowNotFound(criteria: "ID \(windowId)")
                    }
                    window = foundWindow

                    // Find the app that owns this window
                    let appsOutput = try await context.applications.listApplications()
                    appName = appsOutput.data.applications.first { _ in
                        windows.contains { w in w.windowID == windowId }
                    }?.name ?? "Unknown App"
                } else if let title {
                    guard let foundWindow = windows
                        .first(where: { $0.title.lowercased().contains(title.lowercased()) })
                    else {
                        throw PeekabooError.windowNotFound(criteria: "title '\(title)'")
                    }
                    window = foundWindow

                    // Find the app that owns this window
                    let appsOutput = try await context.applications.listApplications()
                    appName = appsOutput.data.applications.first { _ in
                        windows.contains { w in w.title == foundWindow.title }
                    }?.name ?? "Unknown App"
                } else {
                    throw PeekabooError.windowNotFound(criteria: "no criteria provided")
                }

                // Capture the window
                let captureResult = try await context.screenCapture.captureWindow(
                    appIdentifier: appName,
                    windowIndex: nil)

                // Detect elements
                let detectionResult = try await context.automation.detectElements(
                    in: captureResult.imageData,
                    sessionId: nil as String?,
                    windowContext: nil)

                // Save if path provided
                var savedPath: String?
                if let savePath {
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
                    output += "Searched \(searchedApps) apps\n"
                }
                output += "\n"
                output += elementList.description

                if let savedPath {
                    output += "\nSaved to: \(savedPath)"
                }

                return ToolOutput.success(output)
            })
    }
}

// MARK: - Helper Functions

/// Format detected elements into a structured list
private func formatElementList(_ elements: DetectedElements, filterType: String) -> ElementListOutput {
    var output = ""
    var totalCount = 0

    // Buttons
    if !elements.buttons.isEmpty, filterType == "all" || filterType == "button" {
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
    if !elements.textFields.isEmpty, filterType == "all" || filterType == "text_field" {
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
    if !elements.links.isEmpty, filterType == "all" || filterType == "link" {
        output += "LINKS:\n"
        for link in elements.links {
            output += "  • \(link.label ?? "Unlabeled link") [\(Int(link.bounds.minX)),\(Int(link.bounds.minY))]\n"
        }
        output += "\n"
        totalCount += elements.links.count
    }

    // Static Texts
    if !elements.other.isEmpty, filterType == "all" || filterType == "static_text" {
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
    if !elements.images.isEmpty, filterType == "all" || filterType == "image" {
        output += "IMAGES:\n"
        for image in elements.images {
            output += "  • \(image.label?.isEmpty ?? true ? "Unlabeled image" : image.label ?? "Unlabeled image") [\(Int(image.bounds.minX)),\(Int(image.bounds.minY))]\n"
        }
        output += "\n"
        totalCount += elements.images.count
    }

    // Menus
    if !elements.menus.isEmpty, filterType == "all" || filterType == "menu" {
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
