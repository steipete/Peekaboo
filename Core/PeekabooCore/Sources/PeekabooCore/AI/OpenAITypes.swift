import Foundation
import AXorcist

// MARK: - OpenAI API Types

public struct Assistant: Codable, Sendable {
    public let id: String
    public let object: String
    public let createdAt: Int
}

public struct Thread: Codable, Sendable {
    public let id: String
    public let object: String
    public let createdAt: Int
}

public struct Run: Codable, Sendable {
    public let id: String
    public let object: String
    public let status: Status
    public let requiredAction: RequiredAction?

    public enum Status: String, Codable, Sendable {
        case queued
        case inProgress = "in_progress"
        case requiresAction = "requires_action"
        case cancelling
        case cancelled
        case failed
        case completed
        case expired
    }
}

public struct RequiredAction: Codable, Sendable {
    public let type: String
    public let submitToolOutputs: SubmitToolOutputs
}

public struct SubmitToolOutputs: Codable, Sendable {
    public let toolCalls: [ToolCall]
}

public struct ToolCall: Codable, Sendable {
    public let id: String
    public let type: String
    public let function: OpenAIFunctionCall
}

public struct OpenAIFunctionCall: Codable, Sendable {
    public let name: String
    public let arguments: String
}

public struct Message: Codable, Sendable {
    public let id: String
    public let object: String
    public let role: String
    public let content: [OpenAIMessageContent]
    public let createdAt: Int
}

public struct OpenAIMessageContent: Codable, Sendable {
    public let type: String
    public let text: TextContent?
}

public struct TextContent: Codable, Sendable {
    public let value: String
}

public struct MessageList: Codable, Sendable {
    public let data: [Message]
}

// MARK: - Tool Definition

public struct OpenAITool: Codable, Sendable {
    public let type: String
    public let function: Function

    public init(type: String = "function", function: Function) {
        self.type = type
        self.function = function
    }
    
    // Nested types to match OpenAI API structure
    public struct Function: Codable, Sendable {
        public let name: String
        public let description: String
        public let parameters: Parameters
        
        public init(name: String, description: String, parameters: Parameters) {
            self.name = name
            self.description = description
            self.parameters = parameters
        }
    }
    
    public struct Parameters: Codable, Sendable {
        public let type: String
        // Using a JSON-serializable dictionary instead of [String: Any]
        public let propertiesJSON: String
        public let required: [String]
        
        public var properties: [String: Any] {
            guard let data = propertiesJSON.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return [:]
            }
            return dict
        }
        
        public init(type: String = "object", properties: [String: Any] = [:], required: [String] = []) {
            self.type = type
            // Convert properties to JSON string for Sendable conformance
            if let data = try? JSONSerialization.data(withJSONObject: properties),
               let json = String(data: data, encoding: .utf8) {
                self.propertiesJSON = json
            } else {
                self.propertiesJSON = "{}"
            }
            self.required = required
        }
        
        // Custom encoding/decoding for the properties dictionary
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(required, forKey: .required)
            
            // Encode properties as a JSON object
            if let data = propertiesJSON.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: data) {
                try container.encode(AnyEncodable(jsonObject), forKey: .properties)
            }
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.type = try container.decode(String.self, forKey: .type)
            self.required = try container.decode([String].self, forKey: .required)
            
            // Decode properties as Any
            if let anyProperties = try? container.decode(AnyDecodable.self, forKey: .properties),
               let dict = anyProperties.value as? [String: Any],
               let data = try? JSONSerialization.data(withJSONObject: dict),
               let json = String(data: data, encoding: .utf8) {
                self.propertiesJSON = json
            } else {
                self.propertiesJSON = "{}"
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case type, properties, required
        }
    }
}

// MARK: - Helper types for encoding/decoding Any

struct AnyEncodable: Encodable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        if let data = try? JSONSerialization.data(withJSONObject: value),
           let json = try? JSONSerialization.jsonObject(with: data) {
            try (json as? Encodable)?.encode(to: encoder)
        }
    }
}

struct AnyDecodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyDecodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyDecodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
}

// MARK: - Error Types

public struct OpenAIError: Codable, Sendable {
    public let error: ErrorDetail

    public struct ErrorDetail: Codable, Sendable {
        public let message: String
        public let type: String?
        public let code: String?
    }
}

// MARK: - Request Types

public struct AssistantRequest: Codable, Sendable {
    public let model: String
    public let name: String?
    public let description: String?
    public let instructions: String
    public let tools: [OpenAITool]

    public init(model: String, name: String? = nil, description: String? = nil, instructions: String, tools: [OpenAITool]) {
        self.model = model
        self.name = name
        self.description = description
        self.instructions = instructions
        self.tools = tools
    }
}

// MARK: - Chat Completion Types

/// OpenAI Chat Completion Request
public struct OpenAIChatCompletionRequest: Codable, Sendable {
    public let model: String
    public let messages: [OpenAIMessage]
    public let tools: [OpenAITool]?
    public let toolChoice: String?
    public let temperature: Double?
    public let topP: Double?
    public let stream: Bool?
    public let maxTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, tools
        case toolChoice = "tool_choice"
        case temperature
        case topP = "top_p"
        case stream
        case maxTokens = "max_tokens"
    }
    
    public init(
        model: String,
        messages: [OpenAIMessage],
        tools: [OpenAITool]? = nil,
        toolChoice: String? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        stream: Bool? = nil,
        maxTokens: Int? = nil
    ) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.toolChoice = toolChoice
        self.temperature = temperature
        self.topP = topP
        self.stream = stream
        self.maxTokens = maxTokens
    }
}

/// OpenAI Message for Chat Completion
public struct OpenAIMessage: Codable, Sendable {
    public let role: String
    public let content: OpenAIMessageContentUnion?
    public let name: String?
    public let toolCalls: [OpenAIToolCall]?
    public let toolCallId: String?
    
    enum CodingKeys: String, CodingKey {
        case role, content, name
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
    
    public init(
        role: String,
        content: OpenAIMessageContentUnion? = nil,
        name: String? = nil,
        toolCalls: [OpenAIToolCall]? = nil,
        toolCallId: String? = nil
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
}

/// Union type for message content
public enum OpenAIMessageContentUnion: Codable, Sendable {
    case string(String)
    case array([OpenAIMessageContentPart])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let array = try? container.decode([OpenAIMessageContentPart].self) {
            self = .array(array)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid message content")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let str):
            try container.encode(str)
        case .array(let array):
            try container.encode(array)
        }
    }
}

/// Part of a multipart message
public struct OpenAIMessageContentPart: Codable, Sendable {
    public let type: String
    public let text: String?
    public let imageUrl: OpenAIImageUrl?
    
    enum CodingKeys: String, CodingKey {
        case type, text
        case imageUrl = "image_url"
    }
}

/// Image URL for multipart content
public struct OpenAIImageUrl: Codable, Sendable {
    public let url: String
    public let detail: String?
}

/// OpenAI Tool Call
public struct OpenAIToolCall: Codable, Sendable {
    public let id: String
    public let type: String
    public let function: OpenAIFunctionCall
    
    public init(id: String, type: String = "function", function: OpenAIFunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// Chat Completion Response
public struct OpenAIChatCompletionResponse: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [OpenAIChoice]
    public let usage: OpenAIUsage?
}

/// Choice in a chat completion response
public struct OpenAIChoice: Codable, Sendable {
    public let index: Int
    public let message: OpenAIResponseMessage
    public let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

/// Response message
public struct OpenAIResponseMessage: Codable, Sendable {
    public let role: String
    public let content: String?
    public let toolCalls: [OpenAIToolCall]?
    
    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
    }
}

/// Usage statistics
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

/// Streaming response chunk
public struct OpenAIChatCompletionChunk: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [OpenAIStreamChoice]
}

/// Streaming choice
public struct OpenAIStreamChoice: Codable, Sendable {
    public let index: Int
    public let delta: OpenAIDelta
    public let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, delta
        case finishReason = "finish_reason"
    }
}

/// Delta in streaming response
public struct OpenAIDelta: Codable, Sendable {
    public let role: String?
    public let content: String?
    public let toolCalls: [OpenAIToolCallDelta]?
    
    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
    }
}

/// Tool call delta in streaming
public struct OpenAIToolCallDelta: Codable, Sendable {
    public let index: Int
    public let id: String?
    public let type: String?
    public let function: OpenAIFunctionCallDelta?
}

/// Function call delta
public struct OpenAIFunctionCallDelta: Codable, Sendable {
    public let name: String?
    public let arguments: String?
}

/// Error response
public struct OpenAIErrorResponse: Codable, Sendable {
    public let error: OpenAIError
}

// MARK: - Tool Choice Types

/// Tool choice for OpenAI API
public enum OpenAIToolChoice: Codable, Sendable {
    case string(String)
    case object(OpenAIToolChoiceObject)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let obj = try? container.decode(OpenAIToolChoiceObject.self) {
            self = .object(obj)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid tool choice")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let str):
            try container.encode(str)
        case .object(let obj):
            try container.encode(obj)
        }
    }
}

/// Tool choice object
public struct OpenAIToolChoiceObject: Codable, Sendable {
    public let type: String
    public let function: [String: String]
    
    public init(type: String, function: [String: String]) {
        self.type = type
        self.function = function
    }
}

// MARK: - Response Format Types

/// Response format for OpenAI API
public struct OpenAIResponseFormat: Codable, Sendable {
    public let type: String
    public let jsonSchema: OpenAIJSONSchema?
    
    enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }
    
    public init(type: String, jsonSchema: OpenAIJSONSchema? = nil) {
        self.type = type
        self.jsonSchema = jsonSchema
    }
}

/// JSON Schema for response format
public struct OpenAIJSONSchema: Codable, Sendable {
    public let name: String
    public let strict: Bool
    public let schema: AnyCodable
    
    public init(name: String, strict: Bool, schema: [String: Any]) {
        self.name = name
        self.strict = strict
        self.schema = AnyCodable(schema)
    }
}
