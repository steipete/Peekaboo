import Foundation

// MARK: - Event Types

/// Events emitted during agent execution
public enum AgentEvent: Sendable {
    case started(task: String)
    case assistantMessage(content: String)
    case thinkingMessage(content: String) // New case for thinking/reasoning content
    case toolCallStarted(name: String, arguments: String)
    case toolCallCompleted(name: String, result: String)
    case error(message: String)
    case completed(summary: String, usage: Usage?)
}

/// Protocol for receiving agent events
@MainActor
public protocol AgentEventDelegate: AnyObject, Sendable {
    /// Called when an agent event is emitted
    func agentDidEmitEvent(_ event: AgentEvent)
}

// MARK: - Event Delegate Extensions

/// Extension to make the existing AgentEventDelegate compatible with our usage
extension AgentEventDelegate {
    /// Helper method for backward compatibility
    func agentDidStart() async {
        self.agentDidEmitEvent(.started(task: ""))
    }

    /// Helper method for backward compatibility
    func agentDidReceiveChunk(_ chunk: String) async {
        self.agentDidEmitEvent(.assistantMessage(content: chunk))
    }
}
