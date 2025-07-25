import AppKit
import ArgumentParser
import AXorcist
import CoreGraphics
import Foundation
import PeekabooCore

/// Capture a screenshot and build an interactive UI map
@available(macOS 14.0, *)
struct SeeCommand: AsyncParsableCommand, VerboseCommand {
    static let configuration = CommandConfiguration(
        commandName: "see",
        abstract: "Capture screen and map UI elements",
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
        Logger.shared.operationStart("see_command", metadata: [
            "app": self.app ?? "none",
            "mode": self.mode?.rawValue ?? "auto",
            "annotate": self.annotate,
            "hasAnalyzePrompt": self.analyze != nil,
        ])

        do {
            // Check permissions
            Logger.shared.verbose("Checking screen recording permissions", category: "Permissions")
            guard await PeekabooServices.shared.screenCapture.hasScreenRecordingPermission() else {
                Logger.shared.error("Screen recording permission denied", category: "Permissions")
                throw CaptureError.screenRecordingPermissionDenied
            }
            Logger.shared.verbose("Screen recording permission granted", category: "Permissions")

            // Perform capture and element detection
            Logger.shared.verbose("Starting capture and detection phase", category: "Capture")
            let captureResult = try await performCaptureWithDetection()
            Logger.shared.verbose("Capture completed successfully", category: "Capture", metadata: [
                "sessionId": captureResult.sessionId,
                "elementCount": captureResult.elements.all.count,
                "screenshotSize": self.getFileSize(captureResult.screenshotPath) ?? 0,
            ])

            // Generate annotated screenshot if requested
            var annotatedPath: String?
            if self.annotate {
                Logger.shared.operationStart("generate_annotations")
                annotatedPath = try await self.generateAnnotatedScreenshot(
                    sessionId: captureResult.sessionId,
                    originalPath: captureResult.screenshotPath)
                Logger.shared.operationComplete("generate_annotations", metadata: [
                    "annotatedPath": annotatedPath ?? "none",
                ])
            }

            // Perform AI analysis if requested
            var analysisResult: String?
            if let prompt = analyze {
                Logger.shared.operationStart("ai_analysis", metadata: ["prompt": prompt])
                analysisResult = try await self.performAnalysis(
                    imagePath: captureResult.screenshotPath,
                    prompt: prompt)
                Logger.shared.operationComplete("ai_analysis", success: analysisResult != nil)
            }

            // Output results
            let executionTime = Date().timeIntervalSince(Date())
            Logger.shared.operationComplete("see_command", metadata: [
                "executionTimeMs": Int(executionTime * 1000),
                "success": true,
            ])

            if self.jsonOutput {
                await outputJSONResults(
                    sessionId: captureResult.sessionId,
                    screenshotPath: captureResult.screenshotPath,
                    annotatedPath: annotatedPath,
                    metadata: captureResult.metadata,
                    elements: captureResult.elements,
                    analysisResult: analysisResult,
                    executionTime: executionTime)
            } else {
                await outputTextResults(
                    sessionId: captureResult.sessionId,
                    screenshotPath: captureResult.screenshotPath,
                    annotatedPath: annotatedPath,
                    metadata: captureResult.metadata,
                    elements: captureResult.elements,
                    analysisResult: analysisResult,
                    executionTime: executionTime)
            }

        } catch {
            Logger.shared.operationComplete("see_command", success: false, metadata: [
                "error": error.localizedDescription,
            ])
            if self.jsonOutput {
                ImageErrorHandler.handleError(error, jsonOutput: true)
            } else {
                ImageErrorHandler.handleError(error, jsonOutput: false)
            }
            throw ExitCode.failure
        }
    }

    private func getFileSize(_ path: String) -> Int? {
        try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int
    }

    private func performCaptureWithDetection() async throws -> CaptureAndDetectionResult {
        let effectiveMode = self.determineMode()
        Logger.shared.verbose(
            "Determined capture mode",
            category: "Capture",
            metadata: ["mode": effectiveMode.rawValue])

        // Capture screenshot based on mode
        let captureResult: CaptureResult

        switch effectiveMode {
        case .screen:
            Logger.shared.verbose("Initiating full screen capture", category: "Capture")
            Logger.shared.startTimer("screen_capture")
            captureResult = try await PeekabooServices.shared.screenCapture.captureScreen(displayIndex: nil)
            Logger.shared.stopTimer("screen_capture")

        case .window:
            if let appName = app {
                Logger.shared.verbose("Initiating window capture", category: "Capture", metadata: [
                    "app": appName,
                    "windowTitle": self.windowTitle ?? "any",
                ])

                // Find specific window if title is provided
                if let title = windowTitle {
                    Logger.shared.verbose(
                        "Searching for window with title",
                        category: "WindowSearch",
                        metadata: ["title": title])
                    let windows = try await PeekabooServices.shared.applications.listWindows(for: appName)
                    Logger.shared.verbose("Found windows", category: "WindowSearch", metadata: ["count": windows.count])

                    if let windowIndex = windows.firstIndex(where: { $0.title.contains(title) }) {
                        Logger.shared.verbose(
                            "Window found at index",
                            category: "WindowSearch",
                            metadata: ["index": windowIndex])
                        Logger.shared.startTimer("window_capture")
                        captureResult = try await PeekabooServices.shared.screenCapture.captureWindow(
                            appIdentifier: appName,
                            windowIndex: windowIndex)
                        Logger.shared.stopTimer("window_capture")
                    } else {
                        Logger.shared.error(
                            "Window not found with title",
                            category: "WindowSearch",
                            metadata: ["title": title])
                        throw CaptureError.windowNotFound
                    }
                } else {
                    captureResult = try await PeekabooServices.shared.screenCapture.captureWindow(
                        appIdentifier: appName,
                        windowIndex: nil)
                }
            } else {
                throw ValidationError("--app is required for window mode")
            }

        case .frontmost:
            Logger.shared.verbose("Capturing frontmost window")
            captureResult = try await PeekabooServices.shared.screenCapture.captureFrontmost()
        }

        // Save screenshot
        let outputPath = try saveScreenshot(captureResult.imageData)

        // Detect UI elements
        let detectionResult = try await PeekabooServices.shared.automation.detectElements(
            in: captureResult.imageData,
            sessionId: nil)

        // Store enhanced detection result with window metadata
        let enhancedResult = ElementDetectionResult(
            sessionId: detectionResult.sessionId,
            screenshotPath: outputPath,
            elements: detectionResult.elements,
            metadata: DetectionMetadata(
                detectionTime: detectionResult.metadata.detectionTime,
                elementCount: detectionResult.metadata.elementCount,
                method: detectionResult.metadata.method,
                warnings: detectionResult.metadata.warnings,
                applicationName: captureResult.metadata.applicationInfo?.name,
                windowTitle: captureResult.metadata.windowInfo?.title,
                windowBounds: captureResult.metadata.windowInfo?.bounds))

        // Store the enhanced result in session
        try await PeekabooServices.shared.sessions.storeDetectionResult(
            sessionId: detectionResult.sessionId,
            result: enhancedResult)

        return CaptureAndDetectionResult(
            sessionId: detectionResult.sessionId,
            screenshotPath: outputPath,
            elements: detectionResult.elements,
            metadata: enhancedResult.metadata)
    }

    private func saveScreenshot(_ imageData: Data) throws -> String {
        let outputPath: String

        if let providedPath = path {
            outputPath = NSString(string: providedPath).expandingTildeInPath
        } else {
            let timestamp = Date().timeIntervalSince1970
            let filename = "peekaboo_see_\(Int(timestamp)).png"
            let defaultPath = ConfigurationManager.shared.getDefaultSavePath(cliValue: nil)
            outputPath = (defaultPath as NSString).appendingPathComponent(filename)
        }

        // Create directory if needed
        let directory = (outputPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true)

        // Save the image
        try imageData.write(to: URL(fileURLWithPath: outputPath))
        Logger.shared.verbose("Saved screenshot to: \(outputPath)")

        return outputPath
    }

    private func generateAnnotatedScreenshot(
        sessionId: String,
        originalPath: String) async throws -> String
    {
        // Get detection result from session
        guard let detectionResult = try await PeekabooServices.shared.sessions.getDetectionResult(sessionId: sessionId)
        else {
            Logger.shared.info("No detection result found for session")
            return originalPath
        }

        // Create annotated image
        let annotatedPath = (originalPath as NSString).deletingPathExtension + "_annotated.png"

        // Load original image
        guard let nsImage = NSImage(contentsOfFile: originalPath) else {
            throw CaptureError.fileIOError("Failed to load image from \(originalPath)")
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
        let roleColors: [ElementType: NSColor] = [
            .button: NSColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0), // #007AFF
            .textField: NSColor(red: 0.204, green: 0.78, blue: 0.349, alpha: 1.0), // #34C759
            .link: NSColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0), // #007AFF
            .checkbox: NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0), // #8E8E93
            .slider: NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0), // #8E8E93
            .menu: NSColor(red: 0, green: 0.48, blue: 1.0, alpha: 1.0), // #007AFF
        ]

        // Get window bounds for coordinate transformation
        let windowBounds = detectionResult.metadata.windowBounds ?? .zero

        // Draw UI elements
        for element in detectionResult.elements.all where element.isEnabled {
            // Get color for element type
            let color = roleColors[element.type] ?? NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)

            // Transform coordinates from screen space to window-relative space
            var elementFrame = element.bounds
            if windowBounds != .zero {
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

            color.withAlphaComponent(0.5).setFill()
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

        try pngData.write(to: URL(fileURLWithPath: annotatedPath))
        Logger.shared.verbose("Created annotated screenshot: \(annotatedPath)")

        // Log annotation info only in non-JSON mode
        if !self.jsonOutput {
            let interactableElements = detectionResult.elements.all.filter(\.isEnabled)
            print("📝 Created annotated screenshot with \(interactableElements.count) interactive elements")
        }

        return annotatedPath
    }

    private func performAnalysis(imagePath: String, prompt: String) async throws -> String {
        // For now, just return a placeholder since AI provider is broken
        return "AI analysis is temporarily unavailable"
    }

    private func determineMode() -> CaptureMode {
        if let mode = self.mode {
            mode
        } else if self.app != nil || self.windowTitle != nil {
            // If app or window title is specified, default to window mode
            .window
        } else {
            // Otherwise default to frontmost
            .frontmost
        }
    }

    // MARK: - Output Methods

    @MainActor
    private func outputJSONResults(
        sessionId: String,
        screenshotPath: String,
        annotatedPath: String?,
        metadata: DetectionMetadata,
        elements: DetectedElements,
        analysisResult: String?,
        executionTime: TimeInterval) async
    {
        // Build UI element summaries
        let uiElements: [UIElementSummary] = elements.all.map { element in
            UIElementSummary(
                id: element.id,
                role: element.type.rawValue,
                title: element.attributes["title"],
                label: element.label,
                identifier: element.attributes["identifier"],
                is_actionable: element.isEnabled,
                keyboard_shortcut: element.attributes["keyboardShortcut"])
        }

        // Build session paths
        let sessionPaths = SessionPaths(
            raw: screenshotPath,
            annotated: annotatedPath ?? screenshotPath,
            map: PeekabooServices.shared.sessions.getSessionStoragePath() + "/\(sessionId)/map.json")

        let output = SeeResult(
            session_id: sessionId,
            screenshot_raw: sessionPaths.raw,
            screenshot_annotated: sessionPaths.annotated,
            ui_map: sessionPaths.map,
            application_name: metadata.applicationName,
            window_title: metadata.windowTitle,
            element_count: metadata.elementCount,
            interactable_count: elements.all.count(where: { $0.isEnabled }),
            capture_mode: self.determineMode().rawValue,
            analysis_result: analysisResult,
            execution_time: executionTime,
            ui_elements: uiElements,
            menu_bar: await getMenuBarItemsSummary()
        )

        outputSuccessCodable(data: output)
    }

    @MainActor
    private func getMenuBarItemsSummary() async -> MenuBarSummary {
        // Get menu bar items from service
        var menuExtras: [MenuExtraInfo] = []
        
        do {
            menuExtras = try await PeekabooServices.shared.menu.listMenuExtras()
        } catch {
            // If there's an error, just return empty array
            menuExtras = []
        }
        
        // Group items into menu categories
        // For now, we'll create a simplified view showing each menu bar item as a "menu"
        let menus = menuExtras.map { extra in
            MenuBarSummary.MenuSummary(
                title: extra.title,
                item_count: 1, // Each menu bar item is treated as a single menu
                enabled: true,
                items: [
                    MenuBarSummary.MenuItemSummary(
                        title: extra.title,
                        enabled: true,
                        keyboard_shortcut: nil
                    )
                ]
            )
        }
        
        return MenuBarSummary(menus: menus)
    }
    
    @MainActor
    private func outputTextResults(
        sessionId: String,
        screenshotPath: String,
        annotatedPath: String?,
        metadata: DetectionMetadata,
        elements: DetectedElements,
        analysisResult: String?,
        executionTime: TimeInterval) async
    {
        let sessionPaths = SessionPaths(
            raw: screenshotPath,
            annotated: annotatedPath ?? screenshotPath,
            map: PeekabooServices.shared.sessions.getSessionStoragePath() + "/\(sessionId)/map.json")

        let interactableCount = elements.all.count(where: { $0.isEnabled })

        print("✅ Screenshot captured successfully")
        print("📍 Session ID: \(sessionId)")
        print("🖼  Raw screenshot: \(sessionPaths.raw)")
        if let annotated = annotatedPath {
            print("🎯 Annotated: \(annotated)")
        }
        print("🗺️  UI map: \(sessionPaths.map)")
        print("🔍 Found \(metadata.elementCount) UI elements (\(interactableCount) interactive)")

        if let app = metadata.applicationName {
            print("📱 Application: \(app)")
        }
        if let window = metadata.windowTitle {
            print("🪟 Window: \(window)")
        }
        
        // Show menu bar items
        // Get menu bar items from service
        let menuExtras: [MenuExtraInfo]
        do {
            menuExtras = try await PeekabooServices.shared.menu.listMenuExtras()
        } catch {
            // If there's an error, just return empty array
            menuExtras = []
        }
        
        if !menuExtras.isEmpty {
            print("📊 Menu Bar Items: \(menuExtras.count)")
            for item in menuExtras.prefix(10) { // Show first 10
                print("   • \(item.title)")
            }
            if menuExtras.count > 10 {
                print("   ... and \(menuExtras.count - 10) more")
            }
        }

        if let analysis = analysisResult {
            print("🤖 Analysis:")
            print(analysis)
        }

        print("⏱️  Completed in \(String(format: "%.2f", executionTime))s")
    }
}

// MARK: - Supporting Types

private struct CaptureAndDetectionResult {
    let sessionId: String
    let screenshotPath: String
    let elements: DetectedElements
    let metadata: DetectionMetadata
}

private struct SessionPaths {
    let raw: String
    let annotated: String
    let map: String
}

// MARK: - Extended Detection Metadata

extension DetectionMetadata {
    fileprivate var applicationName: String? {
        warnings.first { $0.hasPrefix("APP:") }?.replacingOccurrences(of: "APP:", with: "")
    }

    fileprivate var windowTitle: String? {
        warnings.first { $0.hasPrefix("WINDOW:") }?.replacingOccurrences(of: "WINDOW:", with: "")
    }

    fileprivate var windowBounds: CGRect? {
        if let boundsString = warnings.first(where: { $0.hasPrefix("BOUNDS:") })?
            .replacingOccurrences(of: "BOUNDS:", with: ""),
            let data = boundsString.data(using: .utf8),
            let rect = try? JSONDecoder().decode(CGRect.self, from: data)
        {
            return rect
        }
        return nil
    }

    fileprivate init(
        detectionTime: TimeInterval,
        elementCount: Int,
        method: String,
        warnings: [String] = [],
        applicationName: String? = nil,
        windowTitle: String? = nil,
        windowBounds: CGRect? = nil)
    {
        var allWarnings = warnings

        // Store metadata in warnings array (temporary until service layer is enhanced)
        if let app = applicationName {
            allWarnings.append("APP:\(app)")
        }
        if let window = windowTitle {
            allWarnings.append("WINDOW:\(window)")
        }
        if let bounds = windowBounds, let boundsData = try? JSONEncoder().encode(bounds),
           let boundsString = String(data: boundsData, encoding: .utf8)
        {
            allWarnings.append("BOUNDS:\(boundsString)")
        }

        self.init(
            detectionTime: detectionTime,
            elementCount: elementCount,
            method: method,
            warnings: allWarnings)
    }
}

// MARK: - JSON Output Structure (matching original)

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
