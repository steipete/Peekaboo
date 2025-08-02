import Foundation

// MARK: - Model Interface Protocol

/// Protocol defining the interface for AI model providers
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public protocol ModelInterface: Sendable {
    /// Get a non-streaming response from the model
    /// - Parameter request: The model request containing messages, tools, and settings
    /// - Returns: The model response
    func getResponse(request: ModelRequest) async throws -> ModelResponse

    /// Get a streaming response from the model
    /// - Parameter request: The model request containing messages, tools, and settings
    /// - Returns: An async stream of events
    func getStreamedResponse(request: ModelRequest) async throws -> AsyncThrowingStream<StreamEvent, any Error>

    /// Get a masked version of the API key for debugging
    /// Returns the first 6 and last 2 characters of the API key
    /// - Returns: Masked API key string (e.g., "sk-ant...AA")
    var maskedApiKey: String { get }
}

// MARK: - Model Request & Response Types

/// Request to send to a model
public struct ModelRequest: Codable, Sendable {
    /// The messages to send to the model
    public let messages: [Message]

    /// Available tools for the model to use
    public let tools: [ToolDefinition]?

    /// Model-specific settings
    public let settings: ModelSettings

    /// System instructions (some models support this separately from messages)
    public let systemInstructions: String?

    public init(
        messages: [Message],
        tools: [ToolDefinition]? = nil,
        settings: ModelSettings,
        systemInstructions: String? = nil)
    {
        self.messages = messages
        self.tools = tools
        self.settings = settings
        self.systemInstructions = systemInstructions
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
        finishReason: FinishReason? = nil)
    {
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
    public let additionalParameters: ModelParameters?

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
        additionalParameters: ModelParameters? = nil)
    {
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

    /// Default settings for Claude Opus 4
    public static var `default`: ModelSettings {
        ModelSettings(modelName: "claude-opus-4-20250514")
    }
    
    // MARK: - Convenience Constructors
    
    /// Create settings with just specified parameters, using Claude Opus 4 as default model
    public init(
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
        additionalParameters: ModelParameters? = nil)
    {
        self.init(
            modelName: "claude-opus-4-20250514",
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens,
            frequencyPenalty: frequencyPenalty,
            presencePenalty: presencePenalty,
            stopSequences: stopSequences,
            toolChoice: toolChoice,
            parallelToolCalls: parallelToolCalls,
            responseFormat: responseFormat,
            seed: seed,
            user: user,
            additionalParameters: additionalParameters
        )
    }
    
    /// Convenience constructors for specific API types and reasoning parameters
    public init(
        apiType: String,
        modelName: String = "claude-opus-4-20250514")
    {
        let params = ModelParameters([
            "apiType": ModelParameters.Value.string(apiType)
        ])
        self.init(modelName: modelName, additionalParameters: params)
    }
    
    public init(
        reasoningEffort: String,
        reasoning: [String: String]? = nil,
        temperature: Double? = nil,
        modelName: String = "o3")
    {
        var params: [String: ModelParameters.Value] = [
            "reasoningEffort": ModelParameters.Value.string(reasoningEffort)
        ]
        if let reasoning = reasoning {
            let reasoningValue = reasoning.mapValues { ModelParameters.Value.string($0) }
            params["reasoning"] = ModelParameters.Value.dictionary(reasoningValue)
        }
        let modelParams = ModelParameters(params)
        self.init(
            modelName: modelName,
            temperature: temperature,
            additionalParameters: modelParams
        )
    }

    // Custom coding for additionalParameters
    enum CodingKeys: String, CodingKey {
        case modelName, temperature, topP, maxTokens
        case frequencyPenalty, presencePenalty, stopSequences
        case toolChoice, parallelToolCalls, responseFormat
        case seed, user, additionalParameters
    }

    public init(from decoder: any Decoder) throws {
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
        self.additionalParameters = try container.decodeIfPresent(ModelParameters.self, forKey: .additionalParameters)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.modelName, forKey: .modelName)
        try container.encodeIfPresent(self.temperature, forKey: .temperature)
        try container.encodeIfPresent(self.topP, forKey: .topP)
        try container.encodeIfPresent(self.maxTokens, forKey: .maxTokens)
        try container.encodeIfPresent(self.frequencyPenalty, forKey: .frequencyPenalty)
        try container.encodeIfPresent(self.presencePenalty, forKey: .presencePenalty)
        try container.encodeIfPresent(self.stopSequences, forKey: .stopSequences)
        try container.encodeIfPresent(self.toolChoice, forKey: .toolChoice)
        try container.encodeIfPresent(self.parallelToolCalls, forKey: .parallelToolCalls)
        try container.encodeIfPresent(self.responseFormat, forKey: .responseFormat)
        try container.encodeIfPresent(self.seed, forKey: .seed)
        try container.encodeIfPresent(self.user, forKey: .user)

        // Encode additional parameters
        try container.encodeIfPresent(self.additionalParameters, forKey: .additionalParameters)
    }
}

// MARK: - Tool Choice

/// Tool choice setting for models
public enum ToolChoice: Codable, Sendable, Equatable {
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

    public init(from decoder: any Decoder) throws {
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

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .auto:
            try container.encode(ChoiceType.auto, forKey: .type)
        case .none:
            try container.encode(ChoiceType.none, forKey: .type)
        case .required:
            try container.encode(ChoiceType.required, forKey: .type)
        case let .specific(toolName):
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
    case text
    case jsonObject = "json_object"
    case jsonSchema = "json_schema"
}

/// JSON schema specification
public struct JSONSchema: Codable, Sendable {
    public let name: String
    public let strict: Bool
    private let schemaData: Data // Store as raw JSON data

    // Custom coding for schema
    enum CodingKeys: String, CodingKey {
        case name, strict, schema
    }

    public init(name: String, strict: Bool = true, schema: [String: Any]) throws {
        self.name = name
        self.strict = strict
        self.schemaData = try JSONSerialization.data(withJSONObject: schema)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.strict = try container.decode(Bool.self, forKey: .strict)
        self.schemaData = try container.decode(Data.self, forKey: .schema)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.strict, forKey: .strict)
        try container.encode(self.schemaData, forKey: .schema)
    }

    /// Get the schema as a dictionary
    public func getSchema() throws -> [String: Any] {
        guard let dict = try JSONSerialization.jsonObject(with: schemaData) as? [String: Any] else {
            throw TachikomaError.invalidConfiguration("Invalid JSON schema data")
        }
        return dict
    }
}

// MARK: - Model Provider Protocol

/// Protocol for model provider factories
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public protocol ModelProviderProtocol {
    /// Get a model by name
    /// - Parameter modelName: The name of the model to retrieve
    /// - Returns: A model instance conforming to ModelInterface
    func getModel(modelName: String) throws -> any ModelInterface
}

// MARK: - Model Errors

// MARK: - Note
// ModelError is defined in TachikomaError.swift to avoid duplication