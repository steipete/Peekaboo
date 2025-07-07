import AppKit
import ArgumentParser
import AXorcist
import CoreGraphics
import Foundation

/// Captures a screenshot and builds an interactive UI map.
/// This is the foundation command for all GUI automation in Peekaboo 3.0.
@available(macOS 14.0, *)
struct SeeCommand: AsyncParsableCommand, VerboseCommand {
    static let configuration = CommandConfiguration(
        commandName: "see",
        abstract: "Capture screen and map UI elements for interaction",
        discussion: """
            The 'see' command captures a screenshot and analyzes the UI hierarchy,
            creating an interactive map that subsequent commands can use.

            EXAMPLES:
              peekaboo see                           # Capture frontmost window
              peekaboo see --app Safari              # Capture Safari window
              peekaboo see --mode screen             # Capture entire screen
              peekaboo see --window-title "GitHub"   # Capture specific window
              peekaboo see --annotate                # Generate annotated screenshot
              peekaboo see --analyze "Find login"    # Capture and analyze

            OUTPUT:
              Returns a session ID that can be used with click, type, and other
              interaction commands. Also outputs the screenshot path and UI analysis.
        """)

    @Option(help: "Application name to capture")
    var app: String?

    @Option(help: "Specific window title to capture")
    var windowTitle: String?

    @Option(help: "Capture mode (screen, window, frontmost)")
    var mode: CaptureMode?

    @Option(help: "Output path for screenshot")
    var path: String?

    @Flag(help: "Generate annotated screenshot with interaction markers")
    var annotate = false

    @Option(help: "Analyze captured content with AI")
    var analyze: String?

    @Flag(help: "Output in JSON format")
    var jsonOutput = false

    @Flag(name: .shortAndLong, help: "Enable verbose logging for detailed output")
    var verbose = false

    enum CaptureMode: String, ExpressibleByArgument {
        case screen
        case window
        case frontmost
    }

    mutating func run() async throws {
        configureVerboseLogging()
        let startTime = Date()
        Logger.shared.verbose("Starting see command execution")

        // Always create a new session for see command
        // Let SessionCache generate its own ID for cross-process compatibility
        Logger.shared.verbose("Creating new session")
        let sessionCache = try SessionCache(sessionId: nil, createIfNeeded: true)

        do {
            // Perform capture based on mode
            let captureResult: CaptureResult

            // Intelligently determine mode if not specified
            let effectiveMode: CaptureMode = if let specifiedMode = mode {
                specifiedMode
            } else if self.app != nil || self.windowTitle != nil {
                // If app or window title is specified, default to window mode
                .window
            } else {
                // Otherwise default to frontmost
                .frontmost
            }

            Logger.shared.verbose("Using capture mode: \(effectiveMode)")

            switch effectiveMode {
            case .screen:
                Logger.shared.verbose("Capturing entire screen")
                captureResult = try await self.captureScreen()
            case .window:
                if let appName = app {
                    Logger.shared.verbose("Capturing window for app: \(appName), title: \(self.windowTitle ?? "any")")
                    captureResult = try await self.captureWindow(app: appName, title: self.windowTitle)
                } else {
                    throw ValidationError("--app is required for window mode")
                }
            case .frontmost:
                Logger.shared.verbose("Capturing frontmost window")
                captureResult = try await self.captureFrontmost()
            }

            // Save screenshot (already saved during capture)
            let outputPath = try saveScreenshot(captureResult)

            // Update session cache with UI map
            try await sessionCache.updateScreenshot(
                path: outputPath,
                application: captureResult.applicationName,
                window: captureResult.windowTitle,
                windowBounds: captureResult.windowBounds)

            // Generate annotated screenshot if requested
            var annotatedPath: String?
            if self.annotate {
                annotatedPath = try await self.generateAnnotatedScreenshot(
                    originalPath: outputPath,
                    sessionCache: sessionCache)
            }

            // Perform AI analysis if requested
            var analysisResult: String?
            if let prompt = analyze {
                analysisResult = try await self.performAnalysis(
                    imagePath: outputPath,
                    prompt: prompt)
            }

            // Load session data for output
            let sessionData = await sessionCache.load()
            let elementCount = sessionData?.uiMap.count ?? 0
            let interactableCount = sessionData?.uiMap.values.count(where: { $0.isActionable }) ?? 0
            let sessionPaths = await sessionCache.getSessionPaths()

            // Prepare output
            if self.jsonOutput {
                // Build UI element summaries
                let uiElements: [UIElementSummary] = sessionData?.uiMap.values.map { element in
                    UIElementSummary(
                        id: element.id,
                        role: element.role,
                        title: element.title,
                        label: element.label,
                        identifier: element.identifier,
                        is_actionable: element.isActionable,
                        keyboard_shortcut: element.keyboardShortcut)
                } ?? []

                // Build menu bar summary
                let menuBarSummary: MenuBarSummary? = sessionData?.menuBar.map { menuBarData in
                    MenuBarSummary(
                        menus: menuBarData.menus.map { menu in
                            MenuBarSummary.MenuSummary(
                                title: menu.title,
                                item_count: menu.items.count,
                                enabled: menu.enabled,
                                items: menu.items.map { item in
                                    MenuBarSummary.MenuItemSummary(
                                        title: item.title,
                                        enabled: item.enabled,
                                        keyboard_shortcut: item.keyboardShortcut)
                                })
                        })
                }

                let output = SeeResult(
                    session_id: sessionCache.sessionId,
                    screenshot_raw: sessionPaths.raw,
                    screenshot_annotated: annotatedPath ?? sessionPaths.annotated,
                    ui_map: sessionPaths.map,
                    application_name: captureResult.applicationName,
                    window_title: captureResult.windowTitle,
                    element_count: elementCount,
                    interactable_count: interactableCount,
                    capture_mode: effectiveMode.rawValue,
                    analysis_result: analysisResult,
                    execution_time: Date().timeIntervalSince(startTime),
                    ui_elements: uiElements,
                    menu_bar: menuBarSummary)
                outputSuccessCodable(data: output)
            } else {
                print("✅ Screenshot captured successfully")
                print("📍 Session ID: \(sessionCache.sessionId)")
                print("🖼  Raw screenshot: \(sessionPaths.raw)")
                if let annotated = annotatedPath {
                    print("🎯 Annotated: \(annotated)")
                }
                print("🗺️  UI map: \(sessionPaths.map)")
                print("🔍 Found \(elementCount) UI elements (\(interactableCount) interactive)")
                if let app = captureResult.applicationName {
                    print("📱 Application: \(app)")
                }
                if let window = captureResult.windowTitle {
                    print("🪟 Window: \(window)")
                }

                // Display menu bar info
                if let menuBar = sessionData?.menuBar {
                    print("📋 Menu bar: \(menuBar.menus.count) menus")
                    for menu in menuBar.menus {
                        if menu.enabled, !menu.items.isEmpty {
                            print("   • \(menu.title) (\(menu.items.count) items)")
                        }
                    }
                }
                if let analysis = analysisResult {
                    print("🤖 Analysis:")
                    print(analysis)
                }
                print("⏱️  Completed in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
            }

        } catch {
            if self.jsonOutput {
                ImageErrorHandler.handleError(error, jsonOutput: true)
            } else {
                ImageErrorHandler.handleError(error, jsonOutput: false)
            }
            throw ExitCode.failure
        }
    }

    private func captureScreen() async throws -> CaptureResult {
        let suggestedName = "screen_\(Date().timeIntervalSince1970)"
        let outputPath = self.path ?? FileNameGenerator.generateFileName(format: .png)

        // Get primary display
        let displayID = CGMainDisplayID()
        try await ScreenCapture.captureDisplay(displayID, to: outputPath)

        return CaptureResult(
            outputPath: outputPath,
            applicationName: nil,
            windowTitle: nil,
            suggestedName: suggestedName,
            windowBounds: nil)
    }

    @MainActor
    private func captureWindow(app: String, title: String?) async throws -> CaptureResult {
        let appInfo = try ApplicationFinder.findApplication(identifier: app)

        // Get the NSRunningApplication
        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier == appInfo.processIdentifier
        }) else {
            throw CaptureError.appNotFound(appInfo.localizedName ?? app)
        }

        // Get windows with subrole information
        let enhancedWindows = WindowManager.getWindowsWithSubroles(for: runningApp)
        guard !enhancedWindows.isEmpty else {
            throw CaptureError.windowNotFound
        }

        let targetWindow: WindowData
        if let title {
            // Look for exact match first, then partial match
            if let match = enhancedWindows.first(where: { $0.window.title == title }) {
                targetWindow = match.window
            } else if let match = enhancedWindows.first(where: { $0.window.title.contains(title) }) {
                targetWindow = match.window
            } else {
                throw CaptureError.windowNotFound
            }
        } else {
            // When no title specified, prefer standard windows over panels/dialogs
            // The windows are already sorted with standard windows first
            targetWindow = enhancedWindows.first!.window
        }

        let appName = appInfo.localizedName ?? "Unknown"
        let suggestedName = appName.lowercased().replacingOccurrences(of: " ", with: "_")
        let outputPath = self.path ?? FileNameGenerator.generateFileName(
            appName: appName,
            windowTitle: targetWindow.title,
            format: .png)

        try await ScreenCapture.captureWindow(targetWindow, to: outputPath)

        return CaptureResult(
            outputPath: outputPath,
            applicationName: appName,
            windowTitle: targetWindow.title,
            suggestedName: suggestedName,
            windowBounds: targetWindow.bounds)
    }

    @MainActor
    private func captureFrontmost() async throws -> CaptureResult {
        // Get the actual topmost visible window from all applications
        let options: CGWindowListOption = [.excludeDesktopElements, .optionOnScreenOnly]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]],
              !windowList.isEmpty
        else {
            throw CaptureError.windowNotFound
        }

        // Find the first visible window with a valid title
        var targetWindow: (windowID: CGWindowID, title: String, pid: pid_t, bounds: CGRect)?

        for windowInfo in windowList {
            // Skip windows without proper metadata
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  let title = windowInfo[kCGWindowName as String] as? String,
                  !title.isEmpty,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any]
            else {
                continue
            }

            // Extract bounds
            let x = boundsDict["X"] as? Double ?? 0
            let y = boundsDict["Y"] as? Double ?? 0
            let width = boundsDict["Width"] as? Double ?? 0
            let height = boundsDict["Height"] as? Double ?? 0
            let bounds = CGRect(x: x, y: y, width: width, height: height)

            // Skip tiny windows
            if width < 50 || height < 50 {
                continue
            }

            targetWindow = (windowID: windowID, title: title, pid: pid, bounds: bounds)
            break
        }

        guard let windowData = targetWindow else {
            throw CaptureError.windowNotFound
        }

        // Get the application that owns this window
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == windowData.pid })
        else {
            throw CaptureError.appNotFound("Could not find application for window")
        }

        let appName = app.localizedName ?? "Unknown"
        let suggestedName = appName.lowercased().replacingOccurrences(of: " ", with: "_")
        let outputPath = self.path ?? FileNameGenerator.generateFileName(
            appName: appName,
            windowTitle: windowData.title,
            format: .png)

        // Create WindowData for capture
        let window = WindowData(
            windowId: windowData.windowID,
            title: windowData.title,
            bounds: windowData.bounds,
            isOnScreen: true,
            windowIndex: 0)

        try await ScreenCapture.captureWindow(window, to: outputPath)

        return CaptureResult(
            outputPath: outputPath,
            applicationName: appName,
            windowTitle: windowData.title,
            suggestedName: suggestedName,
            windowBounds: windowData.bounds)
    }

    private func saveScreenshot(_ captureResult: CaptureResult) throws -> String {
        // Image is already saved, just return the path
        captureResult.outputPath
    }

    private func generateAnnotatedScreenshot(
        originalPath: String,
        sessionCache: SessionCache) async throws -> String
    {
        // Load the session data to get UI elements
        guard let sessionData = await sessionCache.load() else {
            return originalPath
        }

        // Get annotated path from session
        let sessionPaths = await sessionCache.getSessionPaths()
        let annotatedPath = sessionPaths.annotated

        // Create annotated image
        try await self.createAnnotatedImage(
            from: originalPath,
            to: annotatedPath,
            uiElements: sessionData.uiMap,
            windowBounds: sessionData.windowBounds)

        // Log annotation info only in non-JSON mode
        if !self.jsonOutput {
            let interactableElements = sessionData.uiMap.values.filter(\.isActionable)
            print("📝 Created annotated screenshot with \(interactableElements.count) interactive elements")
        }

        return annotatedPath
    }

    @MainActor
    private func createAnnotatedImage(
        from sourcePath: String,
        to destinationPath: String,
        uiElements: [String: SessionCache.SessionData.UIElement],
        windowBounds: CGRect?) async throws
    {
        // Load the original image
        guard let nsImage = NSImage(contentsOfFile: sourcePath) else {
            throw CaptureError.fileIOError("Failed to load image from \(sourcePath)")
        }

        // Get image size
        let imageSize = nsImage.size

        // Create bitmap context
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(imageSize.width),
            pixelsHigh: Int(imageSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0)
        else {
            throw CaptureError.captureFailure("Failed to create bitmap representation")
        }

        // Draw into context
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)

        // Draw original image
        nsImage.draw(in: NSRect(origin: .zero, size: imageSize))

        // Configure text attributes
        let fontSize: CGFloat = 14
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.8),
        ]

        // Role-based colors from spec
        let roleColors: [String: NSColor] = [
            "AXButton": NSColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0), // #007AFF
            "AXTextField": NSColor(red: 0.204, green: 0.78, blue: 0.349, alpha: 1.0), // #34C759
            "AXTextArea": NSColor(red: 0.204, green: 0.78, blue: 0.349, alpha: 1.0), // #34C759
            "AXLink": NSColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0), // #007AFF
            "AXCheckBox": NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0), // #8E8E93
            "AXRadioButton": NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0), // #8E8E93
            "AXSlider": NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0), // #8E8E93
            "AXPopUpButton": NSColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0), // #007AFF
            "AXComboBox": NSColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0), // #007AFF
        ]

        // Draw UI elements
        for (_, element) in uiElements where element.isActionable {
            // Get color for role
            let color = roleColors[element.role] ?? NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)

            // Transform coordinates from screen space to window-relative space
            var elementFrame = element.frame
            if let windowBounds {
                // Convert from screen coordinates to window-relative coordinates
                elementFrame.origin.x -= windowBounds.origin.x
                elementFrame.origin.y -= windowBounds.origin.y
            }

            // Draw bounding box
            let rect = NSRect(
                x: elementFrame.origin.x,
                y: imageSize.height - elementFrame.origin.y - elementFrame.height, // Flip Y coordinate
                width: elementFrame.width,
                height: elementFrame.height)

            color.withAlphaComponent(0.3).setFill()
            rect.fill()

            color.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 2
            path.stroke()

            // Draw element ID label
            let idString = NSAttributedString(string: element.id, attributes: textAttributes)
            let textSize = idString.size()

            // Position label in top-left corner of element with padding
            let labelRect = NSRect(
                x: rect.origin.x + 4,
                y: rect.origin.y + rect.height - textSize.height - 4,
                width: textSize.width + 8,
                height: textSize.height + 4)

            // Draw label background
            NSColor.black.withAlphaComponent(0.8).setFill()
            NSBezierPath(roundedRect: labelRect, xRadius: 3, yRadius: 3).fill()

            // Draw label text
            idString.draw(at: NSPoint(x: labelRect.origin.x + 4, y: labelRect.origin.y + 2))
        }

        NSGraphicsContext.restoreGraphicsState()

        // Save annotated image
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw CaptureError.captureFailure("Failed to create PNG data")
        }

        try pngData.write(to: URL(fileURLWithPath: destinationPath))
    }

    private func performAnalysis(imagePath: String, prompt: String) async throws -> String {
        // Get configured providers
        let aiProvidersString = ConfigurationManager.shared.getAIProviders(cliValue: nil)
        let configuredProviders = AIProviderFactory.createProviders(from: aiProvidersString)

        guard !configuredProviders.isEmpty else {
            throw CaptureError.invalidArgument("No AI providers configured")
        }

        // Use first available provider
        guard let analyzer = await AIProviderFactory.findAvailableProvider(from: configuredProviders) else {
            throw CaptureError.invalidArgument("No AI provider available")
        }

        // Read image and convert to base64
        let imageData = try Data(contentsOf: URL(fileURLWithPath: imagePath))
        let base64String = imageData.base64EncodedString()

        return try await analyzer.analyze(
            imageBase64: base64String,
            question: prompt)
    }
}

// MARK: - Supporting Types

private struct CaptureResult {
    let outputPath: String
    let applicationName: String?
    let windowTitle: String?
    let suggestedName: String
    let windowBounds: CGRect?
}

// MARK: - JSON Output Structure

struct SeeResult: Codable {
    let session_id: String
    let screenshot_raw: String
    let screenshot_annotated: String
    let ui_map: String
    let application_name: String?
    let window_title: String?
    let element_count: Int
    let interactable_count: Int
    let capture_mode: String
    let analysis_result: String?
    let execution_time: TimeInterval
    let ui_elements: [UIElementSummary]
    let menu_bar: MenuBarSummary?
    var success: Bool = true
}

struct UIElementSummary: Codable {
    let id: String
    let role: String
    let title: String?
    let label: String?
    let identifier: String?
    let is_actionable: Bool
    let keyboard_shortcut: String?
}

struct MenuBarSummary: Codable {
    let menus: [MenuSummary]

    struct MenuSummary: Codable {
        let title: String
        let item_count: Int
        let enabled: Bool
        let items: [MenuItemSummary]
    }

    struct MenuItemSummary: Codable {
        let title: String
        let enabled: Bool
        let keyboard_shortcut: String?
    }
}
