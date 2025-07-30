import Foundation

// MARK: - Agent Session Manager

/// Manages agent conversation sessions for persistence and resume functionality
public actor AgentSessionManager {
    private let sessionDirectory: URL
    private let fileManager = FileManager.default
    private let encoder = JSONCoding.encoder
    private let decoder = JSONCoding.decoder

    /// Session cache to avoid repeated disk reads
    private var sessionCache: [String: AgentSession] = [:]

    public init(directory: URL? = nil) {
        // Default to ~/.peekaboo/agent/sessions/
        if let directory {
            self.sessionDirectory = directory
        } else {
            let homeDirectory = self.fileManager.homeDirectoryForCurrentUser
            self.sessionDirectory = homeDirectory
                .appendingPathComponent(".peekaboo")
                .appendingPathComponent("agent")
                .appendingPathComponent("sessions")
        }

        // JSONCoding.encoder and decoder already have appropriate configuration

        // Ensure directory exists
        try? self.fileManager.createDirectory(
            at: self.sessionDirectory,
            withIntermediateDirectories: true,
            attributes: nil)
    }

    // MARK: - Public Methods

    /// Save a session
    public func saveSession(
        id: String,
        messages: [Message],
        metadata: SessionMetadata? = nil) throws
    {
        let session = AgentSession(
            id: id,
            messages: messages,
            metadata: metadata,
            createdAt: sessionCache[id]?.createdAt ?? Date(),
            updatedAt: Date())

        // Update cache
        self.sessionCache[id] = session

        // Save to disk
        let url = self.sessionURL(for: id)
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
        let url = self.sessionURL(for: id)
        guard self.fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        let session = try decoder.decode(AgentSession.self, from: data)

        // Update cache
        self.sessionCache[id] = session

        return session
    }

    /// Delete a session
    public func deleteSession(id: String) throws {
        // Remove from cache
        self.sessionCache.removeValue(forKey: id)

        // Remove from disk
        let url = self.sessionURL(for: id)
        if self.fileManager.fileExists(atPath: url.path) {
            try self.fileManager.removeItem(at: url)
        }
    }

    /// List all sessions
    public func listSessions() throws -> [SessionSummary] {
        let contents = try fileManager.contentsOfDirectory(
            at: self.sessionDirectory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: .skipsHiddenFiles)

        var summaries: [SessionSummary] = []

        for url in contents where url.pathExtension == "json" {
            let sessionId = url.deletingPathExtension().lastPathComponent

            if let session = try? loadSession(id: sessionId) {
                summaries.append(SessionSummary(
                    id: session.id,
                    createdAt: session.createdAt,
                    updatedAt: session.updatedAt,
                    messageCount: session.messages.count,
                    metadata: session.metadata))
            }
        }

        // Sort by updated date, newest first
        summaries.sort { $0.updatedAt > $1.updatedAt }

        return summaries
    }

    /// Clean up old sessions (older than 30 days)
    public func cleanOldSessions(daysToKeep: Int = 30) throws {
        let cutoffDate = Date().addingTimeInterval(-Double(daysToKeep * 24 * 60 * 60))

        let contents = try fileManager.contentsOfDirectory(
            at: self.sessionDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles)

        for url in contents where url.pathExtension == "json" {
            if let modificationDate = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate,
                modificationDate < cutoffDate
            {
                try fileManager.removeItem(at: url)
            }
        }
    }

    /// Clear all sessions
    public func clearAllSessions() throws {
        // Clear cache
        self.sessionCache.removeAll()

        // Clear disk
        let contents = try fileManager.contentsOfDirectory(
            at: self.sessionDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles)

        for url in contents where url.pathExtension == "json" {
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - Private Methods

    private func sessionURL(for id: String) -> URL {
        self.sessionDirectory.appendingPathComponent("\(id).json")
    }
}

// MARK: - Session Types

/// A stored agent conversation session
public struct AgentSession: Codable, Sendable {
    public let id: String
    public let messages: [Message]
    public let metadata: SessionMetadata?
    public let createdAt: Date
    public let updatedAt: Date
}

/// Summary of a session for listing
public struct SessionSummary: Sendable {
    public let id: String
    public let createdAt: Date
    public let updatedAt: Date
    public let messageCount: Int
    public let metadata: SessionMetadata?
}

// MARK: - Session Extensions

extension AgentSession {
    /// Get the last user message
    public var lastUserMessage: String? {
        for message in self.messages.reversed() {
            if case let .user(_, content) = message {
                switch content {
                case let .text(text):
                    return text
                case let .multimodal(parts):
                    return parts.compactMap(\.text).first
                default:
                    continue
                }
            }
        }
        return nil
    }

    /// Get the last assistant response
    public var lastAssistantResponse: String? {
        for message in self.messages.reversed() {
            if case let .assistant(_, content, _) = message {
                return content.compactMap { content in
                    if case let .outputText(text) = content {
                        return text
                    }
                    return nil
                }.joined()
            }
        }
        return nil
    }

    /// Check if session has any tool calls
    public var hasToolCalls: Bool {
        self.messages.contains { message in
            if case let .assistant(_, content, _) = message {
                return content.contains { content in
                    if case .toolCall = content {
                        return true
                    }
                    return false
                }
            }
            return false
        }
    }
}
