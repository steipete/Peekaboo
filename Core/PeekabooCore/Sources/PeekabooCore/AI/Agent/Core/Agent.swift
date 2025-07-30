import Foundation

// MARK: - Agent Definition

/// An AI agent capable of interacting with tools and producing outputs based on instructions
public final class PeekabooAgent<Context>: @unchecked Sendable {
    /// Unique name of the agent
    public let name: String

    /// Instructions that guide the agent's behavior
    public let instructions: String

    /// Tools available to the agent
    public private(set) var tools: [Tool<Context>]

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
        tools: [Tool<Context>] = [],
        modelSettings: ModelSettings = .default,
        description: String? = nil,
        metadata: [String: Any]? = nil)
    {
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
    public func addTool(_ tool: Tool<Context>) -> Self {
        self.tools.append(tool)
        return self
    }

    /// Add multiple tools to the agent
    @discardableResult
    public func addTools(_ tools: [Tool<Context>]) -> Self {
        self.tools.append(contentsOf: tools)
        return self
    }

    /// Remove a tool by name
    @discardableResult
    public func removeTool(named name: String) -> Self {
        self.tools.removeAll { $0.name == name }
        return self
    }

    /// Find a tool by name
    public func tool(named name: String) -> Tool<Context>? {
        self.tools.first { $0.name == name }
    }

    /// Check if agent has a specific tool
    public func hasTool(named name: String) -> Bool {
        self.tools.contains { $0.name == name }
    }

    // MARK: - Configuration

    /// Update model settings
    @discardableResult
    public func withModelSettings(_ settings: ModelSettings) -> Self {
        self.modelSettings = settings
        return self
    }

    /// Create a copy of this agent
    public func clone() -> PeekabooAgent<Context> {
        PeekabooAgent(
            name: self.name,
            instructions: self.instructions,
            tools: self.tools,
            modelSettings: self.modelSettings,
            description: self.description,
            metadata: self.metadata)
    }

    // MARK: - System Prompt Generation

    /// Generate the system prompt for the model
    public func generateSystemPrompt() -> String {
        var prompt = self.instructions

        // Add tool descriptions if available
        if !self.tools.isEmpty {
            prompt += "\n\n## Available Tools\n\n"
            prompt += "You have access to the following tools:\n\n"

            for tool in self.tools {
                prompt += "### \(tool.name)\n"
                if !tool.description.isEmpty {
                    prompt += "\(tool.description)\n"
                }
                prompt += "\n"
            }

            prompt += """

            When you need to use a tool, call it with the appropriate parameters. 
            The system will execute the tool and provide you with the results.
            """
        }

        return prompt
    }
}

// MARK: - Agent Builder

/// Builder pattern for creating agents
public struct AgentBuilder<Context> {
    private var name: String = ""
    private var instructions: String = ""
    private var tools: [Tool<Context>] = []
    private var modelSettings: ModelSettings = .default
    private var description: String?
    private var metadata: [String: Any]?

    public init() {}

    public func withName(_ name: String) -> AgentBuilder {
        var builder = self
        builder.name = name
        return builder
    }

    public func withInstructions(_ instructions: String) -> AgentBuilder {
        var builder = self
        builder.instructions = instructions
        return builder
    }

    public func withTools(_ tools: [Tool<Context>]) -> AgentBuilder {
        var builder = self
        builder.tools = tools
        return builder
    }

    public func withTool(_ tool: Tool<Context>) -> AgentBuilder {
        var builder = self
        builder.tools.append(tool)
        return builder
    }

    public func withModelSettings(_ settings: ModelSettings) -> AgentBuilder {
        var builder = self
        builder.modelSettings = settings
        return builder
    }

    public func withDescription(_ description: String) -> AgentBuilder {
        var builder = self
        builder.description = description
        return builder
    }

    public func withMetadata(_ metadata: [String: Any]) -> AgentBuilder {
        var builder = self
        builder.metadata = metadata
        return builder
    }

    public func build() throws -> PeekabooAgent<Context> {
        guard !self.name.isEmpty else {
            throw AgentError.invalidConfiguration("Agent name is required")
        }

        guard !self.instructions.isEmpty else {
            throw AgentError.invalidConfiguration("Agent instructions are required")
        }

        return PeekabooAgent(
            name: self.name,
            instructions: self.instructions,
            tools: self.tools,
            modelSettings: self.modelSettings,
            description: self.description,
            metadata: self.metadata)
    }
}

// MARK: - Agent Errors

/// Errors that can occur with agents
public enum AgentError: Error, LocalizedError {
    case invalidConfiguration(String)
    case toolNotFound(String)
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(message):
            "Invalid agent configuration: \(message)"
        case let .toolNotFound(name):
            "Tool not found: \(name)"
        case let .executionFailed(message):
            "Agent execution failed: \(message)"
        }
    }
}

// MARK: - Agent Extensions

extension PeekabooAgent {
    /// Get all tool definitions for the model
    public var toolDefinitions: [ToolDefinition] {
        self.tools.map { $0.toToolDefinition() }
    }

    /// Check if the agent has any tools
    public var hasTools: Bool {
        !self.tools.isEmpty
    }

    /// Get tool count
    public var toolCount: Int {
        self.tools.count
    }
}

// MARK: - Default Agents

extension PeekabooAgent {
    /// Create a basic assistant agent
    public static func assistant(
        name: String = "Assistant",
        tools: [Tool<Context>] = [],
        modelSettings: ModelSettings = .default) -> PeekabooAgent<Context>
    {
        PeekabooAgent(
            name: name,
            instructions: "You are a helpful AI assistant. Answer questions accurately and assist with tasks to the best of your ability.",
            tools: tools,
            modelSettings: modelSettings)
    }

    /// Create a code assistant agent
    public static func codeAssistant(
        name: String = "Code Assistant",
        tools: [Tool<Context>] = [],
        modelSettings: ModelSettings = .default) -> PeekabooAgent<Context>
    {
        PeekabooAgent(
            name: name,
            instructions: """
            You are an expert programming assistant. Help with:
            - Writing clean, efficient code
            - Debugging and fixing issues
            - Explaining code concepts
            - Suggesting best practices
            - Code reviews and improvements

            Always provide clear explanations and consider edge cases.
            """,
            tools: tools,
            modelSettings: modelSettings)
    }
}
