import CoreGraphics
import Foundation
import os.log
import PeekabooFoundation

/// Default implementation of snapshot management operations.
/// Migrated from the legacy CLI automation cache with a thread-safe actor-based design.
@MainActor
public final class SnapshotManager: SnapshotManagerProtocol {
    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "SnapshotManager")
    private let snapshotActor = SnapshotStorageActor()

    // Snapshot validity window (10 minutes)
    private let snapshotValidityWindow: TimeInterval = 600

    public init() {}

    public func createSnapshot() async throws -> String {
        // Generate timestamp-based snapshot ID for cross-process compatibility
        let timestamp = Int(Date().timeIntervalSince1970 * 1000) // milliseconds
        let randomSuffix = Int.random(in: 1000...9999)
        let snapshotId = "\(timestamp)-\(randomSuffix)"

        self.logger.debug("Creating new snapshot: \(snapshotId)")

        // Create snapshot directory
        let snapshotPath = self.getSnapshotPath(for: snapshotId)
        try FileManager.default.createDirectory(at: snapshotPath, withIntermediateDirectories: true)

        // Initialize empty snapshot data
        let snapshotData = UIAutomationSnapshot(creatorProcessId: getpid())
        try await self.snapshotActor.saveSnapshot(snapshotId: snapshotId, data: snapshotData, at: snapshotPath)

        return snapshotId
    }

    public func storeDetectionResult(snapshotId: String, result: ElementDetectionResult) async throws {
        let snapshotPath = self.getSnapshotPath(for: snapshotId)

        // Load existing snapshot or create new
        var snapshotData = await self.snapshotActor
            .loadSnapshot(snapshotId: snapshotId, from: snapshotPath) ?? UIAutomationSnapshot()
        if snapshotData.creatorProcessId == nil {
            snapshotData.creatorProcessId = getpid()
        }

        // Convert detection result to snapshot format (preserve any previously stored screenshot paths).
        if (snapshotData.screenshotPath ?? "").isEmpty, !result.screenshotPath.isEmpty {
            snapshotData.screenshotPath = result.screenshotPath
        }
        snapshotData.lastUpdateTime = Date()

        // Convert detected elements to UI map
        var uiMap: [String: UIElement] = [:]
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
                isActionable: self.isActionableType(element.type),
                keyboardShortcut: element.attributes["keyboardShortcut"])
            uiMap[element.id] = uiElement
        }
        snapshotData.uiMap = uiMap

        // Extract metadata from warnings
        for warning in result.metadata.warnings {
            if warning.hasPrefix("app:") {
                snapshotData.applicationName = String(warning.dropFirst(4))
            } else if warning.hasPrefix("window:") {
                snapshotData.windowTitle = String(warning.dropFirst(7))
            } else if warning.hasPrefix("APP:") {
                snapshotData.applicationName = String(warning.dropFirst(4))
            } else if warning.hasPrefix("WINDOW:") {
                snapshotData.windowTitle = String(warning.dropFirst(7))
            } else if warning.hasPrefix("BOUNDS:") {
                // Parse bounds if needed
                if let boundsData = String(warning.dropFirst(7)).data(using: .utf8),
                   let bounds = try? JSONDecoder().decode(CGRect.self, from: boundsData)
                {
                    snapshotData.windowBounds = bounds
                }
            } else if warning.hasPrefix("WINDOW_ID:") {
                if let windowID = CGWindowID(String(warning.dropFirst(10))) {
                    snapshotData.windowID = windowID
                }
            } else if warning.hasPrefix("AX_IDENTIFIER:") {
                snapshotData.windowAXIdentifier = String(warning.dropFirst(14))
            }
        }

        // Save updated snapshot
        try await self.snapshotActor.saveSnapshot(snapshotId: snapshotId, data: snapshotData, at: snapshotPath)
    }

    public func getDetectionResult(snapshotId: String) async throws -> ElementDetectionResult? {
        let snapshotPath = self.getSnapshotPath(for: snapshotId)

        guard let snapshotData = await self.snapshotActor.loadSnapshot(snapshotId: snapshotId, from: snapshotPath)
        else {
            return nil
        }

        // Convert snapshot data back to detection result
        var elements = DetectedElements()
        var allElements: [DetectedElement] = []

        for (_, uiElement) in snapshotData.uiMap {
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

        // Organize by type
        elements = self.organizeElementsByType(allElements)

        let metadata = DetectionMetadata(
            detectionTime: Date().timeIntervalSince(snapshotData.lastUpdateTime),
            elementCount: snapshotData.uiMap.count,
            method: "snapshot-cache",
            warnings: self.buildWarnings(from: snapshotData))

        return ElementDetectionResult(
            snapshotId: snapshotId,
            screenshotPath: snapshotData.annotatedPath ?? snapshotData.screenshotPath ?? "",
            elements: elements,
            metadata: metadata)
    }

    public func getMostRecentSnapshot() async -> String? {
        await self.findLatestValidSnapshot()
    }

    public func getMostRecentSnapshot(applicationBundleId: String) async -> String? {
        await self.findLatestValidSnapshot(applicationBundleId: applicationBundleId)
    }

    public func listSnapshots() async throws -> [SnapshotInfo] {
        let snapshotDir = self.getSnapshotStorageURL()

        guard let snapshots = try? FileManager.default.contentsOfDirectory(
            at: snapshotDir,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles)
        else {
            return []
        }

        var snapshotInfos: [SnapshotInfo] = []

        for snapshotURL in snapshots {
            guard snapshotURL.hasDirectoryPath else { continue }

            let snapshotId = snapshotURL.lastPathComponent

            // Get snapshot metadata
            let resourceValues = try? snapshotURL.resourceValues(forKeys: [.creationDateKey])
            let creationDate = resourceValues?.creationDate ?? Date()

            // Load snapshot data to get details
            let snapshotData = await self.snapshotActor.loadSnapshot(snapshotId: snapshotId, from: snapshotURL)

            // Count screenshots
            let screenshotCount = self.countScreenshots(in: snapshotURL)

            // Calculate size
            let sizeInBytes = self.calculateDirectorySize(snapshotURL)

            // Check if process is still active
            let processId = snapshotData?.creatorProcessId ?? self.extractProcessId(from: snapshotId)
            let isActive = self.isProcessActive(processId)

            let info = SnapshotInfo(
                id: snapshotId,
                processId: processId,
                createdAt: creationDate,
                lastAccessedAt: snapshotData?.lastUpdateTime ?? creationDate,
                sizeInBytes: sizeInBytes,
                screenshotCount: screenshotCount,
                isActive: isActive)
            snapshotInfos.append(info)
        }

        return snapshotInfos.sorted { $0.createdAt > $1.createdAt }
    }

    public func cleanSnapshot(snapshotId: String) async throws {
        let snapshotPath = self.getSnapshotPath(for: snapshotId)

        // Only try to remove if the directory exists
        if FileManager.default.fileExists(atPath: snapshotPath.path) {
            try FileManager.default.removeItem(at: snapshotPath)
            self.logger.info("Cleaned snapshot: \(snapshotId)")
        } else {
            self.logger.debug("Snapshot \(snapshotId) does not exist, skipping cleanup")
        }
    }

    public func cleanSnapshotsOlderThan(days: Int) async throws -> Int {
        let cutoffDate = Date().addingTimeInterval(-Double(days) * 24 * 3600)
        let snapshots = try await listSnapshots()

        var cleanedCount = 0
        for snapshot in snapshots where snapshot.createdAt < cutoffDate {
            try await cleanSnapshot(snapshotId: snapshot.id)
            cleanedCount += 1
        }

        return cleanedCount
    }

    public func cleanAllSnapshots() async throws -> Int {
        let snapshots = try await listSnapshots()

        for snapshot in snapshots {
            try await self.cleanSnapshot(snapshotId: snapshot.id)
        }

        return snapshots.count
    }

    public func getSnapshotStoragePath() -> String {
        self.getSnapshotStorageURL().path
    }

    // MARK: - Additional Public Methods

    /// Store raw screenshot and build UI map
    public func storeScreenshot(
        snapshotId: String,
        screenshotPath: String,
        applicationBundleId: String?,
        applicationProcessId: Int32?,
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?) async throws
    {
        // Store raw screenshot and build UI map
        let snapshotPath = self.getSnapshotPath(for: snapshotId)
        try FileManager.default.createDirectory(at: snapshotPath, withIntermediateDirectories: true)

        // Load or create snapshot data
        var snapshotData = await self.snapshotActor
            .loadSnapshot(snapshotId: snapshotId, from: snapshotPath) ?? UIAutomationSnapshot()
        if snapshotData.creatorProcessId == nil {
            snapshotData.creatorProcessId = getpid()
        }

        // Copy screenshot to snapshot directory
        let rawPath = snapshotPath.appendingPathComponent("raw.png")
        let sourceURL = URL(fileURLWithPath: screenshotPath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw CaptureError.fileIOError("Screenshot missing at \(sourceURL.path)")
        }
        if FileManager.default.fileExists(atPath: rawPath.path) {
            try FileManager.default.removeItem(at: rawPath)
        }
        do {
            try FileManager.default.copyItem(at: sourceURL, to: rawPath)
        } catch {
            let message = "Failed to copy screenshot to snapshot storage: \(error.localizedDescription)"
            throw CaptureError.fileIOError(message)
        }

        snapshotData.screenshotPath = rawPath.path
        snapshotData.applicationName = applicationName
        snapshotData.applicationBundleId = applicationBundleId
        snapshotData.applicationProcessId = applicationProcessId
        snapshotData.windowTitle = windowTitle
        snapshotData.windowBounds = windowBounds
        snapshotData.lastUpdateTime = Date()

        try await self.snapshotActor.saveSnapshot(snapshotId: snapshotId, data: snapshotData, at: snapshotPath)
    }

    public func storeAnnotatedScreenshot(snapshotId: String, annotatedScreenshotPath: String) async throws {
        let snapshotPath = self.getSnapshotPath(for: snapshotId)
        try FileManager.default.createDirectory(at: snapshotPath, withIntermediateDirectories: true)

        var snapshotData = await self.snapshotActor
            .loadSnapshot(snapshotId: snapshotId, from: snapshotPath) ?? UIAutomationSnapshot()
        if snapshotData.creatorProcessId == nil {
            snapshotData.creatorProcessId = getpid()
        }

        let annotatedPath = snapshotPath.appendingPathComponent("annotated.png")
        let sourceURL = URL(fileURLWithPath: annotatedScreenshotPath).standardizedFileURL

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw CaptureError.fileIOError("Annotated screenshot missing at \(sourceURL.path)")
        }

        if FileManager.default.fileExists(atPath: annotatedPath.path) {
            try FileManager.default.removeItem(at: annotatedPath)
        }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: annotatedPath)
        } catch {
            let message = "Failed to copy annotated screenshot to snapshot storage: \(error.localizedDescription)"
            throw CaptureError.fileIOError(message)
        }

        snapshotData.annotatedPath = annotatedPath.path
        snapshotData.lastUpdateTime = Date()

        try await self.snapshotActor.saveSnapshot(snapshotId: snapshotId, data: snapshotData, at: snapshotPath)
    }

    /// Get element by ID from snapshot
    public func getElement(snapshotId: String, elementId: String) async throws -> UIElement? {
        let snapshotPath = self.getSnapshotPath(for: snapshotId)
        guard let snapshotData = await self.snapshotActor.loadSnapshot(snapshotId: snapshotId, from: snapshotPath)
        else {
            throw SnapshotError.snapshotNotFound
        }
        return snapshotData.uiMap[elementId]
    }

    /// Find elements matching a query
    public func findElements(snapshotId: String, matching query: String) async throws -> [UIElement] {
        let snapshotPath = self.getSnapshotPath(for: snapshotId)
        guard let snapshotData = await self.snapshotActor.loadSnapshot(snapshotId: snapshotId, from: snapshotPath)
        else {
            throw SnapshotError.snapshotNotFound
        }

        let lowercaseQuery = query.lowercased()
        return snapshotData.uiMap.values.filter { element in
            let searchableText = [
                element.title,
                element.label,
                element.value,
                element.role,
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

    public func getUIAutomationSnapshot(snapshotId: String) async throws -> UIAutomationSnapshot? {
        let snapshotPath = self.getSnapshotPath(for: snapshotId)
        return await self.snapshotActor.loadSnapshot(snapshotId: snapshotId, from: snapshotPath)
    }

    // MARK: - Private Helpers

    private func getSnapshotStorageURL() -> URL {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".peekaboo/snapshots")

        // Ensure the directory exists
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }

    private func getSnapshotPath(for snapshotId: String) -> URL {
        self.getSnapshotStorageURL().appendingPathComponent(snapshotId)
    }

    private func findLatestValidSnapshot() async -> String? {
        let snapshotDir = self.getSnapshotStorageURL()

        guard let snapshots = try? FileManager.default.contentsOfDirectory(
            at: snapshotDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles)
        else {
            return nil
        }

        let tenMinutesAgo = Date().addingTimeInterval(-self.snapshotValidityWindow)

        let validSnapshots = snapshots.compactMap { url -> (url: URL, date: Date)? in
            guard let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey]),
                  let creationDate = resourceValues.creationDate,
                  creationDate > tenMinutesAgo
            else {
                return nil
            }
            return (url, creationDate)
        }.sorted { $0.date > $1.date }

        if let latest = validSnapshots.first {
            let age = Int(-latest.date.timeIntervalSinceNow)
            self.logger.debug(
                "Found valid snapshot: \(latest.url.lastPathComponent) created \(age) seconds ago")
            return latest.url.lastPathComponent
        } else {
            self.logger.debug("No valid snapshots found within \(Int(self.snapshotValidityWindow)) second window")
            return nil
        }
    }

    private func findLatestValidSnapshot(applicationBundleId: String) async -> String? {
        let snapshotDir = self.getSnapshotStorageURL()

        guard let snapshots = try? FileManager.default.contentsOfDirectory(
            at: snapshotDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles)
        else {
            return nil
        }

        let cutoff = Date().addingTimeInterval(-self.snapshotValidityWindow)

        let recentSnapshots = snapshots.compactMap { url -> (url: URL, createdAt: Date)? in
            guard let values = try? url.resourceValues(forKeys: [.creationDateKey]),
                  let createdAt = values.creationDate,
                  createdAt > cutoff,
                  url.hasDirectoryPath
            else {
                return nil
            }
            return (url, createdAt)
        }.sorted { $0.createdAt > $1.createdAt }

        for entry in recentSnapshots {
            let snapshotId = entry.url.lastPathComponent
            guard let snapshotData = await self.snapshotActor.loadSnapshot(snapshotId: snapshotId, from: entry.url)
            else { continue }
            if snapshotData.applicationBundleId == applicationBundleId {
                return snapshotId
            }
        }

        return nil
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

    private func countScreenshots(in snapshotURL: URL) -> Int {
        let files = try? FileManager.default.contentsOfDirectory(at: snapshotURL, includingPropertiesForKeys: nil)
        return files?.count(where: { $0.pathExtension == "png" }) ?? 0
    }

    private func calculateDirectorySize(_ url: URL) -> Int64 {
        var totalSize: Int64 = 0

        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles])
        {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize
                {
                    totalSize += Int64(fileSize)
                }
            }
        }

        return totalSize
    }

    private func extractProcessId(from snapshotId: String) -> Int32 {
        // Try to extract PID from old-style snapshot IDs (just numbers)
        if let pid = Int32(snapshotId) {
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

/// Actor for thread-safe snapshot storage operations
private actor SnapshotStorageActor {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        // JSONCoding.encoder already has pretty printing and sorted keys configured
        self.encoder = JSONCoding.makeEncoder()
        self.decoder = JSONCoding.makeDecoder()
    }

    func saveSnapshot(snapshotId: String, data: UIAutomationSnapshot, at snapshotPath: URL) throws {
        // Ensure the snapshot directory exists
        try FileManager.default.createDirectory(at: snapshotPath, withIntermediateDirectories: true)

        let snapshotFile = snapshotPath.appendingPathComponent("snapshot.json")
        let jsonData = try encoder.encode(data)

        // Use built-in atomic write option
        try jsonData.write(to: snapshotFile, options: .atomic)
    }

    func loadSnapshot(snapshotId: String, from snapshotPath: URL) -> UIAutomationSnapshot? {
        let snapshotFile = snapshotPath.appendingPathComponent("snapshot.json")

        guard FileManager.default.fileExists(atPath: snapshotFile.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: snapshotFile)
            let snapshotData = try decoder.decode(UIAutomationSnapshot.self, from: data)

            // Check version compatibility
            if snapshotData.version != UIAutomationSnapshot.currentVersion {
                // Remove incompatible snapshot
                try? FileManager.default.removeItem(at: snapshotFile)
                return nil
            }

            return snapshotData
        } catch {
            // Log the error but don't throw - we'll clean up and return nil
            _ = error.asPeekabooError(context: "Failed to load snapshot \(snapshotId)")
            // Remove corrupted snapshot
            try? FileManager.default.removeItem(at: snapshotFile)
            return nil
        }
    }
}
