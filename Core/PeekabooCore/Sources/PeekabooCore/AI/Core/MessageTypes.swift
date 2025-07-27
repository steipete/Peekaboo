import Foundation
import AXorcist

// MARK: - Base Protocol for Message Items

/// Base protocol for all message items in the chat completion system
public protocol MessageItem: Codable, Sendable {
    var type: MessageItemType { get }
    var id: String? { get }
}

/// Enum representing all possible message item types
public enum MessageItemType: String, Codable, Sendable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
    case tool = "tool"
    case reasoning = "reasoning"
    case unknown = "unknown"
}

// MARK: - Concrete Message Types

/// System message containing instructions for the AI
public struct SystemMessageItem: MessageItem {
    public var type = MessageItemType.system
    public let id: String?
    public let content: String
    
    public init(id: String? = nil, content: String) {
        self.id = id
        self.content = content
    }
}

/// User message containing user input
public struct UserMessageItem: MessageItem {
    public var type = MessageItemType.user
    public let id: String?
    public let content: MessageContent
    
    public init(id: String? = nil, content: MessageContent) {
        self.id = id
        self.content = content
    }
}

/// Assistant message containing AI response
public struct AssistantMessageItem: MessageItem {
    public var type = MessageItemType.assistant
    public let id: String?
    public let content: [AssistantContent]
    public let status: MessageStatus
    
    public init(id: String? = nil, content: [AssistantContent], status: MessageStatus = .completed) {
        self.id = id
        self.content = content
        self.status = status
    }
}

/// Tool result message
public struct ToolMessageItem: MessageItem {
    public var type = MessageItemType.tool
    public let id: String?
    public let toolCallId: String
    public let content: String
    
    public init(id: String? = nil, toolCallId: String, content: String) {
        self.id = id
        self.toolCallId = toolCallId
        self.content = content
    }
}

/// Reasoning message for chain-of-thought
public struct ReasoningMessageItem: MessageItem {
    public var type = MessageItemType.reasoning
    public let id: String?
    public let content: String
    
    public init(id: String? = nil, content: String) {
        self.id = id
        self.content = content
    }
}

/// Unknown message type for forward compatibility
public struct UnknownMessageItem: MessageItem {
    public var type = MessageItemType.unknown
    public let id: String?
    public let rawData: [String: AnyCodable]
    
    public init(id: String? = nil, rawData: [String: Any]) {
        self.id = id
        self.rawData = rawData.mapValues { AnyCodable($0) }
    }
    
    // Custom codable implementation for rawData
    enum CodingKeys: String, CodingKey {
        case type, id, rawData
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        
        // Decode rawData as dictionary
        if let data = try? container.decode(Data.self, forKey: .rawData),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.rawData = dict.mapValues { AnyCodable($0) }
        } else {
            self.rawData = [:]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(id, forKey: .id)
        
        // Encode rawData as JSON data
        if let data = try? JSONSerialization.data(withJSONObject: rawData) {
            try container.encode(data, forKey: .rawData)
        }
    }
}

// MARK: - Content Types

/// User message content variants
public enum MessageContent: Codable, Sendable {
    case text(String)
    case image(ImageContent)
    case file(FileContent)
    case multimodal([MessageContentPart])
    
    // Custom coding for enum
    enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    enum ContentType: String, Codable {
        case text, image, file, multimodal
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)
        
        switch type {
        case .text:
            let value = try container.decode(String.self, forKey: .value)
            self = .text(value)
        case .image:
            let value = try container.decode(ImageContent.self, forKey: .value)
            self = .image(value)
        case .file:
            let value = try container.decode(FileContent.self, forKey: .value)
            self = .file(value)
        case .multimodal:
            let value = try container.decode([MessageContentPart].self, forKey: .value)
            self = .multimodal(value)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let value):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(value, forKey: .value)
        case .image(let value):
            try container.encode(ContentType.image, forKey: .type)
            try container.encode(value, forKey: .value)
        case .file(let value):
            try container.encode(ContentType.file, forKey: .type)
            try container.encode(value, forKey: .value)
        case .multimodal(let value):
            try container.encode(ContentType.multimodal, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}

/// Image content for messages
public struct ImageContent: Codable, Sendable {
    public let url: String?
    public let base64: String?
    public let detail: ImageDetail?
    
    public enum ImageDetail: String, Codable, Sendable {
        case auto, low, high
    }
    
    public init(url: String? = nil, base64: String? = nil, detail: ImageDetail? = nil) {
        self.url = url
        self.base64 = base64
        self.detail = detail
    }
}

/// File content for messages
public struct FileContent: Codable, Sendable {
    public let id: String?
    public let url: String?
    public let name: String?
    
    public init(id: String? = nil, url: String? = nil, name: String? = nil) {
        self.id = id
        self.url = url
        self.name = name
    }
}

/// Multimodal content part
public struct MessageContentPart: Codable, Sendable {
    public let type: String
    public let text: String?
    public let imageUrl: ImageContent?
    
    public init(type: String, text: String? = nil, imageUrl: ImageContent? = nil) {
        self.type = type
        self.text = text
        self.imageUrl = imageUrl
    }
}

/// Assistant response content variants
public enum AssistantContent: Codable, Sendable {
    case outputText(String)
    case refusal(String)
    case toolCall(ToolCallItem)
    
    // Custom coding
    enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    enum ContentType: String, Codable {
        case text, refusal, toolCall
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContentType.self, forKey: .type)
        
        switch type {
        case .text:
            let value = try container.decode(String.self, forKey: .value)
            self = .outputText(value)
        case .refusal:
            let value = try container.decode(String.self, forKey: .value)
            self = .refusal(value)
        case .toolCall:
            let value = try container.decode(ToolCallItem.self, forKey: .value)
            self = .toolCall(value)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .outputText(let value):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(value, forKey: .value)
        case .refusal(let value):
            try container.encode(ContentType.refusal, forKey: .type)
            try container.encode(value, forKey: .value)
        case .toolCall(let value):
            try container.encode(ContentType.toolCall, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}

// MARK: - Tool Call Types

/// Tool call item representing a function invocation
public struct ToolCallItem: Codable, Sendable {
    public let id: String
    public let type: ToolCallType
    public let function: FunctionCall
    public let status: ToolCallStatus?
    
    public init(id: String, type: ToolCallType = .function, function: FunctionCall, status: ToolCallStatus? = nil) {
        self.id = id
        self.type = type
        self.function = function
        self.status = status
    }
}

/// Types of tool calls
public enum ToolCallType: String, Codable, Sendable {
    case function = "function"
    case hosted = "hosted_tool"
    case computer = "computer"
}

/// Function call details
public struct FunctionCall: Codable, Sendable {
    public let name: String
    public let arguments: String
    
    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

/// Tool call execution status
public enum ToolCallStatus: String, Codable, Sendable {
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
}

/// Message processing status
public enum MessageStatus: String, Codable, Sendable {
    case inProgress = "in_progress"
    case completed = "completed"
    case incomplete = "incomplete"
}

// MARK: - Helper Extensions

// Removed convenience initializer to avoid naming conflict with enum case

extension AssistantContent {
    /// Extract text content if available
    public var textContent: String? {
        switch self {
        case .outputText(let text):
            return text
        case .refusal(let text):
            return text
        case .toolCall:
            return nil
        }
    }
}