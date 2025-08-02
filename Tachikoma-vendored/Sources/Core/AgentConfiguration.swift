import Foundation

/// Configuration values for the AI Agent
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum AgentConfiguration {
    /// Maximum number of iterations to prevent infinite loops
    public static let maxIterations = 100

    /// Default reasoning effort for o3 models
    /// Using "medium" for better balance between reasoning and tool usage
    public static let o3ReasoningEffort = "medium"

    /// Maximum completion tokens for o3 models
    public static let o3MaxCompletionTokens = 32768

    /// Default timeout for tool execution
    public static let defaultToolTimeout: TimeInterval = 30.0

    /// Maximum number of tool calls per iteration
    public static let maxToolCallsPerIteration = 10

    /// Default model for agent operations
    public static let defaultModelName = "claude-opus-4-20250514"
}