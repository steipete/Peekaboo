import Algorithms
import AppKit
import AXorcist
import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation
import ScreenCaptureKit

private enum ScreenCaptureBridge {
    static func captureFrontmost(services: any PeekabooServiceProviding) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureFrontmost()
        }.value
    }

    static func captureWindow(
        services: any PeekabooServiceProviding,
        appIdentifier: String,
        windowIndex: Int?
    ) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureWindow(appIdentifier: appIdentifier, windowIndex: windowIndex)
        }.value
    }

    static func captureArea(services: any PeekabooServiceProviding, rect: CGRect) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureArea(rect)
        }.value
    }

    static func captureScreen(
        services: any PeekabooServiceProviding,
        displayIndex: Int?
    ) async throws -> CaptureResult {
        try await Task { @MainActor in
            try await services.screenCapture.captureScreen(displayIndex: displayIndex)
        }.value
    }
}

/// Capture a screenshot and build an interactive UI map
@available(macOS 14.0, *)
@MainActor
struct SeeCommand: ApplicationResolvable, ErrorHandlingCommand, RuntimeOptionsConfigurable, CaptureEngineConfigurable {
    @Option(help: "Application name to capture, or special values: 'menubar', 'frontmost'")
    var app: String?

    @Option(name: .long, help: "Target application by process ID")
    var pid: Int32?

    @Option(help: "Specific window title to capture")
    var windowTitle: String?

    @Option(help: "Capture mode (screen, window, frontmost)")
    var mode: PeekabooCore.CaptureMode?

    @Option(
        names: [.automatic, .customLong("save"), .customLong("output"), .customShort("o", allowingJoined: false)],
        help: "Output path for screenshot (aliases: --save, --output, -o)"
    )
    var path: String?

    @Option(
        name: .long,
        help: "Specific screen index to capture (0-based). If not specified, captures all screens when in screen mode"
    )
    var screenIndex: Int?

    @Flag(help: "Generate annotated screenshot with interaction markers")
    var annotate = false

    @Option(help: "Analyze captured content with AI")
    var analyze: String?

    @Option(
        name: .long,
        help: "Capture engine: auto|modern|sckit|classic|cg (default: auto). modern/sckit force ScreenCaptureKit; classic/cg force CGWindowList; auto tries SC then falls back when allowed."
    )
    var captureEngine: String?

    @Flag(name: .customLong("no-web-focus"), help: "Skip web-content focus fallback when no text fields are detected")
    var noWebFocus = false
    @RuntimeStorage private var runtime: CommandRuntime?
    var runtimeOptions = CommandRuntimeOptions()

    private var resolvedRuntime: CommandRuntime {
        guard let runtime else {
            preconditionFailure("CommandRuntime must be configured before accessing runtime resources")
        }
        return runtime
    }

    var jsonOutput: Bool { self.runtime?.configuration.jsonOutput ?? self.runtimeOptions.jsonOutput }
    var verbose: Bool { self.runtime?.configuration.verbose ?? self.runtimeOptions.verbose }

    private var logger: Logger { self.resolvedRuntime.logger }
    private var services: any PeekabooServiceProviding { self.resolvedRuntime.services }
    var outputLogger: Logger { self.logger }

    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        self.runtime = runtime
        let startTime = Date()
        let logger = self.logger

        logger.operationStart("see_command", metadata: [
            "app": self.app ?? "none",
            "mode": self.mode?.rawValue ?? "auto",
            "annotate": self.annotate,
            "hasAnalyzePrompt": self.analyze != nil,
        ])

        do {
            // Check permissions
            logger.verbose("Checking screen recording permissions", category: "Permissions")
            try await requireScreenRecordingPermission(services: self.services)
            logger.verbose("Screen recording permission granted", category: "Permissions")

            // Perform capture and element detection
            logger.verbose("Starting capture and detection phase", category: "Capture")
            let captureResult = try await performCaptureWithDetection()
            logger.verbose("Capture completed successfully", category: "Capture", metadata: [
                "sessionId": captureResult.sessionId,
                "elementCount": captureResult.elements.all.count,
                "screenshotSize": self.getFileSize(captureResult.screenshotPath) ?? 0,
            ])

            // Generate annotated screenshot if requested
            var annotatedPath: String?
            if self.annotate {
                logger.operationStart("generate_annotations")
                annotatedPath = try await self.generateAnnotatedScreenshot(
                    sessionId: captureResult.sessionId,
                    originalPath: captureResult.screenshotPath
                )
                logger.operationComplete("generate_annotations", metadata: [
                    "annotatedPath": annotatedPath ?? "none",
                ])
            }

            // Perform AI analysis if requested
            var analysisResult: SeeAnalysisData?
            if let prompt = analyze {
                // Pre-analysis diagnostics
                let fileSize = (try? FileManager.default
                    .attributesOfItem(atPath: captureResult.screenshotPath)[.size] as? Int) ?? 0
                logger.verbose(
                    "Starting AI analysis",
                    category: "AI",
                    metadata: [
                        "imagePath": captureResult.screenshotPath,
                        "imageSizeBytes": fileSize,
                        "promptLength": prompt.count
                    ]
                )
                logger.operationStart("ai_analysis", metadata: ["promptPreview": String(prompt.prefix(80))])
                logger.startTimer("ai_generate")
                analysisResult = try await self.performAnalysisDetailed(
                    imagePath: captureResult.screenshotPath,
                    prompt: prompt
                )
                logger.stopTimer("ai_generate")
                logger.operationComplete(
                    "ai_analysis",
                    success: analysisResult != nil,
                    metadata: [
                        "provider": analysisResult?.provider ?? "unknown",
                        "model": analysisResult?.model ?? "unknown"
                    ]
                )
            }

            // Output results
            let executionTime = Date().timeIntervalSince(startTime)
            logger.operationComplete("see_command", metadata: [
                "executionTimeMs": Int(executionTime * 1000),
                "success": true,
            ])

            let context = SeeCommandRenderContext(
                sessionId: captureResult.sessionId,
                screenshotPath: captureResult.screenshotPath,
                annotatedPath: annotatedPath,
                metadata: captureResult.metadata,
                elements: captureResult.elements,
                analysis: analysisResult,
                executionTime: executionTime
            )
            await self.renderResults(context: context)

        } catch {
            logger.operationComplete("see_command", success: false, metadata: [
                "error": error.localizedDescription,
            ])
            self.handleError(error) // Use protocol's error handling
            throw ExitCode.failure
        }
    }

    private func getFileSize(_ path: String) -> Int? {
        try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int
    }

    private func renderResults(context: SeeCommandRenderContext) async {
        if self.jsonOutput {
            await self.outputJSONResults(context: context)
        } else {
            await self.outputTextResults(context: context)
        }
    }

    private func performCaptureWithDetection() async throws -> CaptureAndDetectionResult {
        // Handle special app cases
        let captureResult: CaptureResult

        if let appName = self.app?.lowercased() {
            switch appName {
            case "menubar":
                self.logger.verbose("Capturing menu bar area", category: "Capture")
                captureResult = try await self.captureMenuBar()
            case "frontmost":
                self.logger.verbose("Capturing frontmost window (via --app frontmost)", category: "Capture")
                captureResult = try await ScreenCaptureBridge.captureFrontmost(services: self.services)
            default:
                // Use normal capture logic
                captureResult = try await self.performStandardCapture()
            }
        } else {
            // Use normal capture logic
            captureResult = try await self.performStandardCapture()
        }

        // Save screenshot
        self.logger.startTimer("file_write")
        let outputPath = try saveScreenshot(captureResult.imageData)
        self.logger.stopTimer("file_write")

        // Create window context from capture metadata
        let windowContext = WindowContext(
            applicationName: captureResult.metadata.applicationInfo?.name,
            windowTitle: captureResult.metadata.windowInfo?.title,
            windowBounds: captureResult.metadata.windowInfo?.bounds,
            shouldFocusWebContent: self.noWebFocus ? false : true
        )

        // Detect UI elements with window context
        self.logger.operationStart("element_detection")
        let detectionResult = try await AutomationServiceBridge.detectElements(
            automation: self.services.automation,
            imageData: captureResult.imageData,
            sessionId: nil,
            windowContext: windowContext
        )
        self.logger.operationComplete("element_detection")

        // Update the result with the correct screenshot path
        let resultWithPath = ElementDetectionResult(
            sessionId: detectionResult.sessionId,
            screenshotPath: outputPath,
            elements: detectionResult.elements,
            metadata: detectionResult.metadata
        )

        try await self.services.sessions.storeScreenshot(
            sessionId: detectionResult.sessionId,
            screenshotPath: outputPath,
            applicationName: windowContext.applicationName,
            windowTitle: windowContext.windowTitle,
            windowBounds: windowContext.windowBounds
        )

        // Store the result in session
        try await self.services.sessions.storeDetectionResult(
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
        self.logger.verbose(
            "Determined capture mode",
            category: "Capture",
            metadata: ["mode": effectiveMode.rawValue]
        )

        self.logger.operationStart("capture_phase", metadata: ["mode": effectiveMode.rawValue])
        switch effectiveMode {
        case .screen:
            // Handle screen capture with multi-screen support
            let result = try await self.performScreenCapture()
            self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
            return result

        case .multi:
            // Commander currently treats multi captures as multi-display screen grabs
            let result = try await self.performScreenCapture()
            self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
            return result

        case .window:
            if self.app != nil || self.pid != nil {
                let appIdentifier = try self.resolveApplicationIdentifier()
                self.logger.verbose("Initiating window capture", category: "Capture", metadata: [
                    "app": appIdentifier,
                    "windowTitle": self.windowTitle ?? "any",
                ])

                let windowIndex = try await self.resolveSeeWindowIndex(
                    appIdentifier: appIdentifier,
                    titleFragment: self.windowTitle
                )

                self.logger.startTimer("window_capture")
                let result = try await ScreenCaptureBridge.captureWindow(
                    services: self.services,
                    appIdentifier: appIdentifier,
                    windowIndex: windowIndex
                )
                self.logger.stopTimer("window_capture")
                self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
                return result
            } else {
                throw ValidationError("--app or --pid is required for window mode")
            }

        case .frontmost:
            self.logger.verbose("Capturing frontmost window")
            let result = try await ScreenCaptureBridge.captureFrontmost(services: self.services)
            self.logger.operationComplete("capture_phase", metadata: ["mode": effectiveMode.rawValue])
            return result

        case .area:
            throw ValidationError("Area capture mode is not supported for 'see' yet. Use --mode screen or window")
        }
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
        return try await ScreenCaptureBridge.captureArea(services: self.services, rect: menuBarRect)
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
        self.logger.verbose("Saved screenshot to: \(outputPath)")

        return outputPath
    }

    private func resolveSeeWindowIndex(appIdentifier: String, titleFragment: String?) async throws -> Int? {
        do {
            let windows = try await WindowServiceBridge.listWindows(
                windows: self.services.windows,
                target: .application(appIdentifier)
            )

            let filtered = WindowFilterHelper.filter(
                windows: windows,
                appIdentifier: appIdentifier,
                mode: .capture,
                logger: self.logger
            )

            guard !filtered.isEmpty else {
                throw CaptureError.windowNotFound
            }

            if let fragment = titleFragment {
                guard let match = filtered.first(where: { window in
                    window.title.localizedCaseInsensitiveContains(fragment)
                }) else {
                    throw CaptureError.windowNotFound
                }
                return match.index
            }

            return filtered.first?.index
        } catch let error as PeekabooError {
            switch error {
            case .permissionDeniedAccessibility, .windowNotFound:
                self.logger.debug(
                    "Window enumeration unavailable; falling back",
                    metadata: ["app": appIdentifier, "reason": error.localizedDescription]
                )
                return nil
            default:
                throw error
            }
        } catch {
            self.logger.debug(
                "Window enumeration failed; falling back",
                metadata: ["app": appIdentifier, "reason": error.localizedDescription]
            )
            return nil
        }
    }

    // swiftlint:disable function_body_length
    private func generateAnnotatedScreenshot(
        sessionId: String,
        originalPath: String
    ) async throws -> String {
        // Get detection result from session
        guard let detectionResult = try await self.services.sessions.getDetectionResult(sessionId: sessionId)
        else {
            self.logger.info("No detection result found for session")
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
            self.logger.error("Failed to create graphics context")
            throw CaptureError.captureFailure("Failed to create graphics context")
        }
        NSGraphicsContext.current = context
        self.logger.verbose("Graphics context created successfully")

        // Draw original image
        nsImage.draw(in: NSRect(origin: .zero, size: imageSize))
        self.logger.verbose("Original image drawn")

        // Configure text attributes - smaller font for less occlusion
        let fontSize: CGFloat = 8
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
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

        if enabledElements.isEmpty {
            self.logger.info("No enabled elements to annotate. Total elements: \(detectionResult.elements.all.count)")
            print("\(AgentDisplayTokens.Status.warning)  No interactive UI elements found to annotate")
            return originalPath // Return original image if no elements to annotate
        }

        self.logger.info(
            "Annotating \(enabledElements.count) enabled elements out of \(detectionResult.elements.all.count) total"
        )
        self.logger.verbose("Image size: \(imageSize)")

        // Calculate window origin from element bounds if we have elements
        var windowOrigin = CGPoint.zero
        if !detectionResult.elements.all.isEmpty {
            // Find the leftmost and topmost element to estimate window origin
            let minX = detectionResult.elements.all.map(\.bounds.minX).min() ?? 0
            let minY = detectionResult.elements.all.map(\.bounds.minY).min() ?? 0
            windowOrigin = CGPoint(x: minX, y: minY)
            self.logger.verbose("Estimated window origin from elements: \(windowOrigin)")
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

        // Create smart label placer for intelligent label positioning
        let labelPlacer = SmartLabelPlacer(
            image: nsImage,
            fontSize: fontSize,
            debugMode: self.verbose,
            logger: self.logger
        )

        // Draw elements and calculate label positions
        var labelPositions: [(rect: NSRect, connection: NSPoint?, element: DetectedElement)] = []

        for (element, rect) in elementRects {
            let drawingDetails = [
                "Drawing element: \(element.id)",
                "type: \(element.type)",
                "original bounds: \(element.bounds)",
                "window rect: \(rect)"
            ].joined(separator: ", ")
            self.logger.verbose(drawingDetails)

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

            // Use smart label placer to find best position
            if let placement = labelPlacer.findBestLabelPosition(
                for: element,
                elementRect: rect,
                labelSize: labelSize,
                existingLabels: labelPositions.map { ($0.rect, $0.element) },
                allElements: elementRects
            ) {
                labelPositions.append((
                    rect: placement.labelRect,
                    connection: placement.connectionPoint,
                    element: element
                ))
            }
        }

        // NOTE: Old placement code removed - now using SmartLabelPlacer

        // [OLD CODE REMOVED - lines 483-785 contained the old placement logic]

        // Draw all labels and connection lines
        for (labelRect, connectionPoint, element) in labelPositions {
            // Draw connection line if label is outside - make it more subtle
            if let connection = connectionPoint {
                NSColor.black.withAlphaComponent(0.3).setStroke()
                let linePath = NSBezierPath()
                linePath.lineWidth = 0.5

                // Draw line from connection point to nearest edge of label
                linePath.move(to: connection)

                // Find the closest point on label rectangle to the connection point
                let closestX = max(labelRect.minX, min(connection.x, labelRect.maxX))
                let closestY = max(labelRect.minY, min(connection.y, labelRect.maxY))
                linePath.line(to: NSPoint(x: closestX, y: closestY))

                linePath.stroke()
            }

            // Draw label background - more transparent to show content beneath
            NSColor.black.withAlphaComponent(0.7).setFill()
            NSBezierPath(roundedRect: labelRect, xRadius: 1, yRadius: 1).fill()

            // Draw label border (same color as element) - thinner for less occlusion
            let color = roleColors[element.type] ?? NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1.0)
            color.withAlphaComponent(0.8).setStroke()
            let borderPath = NSBezierPath(roundedRect: labelRect, xRadius: 1, yRadius: 1)
            borderPath.lineWidth = 0.5
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
        self.logger.verbose("Created annotated screenshot: \(annotatedPath)")

        // Log annotation info only in non-JSON mode
        if !self.jsonOutput {
            let interactableElements = detectionResult.elements.all.filter(\.isEnabled)
            print("📝 Created annotated screenshot with \(interactableElements.count) interactive elements")
        }

        return annotatedPath
    }
    // swiftlint:enable function_body_length

    // [OLD CODE REMOVED - massive cleanup of duplicate placement logic]
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

private struct SeeCommandRenderContext {
    let sessionId: String
    let screenshotPath: String
    let annotatedPath: String?
    let metadata: DetectionMetadata
    let elements: DetectedElements
    let analysis: SeeAnalysisData?
    let executionTime: TimeInterval
}

// MARK: - JSON Output Structure (matching original)

struct UIElementSummary: Codable {
    let id: String
    let role: String
    let title: String?
    let label: String?
    let description: String?
    let role_description: String?
    let help: String?
    let identifier: String?
    let is_actionable: Bool
    let keyboard_shortcut: String?
}

struct SeeAnalysisData: Codable {
    let provider: String
    let model: String
    let text: String
}

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
    let analysis: SeeAnalysisData?
    let execution_time: TimeInterval
    let ui_elements: [UIElementSummary]
    let menu_bar: MenuBarSummary?
    var success: Bool = true
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

// MARK: - Format Helpers Extension

extension SeeCommand {
    private func performAnalysisDetailed(imagePath: String, prompt: String) async throws -> SeeAnalysisData {
        // Use PeekabooCore AI service which is configured via ConfigurationManager/Tachikoma
        let ai = PeekabooAIService()
        let res = try await ai.analyzeImageFileDetailed(at: imagePath, question: prompt, model: nil)
        return SeeAnalysisData(provider: res.provider, model: res.model, text: res.text)
    }

    private func buildMenuSummaryIfNeeded() async -> MenuBarSummary? {
        // Placeholder for future UI summary generation; currently unused.
        nil
    }

    private func determineMode() -> PeekabooCore.CaptureMode {
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

    private func outputJSONResults(context: SeeCommandRenderContext) async {
        let uiElements: [UIElementSummary] = context.elements.all.map { element in
            UIElementSummary(
                id: element.id,
                role: element.type.rawValue,
                title: element.attributes["title"],
                label: element.label,
                description: element.attributes["description"],
                role_description: element.attributes["roleDescription"],
                help: element.attributes["help"],
                identifier: element.attributes["identifier"],
                is_actionable: element.isEnabled,
                keyboard_shortcut: element.attributes["keyboardShortcut"]
            )
        }

        let sessionPaths = self.sessionPaths(for: context)

        let output = await SeeResult(
            session_id: context.sessionId,
            screenshot_raw: sessionPaths.raw,
            screenshot_annotated: sessionPaths.annotated,
            ui_map: sessionPaths.map,
            application_name: context.metadata.windowContext?.applicationName,
            window_title: context.metadata.windowContext?.windowTitle,
            is_dialog: context.metadata.isDialog,
            element_count: context.metadata.elementCount,
            interactable_count: context.elements.all.count { $0.isEnabled },
            capture_mode: self.determineMode().rawValue,
            analysis: context.analysis,
            execution_time: context.executionTime,
            ui_elements: uiElements,
            menu_bar: self.getMenuBarItemsSummary()
        )

        outputSuccessCodable(data: output, logger: self.outputLogger)
    }

    private func getMenuBarItemsSummary() async -> MenuBarSummary {
        // Get menu bar items from service
        var menuExtras: [MenuExtraInfo] = []

        do {
            menuExtras = try await self.services.menu.listMenuExtras()
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

    private func outputTextResults(context: SeeCommandRenderContext) async {
        print("🖼️  Screenshot saved to: \(context.screenshotPath)")
        if let annotatedPath = context.annotatedPath {
            print("📝 Annotated screenshot: \(annotatedPath)")
        }

        if let appName = context.metadata.windowContext?.applicationName {
            print("📱 Application: \(appName)")
        }
        if let windowTitle = context.metadata.windowContext?.windowTitle {
            let windowType = context.metadata.isDialog ? "Dialog" : "Window"
            let icon = context.metadata.isDialog ? "🗨️" : "[win]"
            print("\(icon) \(windowType): \(windowTitle)")
        }
        print("🧊 Detection method: \(context.metadata.method)")
        print("📊 UI elements detected: \(context.metadata.elementCount)")
        print("⚙️  Interactable elements: \(context.elements.all.count { $0.isEnabled })")
        let formattedDuration = String(format: "%.2f", context.executionTime)
        print("⏱️  Execution time: \(formattedDuration)s")

        if let analysis = context.analysis {
            print("\n🤖 AI Analysis\n\(analysis.text)")
        }

        if context.metadata.elementCount > 0 {
            print("\n🔍 Element Summary")
            for element in context.elements.all.prefix(10) {
                let summaryLabel = element.label ?? element.attributes["title"] ?? element.value ?? "Untitled"
                print("• \(element.id) (\(element.type.rawValue)) - \(summaryLabel)")
            }

            if context.metadata.elementCount > 10 {
                print("  ...and \(context.metadata.elementCount - 10) more elements")
            }
        }

        if self.annotate {
            print("\n📝 Annotated screenshot created")
        }

        if let menuSummary = await self.buildMenuSummaryIfNeeded() {
            print("\n🧭 Menu Bar Summary")
            for menu in menuSummary.menus {
                print("- \(menu.title) (\(menu.enabled ? "Enabled" : "Disabled"))")
                for item in menu.items.prefix(5) {
                    let shortcut = item.keyboard_shortcut.map { " [\($0)]" } ?? ""
                    print("    • \(item.title)\(shortcut)")
                }
            }
        }

        print("\nSession ID: \(context.sessionId)")

        let terminalCapabilities = TerminalDetector.detectCapabilities()
        if terminalCapabilities.recommendedOutputMode == .minimal {
            print("Agent: Use a tool like view_image to inspect it.")
        }
    }

    private func sessionPaths(for context: SeeCommandRenderContext) -> SessionPaths {
        SessionPaths(
            raw: context.screenshotPath,
            annotated: context.annotatedPath ?? context.screenshotPath,
            map: self.services.sessions.getSessionStoragePath() + "/\(context.sessionId)/map.json"
        )
    }
}

// MARK: - Multi-Screen Support

extension SeeCommand {
    private func performScreenCapture() async throws -> CaptureResult {
        // Log warning if annotation was requested for full screen captures
        if self.annotate {
            self.logger.info("Annotation is disabled for full screen captures due to performance constraints")
        }

        self.logger.verbose("Initiating screen capture", category: "Capture")
        self.logger.startTimer("screen_capture")

        defer {
            self.logger.stopTimer("screen_capture")
        }

        if let index = self.screenIndex ?? (self.analyze != nil ? 0 : nil) {
            // Capture specific screen
            self.logger.verbose("Capturing specific screen", category: "Capture", metadata: ["screenIndex": index])
            let result = try await ScreenCaptureBridge.captureScreen(services: self.services, displayIndex: index)

            // Add display info to output
            if let displayInfo = result.metadata.displayInfo {
                self.printScreenDisplayInfo(
                    index: index,
                    displayInfo: displayInfo,
                    indent: "",
                    suffix: nil
                )
            }

            self.logger.verbose("Screen capture completed", category: "Capture", metadata: [
                "mode": "screen-index",
                "screenIndex": index,
                "imageBytes": result.imageData.count
            ])
            return result
        } else {
            // Capture all screens
            self.logger.verbose("Capturing all screens", category: "Capture")
            let results = try await self.captureAllScreens()

            if results.isEmpty {
                throw CaptureError.captureFailure("Failed to capture any screens")
            }

            // Save all screenshots except the first (which will be saved by the normal flow)
            print("📸 Captured \(results.count) screen(s):")

            for (index, result) in results.indexed() {
                if index > 0 {
                    // Save additional screenshots
                    let screenPath: String
                    if let basePath = self.path {
                        // User specified a path - add screen index to filename
                        let directory = (basePath as NSString).deletingLastPathComponent
                        let filename = (basePath as NSString).lastPathComponent
                        let nameWithoutExt = (filename as NSString).deletingPathExtension
                        let ext = (filename as NSString).pathExtension

                        screenPath = (directory as NSString)
                            .appendingPathComponent("\(nameWithoutExt)_screen\(index).\(ext)")
                    } else {
                        // Default path with screen index
                        let timestamp = ISO8601DateFormatter().string(from: Date())
                        screenPath = "screenshot_\(timestamp)_screen\(index).png"
                    }

                    // Save the screenshot
                    try result.imageData.write(to: URL(fileURLWithPath: screenPath))

                    // Display info about this screen
                    if let displayInfo = result.metadata.displayInfo {
                        let fileSize = self.getFileSize(screenPath) ?? 0
                        let suffix = "\(screenPath) (\(self.formatFileSize(Int64(fileSize))))"
                        self.printScreenDisplayInfo(
                            index: index,
                            displayInfo: displayInfo,
                            indent: "   ",
                            suffix: suffix
                        )
                    }
                } else {
                    // First screen will be saved by the normal flow, just show info
                    if let displayInfo = result.metadata.displayInfo {
                        self.printScreenDisplayInfo(
                            index: index,
                            displayInfo: displayInfo,
                            indent: "   ",
                            suffix: "(primary)"
                        )
                    }
                }
            }

            // Return the primary screen result (first one)
            self.logger.verbose("Multi-screen capture completed", category: "Capture", metadata: [
                "count": results.count,
                "primaryBytes": results.first?.imageData.count ?? 0
            ])
            return results[0]
        }
    }
}

// MARK: - Multi-Screen Support

extension SeeCommand {
    private func captureAllScreens() async throws -> [CaptureResult] {
        var results: [CaptureResult] = []

        // Get available displays from the screen capture service
        let content = try await SCShareableContent.current
        let displays = content.displays

        self.logger.info("Found \(displays.count) display(s) to capture")

        for (index, display) in displays.indexed() {
            self.logger.verbose("Capturing display \(index)", category: "MultiScreen", metadata: [
                "displayID": display.displayID,
                "width": display.width,
                "height": display.height
            ])

            do {
                let result = try await ScreenCaptureBridge.captureScreen(services: self.services, displayIndex: index)

                // Update path to include screen index if capturing multiple screens
                if displays.count > 1 {
                    let updatedResult = self.updateCaptureResultPath(result, screenIndex: index, displayInfo: display)
                    results.append(updatedResult)
                } else {
                    results.append(result)
                }
            } catch {
                self.logger.error("Failed to capture display \(index): \(error)")
                // Continue capturing other screens even if one fails
            }
        }

        if results.isEmpty {
            throw CaptureError.captureFailure("Failed to capture any screens")
        }

        return results
    }

    private func updateCaptureResultPath(
        _ result: CaptureResult,
        screenIndex: Int,
        displayInfo: SCDisplay
    ) -> CaptureResult {
        // Since CaptureResult is immutable and doesn't have a path property,
        // we can't update the path. Just return the original result.
        // The saved path is already included in result.savedPath if it was saved.
        result
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

@MainActor
extension SeeCommand: ParsableCommand {
    nonisolated(unsafe) static var commandDescription: CommandDescription {
        MainActorCommandDescription.describe {
            let definition = VisionToolDefinitions.see.commandConfiguration
            return CommandDescription(
                commandName: definition.commandName,
                abstract: definition.abstract,
                discussion: definition.discussion,
                usageExamples: [
                    CommandUsageExample(
                        command: "peekaboo see --json-output --annotate --path /tmp/see.png",
                        description: "Capture the frontmost window, print structured output, and save annotations."
                    ),
                    CommandUsageExample(
                        command: "peekaboo see --app Safari --window-title \"Login\" --json-output",
                        description: "Target a specific Safari window to collect stable element IDs."
                    ),
                    CommandUsageExample(
                        command: "peekaboo see --mode screen --screen-index 0 --analyze 'Summarize the dashboard'",
                        description: "Capture a display and immediately send it to the configured AI provider."
                    )
                ],
                showHelpOnEmptyInvocation: true
            )
        }
    }
}

extension SeeCommand: AsyncRuntimeCommand {}

@MainActor
extension SeeCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.app = values.singleOption("app")
        self.pid = try values.decodeOption("pid", as: Int32.self)
        self.windowTitle = values.singleOption("windowTitle")
        if let parsedMode: PeekabooCore.CaptureMode = try values.decodeOptionEnum("mode", caseInsensitive: false) {
            self.mode = parsedMode
        }
        self.path = values.singleOption("path")
        self.screenIndex = try values.decodeOption("screenIndex", as: Int.self)
        self.annotate = values.flag("annotate")
        self.analyze = values.singleOption("analyze")
    }
}

extension SeeCommand {
    private func screenDisplayBaseText(index: Int, displayInfo: DisplayInfo) -> String {
        let displayName = displayInfo.name ?? "Display \(index)"
        let bounds = displayInfo.bounds
        let resolution = "(\(Int(bounds.width))×\(Int(bounds.height)))"
        return "[scrn]️  Display \(index): \(displayName) \(resolution)"
    }

    private func printScreenDisplayInfo(
        index: Int,
        displayInfo: DisplayInfo,
        indent: String = "",
        suffix: String? = nil
    ) {
        var line = self.screenDisplayBaseText(index: index, displayInfo: displayInfo)
        if let suffix {
            line += " → \(suffix)"
        }
        print("\(indent)\(line)")
    }
}
