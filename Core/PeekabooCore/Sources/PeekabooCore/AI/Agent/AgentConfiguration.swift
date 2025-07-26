import Foundation

/// Configuration values for the AI Agent
public struct AgentConfiguration {
    /// Maximum number of iterations to prevent infinite loops
    public static let maxIterations = 100
    
    /// Default reasoning effort for o3 models
    /// Using "medium" for better balance between reasoning and communication
    public static let o3ReasoningEffort = "medium"
    
    /// Maximum tokens for o3 models (they need more for reasoning)
    public static let o3MaxTokens = 65536
    
    /// Maximum completion tokens for o3 models
    public static let o3MaxCompletionTokens = 65536
    
    /// Default max tokens for non-o3 models
    public static let defaultMaxTokens = 4096
    
    /// Model name prefixes
    public static let o3ModelPrefix = "o3"
    
    /// Enable debug logging for AI operations
    public static var enableDebugLogging: Bool {
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
}