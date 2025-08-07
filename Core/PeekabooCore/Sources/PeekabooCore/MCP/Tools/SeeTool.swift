import AppKit
import Foundation
import MCP
import os.log

/// MCP tool for capturing UI state and element detection
public struct SeeTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "SeeTool")

    public let name = "see"

    public var description: String {
        """
        Captures a screenshot and analyzes UI elements for automation.
        Returns UI element map with Peekaboo IDs (B1 for buttons, T1 for text fields, etc.)
        that can be used with interaction commands.
        Creates or updates a session for tracking UI state across multiple commands.
        Peekaboo MCP 3.0.0-beta.2 using anthropic/claude-opus-4-20250514, ollama/llava:latest
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "app_target": SchemaBuilder.string(
                    description: """
                    Optional. Specifies the capture target (same as image tool).
                    For example:
                    Omit or use an empty string (e.g., '') for all screens.
                    Use 'screen:INDEX' (e.g., 'screen:0') for a specific display.
                    Use 'frontmost' for all windows of the current foreground application.
                    Use 'AppName' (e.g., 'Safari') for all windows of that application.
                    Use 'PID:PROCESS_ID' (e.g., 'PID:663') to target a specific process by its PID.
                    """),
                "path": SchemaBuilder.string(
                    description: "Optional. Path to save the screenshot. If not provided, uses a temporary file."),
                "session": SchemaBuilder.string(
                    description: "Optional. Session ID for UI automation state tracking. Creates new session if not provided."),
                "annotate": SchemaBuilder.boolean(
                    description: "Optional. If true, generates an annotated screenshot with interaction markers and IDs.",
                    default: false),
            ],
            required: [])
    }

    public init() {}

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        // Parse input
        let appTarget = arguments.getString("app_target")
        let path = arguments.getString("path")
        let sessionId = arguments.getString("session")
        let annotate = arguments.getBool("annotate") ?? false

        do {
            // Create or get session
            let session = try await getOrCreateSession(sessionId: sessionId)

            // Parse capture target
            let target = try parseCaptureTarget(appTarget)

            // Capture screenshot
            let screenshotPath = try await captureScreenshot(
                target: target,
                path: path,
                session: session)

            // Detect UI elements
            let elements = try await detectUIElements(
                target: target,
                session: session)

            // Generate annotated screenshot if requested
            let annotatedPath: String? = if annotate {
                try await self.generateAnnotatedScreenshot(
                    originalPath: screenshotPath,
                    elements: elements,
                    session: session)
            } else {
                nil
            }

            // Build response
            let summary = await buildSummary(
                session: session,
                elements: elements,
                screenshotPath: annotatedPath ?? screenshotPath,
                target: target)

            var content: [MCP.Tool.Content] = [.text(summary)]

            // Add annotated screenshot as base64 if requested
            if annotate, let annotatedPath {
                let imageData = try Data(contentsOf: URL(fileURLWithPath: annotatedPath))
                content.append(.image(data: imageData.base64EncodedString(), mimeType: "image/png", metadata: nil))
            }

            return ToolResponse(
                content: content,
                meta: .object([
                    "session_id": .string(session.id),
                    "element_count": .double(Double(elements.count)),
                    "actionable_count": .double(Double(elements.count(where: { $0.isActionable }))),
                ]))

        } catch {
            self.logger.error("See tool execution failed: \(error)")
            return ToolResponse.error("Failed to capture UI state: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func getOrCreateSession(sessionId: String?) async throws -> UISession {
        if let sessionId {
            // Try to get existing session
            if let existingSession = await UISessionManager.shared.getSession(id: sessionId) {
                return existingSession
            }
        }

        // Create new session
        return await UISessionManager.shared.createSession()
    }

    private func parseCaptureTarget(_ appTarget: String?) throws -> CaptureTarget {
        guard let target = appTarget else {
            return .screen(index: nil)
        }

        // Parse screen:N format
        if target.hasPrefix("screen:") {
            let indexStr = String(target.dropFirst(7))
            if let index = Int(indexStr) {
                return .screen(index: index)
            }
            throw PeekabooError.invalidInput("Invalid screen index: \(indexStr)")
        }

        // Special values
        switch target.lowercased() {
        case "", "screen":
            return .screen(index: nil)
        case "frontmost":
            return .frontmost
        default:
            // Parse PID:N format
            if target.hasPrefix("PID:") {
                let pidStr = String(target.dropFirst(4))
                if let pid = Int32(pidStr) {
                    return .window(app: "PID:\(pid)", index: nil)
                }
                throw PeekabooError.invalidInput("Invalid PID: \(pidStr)")
            }

            // Otherwise treat as app name
            return .window(app: target, index: nil)
        }
    }

    private func captureScreenshot(target: CaptureTarget, path: String?, session: UISession) async throws -> String {
        let screenshotPath = path ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("peekaboo-see-\(Date().timeIntervalSince1970).png")
            .path

        // Use screen capture service
        let captureResult: CaptureResult
        switch target {
        case let .screen(index):
            captureResult = try await PeekabooServices.shared.screenCapture.captureScreen(displayIndex: index)
        case .frontmost:
            captureResult = try await PeekabooServices.shared.screenCapture.captureFrontmost()
        case let .window(identifier, _):
            // Capture first window of the app
            let windows = try await PeekabooServices.shared.windows.listWindows(target: .application(identifier))
            guard !windows.isEmpty else {
                throw PeekabooError.windowNotFound(criteria: "No windows found for application: \(identifier)")
            }
            captureResult = try await PeekabooServices.shared.screenCapture.captureWindow(
                appIdentifier: identifier,
                windowIndex: 0)
        case .area:
            throw PeekabooError.invalidInput("Area capture not supported for see tool")
        }

        // Save the image
        try captureResult.imageData.write(to: URL(fileURLWithPath: screenshotPath))

        // Store in session
        await session.setScreenshot(path: screenshotPath, metadata: captureResult.metadata)

        return screenshotPath
    }

    private func detectUIElements(target: CaptureTarget, session: UISession) async throws -> [UIElement] {
        // Get the screenshot path from session
        guard let screenshotPath = await session.screenshotPath else {
            self.logger.warning("No screenshot available for element detection")
            return []
        }

        // Read the screenshot data
        let imageData = try Data(contentsOf: URL(fileURLWithPath: screenshotPath))

        // Get window context based on target
        let windowContext: WindowContext?
        switch target {
        case .frontmost:
            let appInfo = try await PeekabooServices.shared.applications.getFrontmostApplication()
            windowContext = WindowContext(
                applicationName: appInfo.name,
                windowTitle: nil,
                windowBounds: nil)
        case let .window(appIdentifier, _):
            // Get window information
            let windows = try await PeekabooServices.shared.windows.listWindows(target: .application(appIdentifier))
            if let firstWindow = windows.first {
                windowContext = WindowContext(
                    applicationName: appIdentifier,
                    windowTitle: firstWindow.title,
                    windowBounds: firstWindow.bounds)
            } else {
                windowContext = WindowContext(
                    applicationName: appIdentifier,
                    windowTitle: nil,
                    windowBounds: nil)
            }
        default:
            windowContext = nil
        }

        // Use automation service for element detection
        let detectionResult = try await PeekabooServices.shared.automation.detectElements(
            in: imageData,
            sessionId: session.id,
            windowContext: windowContext)

        // Get all detected elements
        let detectedElements = detectionResult.elements.all

        // Convert DetectedElement to UIElement
        let elements: [UIElement] = detectedElements.map { detected in
            UIElement(
                id: detected.id,
                elementId: detected.id, // Using same ID for compatibility
                role: detected.type.rawValue,
                title: detected.label,
                label: detected.label,
                value: detected.value,
                description: nil,
                help: nil,
                roleDescription: nil,
                identifier: nil,
                frame: detected.bounds,
                isActionable: detected.isEnabled,
                parentId: nil,
                children: [],
                keyboardShortcut: nil)
        }

        self.logger.info("Detected \(elements.count) UI elements")

        // Store in session
        await session.setUIElements(elements)

        return elements
    }

    // Removed getRolePrefix - no longer needed after refactoring to use main UIElement struct

    private func generateAnnotatedScreenshot(
        originalPath: String,
        elements: [UIElement],
        session: UISession) async throws -> String
    {
        // Load the original image
        guard let originalImage = NSImage(contentsOfFile: originalPath) else {
            self.logger.warning("Failed to load image for annotation, returning original")
            return originalPath
        }
        
        // Create a new image with annotations
        let annotatedImage = NSImage(size: originalImage.size)
        annotatedImage.lockFocus()
        
        // Draw the original image
        originalImage.draw(at: .zero, from: NSRect(origin: .zero, size: originalImage.size),
                          operation: .copy, fraction: 1.0)
        
        // Set up drawing attributes
        let strokeColor = NSColor.systemRed
        let fillColor = NSColor.systemRed.withAlphaComponent(0.2)
        let textColor = NSColor.white
        let textBackgroundColor = NSColor.systemRed
        
        // Draw markers for each element
        for element in elements {
            // Skip elements without bounds
            guard element.bounds.width > 0 && element.bounds.height > 0 else { continue }
            
            // Convert coordinates (flip Y axis for screen coordinates)
            let screenHeight = NSScreen.main?.frame.height ?? originalImage.size.height
            let flippedY = screenHeight - element.bounds.minY - element.bounds.height
            let elementRect = NSRect(x: element.bounds.minX, y: flippedY,
                                    width: element.bounds.width, height: element.bounds.height)
            
            // Draw semi-transparent fill
            fillColor.setFill()
            NSBezierPath(rect: elementRect).fill()
            
            // Draw border
            strokeColor.setStroke()
            let borderPath = NSBezierPath(rect: elementRect)
            borderPath.lineWidth = 2.0
            borderPath.stroke()
            
            // Draw element ID label
            let labelText = element.id
            let font = NSFont.boldSystemFont(ofSize: 12)
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
                .backgroundColor: textBackgroundColor
            ]
            
            let textSize = labelText.size(withAttributes: textAttributes)
            let labelRect = NSRect(x: elementRect.minX, y: elementRect.minY - textSize.height - 2,
                                  width: textSize.width + 8, height: textSize.height + 4)
            
            // Draw label background
            textBackgroundColor.setFill()
            NSBezierPath(rect: labelRect).fill()
            
            // Draw label text
            let textPoint = NSPoint(x: labelRect.minX + 4, y: labelRect.minY + 2)
            labelText.draw(at: textPoint, withAttributes: textAttributes)
        }
        
        annotatedImage.unlockFocus()
        
        // Save the annotated image
        let annotatedPath = originalPath.replacingOccurrences(of: ".png", with: "_annotated.png")
        
        if let tiffData = annotatedImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: URL(fileURLWithPath: annotatedPath))
                self.logger.info("Generated annotated screenshot at: \(annotatedPath)")
                return annotatedPath
            } catch {
                self.logger.error("Failed to save annotated screenshot: \(error)")
                return originalPath
            }
        }
        
        self.logger.warning("Failed to generate PNG data for annotation, returning original")
        return originalPath
    }

    @MainActor
    private func buildSummary(
        session: UISession,
        elements: [UIElement],
        screenshotPath: String,
        target: CaptureTarget) async -> String
    {
        var lines: [String] = []

        lines.append("📸 UI State Captured")
        lines.append("Session ID: \(session.id)")

        // Add app/window info if available
        if let metadata = await session.screenshotMetadata {
            if let appInfo = metadata.applicationInfo {
                lines.append("Application: \(appInfo.name)")
            }
            if let windowInfo = metadata.windowInfo {
                lines.append("Window: \(windowInfo.title)")
            }
        }

        lines.append("Screenshot: \(screenshotPath)")
        lines.append("Elements found: \(elements.count)")

        // Group elements by role
        let elementsByRole = Dictionary(grouping: elements, by: { $0.role })

        lines.append("\nUI Elements:")

        for (role, roleElements) in elementsByRole.sorted(by: { $0.key < $1.key }) {
            let actionableCount = roleElements.count(where: { $0.isActionable })
            lines.append("\n\(role) (\(roleElements.count) found, \(actionableCount) actionable):")

            for element in roleElements {
                var parts = ["  \(element.id)"]

                if let title = element.title {
                    parts.append("\"\(title)\"")
                } else if let label = element.label {
                    parts.append("\"\(label)\"")
                } else if let value = element.value {
                    parts.append("value: \"\(value)\"")
                }

                parts.append("at (\(Int(element.frame.origin.x)), \(Int(element.frame.origin.y)))")

                if !element.isActionable {
                    parts.append("[not actionable]")
                }

                lines.append(parts.joined(separator: " - "))
            }
        }

        lines.append("\nUse element IDs (B1, T1, etc.) with click, type, and other interaction commands.")

        return lines.joined(separator: "\n")
    }
}

// MARK: - Supporting Types

// Using CaptureTarget from PeekabooServices - no need to redefine
// Note: menubar case is not available in the main CaptureTarget enum

// Using the main UIElement from Session.swift - no need to redefine

// MARK: - UI Session Management

actor UISession {
    let id: String
    private(set) var screenshotPath: String?
    private(set) var screenshotMetadata: CaptureMetadata?
    private(set) var uiElements: [UIElement] = []
    private(set) var createdAt: Date
    private(set) var lastAccessedAt: Date

    init() {
        self.id = UUID().uuidString
        self.createdAt = Date()
        self.lastAccessedAt = Date()
    }

    func setScreenshot(path: String, metadata: CaptureMetadata) {
        self.screenshotPath = path
        self.screenshotMetadata = metadata
        self.lastAccessedAt = Date()
    }

    func setUIElements(_ elements: [UIElement]) {
        self.uiElements = elements
        self.lastAccessedAt = Date()
    }

    func getElement(byId id: String) -> UIElement? {
        self.uiElements.first { $0.id == id }
    }
}

actor UISessionManager {
    static let shared = UISessionManager()

    private var sessions: [String: UISession] = [:]

    private init() {}

    func createSession() -> UISession {
        let session = UISession()
        self.sessions[session.id] = session
        return session
    }

    func getSession(id: String) -> UISession? {
        self.sessions[id]
    }

    func removeSession(id: String) {
        self.sessions.removeValue(forKey: id)
    }

    func cleanupOldSessions(olderThan timeInterval: TimeInterval = 3600) async {
        let cutoffDate = Date().addingTimeInterval(-timeInterval)
        var newSessions: [String: UISession] = [:]
        for (id, session) in self.sessions {
            if await session.lastAccessedAt > cutoffDate {
                newSessions[id] = session
            }
        }
        self.sessions = newSessions
    }
}
