import Foundation

/// Protocol defining the agent service interface
@available(macOS 14.0, *)
public protocol AgentServiceProtocol: Sendable {
    /// Execute a task using the AI agent
    /// - Parameters:
    ///   - task: The task description
    ///   - dryRun: If true, simulates execution without performing actions
    ///   - eventDelegate: Optional delegate for real-time event updates
    /// - Returns: The agent result containing steps and summary
    func executeTask(
        _ task: String,
        dryRun: Bool,
        eventDelegate: AgentEventDelegate?
    ) async throws -> AgentResult
    
    /// Get or create a shared assistant for the current configuration
    /// - Returns: Assistant ID that can be reused
    func getOrCreateAssistant() async throws -> String
    
    /// Clean up any cached assistants
    func cleanup() async
}