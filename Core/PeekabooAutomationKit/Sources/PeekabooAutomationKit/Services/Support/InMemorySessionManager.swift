import CoreGraphics
import Foundation
import os.log
import PeekabooFoundation

/// In-memory implementation of `SessionManagerProtocol`.
///
/// Unlike `SessionManager`, this manager does not persist session state to disk and is ideal for long-lived host apps
/// (e.g. a macOS menubar app) where automation state can be kept in-process for speed and fidelity.
@MainActor
public final class InMemorySessionManager: SessionManagerProtocol {
    public struct Options: Sendable {
        /// How long sessions are considered valid for `getMostRecentSession()` and pruning.
        public var sessionValidityWindow: TimeInterval

        /// Maximum number of sessions kept in memory (LRU eviction).
        public var maxSessions: Int

        /// If enabled, attempts to delete any referenced screenshot artifacts on session cleanup.
        public var deleteArtifactsOnCleanup: Bool

        public init(
            sessionValidityWindow: TimeInterval = 600,
            maxSessions: Int = 25,
            deleteArtifactsOnCleanup: Bool = false)
        {
            self.sessionValidityWindow = sessionValidityWindow
            self.maxSessions = max(1, maxSessions)
            self.deleteArtifactsOnCleanup = deleteArtifactsOnCleanup
        }
    }

    private struct Entry {
        var createdAt: Date
        var lastAccessedAt: Date
        var processId: Int32
        var detectionResult: ElementDetectionResult?
        var sessionData: UIAutomationSession
    }

    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "InMemorySessionManager")
    private let options: Options
    private var entries: [String: Entry] = [:]

    public init(detectionResult: ElementDetectionResult? = nil, options: Options = Options()) {
        self.options = options

        if let detectionResult {
            let now = Date()
            let sessionId = detectionResult.sessionId
            var entry = Entry(
                createdAt: now,
                lastAccessedAt: now,
                processId: getpid(),
                detectionResult: detectionResult,
                sessionData: UIAutomationSession())
            self.applyDetectionResult(detectionResult, to: &entry.sessionData)
            self.entries[sessionId] = entry
        }
    }

    // MARK: - Session lifecycle

    public func createSession() async throws -> String {
        self.pruneIfNeeded()

        let timestamp = Int(Date().timeIntervalSince1970 * 1000) // milliseconds
        let randomSuffix = Int.random(in: 1000...9999)
        let sessionId = "\(timestamp)-\(randomSuffix)"

        let now = Date()
        self.entries[sessionId] = Entry(
            createdAt: now,
            lastAccessedAt: now,
            processId: getpid(),
            detectionResult: nil,
            sessionData: UIAutomationSession())

        return sessionId
    }

    public func storeDetectionResult(sessionId: String, result: ElementDetectionResult) async throws {
        self.pruneIfNeeded()

        var entry = self.entries[sessionId] ?? Entry(
            createdAt: Date(),
            lastAccessedAt: Date(),
            processId: getpid(),
            detectionResult: nil,
            sessionData: UIAutomationSession())

        entry.lastAccessedAt = Date()
        entry.detectionResult = result
        self.applyDetectionResult(result, to: &entry.sessionData)
        self.entries[sessionId] = entry
    }

    public func getDetectionResult(sessionId: String) async throws -> ElementDetectionResult? {
        guard var entry = self.entries[sessionId] else { return nil }
        entry.lastAccessedAt = Date()
        self.entries[sessionId] = entry

        if let detection = entry.detectionResult {
            return detection
        }

        // Best-effort fallback for sessions that were created via `storeScreenshot` without a stored detection result.
        return self.detectionResult(from: entry.sessionData, sessionId: sessionId)
    }

    public func getMostRecentSession() async -> String? {
        self.pruneIfNeeded()

        let cutoff = Date().addingTimeInterval(-self.options.sessionValidityWindow)
        return self.entries
            .filter { $0.value.createdAt >= cutoff }
            .max(by: { $0.value.lastAccessedAt < $1.value.lastAccessedAt })?
            .key
    }

    public func listSessions() async throws -> [SessionInfo] {
        let values = self.entries.map { id, entry in
            SessionInfo(
                id: id,
                processId: entry.processId,
                createdAt: entry.createdAt,
                lastAccessedAt: entry.lastAccessedAt,
                sizeInBytes: 0,
                screenshotCount: self.screenshotCount(for: entry.sessionData),
                isActive: true)
        }
        return values.sorted { $0.createdAt > $1.createdAt }
    }

    public func cleanSession(sessionId: String) async throws {
        guard let entry = self.entries.removeValue(forKey: sessionId) else { return }
        if self.options.deleteArtifactsOnCleanup {
            self.deleteArtifacts(for: entry.sessionData)
        }
    }

    public func cleanSessionsOlderThan(days: Int) async throws -> Int {
        let cutoff = Date().addingTimeInterval(-Double(days) * 24 * 3600)
        let toRemove = self.entries.filter { $0.value.createdAt < cutoff }.map(\.key)
        for id in toRemove {
            try await self.cleanSession(sessionId: id)
        }
        return toRemove.count
    }

    public func cleanAllSessions() async throws -> Int {
        let count = self.entries.count
        if self.options.deleteArtifactsOnCleanup {
            for entry in self.entries.values {
                self.deleteArtifacts(for: entry.sessionData)
            }
        }
        self.entries.removeAll()
        return count
    }

    public func getSessionStoragePath() -> String {
        "memory"
    }

    // MARK: - Screenshot + UI map helpers

    public func storeScreenshot(
        sessionId: String,
        screenshotPath: String,
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?) async throws
    {
        self.pruneIfNeeded()

        var entry = self.entries[sessionId] ?? Entry(
            createdAt: Date(),
            lastAccessedAt: Date(),
            processId: getpid(),
            detectionResult: nil,
            sessionData: UIAutomationSession())

        entry.lastAccessedAt = Date()
        entry.sessionData.screenshotPath = screenshotPath
        entry.sessionData.annotatedPath = entry.sessionData.annotatedPath ?? screenshotPath
        entry.sessionData.applicationName = applicationName
        entry.sessionData.windowTitle = windowTitle
        entry.sessionData.windowBounds = windowBounds
        entry.sessionData.lastUpdateTime = Date()
        self.entries[sessionId] = entry
    }

    public func getElement(sessionId: String, elementId: String) async throws -> UIElement? {
        guard var entry = self.entries[sessionId] else {
            throw SessionError.sessionNotFound
        }
        entry.lastAccessedAt = Date()
        self.entries[sessionId] = entry
        return entry.sessionData.uiMap[elementId]
    }

    public func findElements(sessionId: String, matching query: String) async throws -> [UIElement] {
        guard var entry = self.entries[sessionId] else {
            throw SessionError.sessionNotFound
        }
        entry.lastAccessedAt = Date()
        self.entries[sessionId] = entry

        let lowercaseQuery = query.lowercased()
        return entry.sessionData.uiMap.values.filter { element in
            let searchableText = [
                element.title,
                element.label,
                element.value,
                element.role,
            ].compactMap(\.self).joined(separator: " ").lowercased()

            return searchableText.contains(lowercaseQuery)
        }.sorted { lhs, rhs in
            if abs(lhs.frame.origin.y - rhs.frame.origin.y) < 10 {
                return lhs.frame.origin.x < rhs.frame.origin.x
            }
            return lhs.frame.origin.y < rhs.frame.origin.y
        }
    }

    public func getUIAutomationSession(sessionId: String) async throws -> UIAutomationSession? {
        guard var entry = self.entries[sessionId] else { return nil }
        entry.lastAccessedAt = Date()
        self.entries[sessionId] = entry
        return entry.sessionData
    }

    // MARK: - Internals

    private func pruneIfNeeded() {
        let cutoff = Date().addingTimeInterval(-self.options.sessionValidityWindow)
        let expired = self.entries.filter { $0.value.lastAccessedAt < cutoff }.map(\.key)
        for id in expired {
            self.entries.removeValue(forKey: id)
        }

        if self.entries.count <= self.options.maxSessions { return }

        let ordered = self.entries.sorted { $0.value.lastAccessedAt < $1.value.lastAccessedAt }
        let overflow = self.entries.count - self.options.maxSessions
        for pair in ordered.prefix(overflow) {
            self.entries.removeValue(forKey: pair.key)
        }
    }

    private func applyDetectionResult(_ result: ElementDetectionResult, to sessionData: inout UIAutomationSession) {
        sessionData.screenshotPath = result.screenshotPath.isEmpty ? sessionData.screenshotPath : result.screenshotPath
        sessionData.annotatedPath = self.annotatedPath(from: result.screenshotPath) ?? sessionData.annotatedPath
        sessionData.lastUpdateTime = Date()

        if let context = result.metadata.windowContext {
            sessionData.applicationName = context.applicationName ?? sessionData.applicationName
            sessionData.windowTitle = context.windowTitle ?? sessionData.windowTitle
            sessionData.windowBounds = context.windowBounds ?? sessionData.windowBounds
        } else {
            self.applyLegacyWarnings(result.metadata.warnings, to: &sessionData)
        }

        var uiMap: [String: UIElement] = [:]
        uiMap.reserveCapacity(result.elements.all.count)
        for element in result.elements.all {
            let uiElement = UIElement(
                id: element.id,
                elementId: "element_\(uiMap.count)",
                role: self.convertElementTypeToRole(element.type),
                title: element.label,
                label: element.label,
                value: element.value,
                identifier: element.attributes["identifier"],
                frame: element.bounds,
                isActionable: element.isEnabled && self.isActionableType(element.type),
                keyboardShortcut: element.attributes["keyboardShortcut"])
            uiMap[element.id] = uiElement
        }
        sessionData.uiMap = uiMap
    }

    private func applyLegacyWarnings(_ warnings: [String], to sessionData: inout UIAutomationSession) {
        for warning in warnings {
            if warning.hasPrefix("APP:") || warning.hasPrefix("app:") {
                sessionData.applicationName = String(warning.dropFirst(4))
            } else if warning.hasPrefix("WINDOW:") || warning.hasPrefix("window:") {
                sessionData.windowTitle = String(warning.dropFirst(7))
            } else if warning.hasPrefix("BOUNDS:"),
                      let boundsData = String(warning.dropFirst(7)).data(using: .utf8),
                      let bounds = try? JSONDecoder().decode(CGRect.self, from: boundsData)
            {
                sessionData.windowBounds = bounds
            } else if warning.hasPrefix("WINDOW_ID:"),
                      let windowID = CGWindowID(String(warning.dropFirst(10)))
            {
                sessionData.windowID = windowID
            } else if warning.hasPrefix("AX_IDENTIFIER:") {
                sessionData.windowAXIdentifier = String(warning.dropFirst(14))
            }
        }
    }

    private func annotatedPath(from screenshotPath: String) -> String? {
        guard !screenshotPath.isEmpty else { return nil }
        if screenshotPath.hasSuffix("raw.png") {
            return screenshotPath.replacingOccurrences(of: "raw.png", with: "annotated.png")
        }
        return screenshotPath
    }

    private func detectionResult(from sessionData: UIAutomationSession, sessionId: String) -> ElementDetectionResult? {
        guard let screenshotPath = sessionData.annotatedPath ?? sessionData.screenshotPath,
              !screenshotPath.isEmpty
        else {
            return nil
        }

        var allElements: [DetectedElement] = []
        allElements.reserveCapacity(sessionData.uiMap.count)

        for uiElement in sessionData.uiMap.values {
            var attributes: [String: String] = [:]
            if let identifier = uiElement.identifier {
                attributes["identifier"] = identifier
            }
            if let shortcut = uiElement.keyboardShortcut {
                attributes["keyboardShortcut"] = shortcut
            }
            let detectedElement = DetectedElement(
                id: uiElement.id,
                type: self.convertRoleToElementType(uiElement.role),
                label: uiElement.label ?? uiElement.title,
                value: uiElement.value,
                bounds: uiElement.frame,
                isEnabled: uiElement.isActionable,
                attributes: attributes)
            allElements.append(detectedElement)
        }

        let elements = self.organizeElementsByType(allElements)
        let metadata = DetectionMetadata(
            detectionTime: Date().timeIntervalSince(sessionData.lastUpdateTime),
            elementCount: sessionData.uiMap.count,
            method: "memory-cache",
            warnings: self.buildWarnings(from: sessionData))

        return ElementDetectionResult(
            sessionId: sessionId,
            screenshotPath: screenshotPath,
            elements: elements,
            metadata: metadata)
    }

    private func screenshotCount(for sessionData: UIAutomationSession) -> Int {
        var count = 0
        if sessionData.screenshotPath != nil { count += 1 }
        if let annotated = sessionData.annotatedPath, annotated != sessionData.screenshotPath { count += 1 }
        return count
    }

    private func deleteArtifacts(for sessionData: UIAutomationSession) {
        let fm = FileManager.default
        if let screenshotPath = sessionData.screenshotPath {
            try? fm.removeItem(atPath: screenshotPath)
        }
        if let annotatedPath = sessionData.annotatedPath, annotatedPath != sessionData.screenshotPath {
            try? fm.removeItem(atPath: annotatedPath)
        }
    }

    private func convertElementTypeToRole(_ type: ElementType) -> String {
        switch type {
        case .button: "AXButton"
        case .textField: "AXTextField"
        case .link: "AXLink"
        case .image: "AXImage"
        case .group: "AXGroup"
        case .slider: "AXSlider"
        case .checkbox: "AXCheckBox"
        case .menu: "AXMenu"
        case .staticText: "AXStaticText"
        case .radioButton: "AXRadioButton"
        case .menuItem: "AXMenuItem"
        case .window: "AXWindow"
        case .dialog: "AXDialog"
        case .other: "AXUnknown"
        }
    }

    private func convertRoleToElementType(_ role: String) -> ElementType {
        switch role {
        case "AXButton": .button
        case "AXTextField", "AXTextArea": .textField
        case "AXLink": .link
        case "AXImage": .image
        case "AXGroup": .group
        case "AXSlider": .slider
        case "AXCheckBox": .checkbox
        case "AXMenu", "AXMenuItem": .menu
        default: .other
        }
    }

    private func isActionableType(_ type: ElementType) -> Bool {
        switch type {
        case .button, .textField, .link, .checkbox, .slider, .menu, .menuItem, .radioButton:
            true
        case .image, .group, .other, .staticText, .window, .dialog:
            false
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
            case .menu, .menuItem: menus.append(element)
            case .other, .staticText, .radioButton, .window, .dialog: other.append(element)
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
            other: other)
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
           let boundsString = String(data: boundsData, encoding: .utf8)
        {
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
}
