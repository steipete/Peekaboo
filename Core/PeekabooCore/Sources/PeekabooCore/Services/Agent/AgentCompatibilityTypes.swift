import Foundation
import Tachikoma

// MARK: - Event Types

/// Events emitted during agent execution
public enum AgentEvent: Sendable {
    case started(task: String)
    case assistantMessage(content: String)
    case thinkingMessage(content: String) // New case for thinking/reasoning content
    case toolCallStarted(name: String, arguments: String)
    case toolCallCompleted(name: String, result: String)
    case error(message: String)
    case completed(summary: String, usage: Usage?)
}

/// Protocol for receiving agent events
@MainActor
public protocol AgentEventDelegate: AnyObject, Sendable {
    /// Called when an agent event is emitted
    func agentDidEmitEvent(_ event: AgentEvent)
}

// MARK: - Event Delegate Extensions

/// Extension to make the existing AgentEventDelegate compatible with our usage
extension AgentEventDelegate {
    /// Helper method for backward compatibility
    func agentDidStart() async {
        self.agentDidEmitEvent(.started(task: ""))
    }

    /// Helper method for backward compatibility
    func agentDidReceiveChunk(_ chunk: String) async {
        self.agentDidEmitEvent(.assistantMessage(content: chunk))
    }
}

// MARK: - Agent Execution Types

/// Result of agent task execution containing response content, metadata, and tool usage information
public struct AgentExecutionResult: Sendable {
    /// The generated response content from the AI model
    public let content: String

    /// Complete conversation messages including tool calls and responses
    public let messages: [ModelMessage]

    /// Session identifier for tracking conversation state
    public let sessionId: String?

    /// Token usage statistics from the AI provider
    public let usage: Usage?

    /// Additional metadata about the execution
    public let metadata: AgentMetadata

    public init(
        content: String,
        messages: [ModelMessage] = [],
        sessionId: String? = nil,
        usage: Usage? = nil,
        metadata: AgentMetadata)
    {
        self.content = content
        self.messages = messages
        self.sessionId = sessionId
        self.usage = usage
        self.metadata = metadata
    }
}

/// Metadata about agent execution including performance metrics and model information
public struct AgentMetadata: Sendable {
    /// Total execution time in seconds
    public let executionTime: TimeInterval

    /// Number of tool calls made during execution
    public let toolCallCount: Int

    /// Model name used for generation
    public let modelName: String

    /// Timestamp when execution started
    public let startTime: Date

    /// Timestamp when execution completed
    public let endTime: Date

    /// Additional context-specific metadata
    public let context: [String: String]

    public init(
        executionTime: TimeInterval,
        toolCallCount: Int,
        modelName: String,
        startTime: Date,
        endTime: Date,
        context: [String: String] = [:])
    {
        self.executionTime = executionTime
        self.toolCallCount = toolCallCount
        self.modelName = modelName
        self.startTime = startTime
        self.endTime = endTime
        self.context = context
    }
}

// MARK: - Session Management Types

/// Summary information about an agent session
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
public enum SessionStatus: String, Codable, Sendable {
    case active
    case completed
    case failed
    case expired
}

/// Complete agent session with full conversation history
public struct AgentSession: Sendable, Codable {
    /// Unique session identifier
    public let id: String

    /// Model name used in this session
    public let modelName: String

    /// Complete conversation history
    public let messages: [ModelMessage]

    /// Session metadata
    public let metadata: SessionMetadata

    /// When the session was created
    public let createdAt: Date

    /// When the session was last updated
    public let updatedAt: Date

    public init(
        id: String,
        modelName: String,
        messages: [ModelMessage],
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
public final class AgentSessionManager: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let sessionDirectory: URL
    private var sessionCache: [String: AgentSession] = [:]
    private let cacheQueue = DispatchQueue(label: "peekaboo.session.cache", attributes: .concurrent)

    /// Maximum number of sessions to keep in memory cache
    public static let maxCacheSize = 50

    /// Maximum age for sessions before they're considered expired
    public static let maxSessionAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days

    public init(sessionDirectory: URL? = nil) throws {
        if let sessionDirectory {
            self.sessionDirectory = sessionDirectory
        } else {
            // Default to ~/.peekaboo/sessions/
            let homeDir = self.fileManager.homeDirectoryForCurrentUser
            self.sessionDirectory = homeDir.appendingPathComponent(".peekaboo/sessions")
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
    public func loadSession(id: String) async throws -> AgentSession? {
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
    public func deleteSession(id: String) async throws {
        let sessionFile = self.sessionDirectory.appendingPathComponent("\(id).json")
        try self.fileManager.removeItem(at: sessionFile)

        // Remove from cache
        self.cacheQueue.async(flags: .barrier) {
            self.sessionCache.removeValue(forKey: id)
        }
    }

    /// Clean up expired sessions
    public func cleanupExpiredSessions() async throws {
        let sessions = self.listSessions()
        let expiredSessions = sessions.filter { self.isSessionExpired($0.lastAccessedAt) }

        for session in expiredSessions {
            try await self.deleteSession(id: session.id)
        }
    }

    // MARK: - Private Methods

    private func isSessionExpired(_ lastAccessed: Date) -> Bool {
        Date().timeIntervalSince(lastAccessed) > Self.maxSessionAge
    }

    private func generateSessionSummary(from messages: [ModelMessage]) -> String? {
        // Find the first user message to use as summary
        for message in messages {
            if message.role == .user {
                for contentPart in message.content {
                    if case let .text(text) = contentPart {
                        return String(text.prefix(100))
                    }
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

// MARK: - Legacy Agent System Compatibility Stubs


/// Legacy ModelParameters stub for compatibility
/// TODO: Replace with LanguageModel enum
public struct ModelParameters: Sendable {
    public let modelName: String
    public let temperature: Double?
    public let maxTokens: Int?
    private let additionalParams: [String: String] // Simplified to Sendable types

    public init(modelName: String, temperature: Double? = nil, maxTokens: Int? = nil) {
        self.modelName = modelName
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.additionalParams = [:]
    }

    private init(modelName: String, temperature: Double?, maxTokens: Int?, additionalParams: [String: String]) {
        self.modelName = modelName
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.additionalParams = additionalParams
    }

    public func with(_ key: String, value: Any) -> ModelParameters {
        var newParams = self.additionalParams
        // Convert Any to String for Sendable compliance
        if let stringValue = value as? String {
            newParams[key] = stringValue
        } else if let intValue = value as? Int {
            newParams[key] = String(intValue)
        } else {
            newParams[key] = String(describing: value)
        }
        return ModelParameters(
            modelName: self.modelName,
            temperature: self.temperature,
            maxTokens: self.maxTokens,
            additionalParams: newParams)
    }

    public func stringValue(_ key: String) -> String? {
        self.additionalParams[key] as? String
    }

    public var isEmpty: Bool {
        self.additionalParams.isEmpty && self.temperature == nil && self.maxTokens == nil
    }
}

/// Legacy AgentRunner stub for compatibility
/// TODO: Replace with direct generateText/streamText calls
public struct AgentRunner: Sendable {
    public init() {}

    public func execute(_ prompt: String, with parameters: ModelParameters) async throws -> String {
        // TODO: Replace with direct generateText call
        throw TachikomaError.unsupportedOperation("Legacy agent runner - use direct generateText calls")
    }
}
