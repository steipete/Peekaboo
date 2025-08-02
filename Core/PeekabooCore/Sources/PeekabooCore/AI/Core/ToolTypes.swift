import Foundation

// MARK: - Tool Call

/// Represents a call to a tool made by the model
public struct ToolCall: Codable {
    public let id: String
    public let name: String
    public let arguments: [String: Any]
    
    public init(id: String, name: String, arguments: [String: Any]) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
    
    // Custom Codable implementation for [String: Any]
    enum CodingKeys: String, CodingKey {
        case id, name, arguments
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        if let data = try? container.decode(Data.self, forKey: .arguments),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            arguments = json
        } else {
            arguments = [:]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        
        if let data = try? JSONSerialization.data(withJSONObject: arguments) {
            try container.encode(data, forKey: .arguments)
        }
    }
}

// MARK: - Model Interface Protocol

/// Protocol for AI model interfaces
public protocol ModelInterface: Sendable {
    /// Send a message to the model and get a response
    func sendMessage(_ message: String, with context: [Message]) async throws -> String
    
    /// Send a request to the model
    func sendRequest(_ request: ModelRequest) async throws -> String
    
    /// Check if the model supports vision/image analysis
    var supportsVision: Bool { get }
    
    /// Get the model name
    var modelName: String { get }
}

// MARK: - Message Types

/// A message in a conversation
public struct Message: Codable, Sendable {
    public let role: String
    public let content: MessageContent
    
    public init(role: String, content: MessageContent) {
        self.role = role
        self.content = content
    }
}

/// Content of a message
public enum MessageContent: Codable, Sendable {
    case text(String)
    case multipart([MessagePart])
    
    enum CodingKeys: String, CodingKey {
        case type, text, parts
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try? container.decode(String.self, forKey: .text) {
            self = .text(text)
        } else if let parts = try? container.decode([MessagePart].self, forKey: .parts) {
            self = .multipart(parts)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown content type")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode(text, forKey: .text)
        case .multipart(let parts):
            try container.encode(parts, forKey: .parts)
        }
    }
}

/// Part of a multipart message
public enum MessagePart: Codable, Sendable {
    case text(String)
    case image(ImageContent)
    
    enum CodingKeys: String, CodingKey {
        case type, text, image
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image":
            let image = try container.decode(ImageContent.self, forKey: .image)
            self = .image(image)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown part type: \(type)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let image):
            try container.encode("image", forKey: .type)
            try container.encode(image, forKey: .image)
        }
    }
}

/// Image content for messages
public struct ImageContent: Codable, Sendable {
    public let url: String?
    public let base64: String?
    public let detail: ImageDetail?
    public let mediaType: String?
    
    public enum ImageDetail: String, Codable, Sendable {
        case auto
        case low
        case high
    }
    
    public init(url: String? = nil, base64: String? = nil, detail: ImageDetail? = nil, mediaType: String? = nil) {
        self.url = url
        self.base64 = base64
        self.detail = detail
        self.mediaType = mediaType
    }
}

// MARK: - Model Provider

/// Singleton for managing model instances
public final class ModelProvider: Sendable {
    public static let shared = ModelProvider()
    
    private init() {}
    
    /// Get or create a model instance
    public func getModel(name: String, providerType: String?) async throws -> any ModelInterface {
        // This is a placeholder - the actual implementation would manage model instances
        throw PeekabooError.invalidInput("ModelProvider.getModel not implemented")
    }
}

// MARK: - Model Request

/// Request to send to a model
public struct ModelRequest: Codable, Sendable {
    public let messages: [Message]
    public let temperature: Double?
    public let maxTokens: Int?
    
    public init(messages: [Message], temperature: Double? = nil, maxTokens: Int? = nil) {
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

// MARK: - Tool Parameter Types

/// Schema type for parameters
public enum ParameterSchemaType: String, Codable, Sendable {
    case string
    case number
    case integer
    case boolean
    case array
    case object
}

/// Schema definition for a parameter
public struct ParameterSchema: Codable, Sendable {
    public let type: ParameterSchemaType
    public let description: String?
    public let enumValues: [String]?
    public let pattern: String?
    public let minimum: Double?
    public let maximum: Double?
    public let items: ParameterSchemaItems?
    public let properties: [String: ParameterSchema]?
    public let required: [String]?
    
    public init(
        type: ParameterSchemaType,
        description: String? = nil,
        enumValues: [String]? = nil,
        pattern: String? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        items: ParameterSchemaItems? = nil,
        properties: [String: ParameterSchema]? = nil,
        required: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
        self.pattern = pattern
        self.minimum = minimum
        self.maximum = maximum
        self.items = items
        self.properties = properties
        self.required = required
    }
    
    // MARK: - Static Factory Methods
    
    /// Create a string parameter schema
    public static func string(description: String? = nil) -> ParameterSchema {
        ParameterSchema(type: .string, description: description)
    }
    
    /// Create an enumeration parameter schema
    public static func enumeration(_ values: [String], description: String? = nil) -> ParameterSchema {
        ParameterSchema(type: .string, description: description, enumValues: values)
    }
    
    /// Create an integer parameter schema
    public static func integer(description: String? = nil) -> ParameterSchema {
        ParameterSchema(type: .integer, description: description)
    }
    
    /// Create a boolean parameter schema
    public static func boolean(description: String? = nil) -> ParameterSchema {
        ParameterSchema(type: .boolean, description: description)
    }
    
    /// Create an object parameter schema
    public static func object(properties: [String: ParameterSchema], description: String? = nil) -> ParameterSchema {
        ParameterSchema(type: .object, description: description, properties: properties)
    }
    
    /// Create an array parameter schema
    public static func array(of itemSchema: ParameterSchema, description: String? = nil) -> ParameterSchema {
        ParameterSchema(type: .array, description: description, items: ParameterSchemaItems(value: itemSchema))
    }
}

/// Schema for parameter items (used in arrays)
public indirect enum ParameterSchemaItems: Codable, Sendable {
    case schema(ParameterSchema)
    
    public var value: ParameterSchema {
        switch self {
        case .schema(let schema):
            return schema
        }
    }
    
    public init(value: ParameterSchema) {
        self = .schema(value)
    }
}

/// Parameters for a tool function
public struct ToolParameters: Codable, Sendable {
    public let type: ParameterSchemaType
    public let properties: [String: ParameterSchema]
    public let required: [String]
    
    public init(
        type: ParameterSchemaType = .object,
        properties: [String: ParameterSchema] = [:],
        required: [String] = []
    ) {
        self.type = type
        self.properties = properties
        self.required = required
    }
    
    // MARK: - Static Factory Methods
    
    /// Create an object-type tool parameters
    public static func object(properties: [String: ParameterSchema], required: [String] = []) -> ToolParameters {
        ToolParameters(type: .object, properties: properties, required: required)
    }
}

/// Function definition for a tool
public struct FunctionDefinition: Codable, Sendable {
    public let name: String
    public let description: String
    public let parameters: ToolParameters
    
    public init(
        name: String,
        description: String,
        parameters: ToolParameters
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Tool definition
public struct ToolDefinition: Codable, Sendable {
    public let type: ToolType
    public let function: FunctionDefinition
    
    public enum ToolType: String, Codable, Sendable {
        case function
    }
    
    public init(type: ToolType = .function, function: FunctionDefinition) {
        self.type = type
        self.function = function
    }
}

/// Input to a tool function
public struct ToolInput: Codable {
    public let toolCallId: String
    public let name: String
    public let arguments: [String: Any]
    
    public init(toolCallId: String, name: String, arguments: [String: Any]) {
        self.toolCallId = toolCallId
        self.name = name
        self.arguments = arguments
    }
    
    // Custom coding to handle [String: Any]
    enum CodingKeys: String, CodingKey {
        case toolCallId, name, arguments
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        toolCallId = try container.decode(String.self, forKey: .toolCallId)
        name = try container.decode(String.self, forKey: .name)
        
        // Decode arguments as JSON object
        if let argumentsData = try? container.decode(Data.self, forKey: .arguments),
           let json = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] {
            arguments = json
        } else {
            arguments = [:]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(toolCallId, forKey: .toolCallId)
        try container.encode(name, forKey: .name)
        
        // Encode arguments as JSON data
        if let data = try? JSONSerialization.data(withJSONObject: arguments) {
            try container.encode(data, forKey: .arguments)
        }
    }
}

/// Output from a tool function
public enum ToolOutput: Sendable {
    case success(String)
    case error(message: String)
    
    /// Get the string content of the output
    public var content: String {
        switch self {
        case .success(let message):
            return message
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    /// Check if this is an error
    public var isError: Bool {
        switch self {
        case .error:
            return true
        case .success:
            return false
        }
    }
}

// MARK: - ToolInput Extensions

extension ToolInput {
    /// Get a string value from arguments
    public func string(_ key: String, default defaultValue: String? = nil) -> String? {
        arguments[key] as? String ?? defaultValue
    }
    
    /// Get an integer value from arguments
    public func int(_ key: String, default defaultValue: Int? = nil) -> Int? {
        if let value = arguments[key] as? Int {
            return value
        }
        if let value = arguments[key] as? Double {
            return Int(value)
        }
        if let value = arguments[key] as? String, let intValue = Int(value) {
            return intValue
        }
        return defaultValue
    }
    
    /// Get a boolean value from arguments
    public func bool(_ key: String, default defaultValue: Bool = false) -> Bool {
        arguments[key] as? Bool ?? defaultValue
    }
    
    /// Get a double value from arguments
    public func double(_ key: String, default defaultValue: Double? = nil) -> Double? {
        if let value = arguments[key] as? Double {
            return value
        }
        if let value = arguments[key] as? Int {
            return Double(value)
        }
        if let value = arguments[key] as? String, let doubleValue = Double(value) {
            return doubleValue
        }
        return defaultValue
    }
}