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
                    """
                ),
                "path": SchemaBuilder.string(
                    description: "Optional. Path to save the screenshot. If not provided, uses a temporary file."
                ),
                "session": SchemaBuilder.string(
                    description: "Optional. Session ID for UI automation state tracking. Creates new session if not provided."
                ),
                "annotate": SchemaBuilder.boolean(
                    description: "Optional. If true, generates an annotated screenshot with interaction markers and IDs.",
                    default: false
                )
            ],
            required: []
        )
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
                session: session
            )
            
            // Detect UI elements
            let elements = try await detectUIElements(
                target: target,
                session: session
            )
            
            // Generate annotated screenshot if requested
            let annotatedPath: String?
            if annotate {
                annotatedPath = try await generateAnnotatedScreenshot(
                    originalPath: screenshotPath,
                    elements: elements,
                    session: session
                )
            } else {
                annotatedPath = nil
            }
            
            // Build response
            let summary = await buildSummary(
                session: session,
                elements: elements,
                screenshotPath: annotatedPath ?? screenshotPath,
                target: target
            )
            
            var content: [MCP.Tool.Content] = [.text(summary)]
            
            // Add annotated screenshot as base64 if requested
            if annotate, let annotatedPath = annotatedPath {
                let imageData = try Data(contentsOf: URL(fileURLWithPath: annotatedPath))
                content.append(.image(data: imageData.base64EncodedString(), mimeType: "image/png", metadata: nil))
            }
            
            return ToolResponse(
                content: content,
                meta: .object([
                    "session_id": .string(session.id),
                    "element_count": .double(Double(elements.count)),
                    "actionable_count": .double(Double(elements.filter { $0.isActionable }.count))
                ])
            )
            
        } catch {
            logger.error("See tool execution failed: \(error)")
            return ToolResponse.error("Failed to capture UI state: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func getOrCreateSession(sessionId: String?) async throws -> UISession {
        if let sessionId = sessionId {
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
        case .screen(let index):
            captureResult = try await PeekabooServices.shared.screenCapture.captureScreen(displayIndex: index)
        case .frontmost:
            captureResult = try await PeekabooServices.shared.screenCapture.captureFrontmost()
        case .window(let identifier, _):
            // Capture first window of the app
            let windows = try await PeekabooServices.shared.windows.listWindows(target: .application(identifier))
            guard !windows.isEmpty else {
                throw PeekabooError.windowNotFound(criteria: "No windows found for application: \(identifier)")
            }
            captureResult = try await PeekabooServices.shared.screenCapture.captureWindow(
                appIdentifier: identifier,
                windowIndex: 0
            )
        case .area(_):
            throw PeekabooError.invalidInput("Area capture not supported for see tool")
        }
        
        // Save the image
        try captureResult.imageData.write(to: URL(fileURLWithPath: screenshotPath))
        
        // Store in session
        await session.setScreenshot(path: screenshotPath, metadata: captureResult.metadata)
        
        return screenshotPath
    }
    
    private func detectUIElements(target: CaptureTarget, session: UISession) async throws -> [UIElement] {
        // Get the application info for element detection
        let appInfo: ServiceApplicationInfo?
        switch target {
        case .frontmost:
            appInfo = try await PeekabooServices.shared.applications.getFrontmostApplication()
        case .window(let appIdentifier, _):
            let apps = try await PeekabooServices.shared.applications.listApplications()
            appInfo = apps.data.applications.first { app in
                app.name == appIdentifier || 
                app.bundleIdentifier == appIdentifier ||
                (appIdentifier.hasPrefix("PID:") && "PID:\(app.processIdentifier)" == appIdentifier)
            }
        default:
            appInfo = nil
        }
        
        guard let appInfo = appInfo else {
            // No specific app, return empty elements
            return []
        }
        
        // Use automation service for element detection
        // For now, just return empty elements since we need proper integration
        // TODO: Call actual detectElements on UIAutomationService with captured image data
        
        // Convert to UI elements with empty data for now
        var elements: [UIElement] = []
        
        // Store in session
        await session.setUIElements(elements)
        
        return elements
    }
    
    // Removed getRolePrefix - no longer needed after refactoring to use main UIElement struct
    
    private func generateAnnotatedScreenshot(
        originalPath: String,
        elements: [UIElement],
        session: UISession
    ) async throws -> String {
        // For now, just return the original path
        // TODO: Implement actual annotation with element markers
        logger.info("Annotation not yet implemented, returning original screenshot")
        return originalPath
    }
    
    @MainActor
    private func buildSummary(
        session: UISession,
        elements: [UIElement],
        screenshotPath: String,
        target: CaptureTarget
    ) async -> String {
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
            let actionableCount = roleElements.filter { $0.isActionable }.count
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
        return uiElements.first { $0.id == id }
    }
}

actor UISessionManager {
    static let shared = UISessionManager()
    
    private var sessions: [String: UISession] = [:]
    
    private init() {}
    
    func createSession() -> UISession {
        let session = UISession()
        sessions[session.id] = session
        return session
    }
    
    func getSession(id: String) -> UISession? {
        return sessions[id]
    }
    
    func removeSession(id: String) {
        sessions.removeValue(forKey: id)
    }
    
    func cleanupOldSessions(olderThan timeInterval: TimeInterval = 3600) async {
        let cutoffDate = Date().addingTimeInterval(-timeInterval)
        var newSessions: [String: UISession] = [:]
        for (id, session) in sessions {
            if await session.lastAccessedAt > cutoffDate {
                newSessions[id] = session
            }
        }
        sessions = newSessions
    }
}