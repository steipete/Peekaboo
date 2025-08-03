import Foundation

/// Generic AI agent that can execute tools within a specific context
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class PeekabooAgent<Context>: @unchecked Sendable {
    /// Agent's unique identifier
    public let name: String

    /// System instructions for the agent
    public let instructions: String

    /// Available tools for the agent
    public private(set) var tools: [Tool<Context>]

    /// Model settings for generation
    public var modelSettings: ModelSettings

    /// The context instance passed to tool executions
    private let context: Context

    public init(
        name: String,
        instructions: String,
        tools: [Tool<Context>] = [],
        modelSettings: ModelSettings,
        context: Context
    ) {
        self.name = name
        self.instructions = instructions
        self.tools = tools
        self.modelSettings = modelSettings
        self.context = context
    }

    /// Convenience initializer with model interface
    public init(
        model _: any ModelInterface,
        sessionId _: String,
        name: String,
        instructions: String,
        tools: [Tool<Context>] = [],
        context: Context
    ) {
        self.name = name
        self.instructions = instructions
        self.tools = tools
        modelSettings = ModelSettings() // Default settings
        self.context = context
    }

    /// Add a tool to the agent
    public func addTool(_ tool: Tool<Context>) {
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
        eventDelegate: (any AgentEventDelegate)? = nil
    ) async throws -> AgentExecutionResult {
        let startTime = Date()
        await eventDelegate?.agentDidEmitEvent(.taskStarted(task: input))

        // Convert tools to tool definitions
        let toolDefinitions = tools.map { $0.toToolDefinition() }

        // Create the request
        let request = ModelRequest(
            messages: [
                .system(content: instructions),
                .user(content: .text(input)),
            ],
            tools: toolDefinitions,
            settings: modelSettings
        )

        // Execute the model request
        let response = try await model.getResponse(request: request)

        // Process tool calls if any
        var allToolCalls: [ToolCallItem] = []
        var finalContent = ""

        for item in response.content {
            if case let .outputText(text) = item {
                finalContent += text
            } else if case let .toolCall(toolCall) = item {
                allToolCalls.append(toolCall)

                // Find and execute the tool
                if let tool = tools.first(where: { $0.name == toolCall.function.name }) {
                    await eventDelegate?.agentDidEmitEvent(.toolCallStarted(
                        toolName: toolCall.function.name,
                        parameters: [:] // Simplified for now
                    ))

                    do {
                        let toolInput = try ToolInput(jsonString: toolCall.function.arguments)
                        let result = try await tool.execute(toolInput, context)

                        await eventDelegate?.agentDidEmitEvent(.toolCallCompleted(
                            toolName: toolCall.function.name,
                            result: String(describing: result)
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

        let endTime = Date()
        let metadata = AgentMetadata(
            executionTime: endTime.timeIntervalSince(startTime),
            toolCallCount: allToolCalls.count,
            modelName: modelSettings.modelName,
            startTime: startTime,
            endTime: endTime
        )

        let result = AgentExecutionResult(
            content: finalContent,
            messages: [
                .system(content: instructions),
                .user(content: .text(input)),
                .assistant(content: response.content),
            ],
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
        eventDelegate: (any AgentEventDelegate)? = nil
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
