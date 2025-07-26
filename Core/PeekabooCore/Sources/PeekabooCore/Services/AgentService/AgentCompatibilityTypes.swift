import Foundation

// MARK: - Agent Compatibility Types

/// Result of agent task execution
/// This type maintains backward compatibility with the existing AgentServiceProtocol
public struct AgentResult: Sendable {
    public let steps: [AgentStep]
    public let summary: String
    
    public init(steps: [AgentStep], summary: String) {
        self.steps = steps
        self.summary = summary
    }
}

/// A single step in agent execution
public struct AgentStep: Sendable {
    public let action: String
    public let description: String
    public let toolCalls: [String]  // Tool call IDs
    public let reasoning: String?
    public let observation: String?
    
    public init(
        action: String,
        description: String,
        toolCalls: [String],
        reasoning: String? = nil,
        observation: String? = nil
    ) {
        self.action = action
        self.description = description
        self.toolCalls = toolCalls
        self.reasoning = reasoning
        self.observation = observation
    }
}

// MARK: - Event Types

/// Events emitted during agent execution
public enum AgentEvent: Sendable {
    case started(task: String)
    case assistantMessage(content: String)
    case toolCallStarted(name: String, arguments: String)
    case toolCallCompleted(name: String, result: String)
    case error(message: String)
    case completed(summary: String)
}

/// Protocol for receiving agent events
@MainActor
public protocol AgentEventDelegate: AnyObject {
    /// Called when an agent event is emitted
    func agentDidEmitEvent(_ event: AgentEvent)
}

// MARK: - Event Delegate Extensions

/// Extension to make the existing AgentEventDelegate compatible with our usage
extension AgentEventDelegate {
    /// Helper method for backward compatibility
    func agentDidStart() async {
        await MainActor.run {
            self.agentDidEmitEvent(.started(task: ""))
        }
    }
    
    /// Helper method for backward compatibility
    func agentDidReceiveChunk(_ chunk: String) async {
        await MainActor.run {
            self.agentDidEmitEvent(.assistantMessage(content: chunk))
        }
    }
    
    /// Helper method for backward compatibility
    func agentDidComplete(_ result: AgentResult) async {
        await MainActor.run {
            self.agentDidEmitEvent(.completed(summary: result.summary))
        }
    }
}