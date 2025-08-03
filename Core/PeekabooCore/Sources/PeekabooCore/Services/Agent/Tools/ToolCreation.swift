import Foundation
import TachikomaCore

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
        description: description,
        execute: execute)
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
        description: description,
        execute: execute)
}

// MARK: - ToolParameterProperty Helpers

/// Create a string parameter property
public func stringParam(
    description: String,
    enumValues: [String]? = nil) -> ToolParameterProperty
{
    ToolParameterProperty(
        type: .string,
        description: description,
        enumValues: enumValues)
}

/// Create a number parameter property
public func numberParam(
    description: String,
    minimum: Double? = nil,
    maximum: Double? = nil) -> ToolParameterProperty
{
    ToolParameterProperty(
        type: .number,
        description: description,
        minimum: minimum,
        maximum: maximum)
}

/// Create an integer parameter property
public func integerParam(
    description: String,
    minimum: Double? = nil,
    maximum: Double? = nil) -> ToolParameterProperty
{
    ToolParameterProperty(
        type: .integer,
        description: description,
        minimum: minimum,
        maximum: maximum)
}

/// Create a boolean parameter property
public func boolParam(description: String) -> ToolParameterProperty {
    ToolParameterProperty(
        type: .boolean,
        description: description)
}
