import AppKit
import ArgumentParser
import AXorcist
import CoreGraphics
import Foundation
import PeekabooCore

/// Refactored SeeCommand using PeekabooCore services
/// Captures a screenshot and builds an interactive UI map using the service layer
@available(macOS 14.0, *)
struct SeeCommand: AsyncParsableCommand, VerboseCommand {
    static let configuration = CommandConfiguration(
        commandName: "see",
        abstract: "Capture screen and map UI elements using PeekabooCore services",
        discussion: """
            This is a refactored version of the 'see' command that uses PeekabooCore services
            instead of direct implementation. It maintains the same interface but delegates
            all operations to the service layer.
            
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

    private let services = PeekabooServices.shared

    mutating func run() async throws {
        configureVerboseLogging()
        let startTime = Date()
        Logger.shared.verbose("Starting see command execution")

        do {
            // Check permissions
            guard await services.screenCapture.hasScreenRecordingPermission() else {
                throw CaptureError.screenRecordingPermissionDenied
            }

            // Perform capture and element detection
            let captureResult = try await performCaptureWithDetection()
            
            // Generate annotated screenshot if requested
            var annotatedPath: String?
            if annotate {
                annotatedPath = try await generateAnnotatedScreenshot(
                    sessionId: captureResult.sessionId,
                    originalPath: captureResult.screenshotPath
                )
            }
            
            // Perform AI analysis if requested
            var analysisResult: String?
            if let prompt = analyze {
                analysisResult = try await performAnalysis(
                    imagePath: captureResult.screenshotPath,
                    prompt: prompt
                )
            }
            
            // Output results
            let executionTime = Date().timeIntervalSince(startTime)
            if jsonOutput {
                outputJSONResults(
                    sessionId: captureResult.sessionId,
                    screenshotPath: captureResult.screenshotPath,
                    annotatedPath: annotatedPath,
                    metadata: captureResult.metadata,
                    elements: captureResult.elements,
                    analysisResult: analysisResult,
                    executionTime: executionTime
                )
            } else {
                outputTextResults(
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
            if jsonOutput {
                ImageErrorHandler.handleError(error, jsonOutput: true)
            } else {
                ImageErrorHandler.handleError(error, jsonOutput: false)
            }
            throw ExitCode.failure
        }
    }

    private func performCaptureWithDetection() async throws -> CaptureAndDetectionResult {
        let effectiveMode = determineMode()
        Logger.shared.verbose("Using capture mode: \(effectiveMode)")
        
        // Capture screenshot based on mode
        let captureResult: ScreenCaptureResult
        
        switch effectiveMode {
        case .screen:
            Logger.shared.verbose("Capturing entire screen")
            captureResult = try await services.screenCapture.captureScreen(displayIndex: nil)
            
        case .window:
            if let appName = app {
                Logger.shared.verbose("Capturing window for app: \(appName), title: \(windowTitle ?? "any")")
                
                // Find specific window if title is provided
                if let title = windowTitle {
                    let windows = try await services.applications.listWindows(for: appName)
                    if let windowIndex = windows.firstIndex(where: { $0.title.contains(title) }) {
                        captureResult = try await services.screenCapture.captureWindow(
                            appIdentifier: appName,
                            windowIndex: windowIndex
                        )
                    } else {
                        throw CaptureError.windowNotFound
                    }
                } else {
                    captureResult = try await services.screenCapture.captureWindow(
                        appIdentifier: appName,
                        windowIndex: nil
                    )
                }
            } else {
                throw ValidationError("--app is required for window mode")
            }
            
        case .frontmost:
            Logger.shared.verbose("Capturing frontmost window")
            captureResult = try await services.screenCapture.captureFrontmost()
        }
        
        // Save screenshot
        let outputPath = try saveScreenshot(captureResult.imageData)
        
        // Detect UI elements
        let detectionResult = try await services.uiAutomation.detectElements(
            in: captureResult.imageData,
            sessionId: nil
        )
        
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
                windowBounds: captureResult.metadata.windowInfo?.bounds
            )
        )
        
        // Store the enhanced result in session
        try await services.sessionManager.storeDetectionResult(
            sessionId: detectionResult.sessionId,
            result: enhancedResult
        )
        
        return CaptureAndDetectionResult(
            sessionId: detectionResult.sessionId,
            screenshotPath: outputPath,
            elements: detectionResult.elements,
            metadata: enhancedResult.metadata
        )
    }
    
    private func saveScreenshot(_ imageData: Data) throws -> String {
        let outputPath: String
        
        if let providedPath = path {
            outputPath = NSString(string: providedPath).expandingTildeInPath
        } else {
            let timestamp = Date().timeIntervalSince1970
            let filename = "peekaboo_see_\(Int(timestamp)).png"
            let defaultPath = ConfigurationManager.shared.getDefaultSavePath(
                cliValue: nil,
                defaultValue: FileManager.default.temporaryDirectory.path
            )
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
        guard let detectionResult = try await services.sessionManager.getDetectionResult(sessionId: sessionId) else {
            Logger.shared.warning("No detection result found for session")
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
        
        try pngData.write(to: URL(fileURLWithPath: annotatedPath))
        Logger.shared.verbose("Created annotated screenshot: \(annotatedPath)")
        
        // Log annotation info only in non-JSON mode
        if !jsonOutput {
            let interactableElements = detectionResult.elements.all.filter { $0.isEnabled }
            print("📝 Created annotated screenshot with \(interactableElements.count) interactive elements")
        }
        
        return annotatedPath
    }
    
    private func performAnalysis(imagePath: String, prompt: String) async throws -> String {
        // TODO: Implement using AI provider from services
        // For now, return placeholder since AI provider is not yet in PeekabooCore
        Logger.shared.warning("AI analysis not yet implemented in service layer")
        return "AI analysis functionality will be available when AI providers are integrated into PeekabooCore services."
    }
    
    private func determineMode() -> CaptureMode {
        if let mode = self.mode {
            return mode
        } else if app != nil || windowTitle != nil {
            // If app or window title is specified, default to window mode
            return .window
        } else {
            // Otherwise default to frontmost
            return .frontmost
        }
    }
    
    // MARK: - Output Methods
    
    private func outputJSONResults(
        sessionId: String,
        screenshotPath: String,
        annotatedPath: String?,
        metadata: DetectionMetadata,
        elements: DetectedElements,
        analysisResult: String?,
        executionTime: TimeInterval
    ) {
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
            map: services.sessionManager.getSessionStoragePath() + "/\(sessionId)/map.json"
        )
        
        let output = SeeResult(
            session_id: sessionId,
            screenshot_raw: sessionPaths.raw,
            screenshot_annotated: sessionPaths.annotated,
            ui_map: sessionPaths.map,
            application_name: metadata.applicationName,
            window_title: metadata.windowTitle,
            element_count: metadata.elementCount,
            interactable_count: elements.all.filter { $0.isEnabled }.count,
            capture_mode: determineMode().rawValue,
            analysis_result: analysisResult,
            execution_time: executionTime,
            ui_elements: uiElements,
            menu_bar: nil // Menu bar extraction not yet implemented in service layer
        )
        
        outputSuccessCodable(data: output)
    }
    
    private func outputTextResults(
        sessionId: String,
        screenshotPath: String,
        annotatedPath: String?,
        metadata: DetectionMetadata,
        elements: DetectedElements,
        analysisResult: String?,
        executionTime: TimeInterval
    ) {
        let sessionPaths = SessionPaths(
            raw: screenshotPath,
            annotated: annotatedPath ?? screenshotPath,
            map: services.sessionManager.getSessionStoragePath() + "/\(sessionId)/map.json"
        )
        
        let interactableCount = elements.all.filter { $0.isEnabled }.count
        
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

private extension DetectionMetadata {
    var applicationName: String? {
        warnings.first { $0.hasPrefix("APP:") }?.replacingOccurrences(of: "APP:", with: "")
    }
    
    var windowTitle: String? {
        warnings.first { $0.hasPrefix("WINDOW:") }?.replacingOccurrences(of: "WINDOW:", with: "")
    }
    
    var windowBounds: CGRect? {
        if let boundsString = warnings.first(where: { $0.hasPrefix("BOUNDS:") })?.replacingOccurrences(of: "BOUNDS:", with: ""),
           let data = boundsString.data(using: .utf8),
           let rect = try? JSONDecoder().decode(CGRect.self, from: data) {
            return rect
        }
        return nil
    }
    
    init(detectionTime: TimeInterval, elementCount: Int, method: String, warnings: [String] = [], 
         applicationName: String? = nil, windowTitle: String? = nil, windowBounds: CGRect? = nil) {
        var allWarnings = warnings
        
        // Store metadata in warnings array (temporary until service layer is enhanced)
        if let app = applicationName {
            allWarnings.append("APP:\(app)")
        }
        if let window = windowTitle {
            allWarnings.append("WINDOW:\(window)")
        }
        if let bounds = windowBounds, let boundsData = try? JSONEncoder().encode(bounds), 
           let boundsString = String(data: boundsData, encoding: .utf8) {
            allWarnings.append("BOUNDS:\(boundsString)")
        }
        
        self.init(
            detectionTime: detectionTime,
            elementCount: elementCount,
            method: method,
            warnings: allWarnings
        )
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