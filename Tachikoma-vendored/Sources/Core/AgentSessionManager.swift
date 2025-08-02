import Foundation

// MARK: - Agent Session

/// Represents a persistent agent conversation session
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AgentSession: Codable, Sendable {
    /// Unique session identifier
    public let id: String
    
    /// Messages in the conversation
    public let messages: [Message]
    
    /// Session metadata
    public let metadata: SessionMetadata?
    
    /// When the session was created
    public let createdAt: Date
    
    /// When the session was last updated
    public let updatedAt: Date
    
    /// Number of messages in the session
    public var messageCount: Int {
        messages.count
    }
    
    public init(
        id: String,
        messages: [Message],
        metadata: SessionMetadata? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.messages = messages
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Session Metadata

/// Metadata associated with an agent session
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct SessionMetadata: Codable, Sendable {
    /// Agent name that created the session
    public let agentName: String?
    
    /// Model used in the session
    public let modelName: String?
    
    /// Total tokens used in the session
    public let totalTokens: Int?
    
    /// Session tags for organization
    public let tags: [String]?
    
    /// Custom metadata
    public let customData: [String: String]?
    
    public init(
        agentName: String? = nil,
        modelName: String? = nil,
        totalTokens: Int? = nil,
        tags: [String]? = nil,
        customData: [String: String]? = nil
    ) {
        self.agentName = agentName
        self.modelName = modelName
        self.totalTokens = totalTokens
        self.tags = tags
        self.customData = customData
    }
}

// MARK: - Session Summary

/// Summary information about a session for listing
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct SessionSummary: Sendable {
    /// Session ID
    public let id: String
    
    /// Creation date
    public let createdAt: Date
    
    /// Last update date
    public let updatedAt: Date
    
    /// Number of messages
    public let messageCount: Int
    
    /// Agent name if available
    public let agentName: String?
    
    /// Model name if available
    public let modelName: String?
    
    public init(
        id: String,
        createdAt: Date,
        updatedAt: Date,
        messageCount: Int,
        agentName: String? = nil,
        modelName: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messageCount = messageCount
        self.agentName = agentName
        self.modelName = modelName
    }
}

// MARK: - Agent Session Manager

/// Manages agent conversation sessions for persistence and resume functionality
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public actor AgentSessionManager {
    private let sessionDirectory: URL
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Session cache to avoid repeated disk reads
    private var sessionCache: [String: AgentSession] = [:]

    public init(directory: URL? = nil) {
        // Configure JSON encoder/decoder
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        // Default to ~/.tachikoma/sessions/
        if let directory {
            self.sessionDirectory = directory
        } else {
            let homeDirectory = fileManager.homeDirectoryForCurrentUser
            self.sessionDirectory = homeDirectory
                .appendingPathComponent(".tachikoma")
                .appendingPathComponent("sessions")
        }

        // Ensure directory exists
        try? fileManager.createDirectory(
            at: sessionDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    // MARK: - Public Methods

    /// Save a session
    public func saveSession(
        id: String,
        messages: [Message],
        metadata: SessionMetadata? = nil
    ) throws {
        let session = AgentSession(
            id: id,
            messages: messages,
            metadata: metadata,
            createdAt: sessionCache[id]?.createdAt ?? Date(),
            updatedAt: Date()
        )

        // Update cache
        sessionCache[id] = session

        // Save to disk
        let url = sessionURL(for: id)
        let data = try encoder.encode(session)
        try data.write(to: url)
    }

    /// Load a session
    public func loadSession(id: String) throws -> AgentSession? {
        // Check cache first
        if let cached = sessionCache[id] {
            return cached
        }

        // Load from disk
        let url = sessionURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        let session = try decoder.decode(AgentSession.self, from: data)

        // Update cache
        sessionCache[id] = session

        return session
    }

    /// Delete a session
    public func deleteSession(id: String) throws {
        // Remove from cache
        sessionCache.removeValue(forKey: id)

        // Remove from disk
        let url = sessionURL(for: id)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    /// List all sessions
    public func listSessions() throws -> [SessionSummary] {
        let contents = try fileManager.contentsOfDirectory(
            at: sessionDirectory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        )

        let sessionFiles = contents.filter { $0.pathExtension == "json" }
        
        return try sessionFiles.compactMap { url in
            let sessionId = url.deletingPathExtension().lastPathComponent
            
            // Try to load from cache first
            if let cached = sessionCache[sessionId] {
                return SessionSummary(
                    id: cached.id,
                    createdAt: cached.createdAt,
                    updatedAt: cached.updatedAt,
                    messageCount: cached.messageCount,
                    agentName: cached.metadata?.agentName,
                    modelName: cached.metadata?.modelName
                )
            }
            
            // Load minimal data from disk if not cached
            guard let data = try? Data(contentsOf: url),
                  let session = try? decoder.decode(AgentSession.self, from: data) else {
                return nil
            }
            
            return SessionSummary(
                id: session.id,
                createdAt: session.createdAt,
                updatedAt: session.updatedAt,
                messageCount: session.messageCount,
                agentName: session.metadata?.agentName,
                modelName: session.metadata?.modelName
            )
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Clear all sessions
    public func clearAllSessions() throws {
        sessionCache.removeAll()
        
        let contents = try fileManager.contentsOfDirectory(
            at: sessionDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        
        for url in contents where url.pathExtension == "json" {
            try fileManager.removeItem(at: url)
        }
    }

    /// Get session count
    public func sessionCount() throws -> Int {
        let contents = try fileManager.contentsOfDirectory(
            at: sessionDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        
        return contents.filter { $0.pathExtension == "json" }.count
    }

    // MARK: - Private Methods

    private func sessionURL(for id: String) -> URL {
        return sessionDirectory.appendingPathComponent("\(id).json")
    }
}