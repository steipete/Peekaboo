import Foundation
import CoreGraphics
import os.log

/// Default implementation of session management operations
/// Migrated from CLI SessionCache with thread-safe actor-based design
public final class SessionManager: SessionManagerProtocol {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "SessionManager")
    private let sessionActor = SessionStorageActor()
    
    // Session validity window (10 minutes)
    private let sessionValidityWindow: TimeInterval = 600
    
    public init() {}
    
    public func createSession() async throws -> String {
        // Generate timestamp-based session ID for cross-process compatibility
        let timestamp = Int(Date().timeIntervalSince1970 * 1000) // milliseconds
        let randomSuffix = Int.random(in: 1000...9999)
        let sessionId = "\(timestamp)-\(randomSuffix)"
        
        logger.debug("Creating new session: \(sessionId)")
        
        // Create session directory
        let sessionPath = getSessionPath(for: sessionId)
        try FileManager.default.createDirectory(at: sessionPath, withIntermediateDirectories: true)
        
        // Initialize empty session data
        let sessionData = UIAutomationSession()
        try await sessionActor.saveSession(sessionId: sessionId, data: sessionData, at: sessionPath)
        
        return sessionId
    }
    
    public func storeDetectionResult(sessionId: String, result: ElementDetectionResult) async throws {
        let sessionPath = getSessionPath(for: sessionId)
        
        // Load existing session or create new
        var sessionData = await sessionActor.loadSession(sessionId: sessionId, from: sessionPath) ?? UIAutomationSession()
        
        // Convert detection result to session format
        sessionData.screenshotPath = result.screenshotPath
        sessionData.annotatedPath = result.screenshotPath.replacingOccurrences(of: "raw.png", with: "annotated.png")
        sessionData.lastUpdateTime = Date()
        
        // Convert detected elements to UI map
        var uiMap: [String: UIElement] = [:]
        for element in result.elements.all {
            let uiElement = UIElement(
                id: element.id,
                elementId: "element_\(uiMap.count)",
                role: convertElementTypeToRole(element.type),
                title: element.label,
                label: element.label,
                value: element.value,
                frame: element.bounds,
                isActionable: isActionableType(element.type),
                keyboardShortcut: element.attributes["keyboardShortcut"]
            )
            uiMap[element.id] = uiElement
        }
        sessionData.uiMap = uiMap
        
        // Extract metadata from warnings
        for warning in result.metadata.warnings {
            if warning.hasPrefix("app:") {
                sessionData.applicationName = String(warning.dropFirst(4))
            } else if warning.hasPrefix("window:") {
                sessionData.windowTitle = String(warning.dropFirst(7))
            } else if warning.hasPrefix("APP:") {
                sessionData.applicationName = String(warning.dropFirst(4))
            } else if warning.hasPrefix("WINDOW:") {
                sessionData.windowTitle = String(warning.dropFirst(7))
            } else if warning.hasPrefix("BOUNDS:") {
                // Parse bounds if needed
                if let boundsData = String(warning.dropFirst(7)).data(using: .utf8),
                   let bounds = try? JSONDecoder().decode(CGRect.self, from: boundsData) {
                    sessionData.windowBounds = bounds
                }
            } else if warning.hasPrefix("WINDOW_ID:") {
                if let windowID = CGWindowID(String(warning.dropFirst(10))) {
                    sessionData.windowID = windowID
                }
            } else if warning.hasPrefix("AX_IDENTIFIER:") {
                sessionData.windowAXIdentifier = String(warning.dropFirst(14))
            }
        }
        
        // Save updated session
        try await sessionActor.saveSession(sessionId: sessionId, data: sessionData, at: sessionPath)
    }
    
    public func getDetectionResult(sessionId: String) async throws -> ElementDetectionResult? {
        let sessionPath = getSessionPath(for: sessionId)
        
        guard let sessionData = await sessionActor.loadSession(sessionId: sessionId, from: sessionPath) else {
            return nil
        }
        
        // Convert session data back to detection result
        var elements = DetectedElements()
        var allElements: [DetectedElement] = []
        
        for (_, uiElement) in sessionData.uiMap {
            let detectedElement = DetectedElement(
                id: uiElement.id,
                type: convertRoleToElementType(uiElement.role),
                label: uiElement.label ?? uiElement.title,
                value: uiElement.value,
                bounds: uiElement.frame,
                isEnabled: uiElement.isActionable,
                attributes: uiElement.keyboardShortcut != nil ? ["keyboardShortcut": uiElement.keyboardShortcut!] : [:]
            )
            allElements.append(detectedElement)
        }
        
        // Organize by type
        elements = organizeElementsByType(allElements)
        
        let metadata = DetectionMetadata(
            detectionTime: Date().timeIntervalSince(sessionData.lastUpdateTime),
            elementCount: sessionData.uiMap.count,
            method: "session-cache",
            warnings: buildWarnings(from: sessionData)
        )
        
        return ElementDetectionResult(
            sessionId: sessionId,
            screenshotPath: sessionData.annotatedPath ?? sessionData.screenshotPath ?? "",
            elements: elements,
            metadata: metadata
        )
    }
    
    public func getMostRecentSession() async -> String? {
        await findLatestValidSession()
    }
    
    public func listSessions() async throws -> [SessionInfo] {
        let sessionDir = getSessionStorageURL()
        
        guard let sessions = try? FileManager.default.contentsOfDirectory(
            at: sessionDir,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }
        
        var sessionInfos: [SessionInfo] = []
        
        for sessionURL in sessions {
            guard sessionURL.hasDirectoryPath else { continue }
            
            let sessionId = sessionURL.lastPathComponent
            
            // Get session metadata
            let resourceValues = try? sessionURL.resourceValues(forKeys: [.creationDateKey])
            let creationDate = resourceValues?.creationDate ?? Date()
            
            // Load session data to get details
            let sessionData = await sessionActor.loadSession(sessionId: sessionId, from: sessionURL)
            
            // Count screenshots
            let screenshotCount = countScreenshots(in: sessionURL)
            
            // Calculate size
            let sizeInBytes = calculateDirectorySize(sessionURL)
            
            // Check if process is still active
            let processId = extractProcessId(from: sessionId)
            let isActive = isProcessActive(processId)
            
            let info = SessionInfo(
                id: sessionId,
                processId: processId,
                createdAt: creationDate,
                lastAccessedAt: sessionData?.lastUpdateTime ?? creationDate,
                sizeInBytes: sizeInBytes,
                screenshotCount: screenshotCount,
                isActive: isActive
            )
            sessionInfos.append(info)
        }
        
        return sessionInfos.sorted { $0.createdAt > $1.createdAt }
    }
    
    public func cleanSession(sessionId: String) async throws {
        let sessionPath = getSessionPath(for: sessionId)
        
        // Only try to remove if the directory exists
        if FileManager.default.fileExists(atPath: sessionPath.path) {
            try FileManager.default.removeItem(at: sessionPath)
            logger.info("Cleaned session: \(sessionId)")
        } else {
            logger.debug("Session \(sessionId) does not exist, skipping cleanup")
        }
    }
    
    public func cleanSessionsOlderThan(days: Int) async throws -> Int {
        let cutoffDate = Date().addingTimeInterval(-Double(days) * 24 * 3600)
        let sessions = try await listSessions()
        
        var cleanedCount = 0
        for session in sessions where session.createdAt < cutoffDate {
            try await cleanSession(sessionId: session.id)
            cleanedCount += 1
        }
        
        return cleanedCount
    }
    
    public func cleanAllSessions() async throws -> Int {
        let sessions = try await listSessions()
        
        for session in sessions {
            try await cleanSession(sessionId: session.id)
        }
        
        return sessions.count
    }
    
    public func getSessionStoragePath() -> String {
        getSessionStorageURL().path
    }
    
    // MARK: - Additional Public Methods
    
    /// Store raw screenshot and build UI map
    public func storeScreenshot(
        sessionId: String,
        screenshotPath: String,
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?
    ) async throws {
        let sessionPath = getSessionPath(for: sessionId)
        
        // Load or create session data
        var sessionData = await sessionActor.loadSession(sessionId: sessionId, from: sessionPath) ?? UIAutomationSession()
        
        // Copy screenshot to session directory
        let rawPath = sessionPath.appendingPathComponent("raw.png")
        try? FileManager.default.removeItem(at: rawPath)
        try FileManager.default.copyItem(atPath: screenshotPath, toPath: rawPath.path)
        
        sessionData.screenshotPath = rawPath.path
        sessionData.applicationName = applicationName
        sessionData.windowTitle = windowTitle
        sessionData.windowBounds = windowBounds
        sessionData.lastUpdateTime = Date()
        
        try await sessionActor.saveSession(sessionId: sessionId, data: sessionData, at: sessionPath)
    }
    
    /// Get element by ID from session
    public func getElement(sessionId: String, elementId: String) async throws -> UIElement? {
        let sessionPath = getSessionPath(for: sessionId)
        guard let sessionData = await sessionActor.loadSession(sessionId: sessionId, from: sessionPath) else {
            throw SessionError.sessionNotFound
        }
        return sessionData.uiMap[elementId]
    }
    
    /// Find elements matching a query
    public func findElements(sessionId: String, matching query: String) async throws -> [UIElement] {
        let sessionPath = getSessionPath(for: sessionId)
        guard let sessionData = await sessionActor.loadSession(sessionId: sessionId, from: sessionPath) else {
            throw SessionError.sessionNotFound
        }
        
        let lowercaseQuery = query.lowercased()
        return sessionData.uiMap.values.filter { element in
            let searchableText = [
                element.title,
                element.label,
                element.value,
                element.role
            ].compactMap { $0 }.joined(separator: " ").lowercased()
            
            return searchableText.contains(lowercaseQuery)
        }.sorted { lhs, rhs in
            // Sort by position: top to bottom, left to right
            if abs(lhs.frame.origin.y - rhs.frame.origin.y) < 10 {
                return lhs.frame.origin.x < rhs.frame.origin.x
            }
            return lhs.frame.origin.y < rhs.frame.origin.y
        }
    }
    
    public func getUIAutomationSession(sessionId: String) async throws -> UIAutomationSession? {
        let sessionPath = getSessionPath(for: sessionId)
        return await sessionActor.loadSession(sessionId: sessionId, from: sessionPath)
    }
    
    // MARK: - Private Helpers
    
    private func getSessionStorageURL() -> URL {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".peekaboo/session")
        
        // Ensure the directory exists
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        
        return url
    }
    
    private func getSessionPath(for sessionId: String) -> URL {
        getSessionStorageURL().appendingPathComponent(sessionId)
    }
    
    private func findLatestValidSession() async -> String? {
        let sessionDir = getSessionStorageURL()
        
        guard let sessions = try? FileManager.default.contentsOfDirectory(
            at: sessionDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return nil
        }
        
        let tenMinutesAgo = Date().addingTimeInterval(-sessionValidityWindow)
        
        let validSessions = sessions.compactMap { url -> (url: URL, date: Date)? in
            guard let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey]),
                  let creationDate = resourceValues.creationDate,
                  creationDate > tenMinutesAgo else {
                return nil
            }
            return (url, creationDate)
        }.sorted { $0.date > $1.date }
        
        if let latest = validSessions.first {
            logger.debug("Found valid session: \(latest.url.lastPathComponent) created \(Int(-latest.date.timeIntervalSinceNow)) seconds ago")
            return latest.url.lastPathComponent
        } else {
            logger.debug("No valid sessions found within \(Int(self.sessionValidityWindow)) second window")
            return nil
        }
    }
    
    private func convertElementTypeToRole(_ type: ElementType) -> String {
        switch type {
        case .button: return "AXButton"
        case .textField: return "AXTextField"
        case .link: return "AXLink"
        case .image: return "AXImage"
        case .group: return "AXGroup"
        case .slider: return "AXSlider"
        case .checkbox: return "AXCheckBox"
        case .menu: return "AXMenu"
        case .other: return "AXUnknown"
        }
    }
    
    private func convertRoleToElementType(_ role: String) -> ElementType {
        switch role {
        case "AXButton": return .button
        case "AXTextField", "AXTextArea": return .textField
        case "AXLink": return .link
        case "AXImage": return .image
        case "AXGroup": return .group
        case "AXSlider": return .slider
        case "AXCheckBox": return .checkbox
        case "AXMenu", "AXMenuItem": return .menu
        default: return .other
        }
    }
    
    private func isActionableType(_ type: ElementType) -> Bool {
        switch type {
        case .button, .textField, .link, .checkbox, .slider, .menu:
            return true
        case .image, .group, .other:
            return false
        }
    }
    
    private func organizeElementsByType(_ elements: [DetectedElement]) -> DetectedElements {
        var buttons: [DetectedElement] = []
        var textFields: [DetectedElement] = []
        var links: [DetectedElement] = []
        var images: [DetectedElement] = []
        var groups: [DetectedElement] = []
        var sliders: [DetectedElement] = []
        var checkboxes: [DetectedElement] = []
        var menus: [DetectedElement] = []
        var other: [DetectedElement] = []
        
        for element in elements {
            switch element.type {
            case .button: buttons.append(element)
            case .textField: textFields.append(element)
            case .link: links.append(element)
            case .image: images.append(element)
            case .group: groups.append(element)
            case .slider: sliders.append(element)
            case .checkbox: checkboxes.append(element)
            case .menu: menus.append(element)
            case .other: other.append(element)
            }
        }
        
        return DetectedElements(
            buttons: buttons,
            textFields: textFields,
            links: links,
            images: images,
            groups: groups,
            sliders: sliders,
            checkboxes: checkboxes,
            menus: menus,
            other: other
        )
    }
    
    private func buildWarnings(from sessionData: UIAutomationSession) -> [String] {
        var warnings: [String] = []
        if let appName = sessionData.applicationName {
            warnings.append("APP:\(appName)")
        }
        if let windowTitle = sessionData.windowTitle {
            warnings.append("WINDOW:\(windowTitle)")
        }
        if let windowBounds = sessionData.windowBounds,
           let boundsData = try? JSONEncoder().encode(windowBounds),
           let boundsString = String(data: boundsData, encoding: .utf8) {
            warnings.append("BOUNDS:\(boundsString)")
        }
        if let windowID = sessionData.windowID {
            warnings.append("WINDOW_ID:\(windowID)")
        }
        if let axIdentifier = sessionData.windowAXIdentifier {
            warnings.append("AX_IDENTIFIER:\(axIdentifier)")
        }
        return warnings
    }
    
    private func countScreenshots(in sessionURL: URL) -> Int {
        let files = try? FileManager.default.contentsOfDirectory(at: sessionURL, includingPropertiesForKeys: nil)
        return files?.filter { $0.pathExtension == "png" }.count ?? 0
    }
    
    private func calculateDirectorySize(_ url: URL) -> Int64 {
        var totalSize: Int64 = 0
        
        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return totalSize
    }
    
    private func extractProcessId(from sessionId: String) -> Int32 {
        // Try to extract PID from old-style session IDs (just numbers)
        if let pid = Int32(sessionId) {
            return pid
        }
        // For new timestamp-based IDs, return 0
        return 0
    }
    
    private func isProcessActive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0
    }
}

// MARK: - Thread-Safe Storage Actor

/// Actor for thread-safe session storage operations
private actor SessionStorageActor {
    private let encoder = JSONCoding.encoder
    private let decoder = JSONCoding.decoder
    
    init() {
        // JSONCoding.encoder already has pretty printing and sorted keys configured
    }
    
    func saveSession(sessionId: String, data: UIAutomationSession, at sessionPath: URL) throws {
        // Ensure the session directory exists
        try FileManager.default.createDirectory(at: sessionPath, withIntermediateDirectories: true)
        
        let sessionFile = sessionPath.appendingPathComponent("map.json")
        let jsonData = try encoder.encode(data)
        
        // Use built-in atomic write option
        try jsonData.write(to: sessionFile, options: .atomic)
    }
    
    func loadSession(sessionId: String, from sessionPath: URL) -> UIAutomationSession? {
        let sessionFile = sessionPath.appendingPathComponent("map.json")
        
        guard FileManager.default.fileExists(atPath: sessionFile.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: sessionFile)
            let sessionData = try decoder.decode(UIAutomationSession.self, from: data)
            
            // Check version compatibility
            if sessionData.version != UIAutomationSession.currentVersion {
                // Remove incompatible session
                try? FileManager.default.removeItem(at: sessionFile)
                return nil
            }
            
            return sessionData
        } catch {
            // Log the error but don't throw - we'll clean up and return nil
            _ = error.asPeekabooError(context: "Failed to load session \(sessionId)")
            // Remove corrupted session
            try? FileManager.default.removeItem(at: sessionFile)
            return nil
        }
    }
}
