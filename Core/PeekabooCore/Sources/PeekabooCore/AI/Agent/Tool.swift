import Foundation

// MARK: - Tool Definition

/// A tool that can be used by an agent to perform actions
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
        execute: @escaping (ToolInput, Context) async throws -> ToolOutput
    ) {
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
                name: name,
                description: description,
                parameters: parameters,
                strict: strict
            )
        )
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
    case function = "function"
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
        strict: Bool? = nil
    ) {
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
        additionalProperties: Bool = false
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
    }
    
    /// Create parameters from a dictionary of property definitions
    public static func object(
        properties: [String: ParameterSchema],
        required: [String] = []
    ) -> ToolParameters {
        ToolParameters(
            type: "object",
            properties: properties,
            required: required,
            additionalProperties: false
        )
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
        pattern: String? = nil
    ) {
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
    
    public static func number(description: String? = nil, minimum: Double? = nil, maximum: Double? = nil) -> ParameterSchema {
        ParameterSchema(type: .number, description: description, minimum: minimum, maximum: maximum)
    }
    
    public static func integer(description: String? = nil, minimum: Double? = nil, maximum: Double? = nil) -> ParameterSchema {
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
    case string = "string"
    case number = "number"
    case integer = "integer"
    case boolean = "boolean"
    case array = "array"
    case object = "object"
    case null = "null"
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
        guard case .dictionary(let dict) = self else { return nil }
        return dict[key] as? T
    }
    
    /// Get the raw string value
    public var stringValue: String? {
        switch self {
        case .string(let str):
            return str
        case .dictionary, .array:
            if let data = try? JSONSerialization.data(withJSONObject: rawValue),
               let str = String(data: data, encoding: .utf8) {
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
        case .string(let str):
            return str
        case .dictionary(let dict):
            return dict
        case .array(let array):
            return array
        case .null:
            return NSNull()
        }
    }
}

/// Output from a tool
public enum ToolOutput {
    case string(String)
    case dictionary([String: Any])
    case array([Any])
    case null
    case error(String)
    
    /// Convert to JSON string for the model
    public func toJSONString() throws -> String {
        let object: Any
        
        switch self {
        case .string(let str):
            return str // Return string directly for text output
        case .dictionary(let dict):
            object = dict
        case .array(let array):
            object = array
        case .null:
            return "null"
        case .error(let message):
            object = ["error": message]
        }
        
        let data = try JSONSerialization.data(withJSONObject: object, options: .prettyPrinted)
        guard let string = String(data: data, encoding: .utf8) else {
            throw ToolError.serializationFailed
        }
        return string
    }
}

// MARK: - Tool Errors

/// Errors that can occur during tool execution
public enum ToolError: Error, LocalizedError {
    case invalidInput(String)
    case executionFailed(String)
    case serializationFailed
    case contextMissing
    case toolNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid tool input: \(message)"
        case .executionFailed(let message):
            return "Tool execution failed: \(message)"
        case .serializationFailed:
            return "Failed to serialize tool output"
        case .contextMissing:
            return "Required context is missing"
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(T.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Tool Builder

/// Builder pattern for creating tools
public struct ToolBuilder<Context> {
    private var name: String = ""
    private var description: String = ""
    private var parameters: ToolParameters = ToolParameters()
    private var strict: Bool = true
    private var execute: ((ToolInput, Context) async throws -> ToolOutput)?
    
    public init() {}
    
    public func withName(_ name: String) -> ToolBuilder {
        var builder = self
        builder.name = name
        return builder
    }
    
    public func withDescription(_ description: String) -> ToolBuilder {
        var builder = self
        builder.description = description
        return builder
    }
    
    public func withParameters(_ parameters: ToolParameters) -> ToolBuilder {
        var builder = self
        builder.parameters = parameters
        return builder
    }
    
    public func withStrict(_ strict: Bool) -> ToolBuilder {
        var builder = self
        builder.strict = strict
        return builder
    }
    
    public func withExecution(_ execute: @escaping (ToolInput, Context) async throws -> ToolOutput) -> ToolBuilder {
        var builder = self
        builder.execute = execute
        return builder
    }
    
    public func build() throws -> Tool<Context> {
        guard !name.isEmpty else {
            throw ToolError.invalidInput("Tool name is required")
        }
        
        guard let execute = execute else {
            throw ToolError.invalidInput("Tool execution function is required")
        }
        
        return Tool(
            name: name,
            description: description,
            parameters: parameters,
            strict: strict,
            execute: execute
        )
    }
}