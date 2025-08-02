import Foundation

// MARK: - Agent Session Types

/// Agent session information
public struct AgentSession: Codable, Sendable {
    public let id: String
    public let createdAt: Date
    public let lastUpdated: Date
    public let messages: [Message]
    public let context: [String: String]
    
    public init(id: String, createdAt: Date = Date(), lastUpdated: Date = Date(), messages: [Message] = [], context: [String: String] = [:]) {
        self.id = id
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.messages = messages
        self.context = context
    }
}

/// Manager for agent sessions
@MainActor
public final class AgentSessionManager: Sendable {
    private var sessions: [String: AgentSession] = [:]
    
    public init() {}
    
    public func createSession() -> String {
        let sessionId = UUID().uuidString
        sessions[sessionId] = AgentSession(id: sessionId)
        return sessionId
    }
    
    public func getSession(id: String) -> AgentSession? {
        sessions[id]
    }
    
    public func updateSession(id: String, with session: AgentSession) {
        sessions[id] = session
    }
    
    public func deleteSession(id: String) {
        sessions.removeValue(forKey: id)
    }
    
    public func listSessions() -> [AgentSession] {
        Array(sessions.values)
    }
    
    public func cleanOldSessions(olderThan date: Date = Date().addingTimeInterval(-7 * 24 * 60 * 60)) {
        sessions = sessions.filter { _, session in
            session.lastUpdated > date
        }
    }
    
    public func loadSession(id: String) async -> AgentSession? {
        getSession(id: id)
    }
    
    public func deleteSession(id: String) async {
        sessions.removeValue(forKey: id)
    }
    
    public func clearAllSessions() async {
        sessions.removeAll()
    }
}

/// The main agent type
public struct PeekabooAgent<Services> {
    public let model: any ModelInterface
    public let sessionId: String
    public let services: Services
    
    public init(model: any ModelInterface, sessionId: String, services: Services) {
        self.model = model
        self.sessionId = sessionId
        self.services = services
    }
}

// MARK: - Usage Statistics

/// Usage statistics from AI model
public struct Usage: Codable, Sendable {
    public let promptTokens: Int?
    public let completionTokens: Int?
    public let totalTokens: Int?
    
    public init(promptTokens: Int? = nil, completionTokens: Int? = nil, totalTokens: Int? = nil) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}

// MARK: - Agent Metadata

/// Metadata about an agent execution
public struct AgentMetadata: Sendable {
    public let startTime: Date
    public let endTime: Date
    public let toolCallCount: Int
    public let modelName: String
    public let isResumed: Bool
    public let maskedApiKey: String?
    
    public init(
        startTime: Date,
        endTime: Date,
        toolCallCount: Int,
        modelName: String,
        isResumed: Bool,
        maskedApiKey: String? = nil
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.toolCallCount = toolCallCount
        self.modelName = modelName
        self.isResumed = isResumed
        self.maskedApiKey = maskedApiKey
    }
}

// MARK: - Agent Execution Result

/// Result of agent task execution
public struct AgentExecutionResult: Sendable {
    /// The content/response from the agent
    public let content: String
    
    /// Messages exchanged during execution
    public let messages: [Message]
    
    /// Session ID if applicable
    public let sessionId: String?
    
    /// Usage statistics if available
    public let usage: Usage?
    
    
    /// Metadata about the execution
    public let metadata: AgentMetadata
    
    public init(
        content: String,
        messages: [Message] = [],
        sessionId: String? = nil,
        usage: Usage? = nil,
        metadata: AgentMetadata
    ) {
        self.content = content
        self.messages = messages
        self.sessionId = sessionId
        self.usage = usage
        self.metadata = metadata
    }
}

// MARK: - Session Summary

/// Summary of a conversation session
public struct SessionSummary: Codable, Sendable {
    public let id: String
    public let title: String
    public let createdAt: Date
    public let lastModified: Date
    public let messageCount: Int
    
    public init(
        id: String,
        title: String,
        createdAt: Date,
        lastModified: Date,
        messageCount: Int
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.messageCount = messageCount
    }
}

// MARK: - Agent Configuration

/// Configuration constants for agent behavior
public enum AgentConfiguration {
    /// Prefix for o3 models
    public static let o3ModelPrefix = "o3"
    
    /// Default max tokens for responses
    public static let defaultMaxTokens = 4096
    
    /// Max tokens for o3 models
    public static let o3MaxTokens = 100000
    
    /// Max completion tokens for o3 models
    public static let o3MaxCompletionTokens = 100000
    
    /// Reasoning effort for o3 models
    public static let o3ReasoningEffort = "medium"
}

// MARK: - Agent Runner

/// Agent runner for executing agent tasks
public enum AgentRunner {
    /// Run an agent task with streaming
    public static func runStreaming<Services>(
        agent: PeekabooAgent<Services>,
        input: String,
        context: Services,
        sessionId: String,
        streamHandler: @escaping (String) async -> Void
    ) async throws -> AgentExecutionResult {
        // Implementation would go here
        fatalError("AgentRunner.runStreaming not yet implemented")
    }
    
    /// Run an agent task without streaming
    public static func run<Services>(
        agent: PeekabooAgent<Services>,
        input: String,
        context: Services,
        sessionId: String
    ) async throws -> AgentExecutionResult {
        // Implementation would go here
        fatalError("AgentRunner.run not yet implemented")
    }
}

// MARK: - Audio Content

/// Audio content for agent processing
public struct AudioContent: Codable, Sendable {
    /// Base64 encoded audio data
    public let base64: String
    
    /// MIME type of the audio (e.g., "audio/mp3", "audio/wav")
    public let mimeType: String
    
    /// Optional transcript of the audio
    public let transcript: String?
    
    /// Duration in seconds
    public let duration: TimeInterval?
    
    public init(
        base64: String,
        mimeType: String,
        transcript: String? = nil,
        duration: TimeInterval? = nil
    ) {
        self.base64 = base64
        self.mimeType = mimeType
        self.transcript = transcript
        self.duration = duration
    }
}