import Foundation
import PeekabooAutomation
import PeekabooAutomationKit

actor UISnapshot {
    let id: String
    private(set) var screenshotPath: String?
    private(set) var screenshotMetadata: CaptureMetadata?
    private(set) var uiElements: [UIElement] = []
    private(set) var createdAt: Date
    private(set) var lastAccessedAt: Date
    private(set) nonisolated(unsafe) var cachedApplicationName: String?
    private(set) nonisolated(unsafe) var cachedWindowTitle: String?
    private(set) nonisolated(unsafe) var cachedApplicationProcessId: Int32?

    init() {
        self.id = UUID().uuidString
        self.createdAt = Date()
        self.lastAccessedAt = Date()
    }

    func setScreenshot(path: String, metadata: CaptureMetadata) {
        self.screenshotPath = path
        self.screenshotMetadata = metadata
        self.cachedApplicationName = metadata.applicationInfo?.name
        self.cachedWindowTitle = metadata.windowInfo?.title
        self.cachedApplicationProcessId = metadata.applicationInfo.map { Int32($0.processIdentifier) }
        self.lastAccessedAt = Date()
    }

    func setUIElements(_ elements: [UIElement]) {
        self.uiElements = elements
        self.lastAccessedAt = Date()
    }

    func setTargetMetadata(from context: WindowContext?) {
        self.cachedApplicationName = context?.applicationName
        self.cachedWindowTitle = context?.windowTitle
        self.cachedApplicationProcessId = context?.applicationProcessId
        self.lastAccessedAt = Date()
    }

    func getElement(byId id: String) -> UIElement? {
        self.uiElements.first { $0.id == id }
    }

    nonisolated var applicationName: String? {
        self.cachedApplicationName
    }

    nonisolated var windowTitle: String? {
        self.cachedWindowTitle
    }

    nonisolated var applicationProcessId: Int32? {
        self.cachedApplicationProcessId
    }
}

actor UISnapshotManager {
    static let shared = UISnapshotManager()

    private var snapshots: [String: UISnapshot] = [:]
    private var orderedSnapshotIds: [String] = []

    private init() {}

    func createSnapshot() -> UISnapshot {
        let snapshot = UISnapshot()
        self.snapshots[snapshot.id] = snapshot
        self.orderedSnapshotIds.append(snapshot.id)
        return snapshot
    }

    func getSnapshot(id: String?) -> UISnapshot? {
        if let id {
            return self.snapshots[id]
        }
        if let mostRecentSnapshotId = self.orderedSnapshotIds.last {
            return self.snapshots[mostRecentSnapshotId]
        }
        return nil
    }

    func removeSnapshot(id: String) {
        self.snapshots.removeValue(forKey: id)
        self.orderedSnapshotIds.removeAll(where: { $0 == id })
    }

    func activeSnapshotId(id: String?) -> String? {
        if let id, self.snapshots[id] != nil {
            return id
        }
        if id != nil {
            return nil
        }
        return self.orderedSnapshotIds.last
    }

    @discardableResult
    func invalidateActiveSnapshot(id: String?) -> String? {
        guard let id = self.activeSnapshotId(id: id) else { return nil }
        self.removeSnapshot(id: id)
        return id
    }

    func removeAllSnapshots() {
        self.snapshots.removeAll()
        self.orderedSnapshotIds.removeAll()
    }

    func cleanupOldSnapshots(olderThan timeInterval: TimeInterval = 3600) async {
        let cutoffDate = Date().addingTimeInterval(-timeInterval)
        var newSnapshots: [String: UISnapshot] = [:]
        for (id, snapshot) in self.snapshots {
            let lastAccessed = await snapshot.lastAccessedAt
            guard lastAccessed > cutoffDate else { continue }
            newSnapshots[id] = snapshot
        }
        self.snapshots = newSnapshots
        self.orderedSnapshotIds = self.orderedSnapshotIds.filter { newSnapshots[$0] != nil }
    }
}
