import Foundation
import AXorcist

// MARK: - Agent Session Manager

/// Manages agent conversation sessions for persistence and resume functionality
public actor AgentSessionManager {
    private let sessionDirectory: URL
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    /// Session cache to avoid repeated disk reads
    private var sessionCache: [String: AgentSession] = [:]
    
    public init(directory: URL? = nil) {
        // Default to ~/.peekaboo/agent/sessions/
        if let directory = directory {
            self.sessionDirectory = directory
        } else {
            let homeDirectory = fileManager.homeDirectoryForCurrentUser
            self.sessionDirectory = homeDirectory
                .appendingPathComponent(".peekaboo")
                .appendingPathComponent("agent")
                .appendingPathComponent("sessions")
        }
        
        // Configure encoder/decoder
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
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
        messages: [any MessageItem],
        metadata: [String: Any]? = nil
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
        
        return contents.compactMap { url in
            guard url.pathExtension == "json" else { return nil }
            
            do {
                let data = try Data(contentsOf: url)
                let session = try decoder.decode(AgentSession.self, from: data)
                
                return SessionSummary(
                    id: session.id,
                    createdAt: session.createdAt,
                    updatedAt: session.updatedAt,
                    messageCount: session.messages.count,
                    metadata: session.metadata
                )
            } catch {
                // Skip invalid sessions
                return nil
            }
        }.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    /// Clean up old sessions
    public func cleanupSessions(olderThan date: Date) throws {
        let sessions = try listSessions()
        
        for session in sessions where session.updatedAt < date {
            try deleteSession(id: session.id)
        }
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
    
    // MARK: - Private Methods
    
    private func sessionURL(for id: String) -> URL {
        sessionDirectory.appendingPathComponent("\(id).json")
    }
}

// MARK: - Session Types

/// A stored agent conversation session
public struct AgentSession: Codable, Sendable {
    public let id: String
    public let messages: [AnyMessageItem]
    public let metadata: [String: AnyCodable]?
    public let createdAt: Date
    public let updatedAt: Date
    
    init(
        id: String,
        messages: [any MessageItem],
        metadata: [String: Any]?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.messages = messages.map(AnyMessageItem.init)
        self.metadata = metadata?.mapValues(AnyCodable.init)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Summary of a session for listing
public struct SessionSummary: Sendable {
    public let id: String
    public let createdAt: Date
    public let updatedAt: Date
    public let messageCount: Int
    public let metadata: [String: AnyCodable]?
}

// MARK: - Type Erasure for Messages

/// Type-erased message item for storage
public struct AnyMessageItem: Codable, Sendable {
    private let wrapped: any MessageItem
    
    init(_ message: any MessageItem) {
        self.wrapped = message
    }
    
    var message: any MessageItem {
        wrapped
    }
    
    // Custom coding to handle different message types
    enum CodingKeys: String, CodingKey {
        case type, data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageItemType.self, forKey: .type)
        
        switch type {
        case .system:
            let message = try container.decode(SystemMessageItem.self, forKey: .data)
            self.wrapped = message
        case .user:
            let message = try container.decode(UserMessageItem.self, forKey: .data)
            self.wrapped = message
        case .assistant:
            let message = try container.decode(AssistantMessageItem.self, forKey: .data)
            self.wrapped = message
        case .tool:
            let message = try container.decode(ToolMessageItem.self, forKey: .data)
            self.wrapped = message
        case .reasoning:
            let message = try container.decode(ReasoningMessageItem.self, forKey: .data)
            self.wrapped = message
        case .unknown:
            let message = try container.decode(UnknownMessageItem.self, forKey: .data)
            self.wrapped = message
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(wrapped.type, forKey: .type)
        
        switch wrapped {
        case let message as SystemMessageItem:
            try container.encode(message, forKey: .data)
        case let message as UserMessageItem:
            try container.encode(message, forKey: .data)
        case let message as AssistantMessageItem:
            try container.encode(message, forKey: .data)
        case let message as ToolMessageItem:
            try container.encode(message, forKey: .data)
        case let message as ReasoningMessageItem:
            try container.encode(message, forKey: .data)
        case let message as UnknownMessageItem:
            try container.encode(message, forKey: .data)
        default:
            throw EncodingError.invalidValue(
                wrapped,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unknown message type"
                )
            )
        }
    }
}

// MARK: - Session Extensions

extension AgentSession {
    /// Get the last user message
    public var lastUserMessage: String? {
        for message in messages.reversed() {
            if let userMessage = message.message as? UserMessageItem,
               case .text(let text) = userMessage.content {
                return text
            }
        }
        return nil
    }
    
    /// Get the last assistant response
    public var lastAssistantResponse: String? {
        for message in messages.reversed() {
            if let assistantMessage = message.message as? AssistantMessageItem {
                return assistantMessage.content.compactMap { content in
                    if case .outputText(let text) = content {
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
        messages.contains { message in
            if let assistantMessage = message.message as? AssistantMessageItem {
                return assistantMessage.content.contains { content in
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