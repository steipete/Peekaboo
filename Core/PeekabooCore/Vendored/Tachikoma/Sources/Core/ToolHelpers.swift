import Foundation

/// Helper functions for creating tools with Tachikoma
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func createTool<Context>(
    name: String,
    description: String,
    parameters: ToolParameters? = nil,
    execute: @escaping (ToolInput, Context) async throws -> ToolOutput
) -> AITool<Context> {
    return AITool<Context>(
        name: name,
        description: description,
        parameters: parameters ?? ToolParameters.object(properties: [:], required: []),
        execute: execute
    )
}

/// Create a simple tool with basic parameter handling
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func createSimpleTool<Context>(
    name: String,
    description: String,
    parameters: [String: ParameterSchema] = [:],
    required: [String] = [],
    execute: @escaping (ToolInput, Context) async throws -> ToolOutput
) -> AITool<Context> {
    return createTool(
        name: name,
        description: description,
        parameters: ToolParameters.object(properties: parameters, required: required),
        execute: execute
    )
}

/// Create a string parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func stringParam(
    description: String,
    enumValues: [String]? = nil,
    pattern: String? = nil
) -> ParameterSchema {
    ParameterSchema.string(description: description, pattern: pattern, enumValues: enumValues)
}

/// Create a number parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func numberParam(
    description: String,
    minimum: Double? = nil,
    maximum: Double? = nil
) -> ParameterSchema {
    ParameterSchema.number(description: description, minimum: minimum, maximum: maximum)
}

/// Create an integer parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func integerParam(
    description: String,
    minimum: Int? = nil,
    maximum: Int? = nil
) -> ParameterSchema {
    ParameterSchema.integer(description: description, minimum: minimum?.double, maximum: maximum?.double)
}

/// Create a boolean parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func boolParam(description: String) -> ParameterSchema {
    ParameterSchema.boolean(description: description)
}

/// Create an array parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func arrayParam(
    description: String,
    items: ParameterSchema
) -> ParameterSchema {
    ParameterSchema.array(of: items, description: description)
}

/// Create an object parameter schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public func objectParam(
    description: String,
    properties: [String: ParameterSchema],
    required: [String] = []
) -> ParameterSchema {
    ParameterSchema.object(properties: properties, description: description, required: required)
}

// MARK: - Type Extensions

extension Int {
    var double: Double {
        Double(self)
    }
}