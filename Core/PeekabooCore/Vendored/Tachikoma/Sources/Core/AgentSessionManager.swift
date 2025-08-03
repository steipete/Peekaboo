import Foundation

/// Summary information about an agent session
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct SessionSummary: Sendable, Codable {
    /// Unique session identifier
    public let id: String

    /// Model name used in this session
    public let modelName: String

    /// When the session was created
    public let createdAt: Date

    /// When the session was last accessed
    public let lastAccessedAt: Date

    /// Number of messages in the session
    public let messageCount: Int

    /// Session status
    public let status: SessionStatus

    /// Brief description of the session
    public let summary: String?

    public init(
        id: String,
        modelName: String,
        createdAt: Date,
        lastAccessedAt: Date,
        messageCount: Int,
        status: SessionStatus,
        summary: String? = nil)
    {
        self.id = id
        self.modelName = modelName
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.messageCount = messageCount
        self.status = status
        self.summary = summary
    }
}

/// Status of an agent session
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum SessionStatus: String, Codable, Sendable {
    case active
    case completed
    case failed
    case expired
}

/// Complete agent session with full conversation history
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AgentSession: Sendable, Codable {
    /// Unique session identifier
    public let id: String

    /// Model name used in this session
    public let modelName: String

    /// Complete conversation history
    public let messages: [Message]

    /// Session metadata
    public let metadata: SessionMetadata

    /// When the session was created
    public let createdAt: Date

    /// When the session was last updated
    public let updatedAt: Date

    public init(
        id: String,
        modelName: String,
        messages: [Message],
        metadata: SessionMetadata,
        createdAt: Date,
        updatedAt: Date)
    {
        self.id = id
        self.modelName = modelName
        self.messages = messages
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Metadata associated with an agent session
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct SessionMetadata: Sendable, Codable {
    /// Total tokens used across all requests
    public let totalTokens: Int

    /// Total cost if available
    public let totalCost: Double?

    /// Number of tool calls made
    public let toolCallCount: Int

    /// Total execution time in seconds
    public let totalExecutionTime: TimeInterval

    /// Additional custom metadata
    public let customData: [String: String]

    public init(
        totalTokens: Int = 0,
        totalCost: Double? = nil,
        toolCallCount: Int = 0,
        totalExecutionTime: TimeInterval = 0,
        customData: [String: String] = [:])
    {
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.toolCallCount = toolCallCount
        self.totalExecutionTime = totalExecutionTime
        self.customData = customData
    }
}

/// Manages agent conversation sessions with persistence and caching
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class AgentSessionManager: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let sessionDirectory: URL
    private var sessionCache: [String: AgentSession] = [:]
    private let cacheQueue = DispatchQueue(label: "tachikoma.session.cache", attributes: .concurrent)

    /// Maximum number of sessions to keep in memory cache
    public static let maxCacheSize = 50

    /// Maximum age for sessions before they're considered expired
    public static let maxSessionAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days

    public init(sessionDirectory: URL? = nil) throws {
        if let sessionDirectory {
            self.sessionDirectory = sessionDirectory
        } else {
            // Default to ~/.tachikoma/sessions/
            let homeDir = self.fileManager.homeDirectoryForCurrentUser
            self.sessionDirectory = homeDir.appendingPathComponent(".tachikoma/sessions")
        }

        // Create session directory if it doesn't exist
        try self.fileManager.createDirectory(at: self.sessionDirectory, withIntermediateDirectories: true)
    }

    /// List all available sessions
    public func listSessions() -> [SessionSummary] {
        do {
            let sessionFiles = try fileManager.contentsOfDirectory(
                at: self.sessionDirectory,
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey])

            return sessionFiles.compactMap { url in
                guard url.pathExtension == "json" else { return nil }

                do {
                    let data = try Data(contentsOf: url)
                    let session = try JSONDecoder().decode(AgentSession.self, from: data)

                    let resourceValues = try url.resourceValues(forKeys: [
                        .creationDateKey,
                        .contentModificationDateKey,
                    ])
                    let createdAt = resourceValues.creationDate ?? Date()
                    let lastAccessedAt = resourceValues.contentModificationDate ?? Date()

                    return SessionSummary(
                        id: session.id,
                        modelName: session.modelName,
                        createdAt: createdAt,
                        lastAccessedAt: lastAccessedAt,
                        messageCount: session.messages.count,
                        status: self.isSessionExpired(lastAccessedAt) ? .expired : .active,
                        summary: self.generateSessionSummary(from: session.messages))
                } catch {
                    return nil
                }
            }.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
        } catch {
            return []
        }
    }

    /// Save a session to persistent storage
    public func saveSession(_ session: AgentSession) throws {
        let sessionFile = self.sessionDirectory.appendingPathComponent("\(session.id).json")
        let data = try JSONEncoder().encode(session)
        try data.write(to: sessionFile)

        // Update cache
        self.cacheQueue.async(flags: .barrier) {
            self.sessionCache[session.id] = session
            self.evictOldCacheEntries()
        }
    }

    /// Load a session from storage
    public func loadSession(id: String) throws -> AgentSession? {
        // Check cache first
        let cachedSession = self.cacheQueue.sync {
            self.sessionCache[id]
        }

        if let cachedSession {
            return cachedSession
        }

        // Load from disk
        let sessionFile = self.sessionDirectory.appendingPathComponent("\(id).json")
        guard self.fileManager.fileExists(atPath: sessionFile.path) else {
            return nil
        }

        let data = try Data(contentsOf: sessionFile)
        let session = try JSONDecoder().decode(AgentSession.self, from: data)

        // Add to cache
        self.cacheQueue.async(flags: .barrier) {
            self.sessionCache[id] = session
            self.evictOldCacheEntries()
        }

        return session
    }

    /// Delete a session
    public func deleteSession(id: String) throws {
        let sessionFile = self.sessionDirectory.appendingPathComponent("\(id).json")
        try self.fileManager.removeItem(at: sessionFile)

        // Remove from cache
        self.cacheQueue.async(flags: .barrier) {
            self.sessionCache.removeValue(forKey: id)
        }
    }

    /// Clean up expired sessions
    public func cleanupExpiredSessions() throws {
        let sessions = self.listSessions()
        let expiredSessions = sessions.filter { self.isSessionExpired($0.lastAccessedAt) }

        for session in expiredSessions {
            try self.deleteSession(id: session.id)
        }
    }

    // MARK: - Private Methods

    private func isSessionExpired(_ lastAccessed: Date) -> Bool {
        Date().timeIntervalSince(lastAccessed) > Self.maxSessionAge
    }

    private func generateSessionSummary(from messages: [Message]) -> String? {
        // Find the first user message to use as summary
        for message in messages {
            if case let .user(_, content) = message {
                switch content {
                case let .text(text):
                    return String(text.prefix(100))
                case let .multimodal(parts):
                    for part in parts {
                        if let text = part.text {
                            return String(text.prefix(100))
                        }
                    }
                case .image, .file, .audio:
                    continue // Skip non-text content
                }
            }
        }
        return nil
    }

    private func evictOldCacheEntries() {
        guard self.sessionCache.count > Self.maxCacheSize else { return }

        // Remove oldest entries
        let sortedKeys = self.sessionCache.keys.sorted { key1, key2 in
            let session1 = self.sessionCache[key1]!
            let session2 = self.sessionCache[key2]!
            return session1.updatedAt < session2.updatedAt
        }

        let keysToRemove = sortedKeys.prefix(self.sessionCache.count - Self.maxCacheSize)
        for key in keysToRemove {
            self.sessionCache.removeValue(forKey: key)
        }
    }
}
