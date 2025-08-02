import Foundation

// MARK: - Agent Tool Definition

/// A tool that can be used by the AI agent
public struct Tool<Context> {
    public let definition: ToolDefinition
    public let execute: (ToolInput, Context) async throws -> ToolOutput
    
    public init(
        definition: ToolDefinition,
        execute: @escaping (ToolInput, Context) async throws -> ToolOutput
    ) {
        self.definition = definition
        self.execute = execute
    }
}