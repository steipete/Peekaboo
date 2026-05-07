import Foundation

extension InMemorySnapshotManager {
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
            snapshotData: UIAutomationSnapshot(creatorProcessId: getpid()))
        self.pruneIfNeeded()

        return snapshotId
    }

    public func storeDetectionResult(snapshotId: String, result: ElementDetectionResult) async throws {
        self.pruneIfNeeded()

        var entry = self.entries[snapshotId] ?? Entry(
            createdAt: Date(),
            lastAccessedAt: Date(),
            processId: getpid(),
            detectionResult: nil,
            snapshotData: UIAutomationSnapshot(creatorProcessId: getpid()))

        entry.lastAccessedAt = Date()
        entry.detectionResult = result
        self.applyDetectionResult(result, to: &entry.snapshotData)
        self.entries[snapshotId] = entry
        self.pruneIfNeeded()
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

    public func getMostRecentSnapshot(applicationBundleId: String) async -> String? {
        self.pruneIfNeeded()

        let cutoff = Date().addingTimeInterval(-self.options.snapshotValidityWindow)
        return self.entries
            .filter { _, entry in
                entry.createdAt >= cutoff && entry.snapshotData.applicationBundleId == applicationBundleId
            }
            .max(by: { $0.value.lastAccessedAt < $1.value.lastAccessedAt })?
            .key
    }

    public func listSnapshots() async throws -> [SnapshotInfo] {
        self.pruneIfNeeded()

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
        self.removeEntry(forSnapshotId: snapshotId)
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
}
