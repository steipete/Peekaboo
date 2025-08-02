import Foundation

// MARK: - AI Agent

/// An AI agent capable of interacting with tools and producing outputs based on instructions
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class PeekabooAgent<Context>: @unchecked Sendable {
    /// Unique name of the agent
    public let name: String

    /// Instructions that guide the agent's behavior
    public let instructions: String

    /// Tools available to the agent
    public private(set) var tools: [AITool<Context>]

    /// Model settings for the agent
    public var modelSettings: ModelSettings

    /// Optional description of the agent
    public let description: String?

    /// Optional metadata for the agent
    public let metadata: [String: Any]?

    /// Create a new agent
    public init(
        name: String,
        instructions: String,
        tools: [AITool<Context>] = [],
        modelSettings: ModelSettings = .default,
        description: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.name = name
        self.instructions = instructions
        self.tools = tools
        self.modelSettings = modelSettings
        self.description = description
        self.metadata = metadata
    }

    // MARK: - Tool Management

    /// Add a tool to the agent
    @discardableResult
    public func addTool(_ tool: AITool<Context>) -> Self {
        self.tools.append(tool)
        return self
    }

    /// Add multiple tools to the agent
    @discardableResult
    public func addTools(_ tools: [AITool<Context>]) -> Self {
        self.tools.append(contentsOf: tools)
        return self
    }

    /// Remove a tool by name
    @discardableResult
    public func removeTool(named name: String) -> Self {
        self.tools.removeAll { $0.name == name }
        return self
    }

    /// Clear all tools
    @discardableResult
    public func clearTools() -> Self {
        self.tools.removeAll()
        return self
    }

    /// Get a tool by name
    public func tool(named name: String) -> AITool<Context>? {
        return tools.first { $0.name == name }
    }

    /// Get all tool definitions for the model
    public func toolDefinitions() -> [ToolDefinition] {
        return tools.map { $0.toToolDefinition() }
    }
}

// MARK: - Agent Runner

/// Utility for running agents with different execution modes
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AgentRunner {
    
    /// Execute an agent with basic input/output
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

    /// Execute an agent with streaming output
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

// MARK: - Private Implementation

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
private actor AgentRunnerImpl<Context> where Context: Sendable {
    let agent: PeekabooAgent<Context>
    let context: Context
    let model: (any ModelInterface)?
    
    init(agent: PeekabooAgent<Context>, context: Context, model: (any ModelInterface)? = nil) {
        self.agent = agent
        self.context = context
        self.model = model
    }
    
    func run(input: String, sessionId: String? = nil) async throws -> AgentExecutionResult {
        let startTime = Date()
        
        // Create initial messages
        var messages: [Message] = [
            .system(content: agent.instructions),
            .user(content: .text(input))
        ]
        
        let currentModel = try await getModel()
        let request = ModelRequest(
            messages: messages,
            tools: agent.toolDefinitions(),
            settings: agent.modelSettings
        )
        
        let response = try await currentModel.getResponse(request: request)
        let content = extractContent(from: response.content)
        
        return AgentExecutionResult(
            content: content,
            messages: messages + [.assistant(content: response.content)],
            sessionId: sessionId ?? UUID().uuidString,
            usage: response.usage,
            toolCalls: [],
            metadata: AgentMetadata(
                startTime: startTime,
                endTime: Date(),
                toolCallCount: 0,
                modelName: agent.modelSettings.modelName,
                isResumed: false,
                maskedApiKey: currentModel.maskedApiKey
            )
        )
    }
    
    func runStreaming(
        input: String,
        sessionId: String? = nil,
        streamHandler: @Sendable @escaping (String) async -> Void,
        eventHandler: (@Sendable (ToolExecutionEvent) async -> Void)? = nil,
        reasoningHandler: (@Sendable (String) async -> Void)? = nil
    ) async throws -> AgentExecutionResult {
        let startTime = Date()
        
        // Create initial messages
        var messages: [Message] = [
            .system(content: agent.instructions),
            .user(content: .text(input))
        ]
        
        let currentModel = try await getModel()
        let request = ModelRequest(
            messages: messages,
            tools: agent.toolDefinitions(),
            settings: agent.modelSettings
        )
        
        var responseContent = ""
        var assistantContent: [AssistantContent] = []
        var usage: Usage?
        
        for try await event in try await currentModel.getStreamedResponse(request: request) {
            switch event {
            case .textDelta(let delta):
                responseContent += delta.delta
                await streamHandler(delta.delta)
                
            case .responseCompleted(let completed):
                usage = completed.usage
                
            default:
                break
            }
        }
        
        if !responseContent.isEmpty {
            assistantContent.append(.outputText(responseContent))
        }
        
        return AgentExecutionResult(
            content: responseContent,
            messages: messages + [.assistant(content: assistantContent)],
            sessionId: sessionId ?? UUID().uuidString,
            usage: usage,
            toolCalls: [],
            metadata: AgentMetadata(
                startTime: startTime,
                endTime: Date(),
                toolCallCount: 0,
                modelName: agent.modelSettings.modelName,
                isResumed: false,
                maskedApiKey: currentModel.maskedApiKey
            )
        )
    }
    
    private func getModel() async throws -> any ModelInterface {
        if let model = model {
            return model
        }
        
        let modelName = agent.modelSettings.modelName
        return try await Tachikoma.shared.getModel(modelName)
    }
    
    private func extractContent(from content: [AssistantContent]) -> String {
        return content.compactMap { item in
            switch item {
            case .outputText(let text):
                return text
            case .refusal(let text):
                return text
            case .toolCall:
                return nil
            }
        }.joined(separator: "\n")
    }
}