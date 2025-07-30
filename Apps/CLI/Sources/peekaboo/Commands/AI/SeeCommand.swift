import AppKit
import ArgumentParser
import AXorcist
import CoreGraphics
import Foundation
import PeekabooCore
import ScreenCaptureKit

/// Capture a screenshot and build an interactive UI map
@available(macOS 14.0, *)
struct SeeCommand: AsyncParsableCommand, VerboseCommand, ErrorHandlingCommand, OutputFormattable,
ApplicationResolvable {
    static let configuration = VisionToolDefinitions.see.commandConfiguration

    @Option(help: "Application name to capture, or special values: 'menubar', 'frontmost'")
    var app: String?

    @Option(name: .long, help: "Target application by process ID")
    var pid: Int32?

    @Option(help: "Specific window title to capture")
    var windowTitle: String?

    @Option(help: "Capture mode (screen, window, frontmost)")
    var mode: CaptureMode?

    @Option(help: "Output path for screenshot")
    var path: String?
    
    @Option(name: .long, help: "Specific screen index to capture (0-based). If not specified, captures all screens when in screen mode")
    var screenIndex: Int?

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

    @MainActor
    mutating func run() async throws {
        let startTime = Date()
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
            try await requireScreenRecordingPermission()
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
                    originalPath: captureResult.screenshotPath
                )
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
                    prompt: prompt
                )
                Logger.shared.operationComplete("ai_analysis", success: analysisResult != nil)
            }

            // Output results
            let executionTime = Date().timeIntervalSince(startTime)
            Logger.shared.operationComplete("see_command", metadata: [
                "executionTimeMs": Int(executionTime * 1000),
                "success": true,
            ])

            if self.jsonOutput {
                await self.outputJSONResults(
                    sessionId: captureResult.sessionId,
                    screenshotPath: captureResult.screenshotPath,
                    annotatedPath: annotatedPath,
                    metadata: captureResult.metadata,
                    elements: captureResult.elements,
                    analysisResult: analysisResult,
                    executionTime: executionTime
                )
            } else {
                await self.outputTextResults(
                    sessionId: captureResult.sessionId,
                    screenshotPath: captureResult.screenshotPath,
                    annotatedPath: annotatedPath,
                    metadata: captureResult.metadata,
                    elements: captureResult.elements,
                    analysisResult: analysisResult,
                    executionTime: executionTime
                )
            }

        } catch {
            Logger.shared.operationComplete("see_command", success: false, metadata: [
                "error": error.localizedDescription,
            ])
            self.handleError(error) // Use protocol's error handling
            throw ExitCode.failure
        }
    }

    private func getFileSize(_ path: String) -> Int? {
        try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int
    }

    private func performCaptureWithDetection() async throws -> CaptureAndDetectionResult {
        // Handle special app cases
        let captureResult: CaptureResult
        
        if let appName = self.app?.lowercased() {
            switch appName {
            case "menubar":
                Logger.shared.verbose("Capturing menu bar area", category: "Capture")
                captureResult = try await self.captureMenuBar()
            case "frontmost":
                Logger.shared.verbose("Capturing frontmost window (via --app frontmost)", category: "Capture")
                captureResult = try await PeekabooServices.shared.screenCapture.captureFrontmost()
            default:
                // Use normal capture logic
                captureResult = try await self.performStandardCapture()
            }
        } else {
            // Use normal capture logic
            captureResult = try await self.performStandardCapture()
        }

        // Save screenshot
        let outputPath = try saveScreenshot(captureResult.imageData)

        // Create window context from capture metadata
        let windowContext = WindowContext(
            applicationName: captureResult.metadata.applicationInfo?.name,
            windowTitle: captureResult.metadata.windowInfo?.title,
            windowBounds: captureResult.metadata.windowInfo?.bounds
        )

        // Detect UI elements with window context
        let detectionResult = try await PeekabooServices.shared.automation.detectElements(
            in: captureResult.imageData,
            sessionId: nil,
            windowContext: windowContext
        )

        // Update the result with the correct screenshot path
        let resultWithPath = ElementDetectionResult(
            sessionId: detectionResult.sessionId,
            screenshotPath: outputPath,
            elements: detectionResult.elements,
            metadata: detectionResult.metadata
        )

        // Store the result in session
        try await PeekabooServices.shared.sessions.storeDetectionResult(
            sessionId: detectionResult.sessionId,
            result: resultWithPath
        )

        return CaptureAndDetectionResult(
            sessionId: detectionResult.sessionId,
            screenshotPath: outputPath,
            elements: detectionResult.elements,
            metadata: detectionResult.metadata
        )
    }
    
    private func performStandardCapture() async throws -> CaptureResult {
        let effectiveMode = self.determineMode()
        Logger.shared.verbose(
            "Determined capture mode",
            category: "Capture",
            metadata: ["mode": effectiveMode.rawValue]
        )

        // Capture screenshot based on mode
        let captureResults: [CaptureResult]

        switch effectiveMode {
        case .screen:
            // Log warning if annotation was requested for full screen captures
            if self.annotate {
                Logger.shared.info("Annotation is disabled for full screen captures due to performance constraints")
                // Don't actually modify self.annotate since we can't in a non-mutating function
            }
            
            Logger.shared.verbose("Initiating screen capture", category: "Capture")
            Logger.shared.startTimer("screen_capture")
            
            if let index = self.screenIndex {
                // Capture specific screen
                Logger.shared.verbose("Capturing specific screen", category: "Capture", metadata: ["screenIndex": index])
                let result = try await PeekabooServices.shared.screenCapture.captureScreen(displayIndex: index)
                captureResults = [result]
            } else {
                // Capture all screens
                Logger.shared.verbose("Capturing all screens", category: "Capture")
                captureResults = try await self.captureAllScreens()
            }
            
            Logger.shared.stopTimer("screen_capture")

        case .window:
            if self.app != nil || self.pid != nil {
                let appIdentifier = try self.resolveApplicationIdentifier()
                Logger.shared.verbose("Initiating window capture", category: "Capture", metadata: [
                    "app": appIdentifier,
                    "windowTitle": self.windowTitle ?? "any",
                ])

                // Find specific window if title is provided
                if let title = windowTitle {
                    Logger.shared.verbose(
                        "Searching for window with title",
                        category: "WindowSearch",
                        metadata: ["title": title]
                    )
                    let windowsOutput = try await PeekabooServices.shared.applications.listWindows(for: appIdentifier)
                    Logger.shared.verbose(
                        "Found windows",
                        category: "WindowSearch",
                        metadata: ["count": windowsOutput.data.windows.count]
                    )

                    if let windowIndex = windowsOutput.data.windows.firstIndex(where: { $0.title.contains(title) }) {
                        Logger.shared.verbose(
                            "Window found at index",
                            category: "WindowSearch",
                            metadata: ["index": windowIndex]
                        )
                        Logger.shared.startTimer("window_capture")
                        let result = try await PeekabooServices.shared.screenCapture.captureWindow(
                            appIdentifier: appIdentifier,
                            windowIndex: windowIndex
                        )
                        captureResults = [result]
                        Logger.shared.stopTimer("window_capture")
                    } else {
                        Logger.shared.error(
                            "Window not found with title",
                            category: "WindowSearch",
                            metadata: ["title": title]
                        )
                        throw CaptureError.windowNotFound
                    }
                } else {
                    let result = try await PeekabooServices.shared.screenCapture.captureWindow(
                        appIdentifier: appIdentifier,
                        windowIndex: nil
                    )
                    captureResults = [result]
                }
            } else {
                throw ValidationError("--app or --pid is required for window mode")
            }

        case .frontmost:
            Logger.shared.verbose("Capturing frontmost window")
            let result = try await PeekabooServices.shared.screenCapture.captureFrontmost()
            captureResults = [result]
        }
        
        // For non-screen modes, we always have single result
        if effectiveMode != .screen {
            return captureResults[0]
        }
        
        // For screen mode with multiple results, handle them
        return try await self.handleMultipleScreenCaptures(captureResults)
    }

    private func captureMenuBar() async throws -> CaptureResult {
        // Get the main screen bounds
        guard let mainScreen = NSScreen.main else {
            throw PeekabooError.captureFailed("No main screen found")
        }
        
        // Menu bar is at the top of the screen
        let menuBarHeight: CGFloat = 24.0 // Standard macOS menu bar height
        let menuBarRect = CGRect(
            x: mainScreen.frame.origin.x,
            y: mainScreen.frame.origin.y + mainScreen.frame.height - menuBarHeight,
            width: mainScreen.frame.width,
            height: menuBarHeight
        )
        
        // Capture the menu bar area
        return try await PeekabooServices.shared.screenCapture.captureArea(menuBarRect)
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
            withIntermediateDirectories: true
        )

        // Save the image
        try imageData.write(to: URL(fileURLWithPath: outputPath))
        Logger.shared.verbose("Saved screenshot to: \(outputPath)")

        return outputPath
    }

    private func generateAnnotatedScreenshot(
        sessionId: String,
        originalPath: String
    ) async throws -> String {
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
            bitsPerPixel: 0
        )
        else {
            throw CaptureError.captureFailure("Failed to create bitmap representation")
        }

        // Draw into context
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            Logger.shared.error("Failed to create graphics context")
            throw CaptureError.captureFailure("Failed to create graphics context")
        }
        NSGraphicsContext.current = context
        Logger.shared.verbose("Graphics context created successfully")

        // Draw original image
        nsImage.draw(in: NSRect(origin: .zero, size: imageSize))
        Logger.shared.verbose("Original image drawn")

        // Configure text attributes - smaller font
        let fontSize: CGFloat = 10
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor.white,
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

        // Draw UI elements
        let enabledElements = detectionResult.elements.all.filter(\.isEnabled)
        Logger.shared
            .verbose(
                "Drawing \(enabledElements.count) enabled elements out of \(detectionResult.elements.all.count) total"
            )
        Logger.shared.verbose("Image size: \(imageSize)")

        // Calculate window origin from element bounds if we have elements
        var windowOrigin = CGPoint.zero
        if !detectionResult.elements.all.isEmpty {
            // Find the leftmost and topmost element to estimate window origin
            let minX = detectionResult.elements.all.map(\.bounds.minX).min() ?? 0
            let minY = detectionResult.elements.all.map(\.bounds.minY).min() ?? 0
            windowOrigin = CGPoint(x: minX, y: minY)
            Logger.shared.verbose("Estimated window origin from elements: \(windowOrigin)")
        }

        // Convert all element bounds to window-relative coordinates and flip Y
        var elementRects: [(element: DetectedElement, rect: NSRect)] = []
        for element in enabledElements {
            let elementFrame = CGRect(
                x: element.bounds.origin.x - windowOrigin.x,
                y: element.bounds.origin.y - windowOrigin.y,
                width: element.bounds.width,
                height: element.bounds.height
            )

            let rect = NSRect(
                x: elementFrame.origin.x,
                y: imageSize.height - elementFrame.origin.y - elementFrame.height, // Flip Y coordinate
                width: elementFrame.width,
                height: elementFrame.height
            )

            elementRects.append((element: element, rect: rect))
        }

        // Draw elements and calculate label positions
        var labelPositions: [(rect: NSRect, connection: NSPoint?, element: DetectedElement)] = []

        for (element, rect) in elementRects {
            Logger.shared
                .verbose(
                    "Drawing element: \(element.id), type: \(element.type), original bounds: \(element.bounds), window rect: \(rect)"
                )

            // Get color for element type
            let color = roleColors[element.type] ?? NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)

            // Draw bounding box
            color.withAlphaComponent(0.5).setFill()
            rect.fill()

            color.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 2
            path.stroke()

            // Calculate label size
            let idString = NSAttributedString(string: element.id, attributes: textAttributes)
            let textSize = idString.size()
            let labelPadding: CGFloat = 4
            let labelSize = NSSize(width: textSize.width + labelPadding * 2, height: textSize.height + labelPadding)

            // Smart label placement
            let labelSpacing: CGFloat = 4
            var labelRect: NSRect?
            var connectionPoint: NSPoint?

            // Try positions in order: above, right, left, below, inside
            let positions = [
                // Above
                NSRect(
                    x: rect.midX - labelSize.width / 2,
                    y: rect.maxY + labelSpacing,
                    width: labelSize.width,
                    height: labelSize.height
                ),
                // Right
                NSRect(
                    x: rect.maxX + labelSpacing,
                    y: rect.midY - labelSize.height / 2,
                    width: labelSize.width,
                    height: labelSize.height
                ),
                // Left
                NSRect(
                    x: rect.minX - labelSize.width - labelSpacing,
                    y: rect.midY - labelSize.height / 2,
                    width: labelSize.width,
                    height: labelSize.height
                ),
                // Below
                NSRect(
                    x: rect.midX - labelSize.width / 2,
                    y: rect.minY - labelSize.height - labelSpacing,
                    width: labelSize.width,
                    height: labelSize.height
                ),
            ]

            // Check each position
            for (index, candidateRect) in positions.enumerated() {
                // Check if position is within image bounds
                if candidateRect.minX >= 0 && candidateRect.maxX <= imageSize.width &&
                    candidateRect.minY >= 0 && candidateRect.maxY <= imageSize.height {
                    // Check if it overlaps with any other element
                    var overlaps = false
                    for (otherElement, otherRect) in elementRects {
                        if otherElement.id != element.id && candidateRect.intersects(otherRect) {
                            overlaps = true
                            break
                        }
                    }

                    // Check if it overlaps with already placed labels
                    for (existingLabel, _, _) in labelPositions {
                        if candidateRect.intersects(existingLabel) {
                            overlaps = true
                            break
                        }
                    }

                    if !overlaps {
                        labelRect = candidateRect
                        // Set connection point based on position
                        switch index {
                        case 0: // Above
                            connectionPoint = NSPoint(x: rect.midX, y: rect.maxY)
                        case 1: // Right
                            connectionPoint = NSPoint(x: rect.maxX, y: rect.midY)
                        case 2: // Left
                            connectionPoint = NSPoint(x: rect.minX, y: rect.midY)
                        case 3: // Below
                            connectionPoint = NSPoint(x: rect.midX, y: rect.minY)
                        default:
                            break
                        }
                        break
                    }
                }
            }

            // If no external position works, place inside (top-left with minimal overlap)
            if labelRect == nil {
                // Try different corners inside the element
                let insidePositions = [
                    NSRect(
                        x: rect.minX + 2,
                        y: rect.maxY - labelSize.height - 2,
                        width: labelSize.width,
                        height: labelSize.height
                    ), // Top-left
                    NSRect(
                        x: rect.maxX - labelSize.width - 2,
                        y: rect.maxY - labelSize.height - 2,
                        width: labelSize.width,
                        height: labelSize.height
                    ), // Top-right
                    NSRect(x: rect.minX + 2, y: rect.minY + 2, width: labelSize.width, height: labelSize.height),
                    // Bottom-left
                    NSRect(
                        x: rect.maxX - labelSize.width - 2,
                        y: rect.minY + 2,
                        width: labelSize.width,
                        height: labelSize.height
                    ), // Bottom-right
                ]

                // Pick the first one that fits
                for candidateRect in insidePositions {
                    if rect.contains(candidateRect) {
                        labelRect = candidateRect
                        connectionPoint = nil // No connection line needed for inside placement
                        break
                    }
                }

                // Ultimate fallback - center of element
                if labelRect == nil {
                    labelRect = NSRect(
                        x: rect.midX - labelSize.width / 2,
                        y: rect.midY - labelSize.height / 2,
                        width: labelSize.width,
                        height: labelSize.height
                    )
                }
            }

            if let finalLabelRect = labelRect {
                labelPositions.append((rect: finalLabelRect, connection: connectionPoint, element: element))
            }
        }

        // Draw all labels and connection lines
        for (labelRect, connectionPoint, element) in labelPositions {
            // Draw connection line if label is outside
            if let connection = connectionPoint {
                NSColor.black.withAlphaComponent(0.6).setStroke()
                let linePath = NSBezierPath()
                linePath.lineWidth = 1

                // Draw line from connection point to nearest edge of label
                linePath.move(to: connection)

                // Find the closest point on label rectangle to the connection point
                let closestX = max(labelRect.minX, min(connection.x, labelRect.maxX))
                let closestY = max(labelRect.minY, min(connection.y, labelRect.maxY))
                linePath.line(to: NSPoint(x: closestX, y: closestY))

                linePath.stroke()
            }

            // Draw label background
            NSColor.black.withAlphaComponent(0.85).setFill()
            NSBezierPath(roundedRect: labelRect, xRadius: 2, yRadius: 2).fill()

            // Draw label border (same color as element)
            let color = roleColors[element.type] ?? NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)
            color.setStroke()
            let borderPath = NSBezierPath(roundedRect: labelRect, xRadius: 2, yRadius: 2)
            borderPath.lineWidth = 1
            borderPath.stroke()

            // Draw label text
            let idString = NSAttributedString(string: element.id, attributes: textAttributes)
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
        "AI analysis is temporarily unavailable"
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
        executionTime: TimeInterval
    ) async {
        // Build UI element summaries
        let uiElements: [UIElementSummary] = elements.all.map { element in
            UIElementSummary(
                id: element.id,
                role: element.type.rawValue,
                title: element.attributes["title"],
                label: element.label,
                identifier: element.attributes["identifier"],
                is_actionable: element.isEnabled,
                keyboard_shortcut: element.attributes["keyboardShortcut"]
            )
        }

        // Build session paths
        let sessionPaths = SessionPaths(
            raw: screenshotPath,
            annotated: annotatedPath ?? screenshotPath,
            map: PeekabooServices.shared.sessions.getSessionStoragePath() + "/\(sessionId)/map.json"
        )

        let output = await SeeResult(
            session_id: sessionId,
            screenshot_raw: sessionPaths.raw,
            screenshot_annotated: sessionPaths.annotated,
            ui_map: sessionPaths.map,
            application_name: metadata.windowContext?.applicationName,
            window_title: metadata.windowContext?.windowTitle,
            is_dialog: metadata.isDialog,
            element_count: metadata.elementCount,
            interactable_count: elements.all.count { $0.isEnabled },
            capture_mode: self.determineMode().rawValue,
            analysis_result: analysisResult,
            execution_time: executionTime,
            ui_elements: uiElements,
            menu_bar: self.getMenuBarItemsSummary()
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
        executionTime: TimeInterval
    ) async {
        let sessionPaths = SessionPaths(
            raw: screenshotPath,
            annotated: annotatedPath ?? screenshotPath,
            map: PeekabooServices.shared.sessions.getSessionStoragePath() + "/\(sessionId)/map.json"
        )

        let interactableCount = elements.all.count { $0.isEnabled }

        print("✅ Screenshot captured successfully")
        print("📍 Session ID: \(sessionId)")
        print("🖼  Raw screenshot: \(sessionPaths.raw)")
        if let annotated = annotatedPath {
            print("🎯 Annotated: \(annotated)")
        }
        print("🗺️  UI map: \(sessionPaths.map)")
        print("🔍 Found \(metadata.elementCount) UI elements (\(interactableCount) interactive)")

        if let app = metadata.windowContext?.applicationName {
            print("📱 Application: \(app)")
        }
        if let window = metadata.windowContext?.windowTitle {
            let windowType = metadata.isDialog ? "Dialog" : "Window"
            let icon = metadata.isDialog ? "🗨️" : "🪟"
            print("\(icon) \(windowType): \(window)")
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

// MARK: - JSON Output Structure (matching original)

struct SeeResult: Codable {
    let session_id: String
    let screenshot_raw: String
    let screenshot_annotated: String
    let ui_map: String
    let application_name: String?
    let window_title: String?
    let is_dialog: Bool
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

// MARK: - Multi-Screen Support

extension SeeCommand {
    private func captureAllScreens() async throws -> [CaptureResult] {
        var results: [CaptureResult] = []
        
        // Get available displays from the screen capture service
        let content = try await SCShareableContent.current
        let displays = content.displays
        
        Logger.shared.info("Found \(displays.count) display(s) to capture")
        
        for (index, display) in displays.enumerated() {
            Logger.shared.verbose("Capturing display \(index)", category: "MultiScreen", metadata: [
                "displayID": display.displayID,
                "width": display.width,
                "height": display.height
            ])
            
            do {
                let result = try await PeekabooServices.shared.screenCapture.captureScreen(displayIndex: index)
                
                // Update path to include screen index if capturing multiple screens
                if displays.count > 1 {
                    let updatedResult = self.updateCaptureResultPath(result, screenIndex: index, displayInfo: display)
                    results.append(updatedResult)
                } else {
                    results.append(result)
                }
            } catch {
                Logger.shared.error("Failed to capture display \(index): \(error)")
                // Continue capturing other screens even if one fails
            }
        }
        
        if results.isEmpty {
            throw CaptureError.captureFailure("Failed to capture any screens")
        }
        
        return results
    }
    
    private func updateCaptureResultPath(_ result: CaptureResult, screenIndex: Int, displayInfo: SCDisplay) -> CaptureResult {
        // Since CaptureResult is immutable and doesn't have a path property,
        // we can't update the path. Just return the original result.
        // The saved path is already included in result.savedPath if it was saved.
        return result
    }
    
    private func handleMultipleScreenCaptures(_ results: [CaptureResult]) async throws -> CaptureResult {
        if results.count == 1 {
            // Single screen - show display info if available
            if let displayInfo = results[0].metadata.displayInfo {
                print("🖥️  Display \(displayInfo.index): \(Int(displayInfo.bounds.width))×\(Int(displayInfo.bounds.height))")
            }
            return results[0]
        }
        
        // For multiple screens, output information about all captures
        print("📸 Captured \(results.count) screens:")
        for (index, result) in results.enumerated() {
            if let savedPath = result.savedPath {
                let fileSize = self.getFileSize(savedPath) ?? 0
                if let displayInfo = result.metadata.displayInfo {
                    print("   🖥️  Display \(displayInfo.index): \(Int(displayInfo.bounds.width))×\(Int(displayInfo.bounds.height)) → \(savedPath) (\(self.formatFileSize(Int64(fileSize))))")
                } else {
                    print("   📸 Screen \(index): \(savedPath) (\(self.formatFileSize(Int64(fileSize))))")
                }
            }
        }
        
        // Return the first result as the primary one
        // In future, we could combine them or handle differently
        return results[0]
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
