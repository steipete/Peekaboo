import CoreGraphics
import Foundation
import os.log
import PeekabooFoundation

/// In-memory implementation of `SnapshotManagerProtocol`.
///
/// Unlike `SnapshotManager`, this manager does not persist snapshot state to disk and is ideal for long-lived host apps
/// (e.g. a macOS menubar app) where automation state can be kept in-process for speed and fidelity.
@MainActor
public final class InMemorySnapshotManager: SnapshotManagerProtocol {
    public struct Options: Sendable {
        /// How long snapshots are considered valid for `getMostRecentSnapshot()` and pruning.
        public var snapshotValidityWindow: TimeInterval

        /// Maximum number of snapshots kept in memory (LRU eviction).
        public var maxSnapshots: Int

        /// If enabled, attempts to delete any referenced screenshot artifacts on snapshot cleanup.
        public var deleteArtifactsOnCleanup: Bool

        public init(
            snapshotValidityWindow: TimeInterval = 600,
            maxSnapshots: Int = 25,
            deleteArtifactsOnCleanup: Bool = false)
        {
            self.snapshotValidityWindow = snapshotValidityWindow
            self.maxSnapshots = max(1, maxSnapshots)
            self.deleteArtifactsOnCleanup = deleteArtifactsOnCleanup
        }
    }

    private struct Entry {
        var createdAt: Date
        var lastAccessedAt: Date
        var processId: Int32
        var detectionResult: ElementDetectionResult?
        var snapshotData: UIAutomationSnapshot
    }

    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "InMemorySnapshotManager")
    private let options: Options
    private var entries: [String: Entry] = [:]

    public init(detectionResult: ElementDetectionResult? = nil, options: Options = Options()) {
        self.options = options

        if let detectionResult {
            let now = Date()
            let snapshotId = detectionResult.snapshotId
            var entry = Entry(
                createdAt: now,
                lastAccessedAt: now,
                processId: getpid(),
                detectionResult: detectionResult,
                snapshotData: UIAutomationSnapshot())
            self.applyDetectionResult(detectionResult, to: &entry.snapshotData)
            self.entries[snapshotId] = entry
        }
    }

    // MARK: - Snapshot lifecycle

    public func createSnapshot() async throws -> String {
        self.pruneIfNeeded()

        let timestamp = Int(Date().timeIntervalSince1970 * 1000) // milliseconds
        let randomSuffix = Int.random(in: 1000...9999)
        let snapshotId = "\(timestamp)-\(randomSuffix)"

        let now = Date()
        self.entries[snapshotId] = Entry(
            createdAt: now,
            lastAccessedAt: now,
            processId: getpid(),
            detectionResult: nil,
            snapshotData: UIAutomationSnapshot())

        return snapshotId
    }

    public func storeDetectionResult(snapshotId: String, result: ElementDetectionResult) async throws {
        self.pruneIfNeeded()

        var entry = self.entries[snapshotId] ?? Entry(
            createdAt: Date(),
            lastAccessedAt: Date(),
            processId: getpid(),
            detectionResult: nil,
            snapshotData: UIAutomationSnapshot())

        entry.lastAccessedAt = Date()
        entry.detectionResult = result
        self.applyDetectionResult(result, to: &entry.snapshotData)
        self.entries[snapshotId] = entry
    }

    public func getDetectionResult(snapshotId: String) async throws -> ElementDetectionResult? {
        guard var entry = self.entries[snapshotId] else { return nil }
        entry.lastAccessedAt = Date()
        self.entries[snapshotId] = entry

        if let detection = entry.detectionResult {
            return detection
        }

        // Best-effort fallback for snapshots that were created via `storeScreenshot` without a stored detection result.
        return self.detectionResult(from: entry.snapshotData, snapshotId: snapshotId)
    }

    public func getMostRecentSnapshot() async -> String? {
        self.pruneIfNeeded()

        let cutoff = Date().addingTimeInterval(-self.options.snapshotValidityWindow)
        return self.entries
            .filter { $0.value.createdAt >= cutoff }
            .max(by: { $0.value.lastAccessedAt < $1.value.lastAccessedAt })?
            .key
    }

    public func listSnapshots() async throws -> [SnapshotInfo] {
        let values = self.entries.map { id, entry in
            SnapshotInfo(
                id: id,
                processId: entry.processId,
                createdAt: entry.createdAt,
                lastAccessedAt: entry.lastAccessedAt,
                sizeInBytes: 0,
                screenshotCount: self.screenshotCount(for: entry.snapshotData),
                isActive: true)
        }
        return values.sorted { $0.createdAt > $1.createdAt }
    }

    public func cleanSnapshot(snapshotId: String) async throws {
        guard let entry = self.entries.removeValue(forKey: snapshotId) else { return }
        if self.options.deleteArtifactsOnCleanup {
            self.deleteArtifacts(for: entry.snapshotData)
        }
    }

    public func cleanSnapshotsOlderThan(days: Int) async throws -> Int {
        let cutoff = Date().addingTimeInterval(-Double(days) * 24 * 3600)
        let toRemove = self.entries.filter { $0.value.createdAt < cutoff }.map(\.key)
        for id in toRemove {
            try await self.cleanSnapshot(snapshotId: id)
        }
        return toRemove.count
    }

    public func cleanAllSnapshots() async throws -> Int {
        let count = self.entries.count
        if self.options.deleteArtifactsOnCleanup {
            for entry in self.entries.values {
                self.deleteArtifacts(for: entry.snapshotData)
            }
        }
        self.entries.removeAll()
        return count
    }

    public func getSnapshotStoragePath() -> String {
        "memory"
    }

    // MARK: - Screenshot + UI map helpers

    public func storeScreenshot(
        snapshotId: String,
        screenshotPath: String,
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?) async throws
    {
        self.pruneIfNeeded()

        var entry = self.entries[snapshotId] ?? Entry(
            createdAt: Date(),
            lastAccessedAt: Date(),
            processId: getpid(),
            detectionResult: nil,
            snapshotData: UIAutomationSnapshot())

        entry.lastAccessedAt = Date()
        entry.snapshotData.screenshotPath = screenshotPath
        entry.snapshotData.applicationName = applicationName
        entry.snapshotData.windowTitle = windowTitle
        entry.snapshotData.windowBounds = windowBounds
        entry.snapshotData.lastUpdateTime = Date()
        self.entries[snapshotId] = entry
    }

    public func storeAnnotatedScreenshot(snapshotId: String, annotatedScreenshotPath: String) async throws {
        self.pruneIfNeeded()

        var entry = self.entries[snapshotId] ?? Entry(
            createdAt: Date(),
            lastAccessedAt: Date(),
            processId: getpid(),
            detectionResult: nil,
            snapshotData: UIAutomationSnapshot())

        entry.lastAccessedAt = Date()
        entry.snapshotData.annotatedPath = annotatedScreenshotPath
        entry.snapshotData.lastUpdateTime = Date()
        self.entries[snapshotId] = entry
    }

    public func getElement(snapshotId: String, elementId: String) async throws -> UIElement? {
        guard var entry = self.entries[snapshotId] else {
            throw SnapshotError.snapshotNotFound
        }
        entry.lastAccessedAt = Date()
        self.entries[snapshotId] = entry
        return entry.snapshotData.uiMap[elementId]
    }

    public func findElements(snapshotId: String, matching query: String) async throws -> [UIElement] {
        guard var entry = self.entries[snapshotId] else {
            throw SnapshotError.snapshotNotFound
        }
        entry.lastAccessedAt = Date()
        self.entries[snapshotId] = entry

        let lowercaseQuery = query.lowercased()
        return entry.snapshotData.uiMap.values.filter { element in
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

    public func getUIAutomationSnapshot(snapshotId: String) async throws -> UIAutomationSnapshot? {
        guard var entry = self.entries[snapshotId] else { return nil }
        entry.lastAccessedAt = Date()
        self.entries[snapshotId] = entry
        return entry.snapshotData
    }

    // MARK: - Internals

    private func pruneIfNeeded() {
        let cutoff = Date().addingTimeInterval(-self.options.snapshotValidityWindow)
        let expired = self.entries.filter { $0.value.lastAccessedAt < cutoff }.map(\.key)
        for id in expired {
            self.entries.removeValue(forKey: id)
        }

        if self.entries.count <= self.options.maxSnapshots { return }

        let ordered = self.entries.sorted { $0.value.lastAccessedAt < $1.value.lastAccessedAt }
        let overflow = self.entries.count - self.options.maxSnapshots
        for pair in ordered.prefix(overflow) {
            self.entries.removeValue(forKey: pair.key)
        }
    }

    private func applyDetectionResult(_ result: ElementDetectionResult, to snapshotData: inout UIAutomationSnapshot) {
        if (snapshotData.screenshotPath ?? "").isEmpty, !result.screenshotPath.isEmpty {
            snapshotData.screenshotPath = result.screenshotPath
        }
        snapshotData.lastUpdateTime = Date()

        if let context = result.metadata.windowContext {
            snapshotData.applicationName = context.applicationName ?? snapshotData.applicationName
            snapshotData.windowTitle = context.windowTitle ?? snapshotData.windowTitle
            snapshotData.windowBounds = context.windowBounds ?? snapshotData.windowBounds
        } else {
            self.applyLegacyWarnings(result.metadata.warnings, to: &snapshotData)
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
        snapshotData.uiMap = uiMap
    }

    private func applyLegacyWarnings(_ warnings: [String], to snapshotData: inout UIAutomationSnapshot) {
        for warning in warnings {
            if warning.hasPrefix("APP:") || warning.hasPrefix("app:") {
                snapshotData.applicationName = String(warning.dropFirst(4))
            } else if warning.hasPrefix("WINDOW:") || warning.hasPrefix("window:") {
                snapshotData.windowTitle = String(warning.dropFirst(7))
            } else if warning.hasPrefix("BOUNDS:"),
                      let boundsData = String(warning.dropFirst(7)).data(using: .utf8),
                      let bounds = try? JSONDecoder().decode(CGRect.self, from: boundsData)
            {
                snapshotData.windowBounds = bounds
            } else if warning.hasPrefix("WINDOW_ID:"),
                      let windowID = CGWindowID(String(warning.dropFirst(10)))
            {
                snapshotData.windowID = windowID
            } else if warning.hasPrefix("AX_IDENTIFIER:") {
                snapshotData.windowAXIdentifier = String(warning.dropFirst(14))
            }
        }
    }

    private func detectionResult(
        from snapshotData: UIAutomationSnapshot,
        snapshotId: String) -> ElementDetectionResult?
    {
        guard let screenshotPath = snapshotData.annotatedPath ?? snapshotData.screenshotPath,
              !screenshotPath.isEmpty
        else {
            return nil
        }

        var allElements: [DetectedElement] = []
        allElements.reserveCapacity(snapshotData.uiMap.count)

        for uiElement in snapshotData.uiMap.values {
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
            detectionTime: Date().timeIntervalSince(snapshotData.lastUpdateTime),
            elementCount: snapshotData.uiMap.count,
            method: "memory-cache",
            warnings: self.buildWarnings(from: snapshotData))

        return ElementDetectionResult(
            snapshotId: snapshotId,
            screenshotPath: screenshotPath,
            elements: elements,
            metadata: metadata)
    }

    private func screenshotCount(for snapshotData: UIAutomationSnapshot) -> Int {
        var count = 0
        if snapshotData.screenshotPath != nil { count += 1 }
        if let annotated = snapshotData.annotatedPath, annotated != snapshotData.screenshotPath { count += 1 }
        return count
    }

    private func deleteArtifacts(for snapshotData: UIAutomationSnapshot) {
        let fm = FileManager.default
        if let screenshotPath = snapshotData.screenshotPath {
            try? fm.removeItem(atPath: screenshotPath)
        }
        if let annotatedPath = snapshotData.annotatedPath, annotatedPath != snapshotData.screenshotPath {
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

    private func buildWarnings(from snapshotData: UIAutomationSnapshot) -> [String] {
        var warnings: [String] = []
        if let appName = snapshotData.applicationName {
            warnings.append("APP:\(appName)")
        }
        if let windowTitle = snapshotData.windowTitle {
            warnings.append("WINDOW:\(windowTitle)")
        }
        if let windowBounds = snapshotData.windowBounds,
           let boundsData = try? JSONEncoder().encode(windowBounds),
           let boundsString = String(data: boundsData, encoding: .utf8)
        {
            warnings.append("BOUNDS:\(boundsString)")
        }
        if let windowID = snapshotData.windowID {
            warnings.append("WINDOW_ID:\(windowID)")
        }
        if let axIdentifier = snapshotData.windowAXIdentifier {
            warnings.append("AX_IDENTIFIER:\(axIdentifier)")
        }
        return warnings
    }
}
