import CoreGraphics
import Foundation
import os.log
import PeekabooFoundation

/// Default implementation of snapshot management operations.
/// Migrated from the legacy CLI automation cache with a thread-safe actor-based design.
@MainActor
public final class SnapshotManager: SnapshotManagerProtocol {
    let logger = Logger(subsystem: "boo.peekaboo.core", category: "SnapshotManager")
    let snapshotActor = SnapshotStorageActor()

    /// Snapshot validity window (10 minutes)
    let snapshotValidityWindow: TimeInterval = 600

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

        if let context = result.metadata.windowContext {
            self.applyWindowContext(context, to: &snapshotData)
        } else {
            self.applyLegacyWarnings(result.metadata.warnings, to: &snapshotData)
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
    public func storeScreenshot(_ request: SnapshotScreenshotRequest) async throws {
        // Store raw screenshot and build UI map
        let snapshotPath = self.getSnapshotPath(for: request.snapshotId)
        try FileManager.default.createDirectory(at: snapshotPath, withIntermediateDirectories: true)

        // Load or create snapshot data
        var snapshotData = await self.snapshotActor
            .loadSnapshot(snapshotId: request.snapshotId, from: snapshotPath) ?? UIAutomationSnapshot()
        if snapshotData.creatorProcessId == nil {
            snapshotData.creatorProcessId = getpid()
        }

        // Copy screenshot to snapshot directory
        let rawPath = snapshotPath.appendingPathComponent("raw.png")
        let sourceURL = URL(fileURLWithPath: request.screenshotPath).standardizedFileURL
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
        snapshotData.applicationName = request.applicationName
        snapshotData.applicationBundleId = request.applicationBundleId
        snapshotData.applicationProcessId = request.applicationProcessId
        snapshotData.windowTitle = request.windowTitle
        snapshotData.windowBounds = request.windowBounds
        snapshotData.lastUpdateTime = Date()

        try await self.snapshotActor.saveSnapshot(snapshotId: request.snapshotId, data: snapshotData, at: snapshotPath)
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
}

// MARK: - Thread-Safe Storage Actor

/// Actor for thread-safe snapshot storage operations
actor SnapshotStorageActor {
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
