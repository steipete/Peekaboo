import Foundation

// MARK: - Helper Types

class GrokPartialToolCall {
    var id: String = ""
    var type: String = "function"
    var index: Int = 0
    var name: String?
    var arguments: String = ""

    init() {
        // Default initializer
    }

    init(from delta: GrokToolCallDelta) {
        self.id = delta.id ?? ""
        self.index = delta.index
        self.name = delta.function?.name
        self.arguments = delta.function?.arguments ?? ""
    }

    func update(with delta: GrokToolCallDelta) {
        if let funcName = delta.function?.name {
            self.name = funcName
        }
        if let args = delta.function?.arguments {
            self.arguments += args
        }
    }

    func toCompleted() -> FunctionCall? {
        guard let name else { return nil }
        return FunctionCall(name: name, arguments: self.arguments)
    }
}

// MARK: - Grok Request Types

struct GrokChatCompletionRequest: Encodable {
    let model: String
    let messages: [GrokMessage]
    let tools: [GrokTool]?
    let toolChoice: GrokToolChoice?
    let temperature: Double?
    let maxTokens: Int?
    let stream: Bool
    let frequencyPenalty: Double?
    let presencePenalty: Double?
    let stop: [String]?

    enum CodingKeys: String, CodingKey {
        case model, messages, tools, temperature, stream
        case toolChoice = "tool_choice"
        case maxTokens = "max_tokens"
        case frequencyPenalty = "frequency_penalty"
        case presencePenalty = "presence_penalty"
        case stop
    }
}

struct GrokMessage: Encodable {
    let role: String
    let content: GrokMessageContent?
    let toolCalls: [GrokToolCall]?
    let toolCallId: String?

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
}

enum GrokMessageContent: Encodable {
    case string(String)
    case array([GrokMessageContentPart])

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(text):
            try container.encode(text)
        case let .array(parts):
            try container.encode(parts)
        }
    }
}

struct GrokMessageContentPart: Encodable {
    let type: String
    let text: String?
    let imageUrl: GrokImageUrl?

    enum CodingKeys: String, CodingKey {
        case type, text
        case imageUrl = "image_url"
    }
}

struct GrokImageUrl: Encodable {
    let url: String
    let detail: String?
}

struct GrokToolCall: Encodable {
    let id: String
    let type: String
    let function: GrokFunctionCall
}

struct GrokFunctionCall: Encodable {
    let name: String
    let arguments: String
}

struct GrokTool: Encodable {
    let type: String
    let function: Function

    struct Function: Encodable {
        let name: String
        let description: String?
        let parameters: Parameters
    }

    struct Parameters: Encodable {
        let type: String
        let properties: [String: GrokPropertySchema]
        let required: [String]
    }
}

enum GrokToolChoice: Encodable {
    case string(String)
    case object(GrokToolChoiceObject)

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .object(obj):
            try container.encode(obj)
        }
    }
}

struct GrokToolChoiceObject: Encodable {
    let type: String
    let function: GrokToolChoiceFunction
}

struct GrokToolChoiceFunction: Encodable {
    let name: String
}

// MARK: - Response Types

struct GrokChatCompletionResponse: Decodable {
    let id: String
    let model: String
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Decodable {
        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Message: Decodable {
        let role: String
        let content: String?
        let toolCalls: [ToolCall]?

        enum CodingKeys: String, CodingKey {
            case role, content
            case toolCalls = "tool_calls"
        }

        struct ToolCall: Decodable {
            let id: String
            let type: String
            let function: Function

            struct Function: Decodable {
                let name: String
                let arguments: String
            }
        }
    }

    struct Usage: Decodable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - Streaming Types

struct GrokChatCompletionChunk: Decodable {
    let id: String
    let model: String
    let choices: [StreamChoice]
    let systemFingerprint: String?

    enum CodingKeys: String, CodingKey {
        case id, model, choices
        case systemFingerprint = "system_fingerprint"
    }

    struct StreamChoice: Decodable {
        let index: Int
        let delta: Delta
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index, delta
            case finishReason = "finish_reason"
        }

        struct Delta: Decodable {
            let role: String?
            let content: String?
            let toolCalls: [GrokToolCallDelta]?

            enum CodingKeys: String, CodingKey {
                case role, content
                case toolCalls = "tool_calls"
            }
        }
    }
}

struct GrokToolCallDelta: Decodable {
    let index: Int
    let id: String?
    let type: String?
    let function: StreamFunction?

    struct StreamFunction: Decodable {
        let name: String?
        let arguments: String?
    }
}

// MARK: - Error Types

struct GrokErrorResponse: Decodable {
    let error: GrokError

    var message: String {
        self.error.message
    }

    var code: String? {
        self.error.code
    }

    var type: String? {
        self.error.type
    }
}

struct GrokError: Decodable {
    let message: String
    let type: String
    let code: String?
}

// MARK: - Property Schema

/// Type-safe property schema for Grok tool parameters
struct GrokPropertySchema: Codable, Sendable {
    let type: String
    let description: String?
    let `enum`: [String]?
    let items: Box<GrokPropertySchema>?
    let properties: [String: GrokPropertySchema]?
    let minimum: Double?
    let maximum: Double?
    let pattern: String?
    let required: [String]?

    init(
        type: String,
        description: String? = nil,
        enum enumValues: [String]? = nil,
        items: GrokPropertySchema? = nil,
        properties: [String: GrokPropertySchema]? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        pattern: String? = nil,
        required: [String]? = nil)
    {
        self.type = type
        self.description = description
        self.enum = enumValues
        self.items = items.map(Box.init)
        self.properties = properties
        self.minimum = minimum
        self.maximum = maximum
        self.pattern = pattern
        self.required = required
    }

    /// Create from a ParameterSchema
    init(from schema: ParameterSchema) {
        self.type = schema.type.rawValue
        self.description = schema.description
        self.enum = schema.enumValues
        self.items = schema.items.map { Box(GrokPropertySchema(from: $0.value)) }
        self.properties = schema.properties?.mapValues { GrokPropertySchema(from: $0) }
        self.minimum = schema.minimum
        self.maximum = schema.maximum
        self.pattern = schema.pattern
        self.required = nil
    }
}

// MARK: - Extensions

/// Helper to convert ToolParameters to Grok-compatible structure
extension ToolParameters {
    func toGrokParameters() -> (type: String, properties: [String: GrokPropertySchema], required: [String]) {
        var grokProperties: [String: GrokPropertySchema] = [:]

        for (key, schema) in properties {
            grokProperties[key] = GrokPropertySchema(from: schema)
        }

        return (type: type, properties: grokProperties, required: required)
    }
}
