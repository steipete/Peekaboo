import Foundation

// MARK: - Tool Helper Functions

/// Create a simple tool with basic parameters
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func createSimpleTool<Context>(
    name: String,
    description: String,
    parameters: ToolParameters? = nil,
    execute: @escaping (ToolInput, Context) async throws -> ToolOutput
) -> Tool<Context> {
    return Tool<Context>(
        name: name,
        description: description,
        parameters: parameters ?? ToolParameters(),
        execute: execute
    )
}

/// Create a tool with detailed parameters
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func createTool<Context>(
    name: String,
    description: String,
    parameters: ToolParameters,
    strict: Bool = true,
    execute: @escaping (ToolInput, Context) async throws -> ToolOutput
) -> Tool<Context> {
    return Tool<Context>(
        name: name,
        description: description,
        parameters: parameters,
        strict: strict,
        execute: execute
    )
}

/// Create a tool from a tool definition
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func createToolFromDefinition<Context>(
    definition: ToolDefinition,
    execute: @escaping (ToolInput, Context) async throws -> ToolOutput
) -> Tool<Context> {
    return Tool<Context>(
        name: definition.function.name,
        description: definition.function.description,
        parameters: definition.function.parameters,
        strict: definition.function.strict ?? true,
        execute: execute
    )
}

// MARK: - Tool Output Helpers

extension ToolOutput {
    /// Create a success result with a message
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    public static func success(_ message: String) -> ToolOutput {
        return .string(message)
    }
    
    /// Create an error result with a message
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    public static func error(_ message: String, code: String? = nil) -> ToolOutput {
        return .error(message: message, code: code)
    }
    
    /// Create a result with structured data
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    public static func data(_ data: [String: ToolOutput]) -> ToolOutput {
        return .object(data)
    }
}