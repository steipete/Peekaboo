import Foundation

/// Protocol defining UI automation snapshot management operations.
@MainActor
public protocol SnapshotManagerProtocol: Sendable {
    /// Create a new snapshot container.
    /// - Returns: Unique snapshot identifier
    func createSnapshot() async throws -> String

    /// Store element detection results in a snapshot
    /// - Parameters:
    ///   - snapshotId: Snapshot identifier
    ///   - result: Element detection result to store
    func storeDetectionResult(snapshotId: String, result: ElementDetectionResult) async throws

    /// Retrieve element detection results from a snapshot
    /// - Parameter snapshotId: Snapshot identifier
    /// - Returns: Stored detection result if available
    func getDetectionResult(snapshotId: String) async throws -> ElementDetectionResult?

    /// Get the most recent snapshot ID
    /// - Returns: Snapshot ID if available
    func getMostRecentSnapshot() async -> String?

    /// List all active snapshots
    /// - Returns: Array of snapshot information
    func listSnapshots() async throws -> [SnapshotInfo]

    /// Clean up a specific snapshot
    /// - Parameter snapshotId: Snapshot identifier to clean
    func cleanSnapshot(snapshotId: String) async throws

    /// Clean up snapshots older than specified days
    /// - Parameter days: Number of days
    /// - Returns: Number of snapshots cleaned
    func cleanSnapshotsOlderThan(days: Int) async throws -> Int

    /// Clean all snapshots
    /// - Returns: Number of snapshots cleaned
    func cleanAllSnapshots() async throws -> Int

    /// Get snapshot storage path
    /// - Returns: Path to snapshot storage directory
    func getSnapshotStoragePath() -> String

    /// Store raw screenshot and build UI map
    /// - Parameters:
    ///   - snapshotId: Snapshot identifier
    ///   - screenshotPath: Path to the screenshot file
    ///   - applicationName: Name of the application
    ///   - windowTitle: Title of the window
    ///   - windowBounds: Window bounds
    func storeScreenshot(
        snapshotId: String,
        screenshotPath: String,
        applicationName: String?,
        windowTitle: String?,
        windowBounds: CGRect?) async throws

    /// Store an annotated screenshot for a snapshot (optional companion to `raw.png`).
    /// - Parameters:
    ///   - snapshotId: Snapshot identifier
    ///   - annotatedScreenshotPath: Path to the annotated screenshot file
    func storeAnnotatedScreenshot(
        snapshotId: String,
        annotatedScreenshotPath: String) async throws

    /// Get element by ID from snapshot
    /// - Parameters:
    ///   - snapshotId: Snapshot identifier
    ///   - elementId: Element ID to retrieve
    /// - Returns: UI element if found
    func getElement(snapshotId: String, elementId: String) async throws -> UIElement?

    /// Find elements matching a query
    /// - Parameters:
    ///   - snapshotId: Snapshot identifier
    ///   - query: Search query
    /// - Returns: Array of matching elements
    func findElements(snapshotId: String, matching query: String) async throws -> [UIElement]

    /// Get the full UI automation snapshot data
    /// - Parameter snapshotId: Snapshot identifier
    /// - Returns: UI automation snapshot if found
    func getUIAutomationSnapshot(snapshotId: String) async throws -> UIAutomationSnapshot?
}

/// Information about a snapshot
public struct SnapshotInfo: Sendable, Codable {
    /// Unique snapshot identifier
    public let id: String

    /// Process ID that created the snapshot
    public let processId: Int32

    /// Creation timestamp
    public let createdAt: Date

    /// Last accessed timestamp
    public let lastAccessedAt: Date

    /// Size of snapshot data in bytes
    public let sizeInBytes: Int64

    /// Number of stored screenshots
    public let screenshotCount: Int

    /// Whether the snapshot is currently active
    public let isActive: Bool

    public init(
        id: String,
        processId: Int32,
        createdAt: Date,
        lastAccessedAt: Date,
        sizeInBytes: Int64,
        screenshotCount: Int,
        isActive: Bool)
    {
        self.id = id
        self.processId = processId
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.sizeInBytes = sizeInBytes
        self.screenshotCount = screenshotCount
        self.isActive = isActive
    }
}

/// Options for snapshot cleanup
public struct SnapshotCleanupOptions: Sendable {
    /// Perform dry run (don't actually delete)
    public let dryRun: Bool

    /// Only clean snapshots from inactive processes
    public let onlyInactive: Bool

    /// Maximum age in days (nil = no age limit)
    public let maxAgeInDays: Int?

    /// Maximum total size in MB (nil = no size limit)
    public let maxTotalSizeMB: Int?

    public init(
        dryRun: Bool = false,
        onlyInactive: Bool = true,
        maxAgeInDays: Int? = nil,
        maxTotalSizeMB: Int? = nil)
    {
        self.dryRun = dryRun
        self.onlyInactive = onlyInactive
        self.maxAgeInDays = maxAgeInDays
        self.maxTotalSizeMB = maxTotalSizeMB
    }
}
