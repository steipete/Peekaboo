import Foundation

/// Result of agent task execution containing response content, metadata, and tool usage information
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AgentExecutionResult: Sendable {
    /// The generated response content from the AI model
    public let content: String
    
    /// Complete conversation messages including tool calls and responses
    public let messages: [Message]
    
    /// Session identifier for tracking conversation state
    public let sessionId: String?
    
    /// Token usage statistics from the AI provider
    public let usage: Usage?
    
    /// List of tool calls executed during the task
    public let toolCalls: [ToolCallItem]
    
    /// Additional metadata about the execution
    public let metadata: AgentMetadata
    
    public init(
        content: String,
        messages: [Message] = [],
        sessionId: String? = nil,
        usage: Usage? = nil,
        toolCalls: [ToolCallItem] = [],
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

/// Metadata about agent execution including performance metrics and model information
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
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
        context: [String: String] = [:]
    ) {
        self.executionTime = executionTime
        self.toolCallCount = toolCallCount
        self.modelName = modelName
        self.startTime = startTime
        self.endTime = endTime
        self.context = context
    }
}

/// Token usage statistics from AI provider APIs
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct Usage: Codable, Sendable {
    /// Number of tokens in the input/prompt
    public let promptTokens: Int?
    
    /// Number of tokens in the generated response
    public let completionTokens: Int?
    
    /// Total tokens used (prompt + completion)
    public let totalTokens: Int?
    
    /// Cost information if available
    public let cost: Double?
    
    public init(
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        totalTokens: Int? = nil,
        cost: Double? = nil
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.cost = cost
    }
}

/// Real-time event from agent execution for streaming updates
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum AgentEvent: Sendable {
    /// Agent started processing the task
    case taskStarted(task: String)
    
    /// Agent is thinking/planning the next step
    case thinking(message: String)
    
    /// Agent is about to execute a tool
    case toolCallStarted(toolName: String, parameters: [String: Any])
    
    /// Tool execution completed successfully
    case toolCallCompleted(toolName: String, result: String)
    
    /// Tool execution failed
    case toolCallFailed(toolName: String, error: String)
    
    /// Agent generated partial response content
    case responseChunk(content: String)
    
    /// Agent completed the entire task
    case taskCompleted(result: AgentExecutionResult)
    
    /// Agent encountered an error
    case error(message: String)
}

/// Delegate protocol for receiving real-time agent execution events
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public protocol AgentEventDelegate: Sendable {
    /// Called when an agent event occurs during execution
    func agentDidEmitEvent(_ event: AgentEvent) async
}

/// Audio content for multimodal agent tasks
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AudioContent: Sendable {
    /// Audio data in supported format (e.g., WAV, MP3)
    public let data: Data
    
    /// MIME type of the audio (e.g., "audio/wav", "audio/mpeg")
    public let mimeType: String
    
    /// Optional transcription if already available
    public let transcription: String?
    
    public init(data: Data, mimeType: String, transcription: String? = nil) {
        self.data = data
        self.mimeType = mimeType
        self.transcription = transcription
    }
}