import Foundation

/// Events emitted during agent execution for real-time UI updates
public enum AgentEvent: Sendable {
    case started(task: String)
    case thinking(message: String)
    case toolCallStarted(name: String, arguments: String)
    case toolCallCompleted(name: String, result: String)
    case assistantMessage(content: String)
    case error(message: String)
    case completed(summary: String?)
}

/// Protocol for receiving real-time agent events
public protocol AgentEventDelegate: AnyObject, Sendable {
    func agentDidEmitEvent(_ event: AgentEvent)
}

/// Async stream version for SwiftUI
public typealias AgentEventStream = AsyncStream<AgentEvent>