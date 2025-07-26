import Foundation

// MARK: - Agent Runner

/// Executes agents with support for streaming, tool calling, and session persistence
public struct AgentRunner {
    
    // MARK: - Run Methods
    
    /// Run an agent with the given input
    /// - Parameters:
    ///   - agent: The agent to run
    ///   - input: The user input
    ///   - context: The context for tool execution
    ///   - model: The model to use (if nil, uses ModelProvider)
    ///   - sessionId: Optional session ID to resume a previous conversation
    /// - Returns: The result of the agent execution
    public static func run<Context>(
        agent: PeekabooAgent<Context>,
        input: String,
        context: Context,
        model: (any ModelInterface)? = nil,
        sessionId: String? = nil
    ) async throws -> AgentExecutionResult where Context: Sendable {
        let runner = AgentRunnerImpl(
            agent: agent,
            context: context,
            model: model
        )
        
        return try await runner.run(input: input, sessionId: sessionId)
    }
    
    /// Run an agent with streaming output
    /// - Parameters:
    ///   - agent: The agent to run
    ///   - input: The user input
    ///   - context: The context for tool execution
    ///   - model: The model to use (if nil, uses ModelProvider)
    ///   - sessionId: Optional session ID to resume a previous conversation
    ///   - streamHandler: Handler called for each text chunk
    /// - Returns: The final result of the agent execution
    public static func runStreaming<Context>(
        agent: PeekabooAgent<Context>,
        input: String,
        context: Context,
        model: (any ModelInterface)? = nil,
        sessionId: String? = nil,
        streamHandler: @Sendable @escaping (String) async -> Void
    ) async throws -> AgentExecutionResult where Context: Sendable {
        let runner = AgentRunnerImpl(
            agent: agent,
            context: context,
            model: model
        )
        
        return try await runner.runStreaming(
            input: input,
            sessionId: sessionId,
            streamHandler: streamHandler
        )
    }
}

// MARK: - Agent Result

/// Result of an agent execution
public struct AgentExecutionResult: Sendable {
    /// The final text output
    public let content: String
    
    /// All messages in the conversation
    public let messages: [any MessageItem]
    
    /// The session ID for resuming
    public let sessionId: String
    
    /// Usage statistics if available
    public let usage: Usage?
    
    /// Tool calls made during execution
    public let toolCalls: [ToolCallItem]
    
    /// Execution metadata
    public let metadata: AgentMetadata
}

/// Metadata about the agent execution
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
    
    /// Model used for execution
    public let modelName: String
    
    /// Whether this was a resumed session
    public let isResumed: Bool
}

// MARK: - Implementation

private actor AgentRunnerImpl<Context> where Context: Sendable {
    private let agent: PeekabooAgent<Context>
    private let context: Context
    private let model: any ModelInterface
    private let sessionManager: AgentSessionManager
    
    init(agent: PeekabooAgent<Context>, context: Context, model: (any ModelInterface)? = nil) {
        self.agent = agent
        self.context = context
        
        // Use provided model or get from provider
        if let model = model {
            self.model = model
        } else {
            // In a real implementation, this would use ModelProvider
            // For now, we'll create a default OpenAI model
            let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
            self.model = OpenAIModel(apiKey: apiKey)
        }
        
        self.sessionManager = AgentSessionManager()
    }
    
    // MARK: - Non-Streaming Run
    
    func run(input: String, sessionId: String? = nil) async throws -> AgentExecutionResult {
        let startTime = Date()
        
        // Load or create session
        let (messages, actualSessionId, isResumed) = try await prepareSession(
            input: input,
            sessionId: sessionId
        )
        
        // Create request
        let request = ModelRequest(
            messages: messages,
            tools: agent.toolDefinitions,
            settings: agent.modelSettings,
            systemInstructions: nil
        )
        
        // Get response
        let response = try await model.getResponse(request: request)
        
        // Process response
        let (finalMessages, toolCalls) = try await processResponse(
            response: response,
            messages: messages
        )
        
        // Save session
        try await sessionManager.saveSession(
            id: actualSessionId,
            messages: finalMessages,
            metadata: ["agent": agent.name, "lastActivity": Date()]
        )
        
        // Extract content
        let content = extractContent(from: response.content)
        
        return AgentExecutionResult(
            content: content,
            messages: finalMessages,
            sessionId: actualSessionId,
            usage: response.usage,
            toolCalls: toolCalls,
            metadata: AgentMetadata(
                startTime: startTime,
                endTime: Date(),
                toolCallCount: toolCalls.count,
                modelName: agent.modelSettings.modelName,
                isResumed: isResumed
            )
        )
    }
    
    // MARK: - Streaming Run
    
    func runStreaming(
        input: String,
        sessionId: String? = nil,
        streamHandler: @Sendable @escaping (String) async -> Void
    ) async throws -> AgentExecutionResult {
        let startTime = Date()
        
        // Load or create session
        let (messages, actualSessionId, isResumed) = try await prepareSession(
            input: input,
            sessionId: sessionId
        )
        
        // Create request
        let request = ModelRequest(
            messages: messages,
            tools: agent.toolDefinitions,
            settings: agent.modelSettings,
            systemInstructions: nil
        )
        
        // Get streaming response
        let eventStream = try await model.getStreamedResponse(request: request)
        
        // Process stream
        var responseContent = ""
        var responseId = ""
        var toolCalls: [ToolCallItem] = []
        var pendingToolCalls: [String: PartialToolCall] = [:]
        var usage: Usage?
        
        for try await event in eventStream {
            switch event {
            case .responseStarted(let started):
                responseId = started.id
                
            case .textDelta(let delta):
                responseContent += delta.delta
                await streamHandler(delta.delta)
                
            case .toolCallDelta(let delta):
                updatePartialToolCall(&pendingToolCalls, with: delta)
                
            case .toolCallCompleted(let completed):
                toolCalls.append(ToolCallItem(
                    id: completed.id,
                    type: .function,
                    function: completed.function
                ))
                
            case .responseCompleted(let completed):
                usage = completed.usage
                
            case .error(let error):
                throw ModelError.requestFailed(
                    NSError(domain: "AgentRunner", code: 0, userInfo: [
                        NSLocalizedDescriptionKey: error.error.message
                    ])
                )
                
            default:
                break
            }
        }
        
        // Handle tool calls if any
        var finalMessages = messages
        if !toolCalls.isEmpty {
            let toolResults = try await executeTools(toolCalls)
            
            // Add assistant message with tool calls
            finalMessages.append(AssistantMessageItem(
                id: responseId,
                content: responseContent.isEmpty ? [] : [.outputText(responseContent)],
                status: .completed
            ))
            
            // Add tool results
            for (toolCall, result) in zip(toolCalls, toolResults) {
                finalMessages.append(ToolMessageItem(
                    id: UUID().uuidString,
                    toolCallId: toolCall.id,
                    content: result
                ))
            }
            
            // Get final response after tools
            let followUpRequest = ModelRequest(
                messages: finalMessages,
                tools: agent.toolDefinitions,
                settings: agent.modelSettings
            )
            
            let followUpStream = try await model.getStreamedResponse(request: followUpRequest)
            
            for try await event in followUpStream {
                switch event {
                case .textDelta(let delta):
                    responseContent += delta.delta
                    await streamHandler(delta.delta)
                    
                case .responseCompleted(let completed):
                    if let completedUsage = completed.usage {
                        usage = completedUsage
                    }
                    
                default:
                    break
                }
            }
        }
        
        // Add final assistant message
        if !responseContent.isEmpty || !toolCalls.isEmpty {
            var content: [AssistantContent] = []
            if !responseContent.isEmpty {
                content.append(.outputText(responseContent))
            }
            for toolCall in toolCalls {
                content.append(.toolCall(toolCall))
            }
            
            finalMessages.append(AssistantMessageItem(
                id: responseId.isEmpty ? UUID().uuidString : responseId,
                content: content,
                status: .completed
            ))
        }
        
        // Save session
        try await sessionManager.saveSession(
            id: actualSessionId,
            messages: finalMessages,
            metadata: ["agent": agent.name, "lastActivity": Date()]
        )
        
        return AgentExecutionResult(
            content: responseContent,
            messages: finalMessages,
            sessionId: actualSessionId,
            usage: usage,
            toolCalls: toolCalls,
            metadata: AgentMetadata(
                startTime: startTime,
                endTime: Date(),
                toolCallCount: toolCalls.count,
                modelName: agent.modelSettings.modelName,
                isResumed: isResumed
            )
        )
    }
    
    // MARK: - Helper Methods
    
    private func prepareSession(
        input: String,
        sessionId: String?
    ) async throws -> (messages: [any MessageItem], sessionId: String, isResumed: Bool) {
        var messages: [any MessageItem] = []
        let actualSessionId: String
        let isResumed: Bool
        
        if let sessionId = sessionId,
           let session = try await sessionManager.loadSession(id: sessionId) {
            // Resume existing session
            messages = session.messages.map { $0.message }
            actualSessionId = sessionId
            isResumed = true
        } else {
            // Create new session
            messages.append(SystemMessageItem(
                id: UUID().uuidString,
                content: agent.generateSystemPrompt()
            ))
            actualSessionId = UUID().uuidString
            isResumed = false
        }
        
        // Add user message
        messages.append(UserMessageItem(
            id: UUID().uuidString,
            content: .text(input)
        ))
        
        return (messages, actualSessionId, isResumed)
    }
    
    private func processResponse(
        response: ModelResponse,
        messages: [any MessageItem]
    ) async throws -> (messages: [any MessageItem], toolCalls: [ToolCallItem]) {
        var updatedMessages = messages
        var toolCalls: [ToolCallItem] = []
        
        // Extract tool calls from response
        for content in response.content {
            if case .toolCall(let toolCall) = content {
                toolCalls.append(toolCall)
            }
        }
        
        // Add assistant message
        updatedMessages.append(AssistantMessageItem(
            id: response.id,
            content: response.content,
            status: .completed
        ))
        
        // Execute tools if any
        if !toolCalls.isEmpty {
            let toolResults = try await executeTools(toolCalls)
            
            // Add tool results as messages
            for (toolCall, result) in zip(toolCalls, toolResults) {
                updatedMessages.append(ToolMessageItem(
                    id: UUID().uuidString,
                    toolCallId: toolCall.id,
                    content: result
                ))
            }
            
            // Get follow-up response
            let followUpRequest = ModelRequest(
                messages: updatedMessages,
                tools: agent.toolDefinitions,
                settings: agent.modelSettings
            )
            
            let followUpResponse = try await model.getResponse(request: followUpRequest)
            
            // Add follow-up assistant message
            updatedMessages.append(AssistantMessageItem(
                id: followUpResponse.id,
                content: followUpResponse.content,
                status: .completed
            ))
        }
        
        return (updatedMessages, toolCalls)
    }
    
    private func executeTools(_ toolCalls: [ToolCallItem]) async throws -> [String] {
        var results: [String] = []
        
        for toolCall in toolCalls {
            guard let tool = agent.tool(named: toolCall.function.name) else {
                throw ToolError.toolNotFound(toolCall.function.name)
            }
            
            let input = try ToolInput(jsonString: toolCall.function.arguments)
            let output = try await tool.execute(input, context)
            let resultString = try output.toJSONString()
            
            results.append(resultString)
        }
        
        return results
    }
    
    private func extractContent(from content: [AssistantContent]) -> String {
        var text = ""
        
        for item in content {
            if case .outputText(let output) = item {
                text += output
            }
        }
        
        return text
    }
    
    private func updatePartialToolCall(
        _ partialCalls: inout [String: PartialToolCall],
        with delta: StreamToolCallDelta
    ) {
        if let existing = partialCalls[delta.id] {
            existing.update(with: delta)
        } else {
            partialCalls[delta.id] = PartialToolCall(from: delta)
        }
    }
}

// MARK: - Partial Tool Call Helper

private class PartialToolCall {
    var id: String
    var name: String?
    var arguments: String = ""
    
    init(from delta: StreamToolCallDelta) {
        self.id = delta.id
        self.name = delta.function.name
        self.arguments = delta.function.arguments ?? ""
    }
    
    func update(with delta: StreamToolCallDelta) {
        if let funcName = delta.function.name {
            self.name = funcName
        }
        if let args = delta.function.arguments {
            self.arguments += args
        }
    }
}