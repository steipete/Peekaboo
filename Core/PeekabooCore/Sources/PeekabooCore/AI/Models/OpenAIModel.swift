import Foundation

// Simple debug logging check
fileprivate var isDebugLoggingEnabled: Bool {
    // Check if verbose mode is enabled via log level
    if let logLevel = ProcessInfo.processInfo.environment["PEEKABOO_LOG_LEVEL"]?.lowercased() {
        return logLevel == "debug" || logLevel == "trace"
    }
    // Check if agent is in verbose mode
    if ProcessInfo.processInfo.arguments.contains("-v") || 
       ProcessInfo.processInfo.arguments.contains("--verbose") {
        return true
    }
    return false
}

fileprivate func aiDebugPrint(_ message: String) {
    if isDebugLoggingEnabled {
        print(message)
    }
}

/// OpenAI model implementation conforming to ModelInterface
public final class OpenAIModel: ModelInterface {
    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession
    private let organizationId: String?
    
    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        organizationId: String? = nil,
        session: URLSession? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.organizationId = organizationId
        self.session = session ?? URLSession.shared
    }
    
    // MARK: - ModelInterface Implementation
    
    public func getResponse(request: ModelRequest) async throws -> ModelResponse {
        let openAIRequest = try convertToOpenAIRequest(request, stream: false)
        
        
        let urlRequest = try createURLRequest(endpoint: "chat/completions", body: openAIRequest)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelError.requestFailed(URLError(.badServerResponse))
        }
        
        if httpResponse.statusCode != 200 {
            aiDebugPrint("DEBUG: HTTP Status Code: \(httpResponse.statusCode)")
            aiDebugPrint("DEBUG: Response Headers: \(httpResponse.allHeaderFields)")
            if let responseString = String(data: data, encoding: .utf8) {
                aiDebugPrint("DEBUG: Error Response: \(responseString)")
            }
            if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw handleOpenAIError(errorResponse, statusCode: httpResponse.statusCode)
            }
            throw ModelError.requestFailed(URLError(.badServerResponse))
        }
        
        // Debug: Print response for troubleshooting
        if let responseString = String(data: data, encoding: .utf8) {
            aiDebugPrint("DEBUG: OpenAI Response: \(responseString)")
        }
        
        do {
            let openAIResponse = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data)
            return try convertFromOpenAIResponse(openAIResponse)
        } catch {
            aiDebugPrint("DEBUG: Failed to decode OpenAI response: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                aiDebugPrint("DEBUG: Raw response was: \(responseString)")
            }
            throw ModelError.requestFailed(error)
        }
    }
    
    public func getStreamedResponse(request: ModelRequest) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        let openAIRequest = try convertToOpenAIRequest(request, stream: true)
        let urlRequest = try createURLRequest(endpoint: "chat/completions", body: openAIRequest)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ModelError.requestFailed(URLError(.badServerResponse)))
                        return
                    }
                    
                    aiDebugPrint("DEBUG: HTTP Response Status: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode != 200 {
                        // Try to read error from first chunk
                        var errorData = Data()
                        for try await byte in bytes.prefix(1024) {
                            errorData.append(byte)
                        }
                        
                        aiDebugPrint("DEBUG: Error response: \(String(data: errorData, encoding: .utf8) ?? "Unable to decode")")
                        
                        if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: errorData) {
                            continuation.finish(throwing: self.handleOpenAIError(errorResponse, statusCode: httpResponse.statusCode))
                        } else {
                            continuation.finish(throwing: ModelError.requestFailed(URLError(.badServerResponse)))
                        }
                        return
                    }
                    
                    // Process SSE stream
                    var currentToolCalls: [String: PartialToolCall] = [:]
                    var toolCallIndexMap: [Int: String] = [:]  // Track tool call IDs by index
                    
                    for try await line in bytes.lines {
                        // Handle SSE format
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))
                            
                            if data == "[DONE]" {
                                // Send any pending tool calls
                                for (id, toolCall) in currentToolCalls {
                                    if let completed = toolCall.toCompleted() {
                                        continuation.yield(.toolCallCompleted(
                                            StreamToolCallCompleted(id: id, function: completed)
                                        ))
                                    }
                                }
                                continuation.finish()
                                return
                            }
                            
                            // Parse chunk
                            if let chunkData = data.data(using: .utf8) {
                                do {
                                    let chunk = try JSONDecoder().decode(OpenAIChatCompletionChunk.self, from: chunkData)
                                    
                                    // Process chunk into stream events
                                    if let events = self.processChunk(chunk, toolCalls: &currentToolCalls, indexMap: &toolCallIndexMap) {
                                        for event in events {
                                            continuation.yield(event)
                                        }
                                    }
                                } catch {
                                    aiDebugPrint("DEBUG: Failed to decode chunk: \(error)")
                                    aiDebugPrint("DEBUG: Chunk data: \(data)")
                                    // Try to see what's in the error
                                    if let decodingError = error as? DecodingError {
                                        aiDebugPrint("DEBUG: DecodingError details: \(decodingError)")
                                    }
                                }
                            }
                        }
                    }
                    
                    aiDebugPrint("DEBUG: Stream processing completed")
                    continuation.finish()
                } catch {
                    aiDebugPrint("DEBUG: Stream error: \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func createURLRequest(endpoint: String, body: Encodable) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let orgId = organizationId {
            request.setValue(orgId, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            aiDebugPrint("DEBUG: JSON Encoding failed: \(error)")
            throw error
        }
        
        request.timeoutInterval = 60
        
        // Debug: Print request body
        if let bodyData = request.httpBody,
           let bodyString = String(data: bodyData, encoding: .utf8) {
            aiDebugPrint("DEBUG: OpenAI Request Body:")
            aiDebugPrint(bodyString)
        }
        
        return request
    }
    
    private func convertToOpenAIRequest(_ request: ModelRequest, stream: Bool) throws -> OpenAIChatCompletionRequest {
        // Convert messages to OpenAI format
        let messages = try request.messages.map { message -> OpenAIMessage in
            switch message.type {
            case .system:
                guard let system = message as? SystemMessageItem else {
                    throw ModelError.invalidConfiguration("Invalid system message")
                }
                return OpenAIMessage(role: "system", content: .string(system.content))
                
            case .user:
                guard let user = message as? UserMessageItem else {
                    throw ModelError.invalidConfiguration("Invalid user message")
                }
                return try convertUserMessage(user)
                
            case .assistant:
                guard let assistant = message as? AssistantMessageItem else {
                    throw ModelError.invalidConfiguration("Invalid assistant message")
                }
                return try convertAssistantMessage(assistant)
                
            case .tool:
                guard let tool = message as? ToolMessageItem else {
                    throw ModelError.invalidConfiguration("Invalid tool message")
                }
                return OpenAIMessage(
                    role: "tool",
                    content: .string(tool.content),
                    toolCallId: tool.toolCallId
                )
                
            default:
                throw ModelError.invalidConfiguration("Unsupported message type: \(message.type)")
            }
        }
        
        // Convert tools to OpenAI format
        let tools = request.tools?.map { toolDef -> OpenAITool in
            OpenAITool(
                type: "function",
                function: OpenAITool.Function(
                    name: toolDef.function.name,
                    description: toolDef.function.description,
                    parameters: convertToolParameters(toolDef.function.parameters)
                )
            )
        }
        
        return OpenAIChatCompletionRequest(
            model: request.settings.modelName,
            messages: messages,
            tools: tools,
            toolChoice: convertToolChoice(request.settings.toolChoice),
            temperature: request.settings.temperature,
            topP: request.settings.topP,
            stream: stream,
            maxTokens: request.settings.maxTokens
        )
    }
    
    private func convertUserMessage(_ message: UserMessageItem) throws -> OpenAIMessage {
        switch message.content {
        case .text(let text):
            return OpenAIMessage(role: "user", content: .string(text))
            
        case .image(let imageContent):
            var content: [OpenAIMessageContentPart] = []
            
            if let url = imageContent.url {
                content.append(OpenAIMessageContentPart(
                    type: "image_url",
                    text: nil,
                    imageUrl: OpenAIImageUrl(
                        url: url,
                        detail: imageContent.detail?.rawValue
                    )
                ))
            } else if let base64 = imageContent.base64 {
                content.append(OpenAIMessageContentPart(
                    type: "image_url",
                    text: nil,
                    imageUrl: OpenAIImageUrl(
                        url: "data:image/jpeg;base64,\(base64)",
                        detail: imageContent.detail?.rawValue
                    )
                ))
            }
            
            return OpenAIMessage(role: "user", content: .array(content))
            
        case .multimodal(let parts):
            let content = parts.compactMap { part -> OpenAIMessageContentPart? in
                if let text = part.text {
                    return OpenAIMessageContentPart(
                        type: "text",
                        text: text,
                        imageUrl: nil
                    )
                } else if let image = part.imageUrl {
                    if let url = image.url {
                        return OpenAIMessageContentPart(
                            type: "image_url",
                            text: nil,
                            imageUrl: OpenAIImageUrl(url: url, detail: image.detail?.rawValue)
                        )
                    } else if let base64 = image.base64 {
                        return OpenAIMessageContentPart(
                            type: "image_url",
                            text: nil,
                            imageUrl: OpenAIImageUrl(
                                url: "data:image/jpeg;base64,\(base64)",
                                detail: image.detail?.rawValue
                            )
                        )
                    }
                }
                return nil
            }
            return OpenAIMessage(role: "user", content: .array(content))
            
        case .file:
            throw ModelError.invalidConfiguration("File content not supported in OpenAI chat completions")
        }
    }
    
    private func convertAssistantMessage(_ message: AssistantMessageItem) throws -> OpenAIMessage {
        var textContent = ""
        var toolCalls: [OpenAIToolCall] = []
        
        for content in message.content {
            switch content {
            case .outputText(let text):
                textContent += text
                
            case .refusal(let refusal):
                return OpenAIMessage(role: "assistant", content: .string(refusal))
                
            case .toolCall(let toolCall):
                toolCalls.append(OpenAIToolCall(
                    id: toolCall.id,
                    type: "function",
                    function: OpenAIFunctionCall(
                        name: toolCall.function.name,
                        arguments: toolCall.function.arguments
                    )
                ))
            }
        }
        
        if !toolCalls.isEmpty {
            return OpenAIMessage(
                role: "assistant",
                content: textContent.isEmpty ? nil : .string(textContent),
                toolCalls: toolCalls
            )
        } else {
            return OpenAIMessage(role: "assistant", content: .string(textContent))
        }
    }
    
    private func convertToolParameters(_ params: ToolParameters) -> OpenAITool.Parameters {
        // Convert ToolParameters to a dictionary for serialization
        var properties: [String: Any] = [:]
        
        for (key, schema) in params.properties {
            var prop: [String: Any] = [
                "type": schema.type.rawValue
            ]
            
            if let description = schema.description {
                prop["description"] = description
            }
            
            if let enumValues = schema.enumValues {
                prop["enum"] = enumValues
            }
            
            if let minimum = schema.minimum {
                prop["minimum"] = minimum
            }
            
            if let maximum = schema.maximum {
                prop["maximum"] = maximum
            }
            
            if let pattern = schema.pattern {
                prop["pattern"] = pattern
            }
            
            // Handle nested items for arrays
            if schema.type == .array, let items = schema.items {
                prop["items"] = [
                    "type": items.value.type.rawValue
                ]
            }
            
            // Handle nested properties for objects
            if schema.type == .object, let nestedProps = schema.properties {
                var nestedProperties: [String: Any] = [:]
                for (nestedKey, nestedSchema) in nestedProps {
                    nestedProperties[nestedKey] = [
                        "type": nestedSchema.type.rawValue,
                        "description": nestedSchema.description ?? ""
                    ]
                }
                prop["properties"] = nestedProperties
            }
            
            properties[key] = prop
        }
        
        return OpenAITool.Parameters(
            type: params.type,
            properties: properties,
            required: params.required
        )
    }
    
    private func convertToolChoice(_ toolChoice: ToolChoice?) -> String? {
        guard let toolChoice = toolChoice else { return nil }
        
        switch toolChoice {
        case .auto:
            return "auto"
        case .none:
            return "none"
        case .required:
            return "required"
        case .specific(let toolName):
            // For specific tool, we need to encode it as JSON
            let obj = OpenAIToolChoiceObject(type: "function", function: ["name": toolName])
            if let data = try? JSONEncoder().encode(obj),
               let json = String(data: data, encoding: .utf8) {
                return json
            }
            return nil
        }
    }
    
    private func convertResponseFormat(_ format: ResponseFormat?) -> OpenAIResponseFormat? {
        guard let format = format else { return nil }
        
        switch format.type {
        case .text:
            return OpenAIResponseFormat(type: "text")
        case .jsonObject:
            return OpenAIResponseFormat(type: "json_object")
        case .jsonSchema:
            guard let schema = format.jsonSchema else { return nil }
            return OpenAIResponseFormat(
                type: "json_schema",
                jsonSchema: OpenAIJSONSchema(
                    name: schema.name,
                    strict: schema.strict,
                    schema: schema.schema
                )
            )
        }
    }
    
    private func convertFromOpenAIResponse(_ response: OpenAIChatCompletionResponse) throws -> ModelResponse {
        guard let choice = response.choices.first else {
            throw ModelError.responseParsingFailed("No choices in response")
        }
        
        var content: [AssistantContent] = []
        
        // Add text content if present
        if let textContent = choice.message.content {
            content.append(.outputText(textContent))
        }
        
        // Add tool calls if present
        if let toolCalls = choice.message.toolCalls {
            for toolCall in toolCalls {
                content.append(.toolCall(ToolCallItem(
                    id: toolCall.id,
                    type: .function,
                    function: FunctionCall(
                        name: toolCall.function.name,
                        arguments: toolCall.function.arguments
                    )
                )))
            }
        }
        
        let usage = response.usage.map { usage in
            Usage(
                promptTokens: usage.promptTokens,
                completionTokens: usage.completionTokens,
                totalTokens: usage.totalTokens,
                promptTokensDetails: nil,
                completionTokensDetails: nil
            )
        }
        
        return ModelResponse(
            id: response.id,
            model: response.model,
            content: content,
            usage: usage,
            flagged: false,
            finishReason: convertFinishReason(choice.finishReason)
        )
    }
    
    private func convertFinishReason(_ reason: String?) -> FinishReason? {
        guard let reason = reason else { return nil }
        return FinishReason(rawValue: reason)
    }
    
    private func processChunk(
        _ chunk: OpenAIChatCompletionChunk,
        toolCalls: inout [String: PartialToolCall],
        indexMap: inout [Int: String]
    ) -> [StreamEvent]? {
        guard let choice = chunk.choices.first else { return nil }
        
        var events: [StreamEvent] = []
        
        // Handle response started
        if chunk.choices.first?.index == 0 && events.isEmpty {
            events.append(.responseStarted(StreamResponseStarted(
                id: chunk.id,
                model: chunk.model,
                systemFingerprint: nil
            )))
        }
        
        // Handle text delta
        if let content = choice.delta.content, !content.isEmpty {
            events.append(.textDelta(StreamTextDelta(delta: content, index: choice.index)))
        }
        
        // Handle tool call deltas
        if let toolCallDeltas = choice.delta.toolCalls {
            for toolCallDelta in toolCallDeltas {
                // Determine the ID to use - either from the delta or by index lookup
                let effectiveId: String?
                if let id = toolCallDelta.id {
                    effectiveId = id
                    // Store the index mapping for future updates
                    indexMap[toolCallDelta.index] = id
                } else {
                    // Look up by index
                    effectiveId = indexMap[toolCallDelta.index]
                }
                
                if let id = effectiveId {
                    if let existingCall = toolCalls[id] {
                        // Update existing call
                        existingCall.update(with: toolCallDelta)
                    } else {
                        // New tool call
                        toolCalls[id] = PartialToolCall(from: toolCallDelta)
                    }
                    
                    // Always emit the delta event
                    events.append(.toolCallDelta(StreamToolCallDelta(
                        id: id,
                        index: toolCallDelta.index,
                        function: FunctionCallDelta(
                            name: toolCallDelta.function?.name,
                            arguments: toolCallDelta.function?.arguments
                        )
                    )))
                }
            }
        }
        
        // Handle finish reason
        if let finishReason = choice.finishReason {
            // Complete any pending tool calls
            for (id, toolCall) in toolCalls {
                if let completed = toolCall.toCompleted() {
                    events.append(.toolCallCompleted(
                        StreamToolCallCompleted(id: id, function: completed)
                    ))
                }
            }
            
            // Clear tool calls so they don't get emitted again
            toolCalls.removeAll()
            
            events.append(.responseCompleted(StreamResponseCompleted(
                id: chunk.id,
                usage: nil, // Usage comes separately in OpenAI streaming
                finishReason: convertFinishReason(finishReason)
            )))
        }
        
        return events.isEmpty ? nil : events
    }
    
    private func handleOpenAIError(_ errorResponse: OpenAIErrorResponse, statusCode: Int) -> Error {
        // OpenAIErrorResponse.error is of type OpenAIError
        // OpenAIError.error is of type ErrorDetail  
        let errorDetail = errorResponse.error.error
        
        switch statusCode {
        case 401:
            return ModelError.authenticationFailed
        case 429:
            return ModelError.rateLimitExceeded
        case 400 where errorDetail.code == "context_length_exceeded":
            return ModelError.contextLengthExceeded
        default:
            return ModelError.requestFailed(NSError(
                domain: "OpenAI",
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: errorDetail.message]
            ))
        }
    }
}

// MARK: - Helper Types

private class PartialToolCall {
    var id: String
    var index: Int
    var name: String?
    var arguments: String = ""
    
    init(from delta: OpenAIToolCallDelta) {
        self.id = delta.id ?? ""
        self.index = delta.index
        self.name = delta.function?.name
        self.arguments = delta.function?.arguments ?? ""
    }
    
    func update(with delta: OpenAIToolCallDelta) {
        if let funcName = delta.function?.name {
            self.name = funcName
        }
        if let args = delta.function?.arguments {
            self.arguments += args
        }
    }
    
    func toCompleted() -> FunctionCall? {
        guard let name = name else { return nil }
        return FunctionCall(name: name, arguments: arguments)
    }
}