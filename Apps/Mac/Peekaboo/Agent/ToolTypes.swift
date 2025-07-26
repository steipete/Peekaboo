import Foundation
import PeekabooCore

// MARK: - Tool Function Types

/// Function definition for tools - maps to FunctionDefinition in PeekabooCore
public typealias ToolFunction = FunctionDefinition

/// Function parameters - maps to ToolParameters in PeekabooCore
public typealias FunctionParameters = ToolParameters

/// Property schema - maps to ParameterSchema in PeekabooCore  
public typealias Property = ParameterSchema

// MARK: - Tool Executor

/// Tool executor protocol for Mac app
public protocol ToolExecutor {
    /// Execute a tool with given input and services context
    func execute(input: ToolInput, services: PeekabooServices) async throws -> ToolOutput
}

// MARK: - Tool Execution Result

/// Result from executing a tool
public struct ToolExecutionResult {
    public let output: ToolOutput
    public let metadata: [String: Any]
    
    public init(output: ToolOutput, metadata: [String: Any] = [:]) {
        self.output = output
        self.metadata = metadata
    }
}

// MARK: - Tool Builder for Mac App

/// Convenience builder for creating tools in the Mac app
public struct MacAppToolBuilder {
    public static func tool(
        name: String,
        description: String,
        parameters: ToolParameters,
        execute: @escaping (ToolInput, PeekabooServices) async throws -> ToolOutput
    ) -> Tool<PeekabooServices> {
        Tool(
            name: name,
            description: description,
            parameters: parameters,
            execute: execute
        )
    }
}