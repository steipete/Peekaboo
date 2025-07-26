import Foundation
import AXorcist

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
        let endpoint = getEndpointForModel(request.settings.modelName)
        let urlRequest = try createURLRequest(endpoint: endpoint, body: openAIRequest)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelError.requestFailed(URLError(.badServerResponse))
        }
        
        if httpResponse.statusCode != 200 {
            aiDebugPrint("DEBUG: HTTP Status Code: \(httpResponse.statusCode)")
            aiDebugPrint("DEBUG: Response Headers: \(httpResponse.allHeaderFields)")
            
            var errorMessage = "HTTP \(httpResponse.statusCode)"
            if let responseString = String(data: data, encoding: .utf8) {
                aiDebugPrint("DEBUG: Error Response: \(responseString)")
                errorMessage += ": \(responseString)"
            }
            
            if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw handleOpenAIError(errorResponse, statusCode: httpResponse.statusCode)
            }
            
            // Create a more descriptive error
            throw ModelError.requestFailed(NSError(
                domain: "OpenAI",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            ))
        }
        
        // Debug: Print response for troubleshooting
        if let responseString = String(data: data, encoding: .utf8) {
            aiDebugPrint("DEBUG: OpenAI Response: \(responseString)")
        }
        
        do {
            // Always expect Responses API format
            let responsesResponse = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
            return try convertFromOpenAIResponsesResponse(responsesResponse)
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
        let endpoint = getEndpointForModel(request.settings.modelName)
        let urlRequest = try createURLRequest(endpoint: endpoint, body: openAIRequest)
        
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
                        
                        var errorMessage = "HTTP \(httpResponse.statusCode)"
                        if let responseString = String(data: errorData, encoding: .utf8) {
                            aiDebugPrint("DEBUG: Error response: \(responseString)")
                            errorMessage += ": \(responseString)"
                        }
                        
                        if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: errorData) {
                            continuation.finish(throwing: self.handleOpenAIError(errorResponse, statusCode: httpResponse.statusCode))
                        } else {
                            // Create a more descriptive error
                            continuation.finish(throwing: ModelError.requestFailed(NSError(
                                domain: "OpenAI",
                                code: httpResponse.statusCode,
                                userInfo: [NSLocalizedDescriptionKey: errorMessage]
                            )))
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
                                // Use simple JSON parsing for now to avoid decoding issues
                                if let jsonObj = try? JSONSerialization.jsonObject(with: chunkData, options: []) as? [String: Any] {
                                    let chunkType = jsonObj["type"] as? String ?? "unknown"
                                    
                                    // Handle text delta events directly
                                    if chunkType == "response.output_text.delta" {
                                        if let delta = jsonObj["delta"] as? String, 
                                           let outputIndex = jsonObj["output_index"] as? Int {
                                            let event = StreamEvent.textDelta(StreamTextDelta(delta: delta, index: outputIndex))
                                            continuation.yield(event)
                                        }
                                    } else if chunkType == "response.created" || chunkType == "response.in_progress" {
                                        if let responseData = jsonObj["response"] as? [String: Any],
                                           let id = responseData["id"] as? String,
                                           let model = responseData["model"] as? String {
                                            let event = StreamEvent.responseStarted(StreamResponseStarted(
                                                id: id,
                                                model: model,
                                                systemFingerprint: nil
                                            ))
                                            continuation.yield(event)
                                        }
                                    } else if chunkType == "response.completed" {
                                        if let responseData = jsonObj["response"] as? [String: Any],
                                           let id = responseData["id"] as? String {
                                            let event = StreamEvent.responseCompleted(StreamResponseCompleted(
                                                id: id,
                                                usage: nil,
                                                finishReason: nil
                                            ))
                                            continuation.yield(event)
                                        }
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
    
    private func getEndpointForModel(_ modelName: String) -> String {
        // Always use Responses API for all models
        // It supports reasoning visibility and all modern features
        return "responses"
    }
    
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
    
    private func convertToOpenAIRequest(_ request: ModelRequest, stream: Bool) throws -> any Encodable {
        // Always use Responses API
        return try convertToOpenAIResponsesRequest(request, stream: stream)
    }
    
    private func convertToOpenAIResponsesRequest(_ request: ModelRequest, stream: Bool) throws -> OpenAIResponsesRequest {
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
                
            case .reasoning:
                // Skip reasoning messages for now - they may not be supported by the API
                throw ModelError.invalidConfiguration("Reasoning messages not supported in OpenAI API")
                
            case .unknown:
                throw ModelError.invalidConfiguration("Unknown message type")
            }
        }
        
        // Convert tools
        let tools = request.tools?.map { tool in
            OpenAITool(
                type: "function",
                function: OpenAITool.Function(
                    name: tool.function.name,
                    description: tool.function.description,
                    parameters: convertToolParameters(tool.function.parameters)
                )
            )
        }
        
        return OpenAIResponsesRequest(
            model: request.settings.modelName,
            input: messages,  // Note: 'input' not 'messages' for Responses API
            tools: nil,  // TODO: Fix tool format for Responses API
            toolChoice: nil,
            temperature: (request.settings.modelName.hasPrefix("o3") || request.settings.modelName.hasPrefix("o4")) ? nil : request.settings.temperature,
            topP: request.settings.topP,
            stream: stream,
            maxOutputTokens: request.settings.maxTokens ?? 65536,
            reasoningEffort: nil,  // Removed - now part of reasoning object
            reasoning: (request.settings.modelName.hasPrefix("o3") || request.settings.modelName.hasPrefix("o4")) ? 
                OpenAIReasoning(effort: request.settings.additionalParameters?["reasoning_effort"]?.value as? String ?? "high", summary: "detailed") : nil
        )
    }
    
    private func convertToOpenAIChatCompletionRequest(_ request: ModelRequest, stream: Bool) throws -> OpenAIChatCompletionRequest {
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
        
        // Use max_completion_tokens for models that require it (o3, o4, etc.)
        let useMaxCompletionTokens = request.settings.modelName.hasPrefix("o3") || request.settings.modelName.hasPrefix("o4")
        
        return OpenAIChatCompletionRequest(
            model: request.settings.modelName,
            messages: messages,
            tools: tools,
            toolChoice: convertToolChoice(request.settings.toolChoice),
            temperature: request.settings.temperature,
            topP: request.settings.topP,
            stream: stream,
            maxTokens: useMaxCompletionTokens ? nil : request.settings.maxTokens,
            reasoningEffort: nil,  // Not supported in current API
            maxCompletionTokens: useMaxCompletionTokens ? request.settings.maxTokens : nil,
            reasoning: nil  // Not supported in current API
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
    
    private func convertFromOpenAIResponsesResponse(_ response: OpenAIResponsesResponse) throws -> ModelResponse {
        guard let choice = response.choices.first else {
            throw ModelError.responseParsingFailed("No choices in response")
        }
        
        var content: [AssistantContent] = []
        
        // Add text content if present
        if let textContent = choice.message.content {
            content.append(.outputText(textContent))
        }
        
        // Add reasoning content if present
        if let reasoningContent = choice.message.reasoningContent {
            // For now, append reasoning as regular text with a prefix
            content.append(.outputText("\n💭 Reasoning: \(reasoningContent)\n"))
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
                promptTokensDetails: usage.promptTokensDetails.map { details in
                    TokenDetails(
                        cachedTokens: details.cachedTokens,
                        audioTokens: details.audioTokens,
                        reasoningTokens: details.reasoningTokens
                    )
                },
                completionTokensDetails: usage.completionTokensDetails.map { details in
                    TokenDetails(
                        cachedTokens: details.cachedTokens,
                        audioTokens: details.audioTokens,
                        reasoningTokens: details.reasoningTokens
                    )
                }
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
    
    // Removed - we only use Responses API now
    
    private func processResponsesChunk(
        _ chunk: OpenAIResponsesChunk,
        toolCalls: inout [String: PartialToolCall],
        indexMap: inout [Int: String]
    ) -> [StreamEvent]? {
        var events: [StreamEvent] = []
        
        switch chunk.type {
        case "response.created", "response.in_progress":
            // Handle response started
            if let response = chunk.response {
                events.append(.responseStarted(StreamResponseStarted(
                    id: response.id,
                    model: response.model ?? "unknown",
                    systemFingerprint: nil
                )))
            }
            
        case "response.output_text.delta":
            // Handle text delta
            if let delta = chunk.delta, !delta.isEmpty, let outputIndex = chunk.outputIndex {
                events.append(.textDelta(StreamTextDelta(delta: delta, index: outputIndex)))
            }
            
        case "response.reasoning_summary.delta":
            // Handle reasoning content delta
            if let delta = chunk.delta, !delta.isEmpty {
                events.append(.reasoningSummaryDelta(StreamReasoningSummaryDelta(delta: delta)))
                aiDebugPrint("DEBUG: Responses API streaming reasoning: \(delta)")
            }
            
        case "response.function_call_arguments.delta":
            // Handle function call arguments delta
            if let itemId = chunk.itemId, let delta = chunk.delta, let outputIndex = chunk.outputIndex {
                // For function calls, we need to parse the JSON arguments incrementally
                var toolCallId = itemId
                
                // Store or update the tool call
                if toolCalls[toolCallId] == nil {
                    // Create a new partial tool call
                    let partialCall = PartialToolCall()
                    partialCall.id = toolCallId
                    partialCall.type = "function"
                    partialCall.index = outputIndex
                    toolCalls[toolCallId] = partialCall
                }
                
                // Append arguments delta
                if let existingCall = toolCalls[toolCallId] {
                    existingCall.appendArguments(delta)
                    
                    // Emit delta event
                    events.append(.toolCallDelta(StreamToolCallDelta(
                        id: toolCallId,
                        index: outputIndex,
                        function: FunctionCallDelta(
                            name: existingCall.name,
                            arguments: delta
                        )
                    )))
                }
            }
            
        case "response.completed":
            // Handle response completion
            if let response = chunk.response {
                // Emit completion event
                events.append(.responseCompleted(StreamResponseCompleted(
                    id: response.id,
                    usage: nil,
                    finishReason: nil
                )))
            }
            
        default:
            // Ignore other event types for now
            break
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
    var id: String = ""
    var type: String = "function"
    var index: Int = 0
    var name: String?
    var arguments: String = ""
    
    init() {
        // Default initializer for Responses API
    }
    
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
    
    func appendArguments(_ args: String) {
        self.arguments += args
    }
    
    func toCompleted() -> FunctionCall? {
        guard let name = name else { return nil }
        return FunctionCall(name: name, arguments: arguments)
    }
}