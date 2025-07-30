import Foundation

/// Protocol defining the agent service interface
@available(macOS 14.0, *)
public protocol AgentServiceProtocol: Sendable {
    /// Execute a task using the AI agent
    /// - Parameters:
    ///   - task: The task description
    ///   - dryRun: If true, simulates execution without performing actions
    ///   - eventDelegate: Optional delegate for real-time event updates
    /// - Returns: The agent execution result
    func executeTask(
        _ task: String,
        dryRun: Bool,
        eventDelegate: AgentEventDelegate?) async throws -> AgentExecutionResult

    /// Clean up any cached sessions or resources
    func cleanup() async
}
