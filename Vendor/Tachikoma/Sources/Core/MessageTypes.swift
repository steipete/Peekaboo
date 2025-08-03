import Foundation

// MARK: - Unified Message Type

/// Unified message enum that provides type-safe message handling
public enum Message: Codable, Sendable {
    case system(id: String? = nil, content: String)
    case user(id: String? = nil, content: MessageContent)
    case assistant(id: String? = nil, content: [AssistantContent], status: MessageStatus = .completed)
    case tool(id: String? = nil, toolCallId: String, content: String)
    case reasoning(id: String? = nil, content: String)

    // MARK: - Properties

    /// Get the message type
    public var type: MessageType {
        switch self {
        case .system: .system
        case .user: .user
        case .assistant: .assistant
        case .tool: .tool
        case .reasoning: .reasoning
        }
    }

    /// Get the message ID
    public var id: String? {
        switch self {
        case let .system(id, _), let .user(id, _), let .assistant(id, _, _),
             let .tool(id, _, _), let .reasoning(id, _):
            id
        }
    }

    // MARK: - Codable Implementation

    private enum CodingKeys: String, CodingKey {
        case type, id, content, status, toolCallId
    }

    public enum MessageType: String, Codable {
        case system, user, assistant, tool, reasoning
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)
        let id = try container.decodeIfPresent(String.self, forKey: .id)

        switch type {
        case .system:
            let content = try container.decode(String.self, forKey: .content)
            self = .system(id: id, content: content)

        case .user:
            let content = try container.decode(MessageContent.self, forKey: .content)
            self = .user(id: id, content: content)

        case .assistant:
            let content = try container.decode([AssistantContent].self, forKey: .content)
            let status = try container.decodeIfPresent(MessageStatus.self, forKey: .status) ?? .completed
            self = .assistant(id: id, content: content, status: status)

        case .tool:
            let toolCallId = try container.decode(String.self, forKey: .toolCallId)
            let content = try container.decode(String.self, forKey: .content)
            self = .tool(id: id, toolCallId: toolCallId, content: content)

        case .reasoning:
            let content = try container.decode(String.self, forKey: .content)
            self = .reasoning(id: id, content: content)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        switch self {
        case let .system(id, content):
            try container.encodeIfPresent(id, forKey: .id)
            try container.encode(content, forKey: .content)

        case let .user(id, content):
            try container.encodeIfPresent(id, forKey: .id)
            try container.encode(content, forKey: .content)

        case let .assistant(id, content, status):
            try container.encodeIfPresent(id, forKey: .id)
            try container.encode(content, forKey: .content)
            try container.encode(status, forKey: .status)

        case let .tool(id, toolCallId, content):
            try container.encodeIfPresent(id, forKey: .id)
            try container.encode(toolCallId, forKey: .toolCallId)
            try container.encode(content, forKey: .content)

        case let .reasoning(id, content):
            try container.encodeIfPresent(id, forKey: .id)
            try container.encode(content, forKey: .content)
        }
    }
}

// MARK: - Content Types

/// User message content variants
public enum MessageContent: Codable, Sendable {
    case text(String)
    case image(ImageContent)
    case file(FileContent)
    case audio(AudioContent)
    case multimodal([MessageContentPart])

    // Custom coding for enum
    enum CodingKeys: String, CodingKey {
        case type, value
    }

    enum ContentType: String, Codable {
        case text, image, file, audio, multimodal
    }

    public init(from decoder: any Decoder) throws {
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
        case .audio:
            let value = try container.decode(AudioContent.self, forKey: .value)
            self = .audio(value)
        case .multimodal:
            let value = try container.decode([MessageContentPart].self, forKey: .value)
            self = .multimodal(value)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .text(value):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .image(value):
            try container.encode(ContentType.image, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .file(value):
            try container.encode(ContentType.file, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .audio(value):
            try container.encode(ContentType.audio, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .multimodal(value):
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
    public let filename: String?
    public let content: String?
    public let mimeType: String?

    public init(
        id: String? = nil,
        url: String? = nil,
        name: String? = nil,
        filename: String? = nil,
        content: String? = nil,
        mimeType: String? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.filename = filename
        self.content = content
        self.mimeType = mimeType
    }

    // Convenience constructor for test compatibility
    public init(filename: String, content: String, mimeType: String) {
        self.init(name: filename, filename: filename, content: content, mimeType: mimeType)
    }
}

/// Audio content for messages
public struct AudioContent: Codable, Sendable {
    public let url: String?
    public let base64: String?
    public let transcript: String?
    public let duration: TimeInterval?
    public let mimeType: String?

    public init(
        url: String? = nil,
        base64: String? = nil,
        transcript: String? = nil,
        duration: TimeInterval? = nil,
        mimeType: String? = nil
    ) {
        self.url = url
        self.base64 = base64
        self.transcript = transcript
        self.duration = duration
        self.mimeType = mimeType
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

    public init(from decoder: any Decoder) throws {
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

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .outputText(value):
            try container.encode(ContentType.text, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .refusal(value):
            try container.encode(ContentType.refusal, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .toolCall(value):
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
    case function
    case hosted = "hosted_tool"
    case computer
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
    case completed
    case failed
}

/// Message processing status
public enum MessageStatus: String, Codable, Sendable {
    case inProgress = "in_progress"
    case completed
    case incomplete
}

// MARK: - Helper Extensions

public extension AssistantContent {
    /// Extract text content if available
    var textContent: String? {
        switch self {
        case let .outputText(text):
            text
        case let .refusal(text):
            text
        case .toolCall:
            nil
        }
    }
}
