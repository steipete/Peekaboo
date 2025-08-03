import Foundation

/// Configuration settings for agent behavior and execution
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AgentConfiguration: Sendable {
    /// Maximum number of tokens for completion
    public let maxTokens: Int

    /// Temperature for response generation (0.0 to 1.0)
    public let temperature: Double

    /// Maximum number of tool calls per session
    public let maxToolCalls: Int

    /// Timeout for individual tool execution in seconds
    public let toolTimeout: TimeInterval

    /// Timeout for entire agent session in seconds
    public let sessionTimeout: TimeInterval

    /// Whether to enable verbose logging
    public let verboseLogging: Bool

    /// Whether to save sessions automatically
    public let autoSaveSessions: Bool

    /// Custom configuration parameters for specific models
    public let modelSpecificParameters: [String: String]

    /// Default configuration
    public static let `default` = AgentConfiguration()

    /// Configuration optimized for o3/o4 reasoning models
    public static let o3Optimized = AgentConfiguration(
        maxTokens: o3MaxCompletionTokens,
        temperature: 0.0, // o3 models don't support temperature
        maxToolCalls: 50,
        toolTimeout: 120.0,
        sessionTimeout: 1800.0, // 30 minutes for complex reasoning
        modelSpecificParameters: [
            "reasoning_effort": o3ReasoningEffort,
            "reasoning_summary": "detailed",
        ])

    /// Default reasoning effort for o3 models
    public static let o3ReasoningEffort = "medium"

    /// Default max completion tokens for o3 models
    public static let o3MaxCompletionTokens = 8192

    public init(
        maxTokens: Int = 4096,
        temperature: Double = 0.1,
        maxToolCalls: Int = 20,
        toolTimeout: TimeInterval = 60.0,
        sessionTimeout: TimeInterval = 600.0,
        verboseLogging: Bool = false,
        autoSaveSessions: Bool = true,
        modelSpecificParameters: [String: String] = [:])
    {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.maxToolCalls = maxToolCalls
        self.toolTimeout = toolTimeout
        self.sessionTimeout = sessionTimeout
        self.verboseLogging = verboseLogging
        self.autoSaveSessions = autoSaveSessions
        self.modelSpecificParameters = modelSpecificParameters
    }

    /// Create configuration optimized for a specific model
    public static func forModel(_ modelName: String) -> AgentConfiguration {
        if modelName.hasPrefix("o3") || modelName.hasPrefix("o4") {
            .o3Optimized
        } else if modelName.contains("claude") {
            AgentConfiguration(
                maxTokens: 8192,
                temperature: 0.1,
                maxToolCalls: 30,
                toolTimeout: 90.0,
                sessionTimeout: 900.0)
        } else if modelName.contains("gpt-4") {
            AgentConfiguration(
                maxTokens: 4096,
                temperature: 0.1,
                maxToolCalls: 25,
                toolTimeout: 75.0,
                sessionTimeout: 750.0)
        } else {
            .default
        }
    }

    /// Update configuration with model-specific parameters
    public func withModelParameters(_ parameters: [String: String]) -> AgentConfiguration {
        var newParameters = self.modelSpecificParameters
        for (key, value) in parameters {
            newParameters[key] = value
        }

        return AgentConfiguration(
            maxTokens: self.maxTokens,
            temperature: self.temperature,
            maxToolCalls: self.maxToolCalls,
            toolTimeout: self.toolTimeout,
            sessionTimeout: self.sessionTimeout,
            verboseLogging: self.verboseLogging,
            autoSaveSessions: self.autoSaveSessions,
            modelSpecificParameters: newParameters)
    }

    /// Enable verbose logging
    public func withVerboseLogging(_ enabled: Bool = true) -> AgentConfiguration {
        AgentConfiguration(
            maxTokens: self.maxTokens,
            temperature: self.temperature,
            maxToolCalls: self.maxToolCalls,
            toolTimeout: self.toolTimeout,
            sessionTimeout: self.sessionTimeout,
            verboseLogging: enabled,
            autoSaveSessions: self.autoSaveSessions,
            modelSpecificParameters: self.modelSpecificParameters)
    }

    /// Update timeout settings
    public func withTimeouts(tool: TimeInterval? = nil, session: TimeInterval? = nil) -> AgentConfiguration {
        AgentConfiguration(
            maxTokens: self.maxTokens,
            temperature: self.temperature,
            maxToolCalls: self.maxToolCalls,
            toolTimeout: tool ?? self.toolTimeout,
            sessionTimeout: session ?? self.sessionTimeout,
            verboseLogging: self.verboseLogging,
            autoSaveSessions: self.autoSaveSessions,
            modelSpecificParameters: self.modelSpecificParameters)
    }
}
