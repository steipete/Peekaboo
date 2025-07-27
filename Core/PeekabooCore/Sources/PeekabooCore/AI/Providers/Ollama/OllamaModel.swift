import Foundation

// Simple debug logging check
fileprivate var isDebugLoggingEnabled: Bool {
    if let logLevel = ProcessInfo.processInfo.environment["PEEKABOO_LOG_LEVEL"]?.lowercased() {
        return logLevel == "debug" || logLevel == "trace"
    }
    return false
}

fileprivate func aiDebugPrint(_ message: String) {
    if isDebugLoggingEnabled {
        print(message)
    }
}

/// Ollama model implementation conforming to ModelInterface
///
/// This implementation supports tool/function calling for compatible models.
/// 
/// Tool Calling Limitations:
/// - Not all Ollama models support tools (e.g., vision models like llava don't support tools)
/// - Some models (like llama3.3) output tool calls as JSON text rather than structured tool_calls
/// - Models without tool support will return HTTP 400 errors when tools are provided
/// - The implementation automatically detects and parses both standard and text-based tool calls
///
/// Recommended models for tool calling:
/// - llama3.3 (best overall)
/// - llama3.2, llama3.1
/// - mistral-nemo, firefunction-v2
/// - command-r-plus, command-r
public final class OllamaModel: ModelInterface {
    private let baseURL: URL
    private let session: URLSession
    private let modelName: String
    
    // Models known to support tool/function calling
    private static let modelsWithToolSupport: Set<String> = [
        "llama3.3", "llama3.3:latest",
        "llama3.2", "llama3.2:latest", 
        "llama3.1", "llama3.1:latest",
        "mistral-nemo", "mistral-nemo:latest",
        "firefunction-v2", "firefunction-v2:latest",
        "command-r-plus", "command-r-plus:latest",
        "command-r", "command-r:latest"
    ]
    
    // Models known to NOT support tool calling (vision models, etc)
    private static let modelsWithoutToolSupport: Set<String> = [
        "llava", "llava:latest",
        "bakllava", "bakllava:latest",
        "llama3.2-vision:11b", "llama3.2-vision:90b",
        "qwen2.5vl:7b", "qwen2.5vl:32b",
        "devstral", "devstral:latest"
    ]
    
    // Create a custom URLSession with longer timeout for Ollama
    // Note: Ollama can take up to a minute before responding, especially with large models
    private static func createDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600 // 10 minutes for request (Ollama can be very slow)
        config.timeoutIntervalForResource = 1200 // 20 minutes for resource
        return URLSession(configuration: config)
    }
    
    public init(
        modelName: String,
        baseURL: URL = URL(string: "http://localhost:11434")!,
        session: URLSession? = nil
    ) {
        self.modelName = modelName
        self.baseURL = baseURL
        self.session = session ?? Self.createDefaultSession()
    }
    
    // MARK: - Tool Support Detection
    
    /// Check if the current model supports tool calling
    private var supportsTools: Bool {
        // Check if model is in the known supported list
        if Self.modelsWithToolSupport.contains(modelName) {
            return true
        }
        
        // Check if model is in the known unsupported list
        if Self.modelsWithoutToolSupport.contains(modelName) {
            return false
        }
        
        // For unknown models, check if it's a variant of a known model
        // e.g., "llama3.3:70b" should match "llama3.3"
        for supportedModel in Self.modelsWithToolSupport {
            let baseModel = supportedModel.replacingOccurrences(of: ":latest", with: "")
            if modelName.hasPrefix(baseModel) {
                return true
            }
        }
        
        for unsupportedModel in Self.modelsWithoutToolSupport {
            let baseModel = unsupportedModel.replacingOccurrences(of: ":latest", with: "")
            if modelName.hasPrefix(baseModel) {
                return false
            }
        }
        
        // Default to false for unknown models (safer assumption)
        return false
    }
    
    /// Get a user-friendly error message for models without tool support
    private func getToolSupportError() -> String {
        if Self.modelsWithoutToolSupport.contains(modelName) {
            return "Model '\(modelName)' does not support tool calling. Vision models like llava and bakllava cannot use tools. Please use llama3.3 or another model with tool support."
        } else {
            return "Model '\(modelName)' may not support tool calling. Recommended models: llama3.3, llama3.2, mistral-nemo, firefunction-v2, or command-r-plus."
        }
    }
    
    // MARK: - ModelInterface Implementation
    
    public var maskedApiKey: String {
        // Ollama doesn't use API keys
        return "none"
    }
    
    public func getResponse(request: ModelRequest) async throws -> ModelResponse {
        // Convert ModelRequest to Ollama format
        let ollamaRequest = try convertToOllamaRequest(request)
        
        // Create URL request
        let url = baseURL.appendingPathComponent("/api/chat")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONCoding.encoder.encode(ollamaRequest)
        
        aiDebugPrint("[OllamaModel] Sending request to \(url) for model \(modelName)")
        if let jsonString = String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) {
            aiDebugPrint("[OllamaModel] Request body: \(jsonString.prefix(500))...") // Show first 500 chars
            aiDebugPrint("[OllamaModel] Total request size: \(urlRequest.httpBody?.count ?? 0) bytes")
        }
        
        // Make request
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PeekabooError.networkError("Invalid server response")
        }
        
        // Use NetworkErrorHandling for consistent error handling
        do {
            try session.handleErrorResponse(
                data: data,
                response: response,
                context: "Ollama API"
            )
        } catch let error as PeekabooError {
            // Check if this is a tool-related error
            if httpResponse.statusCode == 400 && request.tools != nil && !request.tools!.isEmpty {
                // Model likely doesn't support tools
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                let enhancedMessage = "\(errorMessage)\n\n\(getToolSupportError())"
                throw PeekabooError.apiError(
                    code: httpResponse.statusCode,
                    message: "Ollama API: HTTP 400: \(enhancedMessage)"
                )
            }
            throw error
        }
        
        // Parse response
        let ollamaResponse = try JSONCoding.decoder.decode(OllamaResponse.self, from: data)
        return try convertFromOllamaResponse(ollamaResponse)
    }
    
    public func getStreamedResponse(request: ModelRequest) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        aiDebugPrint("[OllamaModel] getStreamedResponse called for model: \(modelName)")
        
        // Convert ModelRequest to Ollama format with streaming enabled
        var ollamaRequest = try convertToOllamaRequest(request)
        ollamaRequest.stream = true
        
        // Create URL request
        let url = baseURL.appendingPathComponent("/api/chat")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONCoding.encoder.encode(ollamaRequest)
        
        aiDebugPrint("[OllamaModel] Sending streaming request to: \(url)")
        
        // Capture immutable copies for use in closure
        let request = urlRequest
        let capturedSession = self.session
        let debugModelName = self.modelName
        let capturedSelf = self
        
        return AsyncThrowingStream { continuation in
            // Use detached task to avoid potential actor isolation issues
            Task.detached { [self, request, capturedSession, debugModelName, capturedSelf] in
                do {
                    aiDebugPrint("[OllamaModel] Starting streaming request for model \(debugModelName)")
                    
                    // Send response started event immediately
                    continuation.yield(StreamEvent.responseStarted(StreamResponseStarted(id: UUID().uuidString)))
                    
                    aiDebugPrint("[OllamaModel] About to call session.bytes...")
                    let (bytes, response) = try await capturedSession.bytes(for: request)
                    aiDebugPrint("[OllamaModel] session.bytes returned!")
                    
                    aiDebugPrint("[OllamaModel] Got response, status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ModelError.requestFailed(URLError(.badServerResponse)))
                        return
                    }
                    
                    if httpResponse.statusCode != 200 {
                        // Try to read error from first chunk
                        var errorData = Data()
                        for try await byte in bytes.prefix(1024) {
                            errorData.append(byte)
                        }
                        
                        do {
                            try capturedSession.handleErrorResponse(
                                data: errorData,
                                response: response,
                                context: "Ollama API (streaming)"
                            )
                        } catch let error as PeekabooError {
                            // Check if this is a tool-related error
                            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                            if httpResponse.statusCode == 400 && 
                               (errorMessage.contains("tools") || errorMessage.contains("function")) {
                                // Model likely doesn't support tools
                                let modelError = capturedSelf.getToolSupportError()
                                let enhancedMessage = "\(errorMessage)\n\n\(modelError)"
                                continuation.finish(throwing: PeekabooError.apiError(
                                    code: httpResponse.statusCode,
                                    message: "Ollama API (streaming): HTTP 400: \(enhancedMessage)"
                                ))
                                return
                            }
                            continuation.finish(throwing: error)
                            return
                        }
                    }
                    
                    // Process streaming response
                    var buffer = Data()
                    var byteCount = 0
                    
                    for try await byte in bytes {
                        buffer.append(byte)
                        byteCount += 1
                        if byteCount % 100 == 0 {
                            aiDebugPrint("[OllamaModel] Received \(byteCount) bytes so far...")
                        }
                        
                        // Look for newline
                        if byte == 0x0A { // \n
                            if let line = String(data: buffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !line.isEmpty {
                                aiDebugPrint("[OllamaModel] Processing line: \(line)")
                                
                                // Parse JSON chunk
                                if let data = line.data(using: .utf8),
                                   let chunk = try? JSONCoding.decoder.decode(OllamaStreamChunk.self, from: data) {
                                    
                                    // Convert to StreamEvent
                                    if let content = chunk.message?.content, !content.isEmpty {
                                        // Skip malformed content that often comes with tool calls
                                        // llama3.3 sometimes returns partial JSON like '", "parameters": {}}'
                                        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if trimmedContent.hasPrefix("\",") || trimmedContent.hasPrefix("\"}") {
                                            // Skip this malformed content
                                            aiDebugPrint("[OllamaModel] Skipping malformed content: \(content)")
                                        } else if content.hasPrefix("{") && content.contains("\"type\": \"function\"") {
                                            // IMPORTANT: Some Ollama models (especially llama3.3) output tool calls as JSON text
                                            // in the content field instead of using the structured tool_calls field.
                                            // This is a workaround to detect and parse these text-based tool calls.
                                            // Expected format: {"type": "function", "name": "tool_name", "parameters": {...}}
                                            if let data = content.data(using: .utf8),
                                               let toolCall = try? JSONCoding.decoder.decode(TextBasedToolCall.self, from: data),
                                               toolCall.type == "function" {
                                                
                                                // Convert parameters to JSON string
                                                let paramsString = convertToolParameterDictToJSON(toolCall.parameters)
                                                
                                                continuation.yield(StreamEvent.toolCallCompleted(
                                                    StreamToolCallCompleted(
                                                        id: UUID().uuidString,
                                                        function: FunctionCall(
                                                            name: toolCall.name,
                                                            arguments: paramsString
                                                        )
                                                    )
                                                ))
                                            } else {
                                                // If parsing fails, treat as regular text
                                                continuation.yield(StreamEvent.textDelta(StreamTextDelta(delta: content)))
                                            }
                                        } else {
                                            // Regular text content
                                            continuation.yield(StreamEvent.textDelta(StreamTextDelta(delta: content)))
                                        }
                                    }
                                    
                                    // Handle standard tool calls (models that properly use the tool_calls field)
                                    // This is the preferred method for tool calling, supported by newer models
                                    if let toolCalls = chunk.message?.toolCalls, !toolCalls.isEmpty {
                                        aiDebugPrint("[OllamaModel] Processing \(toolCalls.count) tool calls")
                                        for toolCall in toolCalls {
                                            aiDebugPrint("[OllamaModel] Tool call: \(toolCall.function.name) with args: \(toolCall.function.arguments)")
                                            
                                            let event = StreamEvent.toolCallCompleted(
                                                StreamToolCallCompleted(
                                                    id: UUID().uuidString,
                                                    function: FunctionCall(
                                                        name: toolCall.function.name,
                                                        arguments: toolCall.function.arguments
                                                    )
                                                )
                                            )
                                            aiDebugPrint("[OllamaModel] Yielding tool call event: \(toolCall.function.name)")
                                            continuation.yield(event)
                                        }
                                    }
                                    
                                    if chunk.done {
                                        // Send completion event
                                        continuation.yield(StreamEvent.responseCompleted(
                                            StreamResponseCompleted(
                                                id: UUID().uuidString,
                                                usage: nil,
                                                finishReason: .stop
                                            )
                                        ))
                                        continuation.finish()
                                        return
                                    }
                                }
                            }
                            buffer.removeAll()
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    let peekabooError = error.asPeekabooError(context: "Ollama stream processing failed")
                    continuation.finish(throwing: peekabooError)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func convertToOllamaRequest(_ request: ModelRequest) throws -> OllamaRequest {
        // Convert messages
        let messages = request.messages.compactMap { message -> OllamaMessage? in
            switch message {
            case .system(_, let content):
                return OllamaMessage(role: "system", content: content, images: nil, toolCalls: nil)
                
            case .user(_, let content):
                // Handle different content types
                switch content {
                case .text(let text):
                    return OllamaMessage(role: "user", content: text, images: nil, toolCalls: nil)
                    
                case .image(let imageContent):
                    // Ollama expects images as base64 strings
                    if let base64 = imageContent.base64 {
                        return OllamaMessage(role: "user", content: "", images: [base64], toolCalls: nil)
                    } else {
                        // Can't send URL images to Ollama
                        return OllamaMessage(role: "user", content: "[Image URL not supported by Ollama]", images: nil, toolCalls: nil)
                    }
                    
                case .multimodal(let parts):
                    var textParts: [String] = []
                    var images: [String] = []
                    
                    for part in parts {
                        if let text = part.text {
                            textParts.append(text)
                        }
                        if let imageUrl = part.imageUrl, let base64 = imageUrl.base64 {
                            images.append(base64)
                        }
                    }
                    
                    return OllamaMessage(
                        role: "user",
                        content: textParts.joined(separator: " "),
                        images: images.isEmpty ? nil : images,
                        toolCalls: nil
                    )
                    
                case .file:
                    return nil // Ollama doesn't support file content
                }
                
            case .assistant(_, let content, _):
                let textContent = content.compactMap { content -> String? in
                    if case .outputText(let text) = content {
                        return text
                    }
                    return nil
                }.joined(separator: " ")
                
                return OllamaMessage(role: "assistant", content: textContent, images: nil, toolCalls: nil)
                
            case .tool(_, let toolCallId, let content):
                // Convert tool response to assistant message for Ollama
                return OllamaMessage(role: "assistant", content: "Tool result for \(toolCallId): \(content)", images: nil, toolCalls: nil)
                
            case .reasoning(_, let content):
                // Convert reasoning to assistant message
                return OllamaMessage(role: "assistant", content: content, images: nil, toolCalls: nil)
            }
        }
        
        // Build options from settings
        let options = OllamaOptions(
            temperature: request.settings.temperature,
            topP: request.settings.topP,
            numPredict: request.settings.maxTokens,
            seed: request.settings.seed.flatMap { Int($0) }
        )
        
        // Convert tools to Ollama format if provided
        var ollamaTools: [OllamaToolDefinition]? = nil
        if let tools = request.tools, !tools.isEmpty {
            // Check if model supports tools
            if !supportsTools {
                // Log warning but don't fail - model might still support tools
                print("[OllamaModel] Warning: \(getToolSupportError())")
                print("[OllamaModel] Attempting to use tools anyway, but this may fail.")
            }
            
            ollamaTools = try tools.map { tool in
                let parameters = try convertToOllamaParameters(tool.function.parameters)
                
                return OllamaToolDefinition(
                    function: OllamaFunctionDefinition(
                        name: tool.function.name,
                        description: tool.function.description,
                        parameters: parameters
                    )
                )
            }
        }
        
        // Only pass options if at least one value is set
        let hasOptions = options.temperature != nil || options.topP != nil || 
                        options.numPredict != nil || options.seed != nil
        
        return OllamaRequest(
            model: modelName,
            messages: messages,
            stream: false,
            options: hasOptions ? options : nil,
            tools: ollamaTools
        )
    }
    
    
    private func convertFromOllamaResponse(_ response: OllamaResponse) throws -> ModelResponse {
        var content: [AssistantContent] = []
        
        // Add text content if present
        if !response.message.content.isEmpty {
            content.append(.outputText(response.message.content))
        }
        
        // Add tool calls if present
        if let toolCalls = response.message.toolCalls, !toolCalls.isEmpty {
            for toolCall in toolCalls {
                let toolCallItem = ToolCallItem(
                    id: UUID().uuidString,
                    type: .function,
                    function: FunctionCall(
                        name: toolCall.function.name,
                        arguments: toolCall.function.arguments
                    )
                )
                content.append(.toolCall(toolCallItem))
            }
        }
        
        var usage: Usage? = nil
        if let evalCount = response.evalCount {
            usage = Usage(promptTokens: 0, completionTokens: evalCount, totalTokens: evalCount)
        }
        
        return ModelResponse(
            id: UUID().uuidString,
            model: response.model,
            content: content,
            usage: usage,
            flagged: false,
            finishReason: response.done ? .stop : nil
        )
    }
    
    /// Helper to convert ToolParameterValue dictionary to JSON string
    private func convertToolParameterDictToJSON(_ dict: [String: ToolParameterValue]) -> String {
        let plainDict = dict.reduce(into: [String: Any]()) { result, item in
            result[item.key] = item.value.toAny()
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: plainDict),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
}

// MARK: - Ollama API Types

/// Text-based tool call format used by some models like llama3.3
private struct TextBasedToolCall: Decodable {
    let type: String
    let name: String
    let parameters: [String: ToolParameterValue]
}

/// Type-safe tool parameter value for Ollama
private enum ToolParameterValue: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([ToolParameterValue])
    case dictionary([String: ToolParameterValue])
    case null
    
    init(from decoder: Decoder) throws {
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
        } else if let array = try? container.decode([ToolParameterValue].self) {
            self = .array(array)
        } else if let dict = try? container.decode([String: ToolParameterValue].self) {
            self = .dictionary(dict)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode tool parameter value")
        }
    }
    
    /// Convert to Any for JSON serialization
    func toAny() -> Any {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .bool(let value):
            return value
        case .array(let values):
            return values.map { $0.toAny() }
        case .dictionary(let dict):
            return dict.mapValues { $0.toAny() }
        case .null:
            return NSNull()
        }
    }
}

/// Options for Ollama model configuration
private struct OllamaOptions: Codable {
    let temperature: Double?
    let topP: Double?
    let numPredict: Int?
    let seed: Int?
    
    enum CodingKeys: String, CodingKey {
        case temperature
        case topP = "top_p"
        case numPredict = "num_predict"
        case seed
    }
}

private struct OllamaRequest: Codable {
    let model: String
    let messages: [OllamaMessage]
    var stream: Bool = false
    let options: OllamaOptions?
    let tools: [OllamaToolDefinition]?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, stream, options, tools
    }
    
    init(model: String, messages: [OllamaMessage], stream: Bool = false, options: OllamaOptions?, tools: [OllamaToolDefinition]?) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.options = options
        self.tools = tools
    }
}

private struct OllamaMessage: Codable {
    let role: String
    let content: String
    let images: [String]? // Base64 encoded images
    let toolCalls: [OllamaToolCall]? // Tool calls from assistant
    
    enum CodingKeys: String, CodingKey {
        case role, content, images
        case toolCalls = "tool_calls"
    }
}

private struct OllamaToolCall: Codable {
    let function: OllamaFunctionCall
}

private struct OllamaFunctionCall: Codable {
    let name: String
    let arguments: String // JSON string of arguments
    
    init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
    
    // Custom decoding to handle different argument formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        
        // Try to decode arguments as string first
        if let argsString = try? container.decode(String.self, forKey: .arguments) {
            self.arguments = argsString
        } else if let argsDict = try? container.decode([String: ToolParameterValue].self, forKey: .arguments) {
            // Convert dictionary to JSON string
            // Note: Using JSONCoding.encoder here for consistency
            let plainDict = argsDict.reduce(into: [String: Any]()) { dict, item in
                dict[item.key] = item.value.toAny()
            }
            let data = try JSONSerialization.data(withJSONObject: plainDict)
            self.arguments = String(data: data, encoding: .utf8) ?? "{}"
        } else {
            self.arguments = "{}"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case name, arguments
    }
}

// MARK: - Tool Definition Types

private struct OllamaToolDefinition: Codable {
    var type: String = "function"
    let function: OllamaFunctionDefinition
}

private struct OllamaFunctionDefinition: Codable {
    let name: String
    let description: String
    let parameters: OllamaToolParameters
}

private struct OllamaToolParameters: Codable {
    let type: String
    let properties: [String: OllamaParameterSchema]
    let required: [String]
    
    init(type: String = "object", properties: [String: OllamaParameterSchema] = [:], required: [String] = []) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

private struct OllamaParameterSchema: Codable {
    let type: String
    let description: String?
    let `enum`: [String]?
    // Note: Ollama doesn't support nested items, so we'll omit this for now
    
    init(type: String, description: String? = nil, enum enumValues: [String]? = nil) {
        self.type = type
        self.description = description
        self.enum = enumValues
    }
}

// Helper function to convert ToolParameters to OllamaToolParameters
private func convertToOllamaParameters(_ params: ToolParameters) throws -> OllamaToolParameters {
    var properties: [String: OllamaParameterSchema] = [:]
    
    for (key, schema) in params.properties {
        properties[key] = OllamaParameterSchema(
            type: schema.type.rawValue,
            description: schema.description,
            enum: schema.enumValues
        )
    }
    
    return OllamaToolParameters(
        type: params.type,
        properties: properties,
        required: params.required
    )
}

private struct OllamaResponse: Decodable {
    let model: String
    let createdAt: String?
    let message: OllamaMessage
    let done: Bool
    let evalCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case model
        case createdAt = "created_at"
        case message
        case done
        case evalCount = "eval_count"
    }
}

private struct OllamaStreamChunk: Decodable {
    let model: String?
    let createdAt: String?
    let message: OllamaMessage?
    let done: Bool
    
    enum CodingKeys: String, CodingKey {
        case model
        case createdAt = "created_at"
        case message
        case done
    }
}