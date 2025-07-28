import Foundation
import CoreGraphics

// MARK: - Peekaboo Agent Service

/// Service that integrates the new agent architecture with PeekabooCore services
@available(macOS 14.0, *)
public final class PeekabooAgentService: AgentServiceProtocol {
    private let services: PeekabooServices
    private let modelProvider: ModelProvider
    private let sessionManager: AgentSessionManager
    private let defaultModelName: String
    
    /// The default model name used by this agent service
    public var defaultModel: String { defaultModelName }
    
    public init(
        services: PeekabooServices = .shared,
        defaultModelName: String = "claude-opus-4-20250514"
    ) {
        self.services = services
        self.modelProvider = .shared
        self.sessionManager = AgentSessionManager()
        self.defaultModelName = defaultModelName
    }
    
    // MARK: - AgentServiceProtocol Conformance
    
    /// Execute a task using the AI agent
    public func executeTask(
        _ task: String,
        dryRun: Bool = false,
        eventDelegate: AgentEventDelegate? = nil
    ) async throws -> AgentExecutionResult {
        // For dry run, just return a simulated result
        if dryRun {
            return AgentExecutionResult(
                content: "Dry run completed. Task would be: \(task)",
                messages: [],
                sessionId: UUID().uuidString,
                usage: nil,
                toolCalls: [],
                metadata: AgentMetadata(
                    startTime: Date(),
                    endTime: Date(),
                    toolCallCount: 0,
                    modelName: defaultModelName,
                    isResumed: false,
                    maskedApiKey: nil
                )
            )
        }
        
        // Use the new architecture internally
        let agent = createAutomationAgent(modelName: defaultModelName)
        
        // Create a new session for this task
        let sessionId = UUID().uuidString
        
        // Execute with streaming if we have an event delegate
        if eventDelegate != nil {
            // SAFETY: We ensure that the delegate is only accessed on MainActor
            // This is a legacy API pattern that predates Swift's strict concurrency
            let unsafeDelegate = UnsafeTransfer(eventDelegate!)
            
            // Create event stream infrastructure
            let (eventStream, eventContinuation) = AsyncStream<AgentEvent>.makeStream()
            
            // Start processing events on MainActor
            let eventTask = Task { @MainActor in
                let delegate = unsafeDelegate.wrappedValue
                for await event in eventStream {
                    delegate.agentDidEmitEvent(event)
                }
            }
            
            // Create the event handler
            let eventHandler = EventHandler { event in
                eventContinuation.yield(event)
            }
            
            defer {
                eventContinuation.finish()
                eventTask.cancel()
            }
            
            // Run the agent with streaming
            let result = try await AgentRunner.runStreaming(
                agent: agent,
                input: task,
                context: services,
                sessionId: sessionId,
                streamHandler: { chunk in
                    // Convert streaming chunks to events
                    await eventHandler.send(.assistantMessage(content: chunk))
                },
                eventHandler: { toolEvent in
                    // Convert tool events to agent events
                    switch toolEvent {
                    case .started(let name, let arguments):
                        await eventHandler.send(.toolCallStarted(name: name, arguments: arguments))
                    case .completed(let name, let result):
                        await eventHandler.send(.toolCallCompleted(name: name, result: result))
                    }
                }
            )
            
            // Send completion event
            await eventHandler.send(.completed(summary: result.content))
            
            return result
        } else {
            // Execute without streaming
            return try await AgentRunner.run(
                agent: agent,
                input: task,
                context: services,
                sessionId: sessionId
            )
        }
    }
    
    /// Clean up any cached sessions or resources
    public func cleanup() async {
        // Clean up old sessions (older than 7 days)
        try? await sessionManager.cleanOldSessions(daysToKeep: 7)
    }
    
    // MARK: - Agent Creation
    
    /// Create a Peekaboo automation agent with all available tools
    public func createAutomationAgent(
        name: String = "Peekaboo Assistant",
        modelName: String = "claude-opus-4-20250514",
        apiType: String? = nil
    ) -> PeekabooAgent<PeekabooServices> {
        let agent = PeekabooAgent<PeekabooServices>(
            name: name,
            instructions: AgentSystemPrompt.generate(),
            tools: createPeekabooTools(),
            modelSettings: ModelSettings(
                modelName: modelName,
                temperature: modelName.hasPrefix(AgentConfiguration.o3ModelPrefix) ? nil : nil,  // o3 doesn't support temperature
                maxTokens: modelName.hasPrefix(AgentConfiguration.o3ModelPrefix) ? AgentConfiguration.o3MaxTokens : AgentConfiguration.defaultMaxTokens,
                toolChoice: .auto,  // Let the model decide when to use tools vs generate text
                additionalParameters: buildAdditionalParameters(modelName: modelName, apiType: apiType)
            ),
            description: "An AI assistant for macOS automation using Peekaboo"
        )
        
        return agent
    }
    
    // MARK: - Execution Methods
    
    /// Execute a task with the automation agent (with session support)
    public func executeTask(
        _ task: String,
        sessionId: String? = nil,
        modelName: String = "claude-opus-4-20250514",
        eventDelegate: AgentEventDelegate? = nil
    ) async throws -> AgentExecutionResult {
        let agent = createAutomationAgent(modelName: modelName)
        
        // If we have an event delegate, use streaming
        if eventDelegate != nil {
            // SAFETY: We ensure that the delegate is only accessed on MainActor
            // This is a legacy API pattern that predates Swift's strict concurrency
            let unsafeDelegate = UnsafeTransfer(eventDelegate!)
            
            // Create event stream infrastructure
            let (eventStream, eventContinuation) = AsyncStream<AgentEvent>.makeStream()
            
            // Start processing events on MainActor
            let eventTask = Task { @MainActor in
                let delegate = unsafeDelegate.wrappedValue
                
                // Send start event
                delegate.agentDidEmitEvent(.started(task: task))
                
                for await event in eventStream {
                    delegate.agentDidEmitEvent(event)
                }
            }
            
            // Create the event handler
            let eventHandler = EventHandler { event in
                eventContinuation.yield(event)
            }
            
            defer {
                eventContinuation.finish()
                eventTask.cancel()
            }
            
            // Run the agent with streaming
            let result = try await AgentRunner.runStreaming(
                agent: agent,
                input: task,
                context: services,
                sessionId: sessionId,
                streamHandler: { chunk in
                    // Convert streaming chunks to events
                    await eventHandler.send(.assistantMessage(content: chunk))
                },
                eventHandler: { toolEvent in
                    // Convert tool events to agent events
                    switch toolEvent {
                    case .started(let name, let arguments):
                        await eventHandler.send(.toolCallStarted(name: name, arguments: arguments))
                    case .completed(let name, let result):
                        await eventHandler.send(.toolCallCompleted(name: name, result: result))
                    }
                }
            )
            
            // Send completion event
            await eventHandler.send(.completed(summary: result.content))
            
            return result
        } else {
            // Non-streaming execution
            return try await AgentRunner.run(
                agent: agent,
                input: task,
                context: services,
                sessionId: sessionId
            )
        }
    }
    
    
    /// Execute a task with streaming output
    public func executeTaskStreaming(
        _ task: String,
        sessionId: String? = nil,
        modelName: String = "claude-opus-4-20250514",
        streamHandler: @Sendable @escaping (String) async -> Void
    ) async throws -> AgentExecutionResult {
        let agent = createAutomationAgent(modelName: modelName)
        
        return try await AgentRunner.runStreaming(
            agent: agent,
            input: task,
            context: services,
            sessionId: sessionId,
            streamHandler: streamHandler
        )
    }
    
    // MARK: - Tool Creation
    
    private func createPeekabooTools() -> [Tool<PeekabooServices>] {
        var tools: [Tool<PeekabooServices>] = []
        
        // Vision tools
        tools.append(createSeeTool())
        tools.append(createScreenshotTool())
        tools.append(createWindowCaptureTool())
        
        // UI automation tools
        tools.append(createClickTool())
        tools.append(createTypeTool())
        tools.append(createScrollTool())
        tools.append(createHotkeyTool())
        
        // Window management tools
        tools.append(createListWindowsTool())
        tools.append(createFocusWindowTool())
        tools.append(createResizeWindowTool())
        
        // Space management tools (temporarily disabled)
        tools.append(createListSpacesTool())
        tools.append(createSwitchSpaceTool())
        tools.append(createMoveWindowToSpaceTool())
        
        // Application tools
        tools.append(createListAppsTool())
        tools.append(createLaunchAppTool())
        
        // Element tools
        tools.append(createFindElementTool())
        tools.append(createListElementsTool())
        tools.append(createFocusedTool())
        
        // Menu tools
        tools.append(createMenuClickTool())
        tools.append(createListMenusTool())
        
        // Dialog tools
        tools.append(createDialogClickTool())
        tools.append(createDialogInputTool())
        
        // Dock tools
        tools.append(createDockLaunchTool())
        tools.append(createListDockTool())
        
        // Shell tool
        tools.append(createShellTool())
        
        // Completion tools
        tools.append(CompletionTools.createDoneTool())
        tools.append(CompletionTools.createNeedInfoTool())
        
        return tools
    }
    
    // MARK: - Helper Methods
    
    private func buildAdditionalParameters(modelName: String, apiType: String?) -> ModelParameters? {
        var params = ModelParameters()
        
        // Check if API type is explicitly specified
        if let specifiedApiType = apiType {
            params = params.with("apiType", value: specifiedApiType)
        } else if !modelName.hasPrefix("grok") && !modelName.hasPrefix("claude") {
            // Default to Responses API for OpenAI models only (better streaming support)
            // Grok and Anthropic models don't need this parameter
            params = params.with("apiType", value: "responses")
        }
        
        // Add reasoning parameters for o3/o4 models
        if modelName.hasPrefix("o3") || modelName.hasPrefix("o4") {
            params = params
                .with("reasoning_effort", value: AgentConfiguration.o3ReasoningEffort)
                .with("max_completion_tokens", value: AgentConfiguration.o3MaxCompletionTokens)
                .with("reasoning", value: ["summary": "detailed"])
        }
        
        // Only log API type debug info in verbose mode
        if ProcessInfo.processInfo.arguments.contains("--verbose") || 
           ProcessInfo.processInfo.arguments.contains("-v") {
            let apiTypeValue = params.string("apiType") ?? "nil"
            let debugMsg = "DEBUG PeekabooAgentService: Model '\(modelName)' -> API Type: \(apiTypeValue)"
            FileHandle.standardError.write((debugMsg + "\n").data(using: .utf8)!)
        }
        
        return params.isEmpty ? nil : params
    }
}

// MARK: - Convenience Methods

extension PeekabooAgentService {
    /// Create a simple agent for basic tasks
    public func createSimpleAgent(
        modelName: String = "claude-opus-4-20250514"
    ) -> PeekabooAgent<PeekabooServices> {
        return createAutomationAgent(
            name: "Simple Assistant",
            modelName: modelName
        )
    }
    
    /// Resume a previous session
    public func resumeSession(
        sessionId: String,
        modelName: String = "claude-opus-4-20250514",
        eventDelegate: AgentEventDelegate? = nil
    ) async throws -> AgentExecutionResult {
        // Load the session
        guard try await sessionManager.loadSession(id: sessionId) != nil else {
            throw PeekabooError.sessionNotFound(sessionId)
        }
        
        // Use AgentRunner to resume the session with existing messages
        let agent = createAutomationAgent(modelName: modelName)
        
        // Create a continuation prompt if needed
        let continuationPrompt = "Continue from where we left off."
        
        // Execute with the loaded session
        if eventDelegate != nil {
            // SAFETY: We ensure that the delegate is only accessed on MainActor
            let unsafeDelegate = UnsafeTransfer(eventDelegate!)
            
            // Create event stream infrastructure
            let (eventStream, eventContinuation) = AsyncStream<AgentEvent>.makeStream()
            
            // Start processing events on MainActor
            let eventTask = Task { @MainActor in
                let delegate = unsafeDelegate.wrappedValue
                
                // Send start event
                delegate.agentDidEmitEvent(.started(task: continuationPrompt))
                
                for await event in eventStream {
                    delegate.agentDidEmitEvent(event)
                }
            }
            
            // Create the event handler
            let eventHandler = EventHandler { event in
                eventContinuation.yield(event)
            }
            
            defer {
                eventContinuation.finish()
                eventTask.cancel()
            }
            
            // Run the agent with streaming
            let result = try await AgentRunner.runStreaming(
                agent: agent,
                input: continuationPrompt,
                context: services,
                sessionId: sessionId,
                streamHandler: { chunk in
                    // Convert streaming chunks to events
                    await eventHandler.send(.assistantMessage(content: chunk))
                },
                eventHandler: { toolEvent in
                    // Convert tool events to agent events
                    switch toolEvent {
                    case .started(let name, let arguments):
                        await eventHandler.send(.toolCallStarted(name: name, arguments: arguments))
                    case .completed(let name, let result):
                        await eventHandler.send(.toolCallCompleted(name: name, result: result))
                    }
                }
            )
            
            // Send completion event
            await eventHandler.send(.completed(summary: result.content))
            
            return result
        } else {
            // Execute without streaming
            return try await AgentRunner.run(
                agent: agent,
                input: continuationPrompt,
                context: services,
                sessionId: sessionId
            )
        }
    }
    
    // TODO: Implement session management
    /*
    /// List available sessions
    public func listSessions() async throws -> [AgentSessionInfo] {
        return try await sessionManager.listSessions()
    }
    
    /// Get detailed session information
    public func getSessionInfo(sessionId: String) async throws -> AgentSessionInfo? {
        let sessions = try await sessionManager.listSessions()
        return sessions.first { $0.id == sessionId }
    }
    */
    
    /*
    /// Delete a specific session
    public func deleteSession(sessionId: String) async throws {
        try await sessionManager.deleteSession(sessionId)
    }
    */
}

// MARK: - Event Handler

private actor EventHandler {
    private let handler: @Sendable (AgentEvent) async -> Void
    
    init(handler: @escaping @Sendable (AgentEvent) async -> Void) {
        self.handler = handler
    }
    
    func send(_ event: AgentEvent) async {
        await handler(event)
    }
}

// MARK: - Unsafe Transfer

/// Safely transfer non-Sendable values across isolation boundaries
private struct UnsafeTransfer<T>: @unchecked Sendable {
    let wrappedValue: T
    
    init(_ value: T) {
        self.wrappedValue = value
    }
}