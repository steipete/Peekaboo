import Foundation

/// Events emitted during agent execution for real-time UI updates
public enum AgentEvent {
    case started
    case thinking(message: String)
    case toolCallStarted(name: String, arguments: String)
    case toolCallCompleted(name: String, result: String)
    case assistantMessage(content: String)
    case error(message: String)
    case completed
}

/// Protocol for receiving agent execution events
public protocol AgentEventDelegate: AnyObject {
    func agentDidEmitEvent(_ event: AgentEvent)
}