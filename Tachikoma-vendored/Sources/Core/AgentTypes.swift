import Foundation

// MARK: - Agent Execution Result

/// The result of an agent execution containing output and metadata
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AgentExecutionResult: Sendable {
    /// The final text output
    public let content: String
    
    /// All messages in the conversation
    public let messages: [Message]
    
    /// The session ID for resuming
    public let sessionId: String
    
    /// Token usage information
    public let usage: Usage?
    
    /// Tool calls made during execution
    public let toolCalls: [ToolCallItem]
    
    /// Execution metadata
    public let metadata: AgentMetadata
    
    public init(
        content: String,
        messages: [Message],
        sessionId: String,
        usage: Usage?,
        toolCalls: [ToolCallItem],
        metadata: AgentMetadata
    ) {
        self.content = content
        self.messages = messages
        self.sessionId = sessionId
        self.usage = usage
        self.toolCalls = toolCalls
        self.metadata = metadata
    }
}

// MARK: - Agent Metadata

/// Metadata about agent execution
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AgentMetadata: Sendable {
    /// When the execution started
    public let startTime: Date
    
    /// When the execution completed
    public let endTime: Date
    
    /// Total execution duration
    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    /// Number of tool calls made
    public let toolCallCount: Int
    
    /// Name of the model used
    public let modelName: String
    
    /// Whether this was a resumed session
    public let isResumed: Bool
    
    /// Masked API key for security
    public let maskedApiKey: String?
    
    public init(
        startTime: Date,
        endTime: Date,
        toolCallCount: Int,
        modelName: String,
        isResumed: Bool,
        maskedApiKey: String?
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.toolCallCount = toolCallCount
        self.modelName = modelName
        self.isResumed = isResumed
        self.maskedApiKey = maskedApiKey
    }
}

// Note: Usage and ToolCallItem types are already defined in StreamingTypes.swift and MessageTypes.swift

// MARK: - Agent Events

/// Events emitted during agent execution
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum AgentEvent: Sendable {
    case textDelta(String)
    case toolCallStarted(name: String, arguments: String)
    case toolCallCompleted(name: String, result: String)
    case error(message: String)
    case completed(summary: String, usage: Usage?)
}

// MARK: - Agent Event Delegate

/// Protocol for receiving real-time agent events
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public protocol AgentEventDelegate: Sendable {
    func didReceiveEvent(_ event: AgentEvent) async
}

// MARK: - Tool Execution Event

/// Events related to tool execution during agent runs
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ToolExecutionEvent: Sendable {
    case toolStarted(name: String, arguments: String)
    case toolProgress(name: String, progress: String)
    case toolCompleted(name: String, result: String)
    case toolFailed(name: String, error: String)
}