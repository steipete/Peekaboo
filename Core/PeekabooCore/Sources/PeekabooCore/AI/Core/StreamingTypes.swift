import Foundation

// MARK: - Streaming Event Types

/// Base protocol for all streaming events
public protocol StreamingEvent: Codable, Sendable {
    var type: StreamEventType { get }
}

/// Types of streaming events
public enum StreamEventType: String, Codable, Sendable {
    case textDelta = "text_delta"
    case responseStarted = "response_started"
    case responseCompleted = "response_completed"
    case toolCallDelta = "tool_call_delta"
    case toolCallCompleted = "tool_call_completed"
    case functionCallArgumentsDelta = "function_call_arguments_delta"
    case error = "error"
    case unknown = "unknown"
    case reasoningSummaryDelta = "reasoning_summary_delta"
    case reasoningSummaryCompleted = "reasoning_summary_completed"
}

/// Main streaming event enum that encompasses all event types
public enum StreamEvent: Codable, Sendable {
    case textDelta(StreamTextDelta)
    case responseStarted(StreamResponseStarted)
    case responseCompleted(StreamResponseCompleted)
    case toolCallDelta(StreamToolCallDelta)
    case toolCallCompleted(StreamToolCallCompleted)
    case functionCallArgumentsDelta(StreamFunctionCallArgumentsDelta)
    case error(StreamError)
    case unknown(StreamUnknown)
    case reasoningSummaryDelta(StreamReasoningSummaryDelta)
    case reasoningSummaryCompleted(StreamReasoningSummaryCompleted)
    
    // Custom coding for the enum
    enum CodingKeys: String, CodingKey {
        case type, data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(StreamEventType.self, forKey: .type)
        
        switch type {
        case .textDelta:
            let data = try container.decode(StreamTextDelta.self, forKey: .data)
            self = .textDelta(data)
        case .responseStarted:
            let data = try container.decode(StreamResponseStarted.self, forKey: .data)
            self = .responseStarted(data)
        case .responseCompleted:
            let data = try container.decode(StreamResponseCompleted.self, forKey: .data)
            self = .responseCompleted(data)
        case .toolCallDelta:
            let data = try container.decode(StreamToolCallDelta.self, forKey: .data)
            self = .toolCallDelta(data)
        case .toolCallCompleted:
            let data = try container.decode(StreamToolCallCompleted.self, forKey: .data)
            self = .toolCallCompleted(data)
        case .functionCallArgumentsDelta:
            let data = try container.decode(StreamFunctionCallArgumentsDelta.self, forKey: .data)
            self = .functionCallArgumentsDelta(data)
        case .error:
            let data = try container.decode(StreamError.self, forKey: .data)
            self = .error(data)
        case .unknown:
            let data = try container.decode(StreamUnknown.self, forKey: .data)
            self = .unknown(data)
        case .reasoningSummaryDelta:
            let data = try container.decode(StreamReasoningSummaryDelta.self, forKey: .data)
            self = .reasoningSummaryDelta(data)
        case .reasoningSummaryCompleted:
            let data = try container.decode(StreamReasoningSummaryCompleted.self, forKey: .data)
            self = .reasoningSummaryCompleted(data)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .textDelta(let data):
            try container.encode(StreamEventType.textDelta, forKey: .type)
            try container.encode(data, forKey: .data)
        case .responseStarted(let data):
            try container.encode(StreamEventType.responseStarted, forKey: .type)
            try container.encode(data, forKey: .data)
        case .responseCompleted(let data):
            try container.encode(StreamEventType.responseCompleted, forKey: .type)
            try container.encode(data, forKey: .data)
        case .toolCallDelta(let data):
            try container.encode(StreamEventType.toolCallDelta, forKey: .type)
            try container.encode(data, forKey: .data)
        case .toolCallCompleted(let data):
            try container.encode(StreamEventType.toolCallCompleted, forKey: .type)
            try container.encode(data, forKey: .data)
        case .functionCallArgumentsDelta(let data):
            try container.encode(StreamEventType.functionCallArgumentsDelta, forKey: .type)
            try container.encode(data, forKey: .data)
        case .error(let data):
            try container.encode(StreamEventType.error, forKey: .type)
            try container.encode(data, forKey: .data)
        case .unknown(let data):
            try container.encode(StreamEventType.unknown, forKey: .type)
            try container.encode(data, forKey: .data)
        case .reasoningSummaryDelta(let data):
            try container.encode(StreamEventType.reasoningSummaryDelta, forKey: .type)
            try container.encode(data, forKey: .data)
        case .reasoningSummaryCompleted(let data):
            try container.encode(StreamEventType.reasoningSummaryCompleted, forKey: .type)
            try container.encode(data, forKey: .data)
        }
    }
}

// MARK: - Concrete Streaming Event Types

/// Text delta event containing incremental text output
public struct StreamTextDelta: StreamingEvent, Codable, Sendable {
    public var type = StreamEventType.textDelta
    public let delta: String
    public let index: Int?
    
    public init(delta: String, index: Int? = nil) {
        self.delta = delta
        self.index = index
    }
}

/// Response started event
public struct StreamResponseStarted: StreamingEvent, Codable, Sendable {
    public var type = StreamEventType.responseStarted
    public let id: String
    public let model: String?
    public let systemFingerprint: String?
    
    public init(id: String, model: String? = nil, systemFingerprint: String? = nil) {
        self.id = id
        self.model = model
        self.systemFingerprint = systemFingerprint
    }
}

/// Response completed event with final metadata
public struct StreamResponseCompleted: StreamingEvent, Codable, Sendable {
    public var type = StreamEventType.responseCompleted
    public let id: String
    public let usage: Usage?
    public let finishReason: FinishReason?
    
    public init(id: String, usage: Usage? = nil, finishReason: FinishReason? = nil) {
        self.id = id
        self.usage = usage
        self.finishReason = finishReason
    }
}

/// Tool call delta event for incremental tool call information
public struct StreamToolCallDelta: StreamingEvent, Codable, Sendable {
    public var type = StreamEventType.toolCallDelta
    public let id: String
    public let index: Int
    public let function: FunctionCallDelta
    
    public init(id: String, index: Int, function: FunctionCallDelta) {
        self.id = id
        self.index = index
        self.function = function
    }
}

/// Tool call completed event
public struct StreamToolCallCompleted: StreamingEvent, Codable, Sendable {
    public var type = StreamEventType.toolCallCompleted
    public let id: String
    public let function: FunctionCall
    
    public init(id: String, function: FunctionCall) {
        self.id = id
        self.function = function
    }
}

/// Function call arguments delta event for incremental function call argument information
public struct StreamFunctionCallArgumentsDelta: StreamingEvent, Codable, Sendable {
    public var type = StreamEventType.functionCallArgumentsDelta
    public let id: String
    public let arguments: String
    
    public init(id: String, arguments: String) {
        self.id = id
        self.arguments = arguments
    }
}

/// Error event for stream errors
public struct StreamError: StreamingEvent, Codable, Sendable {
    public var type = StreamEventType.error
    public let error: ErrorDetail
    
    public init(error: ErrorDetail) {
        self.error = error
    }
}

/// Unknown event for forward compatibility
public struct StreamUnknown: StreamingEvent, Codable, Sendable {
    public var type = StreamEventType.unknown
    public let eventType: String
    public let rawJSON: Data
    
    public init(eventType: String, rawJSON: Data) {
        self.eventType = eventType
        self.rawJSON = rawJSON
    }
    
    /// Get the raw data as a dictionary if possible
    public func getRawData() throws -> [String: Any]? {
        try JSONSerialization.jsonObject(with: rawJSON) as? [String: Any]
    }
    
    /// Get the raw data as a pretty-printed JSON string
    public func getRawJSONString() -> String? {
        if let json = try? JSONSerialization.jsonObject(with: rawJSON),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            return String(data: prettyData, encoding: .utf8)
        }
        return String(data: rawJSON, encoding: .utf8)
    }
}

/// Reasoning summary delta event for o3 models
public struct StreamReasoningSummaryDelta: StreamingEvent, Codable, Sendable {
    public var type = StreamEventType.reasoningSummaryDelta
    public let delta: String
    public let index: Int?
    
    public init(delta: String, index: Int? = nil) {
        self.delta = delta
        self.index = index
    }
}

/// Reasoning summary completed event for o3 models
public struct StreamReasoningSummaryCompleted: StreamingEvent, Codable, Sendable {
    public var type = StreamEventType.reasoningSummaryCompleted
    public let summary: String
    public let reasoningTokens: Int?
    
    public init(summary: String, reasoningTokens: Int? = nil) {
        self.summary = summary
        self.reasoningTokens = reasoningTokens
    }
}

// MARK: - Supporting Types

/// Function call delta for incremental function information
public struct FunctionCallDelta: Codable, Sendable {
    public let name: String?
    public let arguments: String?
    
    public init(name: String? = nil, arguments: String? = nil) {
        self.name = name
        self.arguments = arguments
    }
}

/// Token usage information
public struct Usage: Codable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
    public let promptTokensDetails: TokenDetails?
    public let completionTokensDetails: TokenDetails?
    
    public init(
        promptTokens: Int,
        completionTokens: Int,
        totalTokens: Int,
        promptTokensDetails: TokenDetails? = nil,
        completionTokensDetails: TokenDetails? = nil
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.promptTokensDetails = promptTokensDetails
        self.completionTokensDetails = completionTokensDetails
    }
}

/// Detailed token usage breakdown
public struct TokenDetails: Codable, Sendable {
    public let cachedTokens: Int?
    public let audioTokens: Int?
    public let reasoningTokens: Int?
    
    public init(cachedTokens: Int? = nil, audioTokens: Int? = nil, reasoningTokens: Int? = nil) {
        self.cachedTokens = cachedTokens
        self.audioTokens = audioTokens
        self.reasoningTokens = reasoningTokens
    }
}

/// Reason why the response finished
public enum FinishReason: String, Codable, Sendable {
    case stop = "stop"
    case length = "length"
    case toolCalls = "tool_calls"
    case contentFilter = "content_filter"
    case functionCall = "function_call"
}

/// Error detail information
public struct ErrorDetail: Codable, Sendable {
    public let message: String
    public let type: String?
    public let code: String?
    public let param: String?
    
    public init(message: String, type: String? = nil, code: String? = nil, param: String? = nil) {
        self.message = message
        self.type = type
        self.code = code
        self.param = param
    }
}

// MARK: - Stream Event Extensions

extension StreamEvent {
    /// Check if this is a final event
    public var isFinal: Bool {
        switch self {
        case .responseCompleted, .error, .reasoningSummaryCompleted:
            return true
        default:
            return false
        }
    }
    
    /// Extract any text content from the event
    public var textContent: String? {
        switch self {
        case .textDelta(let delta):
            return delta.delta
        case .reasoningSummaryDelta(let delta):
            return delta.delta
        case .reasoningSummaryCompleted(let completed):
            return completed.summary
        case .error(let error):
            return error.error.message
        default:
            return nil
        }
    }
}