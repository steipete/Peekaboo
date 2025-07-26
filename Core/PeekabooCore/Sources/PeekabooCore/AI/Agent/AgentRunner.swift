import Foundation

// Simple debug logging check
fileprivate var isDebugLoggingEnabled: Bool {
    // Check if verbose mode is enabled via log level
    if let logLevel = ProcessInfo.processInfo.environment["PEEKABOO_LOG_LEVEL"]?.lowercased() {
        return logLevel == "debug" || logLevel == "trace"
    }
    // Check if agent is in verbose mode
    if ProcessInfo.processInfo.arguments.contains("-v") || 
       ProcessInfo.processInfo.arguments.contains("--verbose") {
        return true
    }
    return false
}

fileprivate func aiDebugPrint(_ message: String) {
    if isDebugLoggingEnabled {
        print(message)
    }
}

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
    ///   - eventHandler: Optional handler for tool execution events
    /// - Returns: The final result of the agent execution
    public static func runStreaming<Context>(
        agent: PeekabooAgent<Context>,
        input: String,
        context: Context,
        model: (any ModelInterface)? = nil,
        sessionId: String? = nil,
        streamHandler: @Sendable @escaping (String) async -> Void,
        eventHandler: (@Sendable (ToolExecutionEvent) async -> Void)? = nil,
        reasoningHandler: (@Sendable (String) async -> Void)? = nil
    ) async throws -> AgentExecutionResult where Context: Sendable {
        let runner = AgentRunnerImpl(
            agent: agent,
            context: context,
            model: model
        )
        
        return try await runner.runStreaming(
            input: input,
            sessionId: sessionId,
            streamHandler: streamHandler,
            eventHandler: eventHandler,
            reasoningHandler: reasoningHandler
        )
    }
}

// MARK: - Tool Execution Event

/// Event emitted during tool execution
public enum ToolExecutionEvent: Sendable {
    case started(name: String, arguments: String)
    case completed(name: String, result: String)
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
    
    /// Masked API key for verification
    public let maskedApiKey: String?
}

// MARK: - Implementation

private actor AgentRunnerImpl<Context> where Context: Sendable {
    private let agent: PeekabooAgent<Context>
    private let context: Context
    private var model: (any ModelInterface)?
    private let sessionManager: AgentSessionManager
    private let lifecycleManager: LifecycleManager
    
    init(agent: PeekabooAgent<Context>, context: Context, model: (any ModelInterface)? = nil) {
        self.agent = agent
        self.context = context
        self.model = model
        self.sessionManager = AgentSessionManager()
        self.lifecycleManager = LifecycleManager()
        
        // Add default console handler if debug logging is enabled
        if isDebugLoggingEnabled {
            Task {
                await lifecycleManager.addHandler(ConsoleLifecycleHandler(verbose: true))
            }
        }
    }
    
    /// Get or create the model instance
    private func getModel() async throws -> any ModelInterface {
        if let model = self.model {
            return model
        }
        
        // Try to get model from ModelProvider
        let modelName = agent.modelSettings.modelName
        do {
            let model = try await ModelProvider.shared.getModel(modelName: modelName)
            self.model = model
            return model
        } catch {
            // Continue to fallback
        }
        
        // Fallback for unregistered models
        if modelName.contains("claude") {
            guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
                throw ModelError.authenticationFailed
            }
            let model = AnthropicModel(apiKey: apiKey, modelName: modelName)
            self.model = model
            return model
        } else {
            guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
                throw ModelError.authenticationFailed
            }
            let model = OpenAIModel(apiKey: apiKey)
            self.model = model
            return model
        }
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
        let currentModel = try await getModel()
        let response = try await currentModel.getResponse(request: request)
        
        // Process response
        let (finalMessages, toolCalls) = try await processResponse(
            response: response,
            messages: messages
        )
        
        // Save session
        try await sessionManager.saveSession(
            id: actualSessionId,
            messages: finalMessages,
            metadata: ["agent": agent.name, "lastActivity": ISO8601DateFormatter().string(from: Date())]
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
                isResumed: isResumed,
                maskedApiKey: currentModel.maskedApiKey
            )
        )
    }
    
    // MARK: - Streaming Run
    
    func runStreaming(
        input: String,
        sessionId: String? = nil,
        streamHandler: @Sendable @escaping (String) async -> Void,
        eventHandler: (@Sendable (ToolExecutionEvent) async -> Void)? = nil,
        reasoningHandler: (@Sendable (String) async -> Void)? = nil
    ) async throws -> AgentExecutionResult {
        let startTime = Date()
        
        // Emit agent started event
        await lifecycleManager.emit(.agentStarted(agent: agent.name, context: input))
        
        // Load or create session
        let (initialMessages, actualSessionId, isResumed) = try await prepareSession(
            input: input,
            sessionId: sessionId
        )
        
        // Process messages recursively until no more tool calls
        let (finalMessages, allToolCalls, responseContent, usage) = try await processMessagesRecursively(
            messages: initialMessages,
            streamHandler: streamHandler,
            eventHandler: eventHandler,
            reasoningHandler: reasoningHandler
        )
        
        // Save session
        try await sessionManager.saveSession(
            id: actualSessionId,
            messages: finalMessages,
            metadata: ["agent": agent.name, "lastActivity": ISO8601DateFormatter().string(from: Date())]
        )
        
        let currentModel = try await getModel()
        let result = AgentExecutionResult(
            content: responseContent,
            messages: finalMessages,
            sessionId: actualSessionId,
            usage: usage,
            toolCalls: allToolCalls,
            metadata: AgentMetadata(
                startTime: startTime,
                endTime: Date(),
                toolCallCount: allToolCalls.count,
                modelName: agent.modelSettings.modelName,
                isResumed: isResumed,
                maskedApiKey: currentModel.maskedApiKey
            )
        )
        
        // Emit agent ended event
        await lifecycleManager.emit(.agentEnded(agent: agent.name, output: responseContent))
        
        return result
    }
    
    // Recursive helper to process messages until no more tool calls
    private func processMessagesRecursively(
        messages: [any MessageItem],
        streamHandler: @Sendable @escaping (String) async -> Void,
        eventHandler: (@Sendable (ToolExecutionEvent) async -> Void)? = nil,
        reasoningHandler: (@Sendable (String) async -> Void)? = nil
    ) async throws -> (messages: [any MessageItem], toolCalls: [ToolCallItem], content: String, usage: Usage?) {
        var currentMessages = messages
        var allToolCalls: [ToolCallItem] = []
        var allContent = ""
        var totalUsage: Usage?
        
        // Maximum iterations to prevent infinite loops
        let maxIterations = AgentConfiguration.maxIterations
        var iteration = 0
        
        // Track repeated tool calls to prevent infinite loops
        var previousToolCallSignatures: [String] = []
        var repetitionCount = 0
        
        while iteration < maxIterations {
            iteration += 1
            aiDebugPrint("DEBUG: Processing iteration \(iteration)")
            
            // Emit iteration started event
            await lifecycleManager.emit(.iterationStarted(number: iteration))
            
            // Create request
            let request = ModelRequest(
                messages: currentMessages,
                tools: agent.toolDefinitions,
                settings: agent.modelSettings,
                systemInstructions: nil
            )
            
            // Get streaming response
            let currentModel = try await getModel()
            let eventStream = try await currentModel.getStreamedResponse(request: request)
            
            // Process stream
            var responseContent = ""
            var responseId = ""
            var toolCalls: [ToolCallItem] = []
            var pendingToolCalls: [String: PartialToolCall] = [:]
            var usage: Usage?
            var reasoningSummary = ""
            
            for try await event in eventStream {
                aiDebugPrint("DEBUG: Received stream event: \(event)")
                switch event {
                case .responseStarted(let started):
                    responseId = started.id
                    aiDebugPrint("DEBUG: Response started with ID: \(responseId)")
                    
                case .textDelta(let delta):
                    responseContent += delta.delta
                    allContent += delta.delta
                    await streamHandler(delta.delta)
                    aiDebugPrint("DEBUG: Text delta received: '\(delta.delta)'")
                    
                case .toolCallDelta(let delta):
                    updatePartialToolCall(&pendingToolCalls, with: delta)
                    aiDebugPrint("DEBUG: Tool call delta: id=\(delta.id), name=\(delta.function.name ?? "nil"), args=\(delta.function.arguments ?? "nil")")
                    
                case .toolCallCompleted(let completed):
                    // Don't use the completed event's function - use our accumulated one
                    if let pendingCall = pendingToolCalls[completed.id] {
                        aiDebugPrint("DEBUG: Tool call completed: \(completed.id), function: \(pendingCall.name ?? "?"), args: \(pendingCall.arguments)")
                        if let name = pendingCall.name {
                            toolCalls.append(ToolCallItem(
                                id: completed.id,
                                type: .function,
                                function: FunctionCall(name: name, arguments: pendingCall.arguments)
                            ))
                        }
                    } else {
                        aiDebugPrint("DEBUG: Tool call completed but no pending call found: \(completed.id)")
                    }
                case .functionCallArgumentsDelta(let delta):
                    updatePartialToolCall(&pendingToolCalls, with: delta)
                    aiDebugPrint("DEBUG: Function call arguments delta: id=\(delta.id), args=\(delta.arguments)")

                case .reasoningSummaryDelta(let delta):
                    reasoningSummary += delta.delta
                    // Send reasoning deltas to the reasoning handler if available
                    if let reasoningHandler = reasoningHandler {
                        await reasoningHandler(delta.delta)
                    }
                    aiDebugPrint("DEBUG: Reasoning summary delta: '\(delta.delta)'")
                    
                case .reasoningSummaryCompleted(let completed):
                    reasoningSummary = completed.summary
                    aiDebugPrint("DEBUG: Reasoning summary completed: \(completed.summary)")
                    // Don't send completed summary - we already streamed the deltas
                    
                case .responseCompleted(let completed):
                    usage = completed.usage
                    totalUsage = usage
                    
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
            
            // Add assistant message if there's content or tool calls
            var assistantContent: [AssistantContent] = []
            if !responseContent.isEmpty {
                assistantContent.append(.outputText(responseContent))
            }
            for toolCall in toolCalls {
                assistantContent.append(.toolCall(toolCall))
            }
            
            // Only add message if we have some content
            if !assistantContent.isEmpty {
                currentMessages.append(AssistantMessageItem(
                    id: responseId.isEmpty ? UUID().uuidString : responseId,
                    content: assistantContent,
                    status: .completed
                ))
            }
            
            // Check if we should continue
            if toolCalls.isEmpty {
                // No tool calls, we're done
                break
            }
            
            // NEW: Detect repeated tool patterns
            let currentToolSignatures = toolCalls.map { "\($0.function.name):\($0.function.arguments)" }
            if currentToolSignatures == previousToolCallSignatures {
                repetitionCount += 1
                aiDebugPrint("DEBUG: Detected repeated tool calls (count: \(repetitionCount))")
                
                if repetitionCount >= 2 {
                    aiDebugPrint("WARNING: Breaking loop - same tools called 3+ times")
                    // Execute final tools and break
                    let toolResults = try await executeTools(toolCalls, eventHandler: eventHandler)
                    for (toolCall, result) in zip(toolCalls, toolResults) {
                        currentMessages.append(ToolMessageItem(
                            id: UUID().uuidString,
                            toolCallId: toolCall.id,
                            content: result
                        ))
                    }
                    allToolCalls.append(contentsOf: toolCalls)
                    break
                }
            } else {
                // Reset counter if different tools
                previousToolCallSignatures = currentToolSignatures
                repetitionCount = 0
            }
            
            // Check if task_completed tool was called
            let hasCompletionTool = toolCalls.contains { toolCall in
                toolCall.function.name == "task_completed"
            }
            
            if hasCompletionTool {
                // Execute the completion tool to get the summary
                let toolResults = try await executeTools(toolCalls, eventHandler: eventHandler)
                
                // Add tool results
                for (toolCall, result) in zip(toolCalls, toolResults) {
                    currentMessages.append(ToolMessageItem(
                        id: UUID().uuidString,
                        toolCallId: toolCall.id,
                        content: result
                    ))
                }
                
                allToolCalls.append(contentsOf: toolCalls)
                aiDebugPrint("DEBUG: Task completed via task_completed tool")
                break
            }
            
            // Legacy: Check if task is complete despite having tool calls
            if !responseContent.isEmpty && isTaskComplete(
                content: responseContent,
                toolCalls: toolCalls,
                iteration: iteration,
                allContent: allContent
            ) {
                // Execute remaining tools but then finish
                let toolResults = try await executeTools(toolCalls, eventHandler: eventHandler)
                
                // Add tool results
                for (toolCall, result) in zip(toolCalls, toolResults) {
                    currentMessages.append(ToolMessageItem(
                        id: UUID().uuidString,
                        toolCallId: toolCall.id,
                        content: result
                    ))
                }
                
                allToolCalls.append(contentsOf: toolCalls)
                aiDebugPrint("DEBUG: Task complete with mixed content and tools (legacy detection)")
                break
            }
            
            // Execute tools
            let toolResults = try await executeTools(toolCalls, eventHandler: eventHandler)
            
            // Add tool results
            for (toolCall, result) in zip(toolCalls, toolResults) {
                currentMessages.append(ToolMessageItem(
                    id: UUID().uuidString,
                    toolCallId: toolCall.id,
                    content: result
                ))
            }
            
            // Add tool calls to our collection
            allToolCalls.append(contentsOf: toolCalls)
            
            // Continue to next iteration
        }
        
        if iteration >= maxIterations {
            aiDebugPrint("WARNING: Reached maximum iterations (\(maxIterations)) in recursive processing")
            
            // If we have no meaningful content after many iterations, force a text-only response
            if allContent.isEmpty || allContent.count < 50 {
                aiDebugPrint("DEBUG: Forcing text-only response after \(iteration) iterations with no meaningful content")
                
                // Create a text-only request
                let textOnlyRequest = ModelRequest(
                    messages: currentMessages,
                    tools: nil, // No tools to force text response
                    settings: ModelSettings(
                        modelName: agent.modelSettings.modelName,
                        temperature: agent.modelSettings.temperature,
                        maxTokens: agent.modelSettings.maxTokens,
                        toolChoice: ToolChoice.none
                    ),
                    systemInstructions: nil
                )
                
                // Get text-only response
                let currentModel = try await getModel()
                let eventStream = try await currentModel.getStreamedResponse(request: textOnlyRequest)
                
                var finalContent = ""
                for try await event in eventStream {
                    switch event {
                    case .textDelta(let delta):
                        finalContent += delta.delta
                        allContent += delta.delta
                        await streamHandler(delta.delta)
                    case .responseCompleted(let completed):
                        if let usage = completed.usage {
                            totalUsage = usage
                        }
                    default:
                        break
                    }
                }
                
                // Add final message
                if !finalContent.isEmpty {
                    currentMessages.append(AssistantMessageItem(
                        id: UUID().uuidString,
                        content: [.outputText(finalContent)],
                        status: .completed
                    ))
                }
            }
        }
        
        return (currentMessages, allToolCalls, allContent, totalUsage)
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
            aiDebugPrint("DEBUG: Resuming session \(sessionId) with \(messages.count) messages")
        } else {
            // Create new session
            messages.append(SystemMessageItem(
                id: UUID().uuidString,
                content: agent.generateSystemPrompt()
            ))
            actualSessionId = UUID().uuidString
            isResumed = false
            aiDebugPrint("DEBUG: Creating new session \(actualSessionId)")
        }
        
        // Add user message
        messages.append(UserMessageItem(
            id: UUID().uuidString,
            content: .text(input)
        ))
        
        aiDebugPrint("DEBUG: Session prepared with \(messages.count) total messages")
        for (index, msg) in messages.enumerated() {
            aiDebugPrint("DEBUG: Message[\(index)]: \(msg.type)")
        }
        
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
            
            let currentModel = try await getModel()
            let followUpResponse = try await currentModel.getResponse(request: followUpRequest)
            
            // Add follow-up assistant message
            updatedMessages.append(AssistantMessageItem(
                id: followUpResponse.id,
                content: followUpResponse.content,
                status: .completed
            ))
        }
        
        return (updatedMessages, toolCalls)
    }
    
    private func executeTools(_ toolCalls: [ToolCallItem], eventHandler: (@Sendable (ToolExecutionEvent) async -> Void)? = nil) async throws -> [String] {
        var results: [String] = []
        
        for toolCall in toolCalls {
            aiDebugPrint("DEBUG: Executing tool: \(toolCall.function.name)")
            aiDebugPrint("DEBUG: Tool arguments: \(toolCall.function.arguments)")
            
            // Emit tool start events
            if let handler = eventHandler {
                await handler(.started(name: toolCall.function.name, arguments: toolCall.function.arguments))
            }
            await lifecycleManager.emit(.toolStarted(name: toolCall.function.name, arguments: toolCall.function.arguments))
            
            guard let tool = agent.tool(named: toolCall.function.name) else {
                throw ToolError.toolNotFound(toolCall.function.name)
            }
            
            do {
                let input = try ToolInput(jsonString: toolCall.function.arguments)
                let output = try await tool.execute(input, context)
                let resultString = try output.toJSONString()
                
                results.append(resultString)
                
                // Emit tool completion events
                if let handler = eventHandler {
                    await handler(.completed(name: toolCall.function.name, result: resultString))
                }
                await lifecycleManager.emit(.toolEnded(name: toolCall.function.name, result: resultString, success: true))
            } catch {
                aiDebugPrint("DEBUG: Tool execution error: \(error)")
                
                // Create error result instead of throwing
                let errorResult: [String: Any] = [
                    "success": false,
                    "error": error.localizedDescription
                ]
                
                let resultString = try JSONSerialization.data(withJSONObject: errorResult, options: [])
                results.append(String(data: resultString, encoding: .utf8) ?? "{\"success\": false}")
                
                // Emit tool completion events with error
                if let handler = eventHandler {
                    await handler(.completed(name: toolCall.function.name, result: String(data: resultString, encoding: .utf8) ?? ""))
                }
                await lifecycleManager.emit(.toolEnded(name: toolCall.function.name, result: error.localizedDescription, success: false))
            }
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

    private func updatePartialToolCall(
        _ partialCalls: inout [String: PartialToolCall],
        with delta: StreamFunctionCallArgumentsDelta
    ) {
        if let existing = partialCalls[delta.id] {
            existing.update(with: delta)
        } else {
            partialCalls[delta.id] = PartialToolCall(from: delta)
        }
    }
    
    // Helper to determine if task is complete despite having tool calls
    private func isTaskComplete(
        content: String,
        toolCalls: [ToolCallItem],
        iteration: Int,
        allContent: String
    ) -> Bool {
        // Check for explicit completion phrases
        let completionPhrases = [
            "i've completed", "task is done", "finished",
            "all done", "everything is complete", "task completed",
            "i have completed", "successfully completed",
            "here's the joke", "here is the joke", "let me tell you",
            "why don't", "why did", "what do you call", "knock knock"
        ]
        
        let lowercaseContent = content.lowercased()
        let hasCompletionPhrase = completionPhrases.contains { phrase in
            lowercaseContent.contains(phrase)
        }
        
        if hasCompletionPhrase {
            aiDebugPrint("DEBUG: Task likely complete - found completion phrase")
            return true
        }
        
        // Check if tools are "finishing" tools (like say or echo)
        let isFinishingTool = toolCalls.allSatisfy { toolCall in
            toolCall.function.name == "say" ||
            toolCall.function.name == "shell" && toolCall.function.arguments.contains("say")
        }
        
        // If we have both content and finishing tools, likely done
        if !content.isEmpty && isFinishingTool {
            aiDebugPrint("DEBUG: Task likely complete - content + finishing tools")
            return true
        }
        
        // Only consider task complete after many iterations if there are NO tool calls
        // This prevents premature completion when the agent is still working
        if iteration > 5 && toolCalls.isEmpty && content.count > 200 {
            aiDebugPrint("DEBUG: Task likely complete - many iterations with substantial content and no more tools")
            return true
        }
        
        return false
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

    init(from delta: StreamFunctionCallArgumentsDelta) {
        self.id = delta.id
        self.arguments = delta.arguments
    }
    
    func update(with delta: StreamToolCallDelta) {
        if let funcName = delta.function.name {
            self.name = funcName
        }
        if let args = delta.function.arguments {
            self.arguments += args
        }
    }

    func update(with delta: StreamFunctionCallArgumentsDelta) {
        self.arguments += delta.arguments
    }
}