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
            warnings: self.buildWarnings(from: snapshotData),
            windowContext: self.windowContext(from: snapshotData))

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
}
