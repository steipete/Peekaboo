import Foundation

/// Configuration settings for agent execution
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AgentConfiguration {
    /// Default reasoning effort level for O3 models
    public static let o3ReasoningEffort = "medium"
    
    /// Default maximum completion tokens for O3 models
    public static let o3MaxCompletionTokens = 8192
    
    /// Default model name for agent operations
    public static let defaultModelName = "claude-opus-4-20250514"
    
    /// Default maximum execution time in seconds
    public static let defaultMaxExecutionTime: TimeInterval = 300
    
    /// Default maximum number of tool calls per session
    public static let defaultMaxToolCalls = 50
}

/// Generic AI agent that can execute tools within a specific context
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class PeekabooAgent<Context>: @unchecked Sendable {
    /// Agent's unique identifier
    public let name: String
    
    /// System instructions for the agent
    public let instructions: String
    
    /// Available tools for the agent
    public private(set) var tools: [AITool<Context>]
    
    /// Model settings for generation
    public var modelSettings: ModelSettings
    
    /// The context instance passed to tool executions
    private let context: Context
    
    public init(
        name: String,
        instructions: String,
        tools: [AITool<Context>] = [],
        modelSettings: ModelSettings,
        context: Context
    ) {
        self.name = name
        self.instructions = instructions
        self.tools = tools
        self.modelSettings = modelSettings
        self.context = context
    }
    
    /// Add a tool to the agent
    public func addTool(_ tool: AITool<Context>) {
        tools.append(tool)
    }
    
    /// Remove a tool by name
    public func removeTool(named name: String) {
        tools.removeAll { $0.name == name }
    }
    
    /// Execute a task using the agent
    public func executeTask(
        _ input: String,
        model: any ModelInterface,
        eventDelegate: AgentEventDelegate? = nil
    ) async throws -> AgentExecutionResult {
        let startTime = Date()
        await eventDelegate?.agentDidEmitEvent(.taskStarted(task: input))
        
        // Convert tools to tool definitions
        let toolDefinitions = tools.map { $0.toToolDefinition() }
        
        // Create the request
        let request = ModelRequest(
            messages: [
                .system(content: instructions),
                .user(content: .text(input))
            ],
            tools: toolDefinitions,
            modelSettings: modelSettings
        )
        
        // Execute the model request
        let response = try await model.getResponse(request: request)
        
        // Process tool calls if any
        var allToolCalls: [ToolCallItem] = []
        var finalContent = ""
        
        for message in response.messages {
            if case let .assistant(_, content, _) = message {
                for item in content {
                    if case let .text(text) = item {
                        finalContent += text
                    } else if case let .toolCall(toolCall) = item {
                        allToolCalls.append(toolCall)
                        
                        // Find and execute the tool
                        if let tool = tools.first(where: { $0.name == toolCall.function.name }) {
                            await eventDelegate?.agentDidEmitEvent(.toolCallStarted(
                                toolName: toolCall.function.name,
                                parameters: [:]  // Simplified for now
                            ))
                            
                            do {
                                let toolInput = try ToolInput(jsonString: toolCall.function.arguments)
                                let result = try await tool.execute(toolInput, context)
                                
                                await eventDelegate?.agentDidEmitEvent(.toolCallCompleted(
                                    toolName: toolCall.function.name,
                                    result: result.description
                                ))
                            } catch {
                                await eventDelegate?.agentDidEmitEvent(.toolCallFailed(
                                    toolName: toolCall.function.name,
                                    error: error.localizedDescription
                                ))
                            }
                        }
                    }
                }
            }
        }
        
        let endTime = Date()
        let metadata = AgentMetadata(
            executionTime: endTime.timeIntervalSince(startTime),
            toolCallCount: allToolCalls.count,
            modelName: modelSettings.modelName ?? "unknown",
            startTime: startTime,
            endTime: endTime
        )
        
        let result = AgentExecutionResult(
            content: finalContent,
            messages: response.messages,
            sessionId: nil,
            usage: response.usage,
            toolCalls: allToolCalls,
            metadata: metadata
        )
        
        await eventDelegate?.agentDidEmitEvent(.taskCompleted(result: result))
        return result
    }
}

/// Utility class for running agent operations
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AgentRunner {
    /// Run an agent with streaming support
    public static func runStreaming<Context>(
        agent: PeekabooAgent<Context>,
        input: String,
        model: any ModelInterface,
        eventDelegate: AgentEventDelegate? = nil
    ) async throws -> AgentExecutionResult {
        return try await agent.executeTask(input, model: model, eventDelegate: eventDelegate)
    }
    
    /// Run an agent without streaming
    public static func run<Context>(
        agent: PeekabooAgent<Context>,
        input: String,
        model: any ModelInterface
    ) async throws -> AgentExecutionResult {
        return try await agent.executeTask(input, model: model, eventDelegate: nil)
    }
}

/// Session manager for persistent agent conversations
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class AgentSessionManager: @unchecked Sendable {
    private var sessions: [String: [Message]] = [:]
    
    public init() {}
    
    /// Create a new session
    public func createSession() -> String {
        let sessionId = UUID().uuidString
        sessions[sessionId] = []
        return sessionId
    }
    
    /// Add message to session
    public func addMessage(_ message: Message, to sessionId: String) {
        sessions[sessionId, default: []].append(message)
    }
    
    /// Get messages for session
    public func getMessages(for sessionId: String) -> [Message] {
        return sessions[sessionId] ?? []
    }
    
    /// Clear session
    public func clearSession(_ sessionId: String) {
        sessions.removeValue(forKey: sessionId)
    }
    
    /// List all session IDs
    public func listSessions() -> [String] {
        return Array(sessions.keys)
    }
}