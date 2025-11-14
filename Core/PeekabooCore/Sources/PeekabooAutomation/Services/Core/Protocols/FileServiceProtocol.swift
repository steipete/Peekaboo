import Foundation

/// Protocol defining file system operations for session management
public protocol FileServiceProtocol: Sendable {
    /// Clean all session data
    /// - Parameter dryRun: If true, only preview what would be deleted without actually deleting
    /// - Returns: Result containing information about cleaned sessions
    func cleanAllSessions(dryRun: Bool) async throws -> CleanResult

    /// Clean sessions older than specified hours
    /// - Parameters:
    ///   - hours: Remove sessions older than this many hours
    ///   - dryRun: If true, only preview what would be deleted without actually deleting
    /// - Returns: Result containing information about cleaned sessions
    func cleanOldSessions(hours: Int, dryRun: Bool) async throws -> CleanResult

    /// Clean a specific session by ID
    /// - Parameters:
    ///   - sessionId: The session ID to remove
    ///   - dryRun: If true, only preview what would be deleted without actually deleting
    /// - Returns: Result containing information about the cleaned session
    func cleanSpecificSession(sessionId: String, dryRun: Bool) async throws -> CleanResult

    /// Get the session cache directory path
    /// - Returns: URL to the session cache directory
    func getSessionCacheDirectory() -> URL

    /// Calculate the total size of a directory and its contents
    /// - Parameter directory: The directory to calculate size for
    /// - Returns: Total size in bytes
    func calculateDirectorySize(_ directory: URL) async throws -> Int64

    /// List all sessions with their metadata
    /// - Returns: Array of session information
    func listSessions() async throws -> [FileSessionInfo]
}

/// Result of cleaning operations
public struct CleanResult: Sendable, Codable {
    /// Number of sessions removed
    public let sessionsRemoved: Int

    /// Total bytes freed
    public let bytesFreed: Int64

    /// Details about each cleaned session
    public let sessionDetails: [SessionDetail]

    /// Whether this was a dry run
    public let dryRun: Bool

    /// Execution time in seconds
    public var executionTime: TimeInterval?

    public init(
        sessionsRemoved: Int,
        bytesFreed: Int64,
        sessionDetails: [SessionDetail],
        dryRun: Bool,
        executionTime: TimeInterval? = nil)
    {
        self.sessionsRemoved = sessionsRemoved
        self.bytesFreed = bytesFreed
        self.sessionDetails = sessionDetails
        self.dryRun = dryRun
        self.executionTime = executionTime
    }
}

/// Details about a specific session
public struct SessionDetail: Sendable, Codable {
    /// Session identifier
    public let sessionId: String

    /// Full path to the session directory
    public let path: String

    /// Size of the session in bytes
    public let size: Int64

    /// Creation date of the session
    public let creationDate: Date?

    /// Last modification date
    public let modificationDate: Date?

    public init(
        sessionId: String,
        path: String,
        size: Int64,
        creationDate: Date? = nil,
        modificationDate: Date? = nil)
    {
        self.sessionId = sessionId
        self.path = path
        self.size = size
        self.creationDate = creationDate
        self.modificationDate = modificationDate
    }
}

/// Information about a session from file system perspective
public struct FileSessionInfo: Sendable, Codable {
    /// Session identifier
    public let sessionId: String

    /// Path to the session directory
    public let path: URL

    /// Size in bytes
    public let size: Int64

    /// Creation date
    public let creationDate: Date

    /// Last modification date
    public let modificationDate: Date

    /// Files contained in the session
    public let files: [String]

    public init(
        sessionId: String,
        path: URL,
        size: Int64,
        creationDate: Date,
        modificationDate: Date,
        files: [String])
    {
        self.sessionId = sessionId
        self.path = path
        self.size = size
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.files = files
    }
}

/// Errors that can occur during file operations
public enum FileServiceError: LocalizedError, Sendable {
    case sessionNotFound(String)
    case directoryNotFound(URL)
    case insufficientPermissions(URL)
    case fileSystemError(String)

    public var errorDescription: String? {
        switch self {
        case let .sessionNotFound(sessionId):
            "Session '\(sessionId)' not found"
        case let .directoryNotFound(url):
            "Directory not found: \(url.path)"
        case let .insufficientPermissions(url):
            "Insufficient permissions to access: \(url.path)"
        case let .fileSystemError(message):
            "File system error: \(message)"
        }
    }
}
