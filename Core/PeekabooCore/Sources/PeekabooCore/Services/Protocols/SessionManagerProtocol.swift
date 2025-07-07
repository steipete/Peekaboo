import Foundation

/// Protocol defining session management operations
public protocol SessionManagerProtocol: Sendable {
    /// Create a new session
    /// - Returns: Unique session identifier
    func createSession() async throws -> String
    
    /// Store element detection results in a session
    /// - Parameters:
    ///   - sessionId: Session identifier
    ///   - result: Element detection result to store
    func storeDetectionResult(sessionId: String, result: ElementDetectionResult) async throws
    
    /// Retrieve element detection results from a session
    /// - Parameter sessionId: Session identifier
    /// - Returns: Stored detection result if available
    func getDetectionResult(sessionId: String) async throws -> ElementDetectionResult?
    
    /// Get the most recent session ID
    /// - Returns: Session ID if available
    func getMostRecentSession() async -> String?
    
    /// List all active sessions
    /// - Returns: Array of session information
    func listSessions() async throws -> [SessionInfo]
    
    /// Clean up a specific session
    /// - Parameter sessionId: Session identifier to clean
    func cleanSession(sessionId: String) async throws
    
    /// Clean up sessions older than specified days
    /// - Parameter days: Number of days
    /// - Returns: Number of sessions cleaned
    func cleanSessionsOlderThan(days: Int) async throws -> Int
    
    /// Clean all sessions
    /// - Returns: Number of sessions cleaned
    func cleanAllSessions() async throws -> Int
    
    /// Get session storage path
    /// - Returns: Path to session storage directory
    func getSessionStoragePath() -> String
}

/// Information about a session
public struct SessionInfo: Sendable {
    /// Unique session identifier
    public let id: String
    
    /// Process ID that created the session
    public let processId: Int32
    
    /// Creation timestamp
    public let createdAt: Date
    
    /// Last accessed timestamp
    public let lastAccessedAt: Date
    
    /// Size of session data in bytes
    public let sizeInBytes: Int64
    
    /// Number of stored screenshots
    public let screenshotCount: Int
    
    /// Whether the session is currently active
    public let isActive: Bool
    
    public init(
        id: String,
        processId: Int32,
        createdAt: Date,
        lastAccessedAt: Date,
        sizeInBytes: Int64,
        screenshotCount: Int,
        isActive: Bool
    ) {
        self.id = id
        self.processId = processId
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.sizeInBytes = sizeInBytes
        self.screenshotCount = screenshotCount
        self.isActive = isActive
    }
}

/// Options for session cleanup
public struct SessionCleanupOptions: Sendable {
    /// Perform dry run (don't actually delete)
    public let dryRun: Bool
    
    /// Only clean sessions from inactive processes
    public let onlyInactive: Bool
    
    /// Maximum age in days (nil = no age limit)
    public let maxAgeInDays: Int?
    
    /// Maximum total size in MB (nil = no size limit)
    public let maxTotalSizeMB: Int?
    
    public init(
        dryRun: Bool = false,
        onlyInactive: Bool = true,
        maxAgeInDays: Int? = nil,
        maxTotalSizeMB: Int? = nil
    ) {
        self.dryRun = dryRun
        self.onlyInactive = onlyInactive
        self.maxAgeInDays = maxAgeInDays
        self.maxTotalSizeMB = maxTotalSizeMB
    }
}