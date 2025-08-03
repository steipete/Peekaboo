import Foundation

// MARK: - Helper Types

/// Sendable wrapper for Any values
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnySendable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            self.value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            self.value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            self.value = stringValue
        } else if let arrayValue = try? container.decode([AnySendable].self) {
            self.value = arrayValue.map(\.value)
        } else if let dictValue = try? container.decode([String: AnySendable].self) {
            self.value = dictValue.mapValues(\.value)
        } else {
            self.value = NSNull()
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self.value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnySendable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnySendable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - OpenAI API Request Types

/// Chat Completions API request format
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIChatRequest: Codable, Sendable {
    public let model: String
    public let messages: [OpenAIMessage]
    public let tools: [OpenAITool]?
    public let toolChoice: String?
    public let temperature: Double?
    public let topP: Double?
    public let stream: Bool?
    public let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model, messages, tools, temperature, stream
        case toolChoice = "tool_choice"
        case topP = "top_p"
        case maxTokens = "max_tokens"
    }
}

/// Responses API request format (for o3/o4 models)
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIResponsesRequest: Codable, Sendable {
    public let model: String
    public let input: [OpenAIMessage]
    public let tools: [OpenAIResponsesTool]?
    public let toolChoice: String?
    public let temperature: Double?
    public let topP: Double?
    public let stream: Bool?
    public let maxOutputTokens: Int?
    public let reasoning: OpenAIReasoning?

    enum CodingKeys: String, CodingKey {
        case model, input, tools, temperature, stream, reasoning
        case toolChoice = "tool_choice"
        case topP = "top_p"
        case maxOutputTokens = "max_output_tokens"
    }
}

/// OpenAI message format
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIMessage: Codable, Sendable {
    public let role: String
    public let content: MessageContent?
    public let toolCalls: [OpenAIToolCall]?
    public let toolCallId: String?

    public enum MessageContent: Codable, Sendable {
        case string(String)
        case array([OpenAIMessageContentPart])

        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
            } else if let arrayValue = try? container.decode([OpenAIMessageContentPart].self) {
                self = .array(arrayValue)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unable to decode message content")
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case let .string(value):
                try container.encode(value)
            case let .array(value):
                try container.encode(value)
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }

    public init(
        role: String,
        content: MessageContent? = nil,
        toolCalls: [OpenAIToolCall]? = nil,
        toolCallId: String? = nil)
    {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
}

/// OpenAI message content part for multimodal messages
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIMessageContentPart: Codable, Sendable {
    public let type: String
    public let text: String?
    public let imageUrl: OpenAIImageUrl?

    enum CodingKeys: String, CodingKey {
        case type, text
        case imageUrl = "image_url"
    }

    public init(type: String, text: String? = nil, imageUrl: OpenAIImageUrl? = nil) {
        self.type = type
        self.text = text
        self.imageUrl = imageUrl
    }
}

/// OpenAI image URL format
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIImageUrl: Codable, Sendable {
    public let url: String
    public let detail: String?

    public init(url: String, detail: String? = nil) {
        self.url = url
        self.detail = detail
    }
}

/// OpenAI tool definition for Chat Completions API
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAITool: Codable, Sendable {
    public let type: String
    public let function: OpenAIFunction

    public init(type: String, function: OpenAIFunction) {
        self.type = type
        self.function = function
    }
}

/// OpenAI tool definition for Responses API
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIResponsesTool: Codable, Sendable {
    public let type: String
    public let name: String
    public let description: String
    public let parameters: [String: AnySendable]

    enum CodingKeys: String, CodingKey {
        case type, name, description, parameters
    }

    public init(type: String, name: String, description: String, parameters: [String: Any]) {
        self.type = type
        self.name = name
        self.description = description
        self.parameters = parameters.mapValues { AnySendable($0) }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)

        // Decode parameters as generic JSON
        let parametersContainer = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .parameters)
        var parameters: [String: AnySendable] = [:]
        for key in parametersContainer.allKeys {
            parameters[key.stringValue] = try parametersContainer.decode(AnySendable.self, forKey: key)
        }
        self.parameters = parameters
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.description, forKey: .description)

        // Skip encoding parameters for now - this needs to be handled at runtime
        try container.encodeIfPresent(nil as String?, forKey: .parameters)
    }
}

/// OpenAI function definition
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIFunction: Codable, Sendable {
    public let name: String
    public let description: String?
    public let parameters: [String: AnySendable]?
    public let arguments: String?

    enum CodingKeys: String, CodingKey {
        case name, description, parameters, arguments
    }

    public init(name: String, description: String? = nil, parameters: [String: Any]? = nil, arguments: String? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters?.mapValues { AnySendable($0) }
        self.arguments = arguments
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.arguments = try container.decodeIfPresent(String.self, forKey: .arguments)

        if container.contains(.parameters) {
            let parametersContainer = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .parameters)
            var parameters: [String: AnySendable] = [:]
            for key in parametersContainer.allKeys {
                parameters[key.stringValue] = try parametersContainer.decode(AnySendable.self, forKey: key)
            }
            self.parameters = parameters
        } else {
            self.parameters = nil
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encodeIfPresent(self.description, forKey: .description)
        try container.encodeIfPresent(self.arguments, forKey: .arguments)

        if let parameters {
            // Convert AnySendable parameters to AnyCodable for encoding
            let codableParams = parameters.mapValues { AnyCodable($0.value) }
            try container.encode(codableParams, forKey: .parameters)
        }
    }
}

/// OpenAI tool call
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIToolCall: Codable, Sendable {
    public let id: String
    public let type: String
    public let function: OpenAIFunction

    public init(id: String, type: String, function: OpenAIFunction) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// OpenAI reasoning configuration for o3/o4 models
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIReasoning: Codable, Sendable {
    public let effort: String
    public let summary: String

    public init(effort: String, summary: String) {
        self.effort = effort
        self.summary = summary
    }
}

// MARK: - OpenAI Response Types

/// OpenAI Chat Completions response
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIResponse: Codable, Sendable {
    public let id: String
    public let model: String
    public let choices: [OpenAIChoice]
    public let usage: OpenAIUsage?
}

/// OpenAI response choice
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIChoice: Codable, Sendable {
    public let message: OpenAIMessage
    public let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

/// OpenAI usage information
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIUsage: Codable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - OpenAI Streaming Types

/// OpenAI streaming chunk
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIStreamChunk: Codable, Sendable {
    public let id: String?
    public let model: String?
    public let choices: [OpenAIStreamChoice]?
}

/// OpenAI streaming choice
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIStreamChoice: Codable, Sendable {
    public let delta: OpenAIStreamDelta?
    public let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

/// OpenAI streaming delta
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIStreamDelta: Codable, Sendable {
    public let content: String?
    public let toolCalls: [OpenAIStreamToolCall]?

    enum CodingKeys: String, CodingKey {
        case content
        case toolCalls = "tool_calls"
    }
}

/// OpenAI streaming tool call
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIStreamToolCall: Codable, Sendable {
    public let id: String?
    public let type: String?
    public let index: Int?
    public let function: OpenAIStreamFunction?
}

/// OpenAI streaming function
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIStreamFunction: Codable, Sendable {
    public let name: String?
    public let arguments: String?
}

// MARK: - Error Types

/// OpenAI error response
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIErrorResponse: Codable, Sendable {
    public let error: OpenAIError
}

/// OpenAI error details
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct OpenAIError: Codable, Sendable {
    public let message: String
    public let type: String?
    public let code: String?
}

// MARK: - Helper Types

/// Dynamic coding key for JSON encoding/decoding
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

/// Wrapper for any codable value
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else {
            let data = try JSONSerialization.data(withJSONObject: self.value)
            let str = String(data: data, encoding: .utf8) ?? "{}"
            try container.encode(str)
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            self.value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            self.value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            self.value = boolValue
        } else {
            self.value = NSNull()
        }
    }
}

// MARK: - Container Extensions

// Note: Complex Any encoding/decoding extensions removed
// We use AnySendable for type-safe handling of dynamic JSON data
