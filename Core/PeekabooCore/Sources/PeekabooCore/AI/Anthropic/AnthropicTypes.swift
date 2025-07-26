import Foundation
import AXorcist

// MARK: - Anthropic API Request Types

/// Main request structure for Anthropic's Messages API
public struct AnthropicRequest: Codable, Sendable {
    /// ID of the model to use (e.g., "claude-3-opus-20240229")
    public let model: String
    
    /// Input messages
    public let messages: [AnthropicMessage]
    
    /// System prompt (separate from messages)
    public let system: String?
    
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
public enum AnthropicRole: String, Codable, Sendable {
    case user
    case assistant
}

/// Content types for Anthropic messages
public enum AnthropicContent: Codable, Sendable {
    case string(String)
    case array([AnthropicContentBlock])
    
    // Custom encoding/decoding
    public init(from decoder: Decoder) throws {
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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .array(let blocks):
            try container.encode(blocks)
        }
    }
}

/// Content block for multimodal messages
public struct AnthropicContentBlock: Codable, Sendable {
    public let type: String
    
    // Text content
    public let text: String?
    
    // Image content
    public let source: AnthropicImageSource?
    
    // Tool use content
    public let id: String?
    public let name: String?
    public let input: [String: AnyCodable]?
    
    // Tool result content
    public let toolUseId: String?
    public let content: AnthropicContent?
    public let isError: Bool?
    
    enum CodingKeys: String, CodingKey {
        case type, text, source, id, name, input
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
    }
}

/// Image source for content blocks
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
public struct AnthropicTool: Codable, Sendable {
    public let name: String
    public let description: String
    public let inputSchema: AnthropicJSONSchema
    
    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

/// JSON Schema for tool parameters
public struct AnthropicJSONSchema: Codable, Sendable {
    public let type: String
    public let properties: [String: AnyCodable]?
    public let required: [String]?
    public let description: String?
    
    // Custom encoding/decoding for properties
    enum CodingKeys: String, CodingKey {
        case type, properties, required, description
    }
    
    public init(type: String = "object", properties: [String: Any]? = nil, required: [String]? = nil, description: String? = nil) {
        self.type = type
        self.properties = properties?.mapValues { AnyCodable($0) }
        self.required = required
        self.description = description
    }
}

/// Tool choice configuration
public enum AnthropicToolChoice: Codable, Sendable {
    case auto
    case any
    case tool(name: String)
    
    // Custom encoding/decoding
    enum CodingKeys: String, CodingKey {
        case type, name
    }
    
    public init(from decoder: Decoder) throws {
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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .auto:
            try container.encode("auto", forKey: .type)
        case .any:
            try container.encode("any", forKey: .type)
        case .tool(let name):
            try container.encode("tool", forKey: .type)
            try container.encode(name, forKey: .name)
        }
    }
}

/// Metadata for requests
public struct AnthropicMetadata: Codable, Sendable {
    public let userId: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

// MARK: - Response Types

/// Response from Anthropic's Messages API
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
public struct AnthropicDelta: Codable, Sendable {
    // Text delta
    public let text: String?
    
    // Tool use delta
    public let type: String?
    public let partialJson: String?
    
    enum CodingKeys: String, CodingKey {
        case text, type
        case partialJson = "partial_json"
    }
}

// MARK: - Error Types

/// Anthropic error response
public struct AnthropicErrorResponse: Codable, Sendable {
    public let error: AnthropicError
}

/// Error details
public struct AnthropicError: Codable, Sendable {
    public let type: String
    public let message: String
}

// MARK: - Helper Extensions

extension AnthropicContentBlock {
    /// Create a text content block
    public static func text(_ text: String) -> AnthropicContentBlock {
        AnthropicContentBlock(
            type: "text",
            text: text,
            source: nil,
            id: nil,
            name: nil,
            input: nil,
            toolUseId: nil,
            content: nil,
            isError: nil
        )
    }
    
    /// Create an image content block
    public static func image(base64: String, mediaType: String) -> AnthropicContentBlock {
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
            isError: nil
        )
    }
    
    /// Create a tool use content block
    public static func toolUse(id: String, name: String, input: [String: Any]) -> AnthropicContentBlock {
        AnthropicContentBlock(
            type: "tool_use",
            text: nil,
            source: nil,
            id: id,
            name: name,
            input: input.mapValues { AnyCodable($0) },
            toolUseId: nil,
            content: nil,
            isError: nil
        )
    }
    
    /// Create a tool result content block
    public static func toolResult(toolUseId: String, content: String, isError: Bool = false) -> AnthropicContentBlock {
        AnthropicContentBlock(
            type: "tool_result",
            text: nil,
            source: nil,
            id: nil,
            name: nil,
            input: nil,
            toolUseId: toolUseId,
            content: .string(content),
            isError: isError
        )
    }
}