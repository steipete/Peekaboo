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

    struct Entry {
        var createdAt: Date
        var lastAccessedAt: Date
        var processId: Int32
        var detectionResult: ElementDetectionResult?
        var snapshotData: UIAutomationSnapshot
    }

    private let logger = Logger(subsystem: "boo.peekaboo.core", category: "InMemorySnapshotManager")
    let options: Options
    var entries: [String: Entry] = [:]

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
                snapshotData: UIAutomationSnapshot(creatorProcessId: getpid()))
            self.applyDetectionResult(detectionResult, to: &entry.snapshotData)
            self.entries[snapshotId] = entry
        }
    }
}
