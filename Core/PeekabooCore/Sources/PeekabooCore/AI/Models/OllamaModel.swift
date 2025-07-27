import Foundation
import AXorcist

/// Ollama model implementation conforming to ModelInterface
public final class OllamaModel: ModelInterface {
    private let baseURL: URL
    private let session: URLSession
    private let modelName: String
    
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
        urlRequest.httpBody = try ollamaRequest.toData()
        
        if ProcessInfo.processInfo.environment["PEEKABOO_LOG_LEVEL"]?.lowercased() == "debug" {
            print("[OllamaModel] Sending request to \(url) for model \(modelName)")
            if let jsonString = String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) {
                print("[OllamaModel] Request body: \(jsonString.prefix(500))...") // Show first 500 chars
                print("[OllamaModel] Total request size: \(urlRequest.httpBody?.count ?? 0) bytes")
            }
        }
        
        // Make request
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelError.requestFailed(URLError(.badServerResponse))
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ModelError.requestFailed(NSError(
                domain: "Ollama",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorMessage)"]
            ))
        }
        
        // Parse response
        let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return try convertFromOllamaResponse(ollamaResponse)
    }
    
    public func getStreamedResponse(request: ModelRequest) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        print("[OllamaModel] getStreamedResponse called for model: \(modelName)")
        
        // Convert ModelRequest to Ollama format with streaming enabled
        var ollamaRequest = try convertToOllamaRequest(request)
        ollamaRequest.stream = true
        
        // Create URL request
        let url = baseURL.appendingPathComponent("/api/chat")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try ollamaRequest.toData()
        
        print("[OllamaModel] Sending streaming request to: \(url)")
        
        // Capture immutable copies for use in closure
        let request = urlRequest
        let capturedSession = self.session
        let debugModelName = self.modelName
        
        return AsyncThrowingStream { continuation in
            // Use detached task to avoid potential actor isolation issues
            Task.detached { [request, capturedSession, debugModelName] in
                do {
                    if ProcessInfo.processInfo.environment["PEEKABOO_LOG_LEVEL"]?.lowercased() == "debug" {
                        print("[OllamaModel] Starting streaming request for model \(debugModelName)")
                    }
                    
                    // Send response started event immediately
                    continuation.yield(StreamEvent.responseStarted(StreamResponseStarted(id: UUID().uuidString)))
                    
                    print("[OllamaModel] About to call session.bytes...")
                    let (bytes, response) = try await capturedSession.bytes(for: request)
                    print("[OllamaModel] session.bytes returned!")
                    
                    print("[OllamaModel] Got response, status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                    
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
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.finish(throwing: ModelError.requestFailed(NSError(
                            domain: "Ollama",
                            code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorMessage)"]
                        )))
                        return
                    }
                    
                    // Process streaming response
                    var buffer = Data()
                    var byteCount = 0
                    
                    for try await byte in bytes {
                        buffer.append(byte)
                        byteCount += 1
                        if byteCount % 100 == 0 {
                            print("[OllamaModel] Received \(byteCount) bytes so far...")
                        }
                        
                        // Look for newline
                        if byte == 0x0A { // \n
                            if let line = String(data: buffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !line.isEmpty {
                                print("[OllamaModel] Processing line: \(line)")
                                
                                // Parse JSON chunk
                                if let data = line.data(using: .utf8),
                                   let chunk = try? JSONDecoder().decode(OllamaStreamChunk.self, from: data) {
                                    
                                    // Convert to StreamEvent
                                    if let content = chunk.message?.content, !content.isEmpty {
                                        // Skip malformed content that often comes with tool calls
                                        // llama3.3 sometimes returns partial JSON like '", "parameters": {}}'
                                        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if trimmedContent.hasPrefix("\",") || trimmedContent.hasPrefix("\"}") {
                                            // Skip this malformed content
                                            if ProcessInfo.processInfo.environment["PEEKABOO_LOG_LEVEL"]?.lowercased() == "debug" {
                                                print("[OllamaModel] Skipping malformed content: \(content)")
                                            }
                                        } else if content.hasPrefix("{") && content.contains("\"type\": \"function\"") {
                                            // Check if content is a tool call JSON (some models output tool calls as text)
                                            // Try to parse as tool call
                                            if let data = content.data(using: .utf8),
                                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                               let type = json["type"] as? String, type == "function",
                                               let name = json["name"] as? String,
                                               let params = json["parameters"] as? [String: Any] {
                                                
                                                // Convert to tool call event
                                                let paramsData = try? JSONSerialization.data(withJSONObject: params)
                                                let paramsString = paramsData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                                                
                                                continuation.yield(StreamEvent.toolCallCompleted(
                                                    StreamToolCallCompleted(
                                                        id: UUID().uuidString,
                                                        function: FunctionCall(
                                                            name: name,
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
                                    
                                    // Handle tool calls
                                    if let toolCalls = chunk.message?.toolCalls, !toolCalls.isEmpty {
                                        print("[OllamaModel] Processing \(toolCalls.count) tool calls")
                                        for toolCall in toolCalls {
                                            print("[OllamaModel] Tool call: \(toolCall.function.name) with args: \(toolCall.function.arguments)")
                                            // Convert arguments to JSON string
                                            let argumentsString: String
                                            
                                            // Handle different argument formats
                                            let argsDict = toolCall.function.argumentsDict
                                            if argsDict.isEmpty {
                                                argumentsString = "{}"
                                            } else {
                                                // Convert dictionary to JSON
                                                let plainDict = argsDict.reduce(into: [String: Any]()) { dict, item in
                                                    dict[item.key] = item.value.value
                                                }
                                                if let data = try? JSONSerialization.data(withJSONObject: plainDict),
                                                   let str = String(data: data, encoding: .utf8) {
                                                    argumentsString = str
                                                } else {
                                                    argumentsString = "{}"
                                                }
                                            }
                                            
                                            let event = StreamEvent.toolCallCompleted(
                                                StreamToolCallCompleted(
                                                    id: UUID().uuidString,
                                                    function: FunctionCall(
                                                        name: toolCall.function.name,
                                                        arguments: argumentsString
                                                    )
                                                )
                                            )
                                            print("[OllamaModel] Yielding tool call event: \(toolCall.function.name)")
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
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func convertToOllamaRequest(_ request: ModelRequest) throws -> OllamaRequest {
        // Convert messages
        let messages = request.messages.compactMap { message -> OllamaMessage? in
            switch message {
            case let systemMsg as SystemMessageItem:
                return OllamaMessage(role: "system", content: systemMsg.content, images: nil, toolCalls: nil)
                
            case let userMsg as UserMessageItem:
                // Handle different content types
                switch userMsg.content {
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
                
            case let assistantMsg as AssistantMessageItem:
                let textContent = assistantMsg.content.compactMap { content -> String? in
                    if case .outputText(let text) = content {
                        return text
                    }
                    return nil
                }.joined(separator: " ")
                
                return OllamaMessage(role: "assistant", content: textContent, images: nil, toolCalls: nil)
                
            default:
                return nil
            }
        }
        
        // Build options from settings
        var options: [String: Any] = [:]
        if let temperature = request.settings.temperature {
            options["temperature"] = temperature
        }
        if let topP = request.settings.topP {
            options["top_p"] = topP
        }
        if let maxTokens = request.settings.maxTokens {
            options["num_predict"] = maxTokens
        }
        if let seed = request.settings.seed {
            options["seed"] = seed
        }
        
        // Convert tools to Ollama format if provided
        var ollamaTools: [[String: Any]]? = nil
        if let tools = request.tools, !tools.isEmpty {
            ollamaTools = tools.map { tool in
                // Convert parameters to dictionary
                let paramsDict = convertParametersToDict(tool.function.parameters)
                
                let toolDict: [String: Any] = [
                    "type": "function",
                    "function": [
                        "name": tool.function.name,
                        "description": tool.function.description,
                        "parameters": paramsDict
                    ]
                ]
                return toolDict
            }
        }
        
        return OllamaRequest(
            model: modelName,
            messages: messages,
            stream: false,
            options: options.isEmpty ? nil : options,
            tools: ollamaTools
        )
    }
    
    private func convertParametersToDict(_ parameters: ToolParameters) -> [String: Any] {
        var dict: [String: Any] = [
            "type": parameters.type
        ]
        
        // Convert properties
        if !parameters.properties.isEmpty {
            dict["properties"] = parameters.properties.mapValues { schema in
                convertSchemaToDict(schema)
            }
        }
        
        // Convert required array
        if !parameters.required.isEmpty {
            dict["required"] = parameters.required
        }
        
        if parameters.additionalProperties {
            dict["additionalProperties"] = true
        }
        
        return dict
    }
    
    private func convertSchemaToDict(_ schema: ParameterSchema) -> [String: Any] {
        var dict: [String: Any] = [
            "type": schema.type.rawValue
        ]
        
        if let description = schema.description {
            dict["description"] = description
        }
        
        if let enumValues = schema.enumValues {
            dict["enum"] = enumValues
        }
        
        // Handle recursive items for arrays
        if let items = schema.items {
            dict["items"] = convertSchemaToDict(items.value)
        }
        
        // Handle nested properties for objects
        if let properties = schema.properties {
            dict["properties"] = properties.mapValues { convertSchemaToDict($0) }
        }
        
        if let minimum = schema.minimum {
            dict["minimum"] = minimum
        }
        
        if let maximum = schema.maximum {
            dict["maximum"] = maximum
        }
        
        if let pattern = schema.pattern {
            dict["pattern"] = pattern
        }
        
        return dict
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
                // Convert arguments dictionary to JSON string
                let argsDict = toolCall.function.argumentsDict
                let plainDict = argsDict.reduce(into: [String: Any]()) { dict, item in
                    dict[item.key] = item.value.value
                }
                let argumentsData = try JSONSerialization.data(withJSONObject: plainDict)
                let argumentsString = String(data: argumentsData, encoding: .utf8) ?? "{}"
                
                let toolCallItem = ToolCallItem(
                    id: UUID().uuidString,
                    type: .function,
                    function: FunctionCall(
                        name: toolCall.function.name,
                        arguments: argumentsString
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
}

// MARK: - Ollama API Types

private struct OllamaRequest {
    let model: String
    let messages: [OllamaMessage]
    var stream: Bool = false
    let options: [String: Any]?
    let tools: [[String: Any]]?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, stream, options, tools
    }
    
    init(model: String, messages: [OllamaMessage], stream: Bool = false, options: [String: Any]?, tools: [[String: Any]]?) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.options = options
        self.tools = tools
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encode(stream, forKey: .stream)
        
        // We'll encode the entire request as JSON manually
        // This is necessary because Swift's Codable doesn't handle [String: Any] well
    }
    
    func toData() throws -> Data {
        var dict: [String: Any] = [
            "model": model,
            "messages": messages.map { msg in
                var msgDict: [String: Any] = ["role": msg.role, "content": msg.content]
                if let images = msg.images {
                    msgDict["images"] = images
                }
                return msgDict
            },
            "stream": stream
        ]
        
        if let options = options {
            dict["options"] = options
        }
        
        if let tools = tools {
            dict["tools"] = tools
        }
        
        return try JSONSerialization.data(withJSONObject: dict, options: [])
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
    let arguments: AnyCodable
    
    init(name: String, arguments: AnyCodable) {
        self.name = name
        self.arguments = arguments
    }
    
    // Helper to get arguments as dictionary
    var argumentsDict: [String: AnyCodable] {
        if let dict = arguments.value as? [String: Any] {
            return dict.mapValues { AnyCodable($0) }
        } else if let dict = arguments.value as? [String: AnyCodable] {
            return dict
        }
        return [:]
    }
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