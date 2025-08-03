import Foundation
import Tachikoma

// MARK: - Tool Creation Helpers

/// Create a simple tool with basic parameter handling
public func createSimpleTool<Context>(
    name: String,
    description: String,
    parameters: [String: ParameterSchema] = [:],
    required: [String] = [],
    execute: @escaping (ToolInput, Context) async throws -> ToolOutput) -> Tool<Context>
{
    Tool(
        name: name,
        description: description,
        parameters: ToolParameters.object(
            properties: parameters,
            required: required),
        execute: execute)
}

/// Create a tool with full control over the definition
public func createTool<Context>(
    name: String,
    description: String,
    parameters: ToolParameters? = nil,
    execute: @escaping (ToolInput, Context) async throws -> ToolOutput) -> Tool<Context>
{
    Tool(
        name: name,
        description: description,
        parameters: parameters ?? ToolParameters.object(
            properties: [:],
            required: []),
        execute: execute)
}

// MARK: - Parameter Schema Helpers

/// Create a string parameter schema
public func stringParam(
    description: String,
    enumValues: [String]? = nil,
    pattern: String? = nil) -> ParameterSchema
{
    ParameterSchema(
        type: .string,
        description: description,
        enumValues: enumValues,
        pattern: pattern)
}

/// Create a number parameter schema
public func numberParam(
    description: String,
    minimum: Double? = nil,
    maximum: Double? = nil) -> ParameterSchema
{
    ParameterSchema(
        type: .number,
        description: description,
        minimum: minimum,
        maximum: maximum)
}

/// Create an integer parameter schema
public func integerParam(
    description: String,
    minimum: Int? = nil,
    maximum: Int? = nil) -> ParameterSchema
{
    ParameterSchema(
        type: .integer,
        description: description,
        minimum: minimum?.double,
        maximum: maximum?.double)
}

/// Create a boolean parameter schema
public func boolParam(description: String) -> ParameterSchema {
    ParameterSchema(
        type: .boolean,
        description: description)
}

/// Create an array parameter schema
public func arrayParam(
    description: String,
    items: ParameterSchema) -> ParameterSchema
{
    ParameterSchema(
        type: .array,
        description: description,
        items: items)
}

/// Create an object parameter schema
public func objectParam(
    description: String,
    properties: [String: ParameterSchema]) -> ParameterSchema
{
    ParameterSchema.object(
        properties: properties,
        description: description)
}

// MARK: - Type Extensions

extension Int {
    var double: Double {
        Double(self)
    }
}
