import Foundation
import AXorcist

// MARK: - Model Interface Protocol

/// Protocol defining the interface for AI model providers
public protocol ModelInterface: Sendable {
    /// Get a non-streaming response from the model
    /// - Parameter request: The model request containing messages, tools, and settings
    /// - Returns: The model response
    func getResponse(request: ModelRequest) async throws -> ModelResponse
    
    /// Get a streaming response from the model
    /// - Parameter request: The model request containing messages, tools, and settings
    /// - Returns: An async stream of events
    func getStreamedResponse(request: ModelRequest) async throws -> AsyncThrowingStream<StreamEvent, Error>
    
    /// Get a masked version of the API key for debugging
    /// Returns the first 6 and last 2 characters of the API key
    /// - Returns: Masked API key string (e.g., "sk-ant...AA")
    var maskedApiKey: String { get }
}

// MARK: - Model Request & Response Types

/// Request to send to a model
public struct ModelRequest: Codable, Sendable {
    /// The messages to send to the model
    public let messages: [any MessageItem]
    
    /// Available tools for the model to use
    public let tools: [ToolDefinition]?
    
    /// Model-specific settings
    public let settings: ModelSettings
    
    /// System instructions (some models support this separately from messages)
    public let systemInstructions: String?
    
    public init(
        messages: [any MessageItem],
        tools: [ToolDefinition]? = nil,
        settings: ModelSettings,
        systemInstructions: String? = nil
    ) {
        self.messages = messages
        self.tools = tools
        self.settings = settings
        self.systemInstructions = systemInstructions
    }
    
    // Custom coding to handle array of protocol types
    enum CodingKeys: String, CodingKey {
        case messages, tools, settings, systemInstructions
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode messages as array of dictionaries first
        var decodedMessages: [any MessageItem] = []
        if let messageArray = try? container.decode([[String: AnyCodable]].self, forKey: .messages) {
            for messageDict in messageArray {
                if let typeAnyCodable = messageDict["type"],
                   let typeStr = typeAnyCodable.value as? String,
                   let type = MessageItemType(rawValue: typeStr) {
                    // Decode based on type
                    let convertedDict = messageDict.mapValues { $0.value }
                    let data = try JSONSerialization.data(withJSONObject: convertedDict)
                    switch type {
                    case .system:
                        if let msg = try? JSONDecoder().decode(SystemMessageItem.self, from: data) {
                            decodedMessages.append(msg)
                        }
                    case .user:
                        if let msg = try? JSONDecoder().decode(UserMessageItem.self, from: data) {
                            decodedMessages.append(msg)
                        }
                    case .assistant:
                        if let msg = try? JSONDecoder().decode(AssistantMessageItem.self, from: data) {
                            decodedMessages.append(msg)
                        }
                    case .tool:
                        if let msg = try? JSONDecoder().decode(ToolMessageItem.self, from: data) {
                            decodedMessages.append(msg)
                        }
                    case .reasoning:
                        if let msg = try? JSONDecoder().decode(ReasoningMessageItem.self, from: data) {
                            decodedMessages.append(msg)
                        }
                    case .unknown:
                        if let msg = try? JSONDecoder().decode(UnknownMessageItem.self, from: data) {
                            decodedMessages.append(msg)
                        }
                    }
                }
            }
        }
        
        self.messages = decodedMessages
        self.tools = try container.decodeIfPresent([ToolDefinition].self, forKey: .tools)
        self.settings = try container.decode(ModelSettings.self, forKey: .settings)
        self.systemInstructions = try container.decodeIfPresent(String.self, forKey: .systemInstructions)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode messages individually
        var messageArray: [[String: AnyCodable]] = []
        for message in messages {
            if let data = try? JSONEncoder().encode(message),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let anyCodableDict = dict.mapValues { AnyCodable($0) }
                messageArray.append(anyCodableDict)
            }
        }
        try container.encode(messageArray, forKey: .messages)
        
        try container.encodeIfPresent(tools, forKey: .tools)
        try container.encode(settings, forKey: .settings)
        try container.encodeIfPresent(systemInstructions, forKey: .systemInstructions)
    }
}

/// Response from a model
public struct ModelResponse: Codable, Sendable {
    /// Unique identifier for the response
    public let id: String
    
    /// The model that generated the response
    public let model: String?
    
    /// Content returned by the model
    public let content: [AssistantContent]
    
    /// Token usage statistics
    public let usage: Usage?
    
    /// Whether the response was flagged for safety
    public let flagged: Bool
    
    /// Reason for flagging if applicable
    public let flaggedCategories: [String]?
    
    /// Finish reason
    public let finishReason: FinishReason?
    
    public init(
        id: String,
        model: String? = nil,
        content: [AssistantContent],
        usage: Usage? = nil,
        flagged: Bool = false,
        flaggedCategories: [String]? = nil,
        finishReason: FinishReason? = nil
    ) {
        self.id = id
        self.model = model
        self.content = content
        self.usage = usage
        self.flagged = flagged
        self.flaggedCategories = flaggedCategories
        self.finishReason = finishReason
    }
}

// MARK: - Model Settings

/// Settings for model behavior
public struct ModelSettings: Codable, Sendable {
    /// The model name/identifier
    public let modelName: String
    
    /// Temperature for randomness (0.0 to 2.0)
    public let temperature: Double?
    
    /// Top-p sampling parameter
    public let topP: Double?
    
    /// Maximum tokens to generate
    public let maxTokens: Int?
    
    /// Frequency penalty (-2.0 to 2.0)
    public let frequencyPenalty: Double?
    
    /// Presence penalty (-2.0 to 2.0)
    public let presencePenalty: Double?
    
    /// Stop sequences
    public let stopSequences: [String]?
    
    /// Tool choice setting
    public let toolChoice: ToolChoice?
    
    /// Whether to use parallel tool calls
    public let parallelToolCalls: Bool?
    
    /// Response format
    public let responseFormat: ResponseFormat?
    
    /// Seed for deterministic generation
    public let seed: Int?
    
    /// User identifier for tracking
    public let user: String?
    
    /// Additional provider-specific parameters
    public let additionalParameters: [String: AnyCodable]?
    
    public init(
        modelName: String,
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil,
        frequencyPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        stopSequences: [String]? = nil,
        toolChoice: ToolChoice? = nil,
        parallelToolCalls: Bool? = nil,
        responseFormat: ResponseFormat? = nil,
        seed: Int? = nil,
        user: String? = nil,
        additionalParameters: [String: AnyCodable]? = nil
    ) {
        self.modelName = modelName
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.stopSequences = stopSequences
        self.toolChoice = toolChoice
        self.parallelToolCalls = parallelToolCalls
        self.responseFormat = responseFormat
        self.seed = seed
        self.user = user
        self.additionalParameters = additionalParameters
    }
    
    /// Default settings for GPT-4
    public static var `default`: ModelSettings {
        ModelSettings(modelName: "gpt-4-turbo-preview")
    }
    
    // Custom coding for additionalParameters
    enum CodingKeys: String, CodingKey {
        case modelName, temperature, topP, maxTokens
        case frequencyPenalty, presencePenalty, stopSequences
        case toolChoice, parallelToolCalls, responseFormat
        case seed, user, additionalParameters
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.modelName = try container.decode(String.self, forKey: .modelName)
        self.temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
        self.topP = try container.decodeIfPresent(Double.self, forKey: .topP)
        self.maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens)
        self.frequencyPenalty = try container.decodeIfPresent(Double.self, forKey: .frequencyPenalty)
        self.presencePenalty = try container.decodeIfPresent(Double.self, forKey: .presencePenalty)
        self.stopSequences = try container.decodeIfPresent([String].self, forKey: .stopSequences)
        self.toolChoice = try container.decodeIfPresent(ToolChoice.self, forKey: .toolChoice)
        self.parallelToolCalls = try container.decodeIfPresent(Bool.self, forKey: .parallelToolCalls)
        self.responseFormat = try container.decodeIfPresent(ResponseFormat.self, forKey: .responseFormat)
        self.seed = try container.decodeIfPresent(Int.self, forKey: .seed)
        self.user = try container.decodeIfPresent(String.self, forKey: .user)
        
        // Decode additional parameters
        if let data = try? container.decode(Data.self, forKey: .additionalParameters),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.additionalParameters = dict.mapValues { AnyCodable($0) }
        } else {
            self.additionalParameters = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(modelName, forKey: .modelName)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(topP, forKey: .topP)
        try container.encodeIfPresent(maxTokens, forKey: .maxTokens)
        try container.encodeIfPresent(frequencyPenalty, forKey: .frequencyPenalty)
        try container.encodeIfPresent(presencePenalty, forKey: .presencePenalty)
        try container.encodeIfPresent(stopSequences, forKey: .stopSequences)
        try container.encodeIfPresent(toolChoice, forKey: .toolChoice)
        try container.encodeIfPresent(parallelToolCalls, forKey: .parallelToolCalls)
        try container.encodeIfPresent(responseFormat, forKey: .responseFormat)
        try container.encodeIfPresent(seed, forKey: .seed)
        try container.encodeIfPresent(user, forKey: .user)
        
        // Encode additional parameters
        if let params = additionalParameters,
           let data = try? JSONSerialization.data(withJSONObject: params) {
            try container.encode(data, forKey: .additionalParameters)
        }
    }
}

// MARK: - Tool Choice

/// Tool choice setting for models
public enum ToolChoice: Codable, Sendable {
    case auto
    case none
    case required
    case specific(toolName: String)
    
    // Custom coding
    enum CodingKeys: String, CodingKey {
        case type, toolName
    }
    
    enum ChoiceType: String, Codable {
        case auto, none, required, specific
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ChoiceType.self, forKey: .type)
        
        switch type {
        case .auto:
            self = .auto
        case .none:
            self = .none
        case .required:
            self = .required
        case .specific:
            let toolName = try container.decode(String.self, forKey: .toolName)
            self = .specific(toolName: toolName)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .auto:
            try container.encode(ChoiceType.auto, forKey: .type)
        case .none:
            try container.encode(ChoiceType.none, forKey: .type)
        case .required:
            try container.encode(ChoiceType.required, forKey: .type)
        case .specific(let toolName):
            try container.encode(ChoiceType.specific, forKey: .type)
            try container.encode(toolName, forKey: .toolName)
        }
    }
}

// MARK: - Response Format

/// Response format specification
public struct ResponseFormat: Codable, Sendable {
    public let type: ResponseFormatType
    public let jsonSchema: JSONSchema?
    
    public init(type: ResponseFormatType, jsonSchema: JSONSchema? = nil) {
        self.type = type
        self.jsonSchema = jsonSchema
    }
    
    /// Plain text response
    public static var text: ResponseFormat {
        ResponseFormat(type: .text)
    }
    
    /// JSON object response
    public static var jsonObject: ResponseFormat {
        ResponseFormat(type: .jsonObject)
    }
}

/// Response format types
public enum ResponseFormatType: String, Codable, Sendable {
    case text = "text"
    case jsonObject = "json_object"
    case jsonSchema = "json_schema"
}

/// JSON schema specification
public struct JSONSchema: Codable, Sendable {
    public let name: String
    public let strict: Bool
    public let schema: [String: AnyCodable]
    
    // Custom coding for schema
    enum CodingKeys: String, CodingKey {
        case name, strict, schema
    }
    
    public init(name: String, strict: Bool = true, schema: [String: Any]) {
        self.name = name
        self.strict = strict
        self.schema = schema.mapValues { AnyCodable($0) }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.strict = try container.decode(Bool.self, forKey: .strict)
        
        if let data = try? container.decode(Data.self, forKey: .schema),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.schema = dict.mapValues { AnyCodable($0) }
        } else {
            self.schema = [:]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(strict, forKey: .strict)
        
        if let data = try? JSONSerialization.data(withJSONObject: schema) {
            try container.encode(data, forKey: .schema)
        }
    }
}

// MARK: - Model Provider Protocol

/// Protocol for model provider factories
public protocol ModelProviderProtocol {
    /// Get a model by name
    /// - Parameter modelName: The name of the model to retrieve
    /// - Returns: A model instance conforming to ModelInterface
    func getModel(modelName: String) throws -> any ModelInterface
}

// MARK: - Model Errors

/// Errors that can occur when using models
public enum ModelError: Error, LocalizedError {
    case modelNotFound(String)
    case invalidConfiguration(String)
    case requestFailed(Error)
    case responseParsingFailed(String)
    case streamingNotSupported
    case rateLimitExceeded
    case contextLengthExceeded
    case authenticationFailed
    
    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "Model not found: \(name)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .responseParsingFailed(let message):
            return "Failed to parse response: \(message)"
        case .streamingNotSupported:
            return "Streaming is not supported by this model"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .contextLengthExceeded:
            return "Context length exceeded"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}