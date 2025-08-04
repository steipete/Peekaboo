import Foundation
import Tachikoma

// MARK: - Tool Creation Helpers

/// Create a simple tool with basic parameter handling
public func createSimpleTool<Context>(
    name: String,
    description: String,
    parameters: [String: ToolParameterProperty] = [:],
    required: [String] = [],
    execute: @escaping @Sendable (ToolInput, Context) async throws -> ToolOutput) -> Tool<Context>
{
    Tool(
        name: name,
        description: description
    ) { input, context in
        try await execute(input, context)
    }
}

/// Create a tool with full control over the definition
public func createTool<Context>(
    name: String,
    description: String,
    parameters: ToolParameters? = nil,
    execute: @escaping @Sendable (ToolInput, Context) async throws -> ToolOutput) -> Tool<Context>
{
    Tool(
        name: name,
        description: description
    ) { input, context in
        try await execute(input, context)
    }
}

// MARK: - ToolParameterProperty Helpers

/// Create a string parameter property
public func stringParam(
    name: String,
    description: String,
    enumValues: [String]? = nil) -> ToolParameterProperty
{
    ToolParameterProperty(
        name: name,
        type: .string,
        description: description,
        enumValues: enumValues)
}

/// Create a number parameter property
public func numberParam(
    name: String,
    description: String,
    minimum: Double? = nil,
    maximum: Double? = nil) -> ToolParameterProperty
{
    ToolParameterProperty(
        name: name,
        type: .number,
        description: description,
        enumValues: nil)
}

/// Create an integer parameter property
public func integerParam(
    name: String,
    description: String,
    minimum: Double? = nil,
    maximum: Double? = nil) -> ToolParameterProperty
{
    ToolParameterProperty(
        name: name,
        type: .integer,
        description: description,
        enumValues: nil)
}

/// Create a boolean parameter property
public func boolParam(name: String, description: String) -> ToolParameterProperty {
    ToolParameterProperty(
        name: name,
        type: .boolean,
        description: description)
}
