import AppKit
import AXorcist
import CoreGraphics
import Foundation

/// Process-isolated session cache for UI automation state.
/// Each session is stored in ~/.peekaboo/session/<PID>/ with atomic file operations.
@available(macOS 14.0, *)
actor SessionCache {
    let sessionId: String
    private let cacheDir: URL
    private let sessionFile: URL

    struct SessionData: Codable {
        static let currentVersion = 4 // Increment when format changes

        let version: Int
        var screenshotPath: String? // Path to raw.png
        var annotatedPath: String? // Path to annotated.png
        var uiMap: [String: UIElement]
        var lastUpdateTime: Date
        var applicationName: String?
        var windowTitle: String?
        var windowBounds: CGRect?

        struct UIElement: Codable {
            let id: String // Peekaboo ID (B1, T1, etc.)
            let elementId: String // Internal unique ID
            let role: String
            let title: String?
            let label: String?
            let value: String?
            let description: String?
            let help: String?
            let roleDescription: String?
            let identifier: String?
            var frame: CGRect
            let isActionable: Bool
            let parentId: String?
            let children: [String]
            let keyboardShortcut: String? // e.g., "cmd+b" for bold

            init(
                id: String,
                elementId: String,
                role: String,
                title: String?,
                label: String?,
                value: String?,
                description: String? = nil,
                help: String? = nil,
                roleDescription: String? = nil,
                identifier: String? = nil,
                frame: CGRect,
                isActionable: Bool,
                parentId: String? = nil,
                keyboardShortcut: String? = nil
            ) {
                self.id = id
                self.elementId = elementId
                self.role = role
                self.title = title
                self.label = label
                self.value = value
                self.description = description
                self.help = help
                self.roleDescription = roleDescription
                self.identifier = identifier
                self.frame = frame
                self.isActionable = isActionable
                self.parentId = parentId
                self.keyboardShortcut = keyboardShortcut
                children = []
            }
        }
    }

    init(sessionId: String? = nil, createIfNeeded: Bool = true) throws {
        // If explicit session ID provided, use it
        if let sessionId {
            self.sessionId = sessionId
        } else if let latestSession = Self.findLatestSession() {
            // Found a valid recent session
            self.sessionId = latestSession
            Logger.shared.debug("Using latest session: \(latestSession)")
        } else if createIfNeeded {
            // Only create new session if explicitly allowed (for see command)
            self.sessionId = String(ProcessInfo.processInfo.processIdentifier)
            Logger.shared.debug("Creating new session with PID: \(self.sessionId)")
        } else {
            // No valid session found and not allowed to create
            throw PeekabooError.noValidSessionFound
        }

        // Create cache directory in ~/.peekaboo/session/<sessionId>/
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        cacheDir = homeDir.appendingPathComponent(".peekaboo/session/\(self.sessionId)")
        try? FileManager.default.createDirectory(
            at: cacheDir,
            withIntermediateDirectories: true
        )

        sessionFile = cacheDir.appendingPathComponent("map.json")
    }

    /// Find the most recent session directory within the time window
    private static func findLatestSession() -> String? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let sessionDir = homeDir.appendingPathComponent(".peekaboo/session")

        guard let sessions = try? FileManager.default.contentsOfDirectory(
            at: sessionDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return nil
        }

        // Only consider sessions created within the last 10 minutes
        let tenMinutesAgo = Date().addingTimeInterval(-600)

        // Filter and sort sessions by creation date (most recent first)
        let validSessions = sessions.compactMap { url -> (url: URL, date: Date)? in
            guard let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey]),
                  let creationDate = resourceValues.creationDate else {
                return nil
            }
            // Only include sessions created within the time window
            guard creationDate > tenMinutesAgo else {
                return nil
            }
            return (url, creationDate)
        }.sorted { $0.date > $1.date }

        // Return the name of the most recent valid session
        if let latest = validSessions.first {
            Logger.shared
                .debug(
                    "Found valid session: \(latest.url.lastPathComponent) created \(Int(-latest.date.timeIntervalSinceNow)) seconds ago"
                )
            return latest.url.lastPathComponent
        } else {
            Logger.shared.debug("No valid sessions found within 10 minute window")
            return nil
        }
    }

    /// Load session data from disk
    func load() -> SessionData? {
        guard FileManager.default.fileExists(atPath: sessionFile.path) else { return nil }

        do {
            let data = try Data(contentsOf: sessionFile)
            let sessionData = try JSONDecoder().decode(SessionData.self, from: data)

            // Check version compatibility
            if sessionData.version != SessionData.currentVersion {
                Logger.shared
                    .info(
                        "Session version mismatch (found: \(sessionData.version), expected: \(SessionData.currentVersion)). Discarding old session."
                    )
                // Remove old incompatible session
                try? FileManager.default.removeItem(at: sessionFile)
                return nil
            }

            return sessionData
        } catch {
            Logger.shared.error("Failed to load session data: \(error)")
            // Remove corrupted session file
            try? FileManager.default.removeItem(at: sessionFile)
            return nil
        }
    }

    /// Save session data atomically
    func save(_ data: SessionData) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(data)

        // Write atomically to prevent corruption
        let tempFile = sessionFile.appendingPathExtension("tmp")
        try jsonData.write(to: tempFile)

        // Atomic move
        _ = try FileManager.default.replaceItem(
            at: sessionFile,
            withItemAt: tempFile,
            backupItemName: nil,
            options: [],
            resultingItemURL: nil
        )
    }

    /// Update screenshot and UI map
    func updateScreenshot(
        path: String,
        application: String?,
        window: String?,
        windowBounds: CGRect? = nil
    ) async throws {
        var data = load() ?? SessionData(
            version: SessionData.currentVersion,
            uiMap: [:],
            lastUpdateTime: Date()
        )

        // Copy screenshot to session directory as raw.png
        let rawPath = cacheDir.appendingPathComponent("raw.png")
        try FileManager.default.copyItem(atPath: path, toPath: rawPath.path)
        data.screenshotPath = rawPath.path

        data.applicationName = application
        data.windowTitle = window
        data.windowBounds = windowBounds
        data.lastUpdateTime = Date()

        // Build UI map using AXorcist
        if let app = application {
            data.uiMap = try await buildUIMap(for: app, window: window)
        }

        try save(data)
    }

    /// Get paths for session files
    func getSessionPaths() -> (raw: String, annotated: String, map: String) {
        let rawPath = cacheDir.appendingPathComponent("raw.png").path
        let annotatedPath = cacheDir.appendingPathComponent("annotated.png").path
        let mapPath = sessionFile.path
        return (raw: rawPath, annotated: annotatedPath, map: mapPath)
    }

    /// Build UI element map for the specified application
    @MainActor
    private func buildUIMap(for appName: String, window: String?) async throws -> [String: SessionData.UIElement] {
        var uiMap: [String: SessionData.UIElement] = [:]
        // roleCounters is now created per window, not needed here

        // Find the application using AXorcist
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName == appName || $0.bundleIdentifier == appName
        }) else {
            // If app not found, return empty map
            return uiMap
        }

        // Create AXUIElement for the application
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let appElement = Element(axApp)

        // Get windows to process
        let windows: [Element]

        if let windowTitle = window {
            // Find specific window by title
            windows = appElement.windows()?.filter { element in
                element.title() == windowTitle
            } ?? []

            if windows.isEmpty {
                Logger.shared.debug("No window found with title: \(windowTitle)")
                return uiMap
            }
        } else {
            // When no specific window is requested, only process the frontmost window
            // This ensures the UI map matches what was captured in the screenshot
            if let frontWindow = appElement.windows()?.first {
                windows = [frontWindow]
            } else {
                return uiMap
            }
        }

        // Process each window with its own role counters
        for (index, window) in windows.enumerated() {
            // Get window title or use index
            let windowTitle = window.title() ?? "Window\(index)"
            var windowRoleCounters: [String: Int] = [:]

            // Process window with window-specific context
            await processElement(
                window,
                parentId: nil,
                uiMap: &uiMap,
                roleCounters: &windowRoleCounters,
                windowContext: windowTitle
            )
        }

        return uiMap
    }

    /// Recursively process an element and its children
    @MainActor
    private func processElement(
        _ element: Element,
        parentId: String?,
        uiMap: inout [String: SessionData.UIElement],
        roleCounters: inout [String: Int],
        windowContext: String? = nil
    ) async {
        // Get element properties using AXorcist's full API
        let role = element.role() ?? "AXGroup"
        let title = element.title()
        let description = element.descriptionText()
        let help = element.help()
        let roleDescription = element.roleDescription()
        let identifier = element.identifier()
        let value = element.value() as? String

        // Use the most descriptive property as the label
        let label = description ?? help ?? roleDescription ?? title

        // Get element bounds
        let position = element.position()
        let size = element.size()
        let frame: CGRect = if let pos = position, let sz = size {
            CGRect(x: pos.x, y: pos.y, width: sz.width, height: sz.height)
        } else {
            .zero
        }

        // Generate Peekaboo ID with window context
        let prefix = ElementIDGenerator.prefix(for: role)
        let counter = (roleCounters[prefix] ?? 0) + 1
        roleCounters[prefix] = counter

        // Create a sanitized window identifier
        let windowId = windowContext.map { context in
            // Remove special characters and spaces, limit length
            let sanitized = context
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: "/", with: "_")
                .prefix(15)
            return String(sanitized)
        } ?? "NoWindow"

        // Generate unique ID: WindowId_Role#
        let peekabooId = "\(windowId)_\(prefix)\(counter)"

        // Create unique element ID
        let elementId = "element_\(uiMap.count)"

        // Detect keyboard shortcut
        let keyboardShortcut = detectKeyboardShortcut(
            role: role,
            title: title,
            label: label,
            description: description,
            identifier: identifier
        )

        // Create UI element with all available properties
        let uiElement = SessionData.UIElement(
            id: peekabooId,
            elementId: elementId,
            role: role,
            title: title,
            label: label,
            value: value,
            description: description,
            help: help,
            roleDescription: roleDescription,
            identifier: identifier,
            frame: frame,
            isActionable: ElementIDGenerator.isActionableRole(role),
            parentId: parentId,
            keyboardShortcut: keyboardShortcut
        )

        // Store in map
        uiMap[peekabooId] = uiElement

        // Process children recursively with window context
        // If this is a window element, use its title as the context for children
        let childWindowContext = if role == "AXWindow" {
            title ?? windowContext ?? "Window"
        } else {
            windowContext
        }

        if let children = element.children() {
            for child in children {
                await processElement(
                    child,
                    parentId: peekabooId,
                    uiMap: &uiMap,
                    roleCounters: &roleCounters,
                    windowContext: childWindowContext
                )
            }
        }
    }

    /// Find UI elements matching a query
    func findElements(matching query: String) -> [SessionData.UIElement] {
        guard let data = load() else { return [] }

        let lowercaseQuery = query.lowercased()
        return data.uiMap.values.filter { element in
            // Search in title, label, value, and role
            let searchableText = [
                element.title,
                element.label,
                element.value,
                element.role
            ].compactMap(\.self).joined(separator: " ").lowercased()

            return searchableText.contains(lowercaseQuery)
        }.sorted { lhs, rhs in
            // Sort by position: top to bottom, left to right
            if abs(lhs.frame.origin.y - rhs.frame.origin.y) < 10 {
                return lhs.frame.origin.x < rhs.frame.origin.x
            }
            return lhs.frame.origin.y < rhs.frame.origin.y
        }
    }

    /// Get element by ID
    func getElement(id: String) -> SessionData.UIElement? {
        load()?.uiMap[id]
    }

    /// Clear session cache
    func clear() throws {
        try? FileManager.default.removeItem(at: sessionFile)
    }

    /// Detect keyboard shortcut for common UI elements
    @MainActor
    private func detectKeyboardShortcut(
        role: String,
        title: String?,
        label: String?,
        description: String?,
        identifier: String?
    ) -> String? {
        // Check for common formatting buttons in TextEdit and other apps
        let allText = [title, label, description, identifier]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        // Common text formatting shortcuts
        if allText.contains("bold") {
            return "cmd+b"
        } else if allText.contains("italic") {
            return "cmd+i"
        } else if allText.contains("underline") {
            return "cmd+u"
        } else if allText.contains("strikethrough") {
            return "cmd+shift+x"
        }

        // Common app shortcuts
        if allText.contains("save") && !allText.contains("save as") {
            return "cmd+s"
        } else if allText.contains("save as") {
            return "cmd+shift+s"
        } else if allText.contains("open") {
            return "cmd+o"
        } else if allText.contains("new") {
            return "cmd+n"
        } else if allText.contains("close") {
            return "cmd+w"
        } else if allText.contains("quit") {
            return "cmd+q"
        } else if allText.contains("print") {
            return "cmd+p"
        }

        // Edit menu shortcuts
        if allText.contains("copy") {
            return "cmd+c"
        } else if allText.contains("cut") {
            return "cmd+x"
        } else if allText.contains("paste") {
            return "cmd+v"
        } else if allText.contains("undo") {
            return "cmd+z"
        } else if allText.contains("redo") {
            return "cmd+shift+z"
        } else if allText.contains("select all") {
            return "cmd+a"
        } else if allText.contains("find") && !allText.contains("replace") {
            return "cmd+f"
        } else if allText.contains("find and replace") || allText.contains("replace") {
            return "cmd+shift+f"
        }

        // Text alignment (common in text editors)
        if allText.contains("align left") || allText.contains("left align") {
            return "cmd+{"
        } else if allText.contains("align right") || allText.contains("right align") {
            return "cmd+}"
        } else if allText.contains("center") && (allText.contains("align") || allText.contains("text")) {
            return "cmd+|"
        }

        // Font panel
        if allText.contains("font") && (allText.contains("panel") || allText.contains("window")) {
            return "cmd+t"
        }

        // Menu items often have keyboard shortcuts in their titles
        if let title {
            // Look for patterns like "Bold ⌘B" or "Bold (Cmd+B)"
            let shortcutPatterns = [
                #"⌘([A-Z])"#, // ⌘B
                #"⌘⇧([A-Z])"#, // ⌘⇧B
                #"\(Cmd\+([A-Z])\)"#, // (Cmd+B)
                #"\(Cmd\+Shift\+([A-Z])\)"# // (Cmd+Shift+B)
            ]

            for pattern in shortcutPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)),
                   let keyRange = Range(match.range(at: 1), in: title) {
                    let key = String(title[keyRange]).lowercased()
                    if pattern.contains("Shift") || pattern.contains("⇧") {
                        return "cmd+shift+\(key)"
                    } else {
                        return "cmd+\(key)"
                    }
                }
            }
        }

        return nil
    }
}

enum PeekabooError: LocalizedError {
    case windowNotFound
    case elementNotFound
    case interactionFailed(String)
    case sessionNotFound
    case noValidSessionFound

    var errorDescription: String? {
        switch self {
        case .windowNotFound:
            "Window not found"
        case .elementNotFound:
            "UI element not found"
        case let .interactionFailed(reason):
            "Interaction failed: \(reason)"
        case .sessionNotFound:
            "Session not found or expired"
        case .noValidSessionFound:
            "No valid session found. Run 'peekaboo see' first to create a session, or specify an explicit --session parameter."
        }
    }
}

// MARK: - Element ID Generation

enum ElementIDGenerator {
    /// Generate prefix based on AX role
    static func prefix(for role: String) -> String {
        switch role {
        case "AXButton":
            "B"
        case "AXTextField", "AXTextArea":
            "T"
        case "AXLink":
            "L"
        case "AXMenu", "AXMenuItem":
            "M"
        case "AXCheckBox":
            "C"
        case "AXRadioButton":
            "R"
        case "AXSlider":
            "S"
        default:
            "G" // Generic/Group
        }
    }

    /// Check if a role is actionable
    static func isActionableRole(_ role: String) -> Bool {
        let actionableRoles = [
            "AXButton", "AXTextField", "AXTextArea", "AXCheckBox",
            "AXRadioButton", "AXPopUpButton", "AXLink", "AXMenuItem",
            "AXSlider", "AXComboBox", "AXSegmentedControl"
        ]
        return actionableRoles.contains(role)
    }
}
