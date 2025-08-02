import Foundation

// MARK: - Tool Definition

/// A tool that can be used by an agent to perform actions
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct Tool<Context> {
    /// Unique name of the tool
    public let name: String

    /// Description of what the tool does
    public let description: String

    /// Parameters the tool accepts
    public let parameters: ToolParameters

    /// Whether to use strict parameter validation
    public let strict: Bool

    /// The function to execute when the tool is called
    public let execute: (ToolInput, Context) async throws -> ToolOutput

    public init(
        name: String,
        description: String,
        parameters: ToolParameters,
        strict: Bool = true,
        execute: @escaping (ToolInput, Context) async throws -> ToolOutput)
    {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.strict = strict
        self.execute = execute
    }

    /// Convert to a tool definition for the model
    public func toToolDefinition() -> ToolDefinition {
        ToolDefinition(
            type: .function,
            function: FunctionDefinition(
                name: self.name,
                description: self.description,
                parameters: self.parameters,
                strict: self.strict))
    }
}

// MARK: - Tool Definition Types

/// Definition of a tool that can be sent to a model
public struct ToolDefinition: Codable, Sendable {
    public let type: ToolType
    public let function: FunctionDefinition

    public init(type: ToolType = .function, function: FunctionDefinition) {
        self.type = type
        self.function = function
    }
}

/// Type of tool
public enum ToolType: String, Codable, Sendable {
    case function
}

/// Function definition for a tool
public struct FunctionDefinition: Codable, Sendable {
    public let name: String
    public let description: String
    public let parameters: ToolParameters
    public let strict: Bool?

    public init(
        name: String,
        description: String,
        parameters: ToolParameters,
        strict: Bool? = nil)
    {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.strict = strict
    }
}

// MARK: - Tool Parameters

/// Parameters schema for a tool
public struct ToolParameters: Codable, Sendable {
    public let type: String
    public let properties: [String: ParameterSchema]
    public let required: [String]
    public let additionalProperties: Bool

    public init(
        type: String = "object",
        properties: [String: ParameterSchema] = [:],
        required: [String] = [],
        additionalProperties: Bool = false)
    {
        self.type = type
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
    }

    /// Create parameters from a dictionary of property definitions
    public static func object(
        properties: [String: ParameterSchema],
        required: [String] = []) -> ToolParameters
    {
        ToolParameters(
            type: "object",
            properties: properties,
            required: required,
            additionalProperties: false)
    }
}

/// Schema for a single parameter
public struct ParameterSchema: Codable, Sendable {
    public let type: ParameterType
    public let description: String?
    public let enumValues: [String]?
    public let items: Box<ParameterSchema>?
    public let properties: [String: ParameterSchema]?
    public let minimum: Double?
    public let maximum: Double?
    public let pattern: String?

    public init(
        type: ParameterType,
        description: String? = nil,
        enumValues: [String]? = nil,
        items: ParameterSchema? = nil,
        properties: [String: ParameterSchema]? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        pattern: String? = nil)
    {
        self.type = type
        self.description = description
        self.enumValues = enumValues
        self.items = items.map(Box.init)
        self.properties = properties
        self.minimum = minimum
        self.maximum = maximum
        self.pattern = pattern
    }

    // Convenience initializers
    public static func string(description: String? = nil, pattern: String? = nil) -> ParameterSchema {
        ParameterSchema(type: .string, description: description, pattern: pattern)
    }

    public static func number(
        description: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil) -> ParameterSchema
    {
        ParameterSchema(type: .number, description: description, minimum: minimum, maximum: maximum)
    }

    public static func integer(
        description: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil) -> ParameterSchema
    {
        ParameterSchema(type: .integer, description: description, minimum: minimum, maximum: maximum)
    }

    public static func boolean(description: String? = nil) -> ParameterSchema {
        ParameterSchema(type: .boolean, description: description)
    }

    public static func array(of items: ParameterSchema, description: String? = nil) -> ParameterSchema {
        ParameterSchema(type: .array, description: description, items: items)
    }

    public static func object(properties: [String: ParameterSchema], description: String? = nil) -> ParameterSchema {
        ParameterSchema(type: .object, description: description, properties: properties)
    }

    public static func enumeration(_ values: [String], description: String? = nil) -> ParameterSchema {
        ParameterSchema(type: .string, description: description, enumValues: values)
    }

    // Custom coding keys
    enum CodingKeys: String, CodingKey {
        case type, description
        case enumValues = "enum"
        case items, properties
        case minimum, maximum, pattern
    }
}

/// Parameter types
public enum ParameterType: String, Codable, Sendable {
    case string
    case number
    case integer
    case boolean
    case array
    case object
    case null
}

// MARK: - Tool Input/Output

/// Input provided to a tool
public enum ToolInput {
    case string(String)
    case dictionary([String: Any])
    case array([Any])
    case null

    /// Parse from a JSON string
    public init(jsonString: String) throws {
        // Handle empty string as empty dictionary
        if jsonString.isEmpty {
            self = .dictionary([:])
            return
        }

        guard let data = jsonString.data(using: .utf8) else {
            throw ToolError.invalidInput("Invalid JSON string")
        }

        let parsed = try JSONSerialization.jsonObject(with: data)

        if let dict = parsed as? [String: Any] {
            self = .dictionary(dict)
        } else if let array = parsed as? [Any] {
            self = .array(array)
        } else if let string = parsed as? String {
            self = .string(string)
        } else {
            self = .null
        }
    }

    /// Get value for a specific key (for dictionary inputs)
    public func value<T>(for key: String) -> T? {
        guard case let .dictionary(dict) = self else { return nil }
        return dict[key] as? T
    }

    /// Get the raw string value
    public var stringValue: String? {
        switch self {
        case let .string(str):
            return str
        case .dictionary, .array:
            if let data = try? JSONSerialization.data(withJSONObject: rawValue),
               let str = String(data: data, encoding: .utf8)
            {
                return str
            }
            return nil
        case .null:
            return nil
        }
    }

    /// Get the raw value
    public var rawValue: Any {
        switch self {
        case let .string(str):
            str
        case let .dictionary(dict):
            dict
        case let .array(array):
            array
        case .null:
            NSNull()
        }
    }
}

/// Strongly-typed output from a tool
public enum ToolOutput: Codable, Sendable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case object([String: ToolOutput])
    case array([ToolOutput])
    case null
    case error(message: String, code: String? = nil)

    // MARK: - Codable Implementation

    private enum CodingKeys: String, CodingKey {
        case type, value, message, code
    }

    private enum OutputType: String, Codable {
        case string, number, boolean, object, array, null, error
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(OutputType.self, forKey: .type)

        switch type {
        case .string:
            let value = try container.decode(String.self, forKey: .value)
            self = .string(value)
        case .number:
            let value = try container.decode(Double.self, forKey: .value)
            self = .number(value)
        case .boolean:
            let value = try container.decode(Bool.self, forKey: .value)
            self = .boolean(value)
        case .object:
            let value = try container.decode([String: ToolOutput].self, forKey: .value)
            self = .object(value)
        case .array:
            let value = try container.decode([ToolOutput].self, forKey: .value)
            self = .array(value)
        case .null:
            self = .null
        case .error:
            let message = try container.decode(String.self, forKey: .message)
            let code = try container.decodeIfPresent(String.self, forKey: .code)
            self = .error(message: message, code: code)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .string(value):
            try container.encode(OutputType.string, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .number(value):
            try container.encode(OutputType.number, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .boolean(value):
            try container.encode(OutputType.boolean, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .object(value):
            try container.encode(OutputType.object, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .array(value):
            try container.encode(OutputType.array, forKey: .type)
            try container.encode(value, forKey: .value)
        case .null:
            try container.encode(OutputType.null, forKey: .type)
        case let .error(message, code):
            try container.encode(OutputType.error, forKey: .type)
            try container.encode(message, forKey: .message)
            try container.encodeIfPresent(code, forKey: .code)
        }
    }

    // MARK: - Conversion Methods

    /// Convert to JSON string for the model
    public func toJSONString() throws -> String {
        switch self {
        case let .string(str):
            return str // Return string directly for text output
        case let .error(message, code):
            // Special handling for errors to match expected format
            var errorDict: [String: ToolOutput] = ["error": .string(message)]
            if let code {
                errorDict["error_code"] = .string(code)
            }
            let data = try JSONEncoder().encode(ToolOutput.object(errorDict))
            guard let string = String(data: data, encoding: .utf8) else {
                throw ToolError.serializationFailed
            }
            return string
        default:
            // For all other types, encode normally
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self)
            guard let string = String(data: data, encoding: .utf8) else {
                throw ToolError.serializationFailed
            }
            return string
        }
    }

    /// Convert to a dictionary representation (for compatibility)
    public func toDictionary() -> [String: Any]? {
        switch self {
        case let .object(dict):
            var result: [String: Any] = [:]
            for (key, value) in dict {
                if let converted = value.toAny() {
                    result[key] = converted
                }
            }
            return result
        default:
            return nil
        }
    }

    /// Convert to Any (for legacy compatibility)
    private func toAny() -> Any? {
        switch self {
        case let .string(value):
            return value
        case let .number(value):
            return value
        case let .boolean(value):
            return value
        case let .object(dict):
            var result: [String: Any] = [:]
            for (key, value) in dict {
                if let converted = value.toAny() {
                    result[key] = converted
                }
            }
            return result
        case let .array(array):
            return array.compactMap { $0.toAny() }
        case .null:
            return NSNull()
        case let .error(message, _):
            return ["error": message]
        }
    }
}

// MARK: - Builder Methods

extension ToolOutput {
    /// Create a dictionary/object output using a builder pattern
    public static func dictionary(_ builder: () -> [String: ToolOutput]) -> ToolOutput {
        .object(builder())
    }

    /// Create a dictionary/object output from key-value pairs
    public static func dictionary(_ pairs: (String, ToolOutput)...) -> ToolOutput {
        var dict: [String: ToolOutput] = [:]
        for (key, value) in pairs {
            dict[key] = value
        }
        return .object(dict)
    }

    /// Create from a Swift dictionary with automatic type conversion
    public static func from(_ dict: [String: Any]) -> ToolOutput {
        var result: [String: ToolOutput] = [:]
        for (key, value) in dict {
            result[key] = self.from(value)
        }
        return .object(result)
    }

    /// Create from any Swift value with automatic type conversion
    public static func from(_ value: Any) -> ToolOutput {
        switch value {
        case let str as String:
            .string(str)
        case let num as Int:
            .number(Double(num))
        case let num as Double:
            .number(num)
        case let bool as Bool:
            .boolean(bool)
        case let dict as [String: Any]:
            self.from(dict)
        case let array as [Any]:
            .array(array.map { self.from($0) })
        case is NSNull:
            .null
        default:
            // Fallback to string representation
            .string(String(describing: value))
        }
    }

    /// Convenience method for success results
    public static func success(_ message: String, metadata: (String, ToolOutput)...) -> ToolOutput {
        var dict: [String: ToolOutput] = ["result": .string(message)]
        for (key, value) in metadata {
            dict[key] = value
        }
        return .object(dict)
    }
}

// MARK: - Tool Errors

/// Errors that can occur during tool execution
public enum ToolError: Error, LocalizedError, Sendable {
    case invalidInput(String)
    case executionFailed(String)
    case serializationFailed
    case contextMissing
    case toolNotFound(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidInput(message):
            "Invalid tool input: \(message)"
        case let .executionFailed(message):
            "Tool execution failed: \(message)"
        case .serializationFailed:
            "Failed to serialize tool output"
        case .contextMissing:
            "Required context is missing"
        case let .toolNotFound(name):
            "Tool not found: \(name)"
        }
    }
}

// MARK: - Helper Types

/// Box type for recursive data structures
public final class Box<T: Codable & Sendable>: Codable, Sendable {
    public let value: T

    public init(_ value: T) {
        self.value = value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(T.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value)
    }
}

// MARK: - Tool Builder

/// Builder pattern for creating tools
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct ToolBuilder<Context> {
    private var name: String = ""
    private var description: String = ""
    private var parameters: ToolParameters = .init()
    private var strict: Bool = true
    private var execute: ((ToolInput, Context) async throws -> ToolOutput)?

    public init() {}

    public func withName(_ name: String) -> ToolBuilder<Context> {
        var builder = self
        builder.name = name
        return builder
    }

    public func withDescription(_ description: String) -> ToolBuilder<Context> {
        var builder = self
        builder.description = description
        return builder
    }

    public func withParameters(_ parameters: ToolParameters) -> ToolBuilder<Context> {
        var builder = self
        builder.parameters = parameters
        return builder
    }

    public func withStrict(_ strict: Bool) -> ToolBuilder<Context> {
        var builder = self
        builder.strict = strict
        return builder
    }

    public func withExecution(_ execute: @escaping (ToolInput, Context) async throws -> ToolOutput)
    -> ToolBuilder<Context> {
        var builder = self
        builder.execute = execute
        return builder
    }

    public func build() throws -> Tool<Context> {
        guard !self.name.isEmpty else {
            throw ToolError.invalidInput("Tool name is required")
        }

        guard let execute else {
            throw ToolError.invalidInput("Tool execution function is required")
        }

        return Tool(
            name: self.name,
            description: self.description,
            parameters: self.parameters,
            strict: self.strict,
            execute: execute)
    }
}