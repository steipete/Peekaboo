import AppKit
import AXorcist
import CoreGraphics
import Foundation

/// Process-isolated session cache for UI automation state.
/// Implements atomic file operations to ensure data integrity across processes.
@available(macOS 14.0, *)
actor SessionCache {
    let sessionId: String
    private let cacheDir: URL
    private let sessionFile: URL

    struct SessionData: Codable {
        var screenshot: String?
        var uiMap: [String: UIElement]
        var lastUpdateTime: Date
        var applicationName: String?
        var windowTitle: String?

        struct UIElement: Codable {
            let id: String // Peekaboo ID (B1, T1, etc.)
            let elementId: String // Internal unique ID
            let role: String
            let title: String?
            let label: String?
            let value: String?
            let frame: CGRect
            let isActionable: Bool
            let parentId: String?
            let children: [String]

            init(
                id: String,
                elementId: String,
                role: String,
                title: String?,
                label: String?,
                value: String?,
                frame: CGRect,
                isActionable: Bool,
                parentId: String? = nil
            ) {
                self.id = id
                self.elementId = elementId
                self.role = role
                self.title = title
                self.label = label
                self.value = value
                self.frame = frame
                self.isActionable = isActionable
                self.parentId = parentId
                children = []
            }
        }
    }

    init(sessionId: String? = nil) {
        self.sessionId = sessionId ?? UUID().uuidString

        // Create cache directory
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        cacheDir = appSupport.appendingPathComponent("peekaboo/sessions")
        try? FileManager.default.createDirectory(
            at: cacheDir,
            withIntermediateDirectories: true
        )

        sessionFile = cacheDir.appendingPathComponent("\(self.sessionId).json")
    }

    /// Load session data from disk
    func load() -> SessionData? {
        guard FileManager.default.fileExists(atPath: sessionFile.path) else { return nil }

        do {
            let data = try Data(contentsOf: sessionFile)
            return try JSONDecoder().decode(SessionData.self, from: data)
        } catch {
            Logger.shared.error("Failed to load session data: \(error)")
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
    func updateScreenshot(path: String, application: String?, window: String?) async throws {
        var data = load() ?? SessionData(uiMap: [:], lastUpdateTime: Date())
        data.screenshot = path
        data.applicationName = application
        data.windowTitle = window
        data.lastUpdateTime = Date()

        // Build UI map using AXorcist
        if let app = application {
            data.uiMap = try await buildUIMap(for: app, window: window)
        }

        try save(data)
    }

    /// Build UI element map for the specified application
    @MainActor
    private func buildUIMap(for appName: String, window: String?) async throws -> [String: SessionData.UIElement] {
        var uiMap: [String: SessionData.UIElement] = [:]
        var roleCounters: [String: Int] = [:]

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

        // Get all windows if no specific window is requested
        let windows: [Element] = if let windowTitle = window {
            // Find specific window
            appElement.children()?.filter { element in
                element.title() == windowTitle
            } ?? []
        } else {
            // Get all windows
            appElement.windows() ?? []
        }

        // Process each window
        for window in windows {
            await processElement(window, parentId: nil, uiMap: &uiMap, roleCounters: &roleCounters)
        }

        return uiMap
    }

    /// Recursively process an element and its children
    @MainActor
    private func processElement(
        _ element: Element,
        parentId: String?,
        uiMap: inout [String: SessionData.UIElement],
        roleCounters: inout [String: Int]
    ) async {
        // Get element properties
        let role = element.role() ?? "AXGroup"
        let title = element.title()
        let label = title // AXorcist doesn't expose label separately
        let value = element.value() as? String

        // Get element bounds
        let position = element.position()
        let size = element.size()
        let frame: CGRect = if let pos = position, let sz = size {
            CGRect(x: pos.x, y: pos.y, width: sz.width, height: sz.height)
        } else {
            .zero
        }

        // Generate Peekaboo ID
        let prefix = ElementIDGenerator.prefix(for: role)
        let counter = (roleCounters[prefix] ?? 0) + 1
        roleCounters[prefix] = counter
        let peekabooId = "\(prefix)\(counter)"

        // Create unique element ID
        let elementId = "element_\(uiMap.count)"

        // Create UI element
        let uiElement = SessionData.UIElement(
            id: peekabooId,
            elementId: elementId,
            role: role,
            title: title,
            label: label,
            value: value,
            frame: frame,
            isActionable: ElementIDGenerator.isActionableRole(role),
            parentId: parentId
        )

        // Store in map
        uiMap[peekabooId] = uiElement

        // Process children recursively
        if let children = element.children() {
            for child in children {
                await processElement(child, parentId: peekabooId, uiMap: &uiMap, roleCounters: &roleCounters)
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
}

enum PeekabooError: LocalizedError {
    case windowNotFound
    case elementNotFound
    case interactionFailed(String)
    case sessionNotFound

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
