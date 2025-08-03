import Foundation

// MARK: - Anthropic API Request Types

/// Cache control configuration
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicCacheControl: Codable, Sendable {
    public let type: String // "ephemeral"

    public init(type: String = "ephemeral") {
        self.type = type
    }
}

/// System content that can be cached
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum AnthropicSystemContent: Codable, Sendable {
    case string(String)
    case array([AnthropicSystemBlock])

    // Custom encoding/decoding
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([AnthropicSystemBlock].self) {
            self = .array(arrayValue)
        } else {
            throw DecodingError.typeMismatch(
                AnthropicSystemContent.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String or Array of system blocks"
                )
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .array(blocks):
            try container.encode(blocks)
        }
    }
}

/// System block that can contain cache control
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicSystemBlock: Codable, Sendable {
    public let type: String // "text"
    public let text: String
    public let cacheControl: AnthropicCacheControl?

    enum CodingKeys: String, CodingKey {
        case type, text
        case cacheControl = "cache_control"
    }

    public init(type: String = "text", text: String, cacheControl: AnthropicCacheControl? = nil) {
        self.type = type
        self.text = text
        self.cacheControl = cacheControl
    }
}

/// Main request structure for Anthropic's Messages API
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicRequest: Codable, Sendable {
    /// ID of the model to use (e.g., "claude-3-opus-20240229")
    public let model: String

    /// Input messages
    public let messages: [AnthropicMessage]

    /// System prompt (separate from messages)
    public let system: AnthropicSystemContent?

    /// Maximum number of tokens to generate
    public let maxTokens: Int

    /// Temperature for randomness (0.0 to 1.0)
    public let temperature: Double?

    /// Top-p sampling parameter
    public let topP: Double?

    /// Top-k sampling parameter
    public let topK: Int?

    /// Whether to stream the response
    public let stream: Bool?

    /// Stop sequences
    public let stopSequences: [String]?

    /// Available tools
    public let tools: [AnthropicTool]?

    /// Tool choice configuration
    public let toolChoice: AnthropicToolChoice?

    /// Metadata about the request
    public let metadata: AnthropicMetadata?

    enum CodingKeys: String, CodingKey {
        case model, messages, system
        case maxTokens = "max_tokens"
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case stream
        case stopSequences = "stop_sequences"
        case tools
        case toolChoice = "tool_choice"
        case metadata
    }
}

/// Anthropic message structure
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicMessage: Codable, Sendable {
    /// Role of the message sender
    public let role: AnthropicRole

    /// Content of the message
    public let content: AnthropicContent

    public init(role: AnthropicRole, content: AnthropicContent) {
        self.role = role
        self.content = content
    }
}

/// Message roles in Anthropic API
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum AnthropicRole: String, Codable, Sendable {
    case user
    case assistant
}

/// Content types for Anthropic messages
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum AnthropicContent: Codable, Sendable {
    case string(String)
    case array([AnthropicContentBlock])

    // Custom encoding/decoding
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([AnthropicContentBlock].self) {
            self = .array(arrayValue)
        } else {
            throw DecodingError.typeMismatch(
                AnthropicContent.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String or Array of content blocks"
                )
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .array(blocks):
            try container.encode(blocks)
        }
    }
}

/// Content block for multimodal messages
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicContentBlock: Codable, Sendable {
    public let type: String

    // Text content
    public let text: String?

    // Image content
    public let source: AnthropicImageSource?

    // Tool use content
    public let id: String?
    public let name: String?
    public let input: [String: AnthropicInputValue]?

    // Tool result content
    public let toolUseId: String?
    public let content: AnthropicContent?
    public let isError: Bool?

    // Cache control
    public let cacheControl: AnthropicCacheControl?

    enum CodingKeys: String, CodingKey {
        case type, text, source, id, name, input
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
        case cacheControl = "cache_control"
    }
}

/// Image source for content blocks
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicImageSource: Codable, Sendable {
    public let type: String // "base64"
    public let mediaType: String // "image/jpeg", "image/png", etc.
    public let data: String // base64 encoded image data

    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}

// MARK: - Tool Definitions

/// Tool definition for Anthropic
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicTool: Codable, Sendable {
    public let name: String
    public let description: String
    public let inputSchema: AnthropicJSONSchema
    public let cacheControl: AnthropicCacheControl?

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
        case cacheControl = "cache_control"
    }

    public init(
        name: String,
        description: String,
        inputSchema: AnthropicJSONSchema,
        cacheControl: AnthropicCacheControl? = nil
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.cacheControl = cacheControl
    }
}

/// JSON Schema for tool parameters
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicJSONSchema: Codable, Sendable {
    public let type: String
    public let properties: [String: AnthropicPropertySchema]?
    public let required: [String]?
    public let description: String?

    public init(
        type: String = "object",
        properties: [String: AnthropicPropertySchema]? = nil,
        required: [String]? = nil,
        description: String? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.description = description
    }
}

/// Tool choice configuration
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum AnthropicToolChoice: Codable, Sendable {
    case auto
    case any
    case tool(name: String)

    // Custom encoding/decoding
    enum CodingKeys: String, CodingKey {
        case type, name
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "auto":
            self = .auto
        case "any":
            self = .any
        case "tool":
            let name = try container.decode(String.self, forKey: .name)
            self = .tool(name: name)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown tool choice type: \(type)"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .auto:
            try container.encode("auto", forKey: .type)
        case .any:
            try container.encode("any", forKey: .type)
        case let .tool(name):
            try container.encode("tool", forKey: .type)
            try container.encode(name, forKey: .name)
        }
    }
}

/// Metadata for requests
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicMetadata: Codable, Sendable {
    public let userId: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

// MARK: - Response Types

/// Response from Anthropic's Messages API
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicResponse: Codable, Sendable {
    public let id: String
    public let type: String
    public let role: AnthropicRole
    public let content: [AnthropicContentBlock]
    public let model: String
    public let stopReason: String?
    public let stopSequence: String?
    public let usage: AnthropicUsage

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }
}

/// Usage statistics
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicUsage: Codable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Streaming Types

/// Server-sent event for streaming
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicStreamEvent: Codable, Sendable {
    public let type: String

    // Common fields
    public let index: Int?
    public let delta: AnthropicDelta?

    // Message start
    public let message: AnthropicStreamMessage?

    // Content block start
    public let contentBlock: AnthropicContentBlock?

    // Message complete
    public let usage: AnthropicUsage?
    public let stopReason: String?
    public let stopSequence: String?

    // Error
    public let error: AnthropicError?

    enum CodingKeys: String, CodingKey {
        case type, index, delta, message
        case contentBlock = "content_block"
        case usage
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case error
    }
}

/// Stream message metadata
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicStreamMessage: Codable, Sendable {
    public let id: String
    public let type: String
    public let role: AnthropicRole
    public let content: [AnthropicContentBlock]
    public let model: String
    public let usage: AnthropicUsage

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model, usage
    }
}

/// Delta updates for streaming
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicDelta: Codable, Sendable {
    // Text delta
    public let text: String?

    // Message delta fields
    public let stopReason: String?
    public let stopSequence: String?

    // Tool use delta
    public let type: String?
    public let partialJson: String?

    enum CodingKeys: String, CodingKey {
        case text
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case type
        case partialJson = "partial_json"
    }
}

// MARK: - Error Types

/// Anthropic error response
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicErrorResponse: Codable, Sendable {
    public let error: AnthropicError

    public var message: String {
        error.message
    }

    public var code: String? {
        nil // Anthropic doesn't provide error codes
    }

    public var type: String? {
        error.type
    }
}

/// Error details
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicError: Codable, Sendable {
    public let type: String
    public let message: String
}

// MARK: - Helper Extensions

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public extension AnthropicContentBlock {
    /// Create a text content block
    static func text(_ text: String, cacheControl: AnthropicCacheControl? = nil) -> AnthropicContentBlock {
        AnthropicContentBlock(
            type: "text",
            text: text,
            source: nil,
            id: nil,
            name: nil,
            input: nil,
            toolUseId: nil,
            content: nil,
            isError: nil,
            cacheControl: cacheControl
        )
    }

    /// Create an image content block
    static func image(
        base64: String,
        mediaType: String,
        cacheControl: AnthropicCacheControl? = nil
    ) -> AnthropicContentBlock {
        AnthropicContentBlock(
            type: "image",
            text: nil,
            source: AnthropicImageSource(
                type: "base64",
                mediaType: mediaType,
                data: base64
            ),
            id: nil,
            name: nil,
            input: nil,
            toolUseId: nil,
            content: nil,
            isError: nil,
            cacheControl: cacheControl
        )
    }

    /// Create a tool use content block
    static func toolUse(id: String, name: String, input: [String: Any]) -> AnthropicContentBlock {
        AnthropicContentBlock(
            type: "tool_use",
            text: nil,
            source: nil,
            id: id,
            name: name,
            input: input.compactMapValues { AnthropicInputValue(from: $0) },
            toolUseId: nil,
            content: nil,
            isError: nil,
            cacheControl: nil
        )
    }

    /// Create a tool result content block
    static func toolResult(toolUseId: String, content: String, isError: Bool = false) -> AnthropicContentBlock {
        AnthropicContentBlock(
            type: "tool_result",
            text: nil,
            source: nil,
            id: nil,
            name: nil,
            input: nil,
            toolUseId: toolUseId,
            content: .string(content),
            isError: isError,
            cacheControl: nil
        )
    }
}

// MARK: - Input Value Types

/// Type-safe input value for Anthropic tool use
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum AnthropicInputValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnthropicInputValue])
    case object([String: AnthropicInputValue])
    case null

    // MARK: - Codable

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let array = try? container.decode([AnthropicInputValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: AnthropicInputValue].self) {
            self = .object(dict)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnthropicInputValue")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .string(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .array(values):
            try container.encode(values)
        case let .object(dict):
            try container.encode(dict)
        case .null:
            try container.encodeNil()
        }
    }

    // MARK: - Conversion

    /// Convert from Any value (for migration)
    public init?(from value: Any) {
        switch value {
        case let string as String:
            self = .string(string)
        case let int as Int:
            self = .int(int)
        case let double as Double:
            self = .double(double)
        case let bool as Bool:
            self = .bool(bool)
        case let array as [Any]:
            let values = array.compactMap { AnthropicInputValue(from: $0) }
            if values.count == array.count {
                self = .array(values)
            } else {
                return nil
            }
        case let dict as [String: Any]:
            var values: [String: AnthropicInputValue] = [:]
            for (key, val) in dict {
                if let inputValue = AnthropicInputValue(from: val) {
                    values[key] = inputValue
                } else {
                    return nil
                }
            }
            self = .object(values)
        case is NSNull:
            self = .null
        default:
            return nil
        }
    }

    /// Convert to Any (for JSON serialization)
    public func toAny() -> Any {
        switch self {
        case let .string(value):
            value
        case let .int(value):
            value
        case let .double(value):
            value
        case let .bool(value):
            value
        case let .array(values):
            values.map { $0.toAny() }
        case let .object(dict):
            dict.mapValues { $0.toAny() }
        case .null:
            NSNull()
        }
    }
}

/// Type-safe property schema for Anthropic JSON Schema
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnthropicPropertySchema: Codable, Sendable {
    public let type: String
    public let description: String?
    public let `enum`: [String]?
    public let items: Box<AnthropicPropertySchema>?
    public let properties: [String: AnthropicPropertySchema]?
    public let required: [String]?

    public init(
        type: String,
        description: String? = nil,
        enum enumValues: [String]? = nil,
        items: AnthropicPropertySchema? = nil,
        properties: [String: AnthropicPropertySchema]? = nil,
        required: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.enum = enumValues
        self.items = items.map(Box.init)
        self.properties = properties
        self.required = required
    }
}
