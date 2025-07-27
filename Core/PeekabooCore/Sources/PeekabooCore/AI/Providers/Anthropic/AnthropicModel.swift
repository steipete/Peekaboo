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

/// Anthropic model implementation conforming to ModelInterface
public final class AnthropicModel: ModelInterface {
    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession
    private let anthropicVersion: String
    private let modelName: String?
    
    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.anthropic.com/v1")!,
        anthropicVersion: String = "2023-06-01",
        modelName: String? = nil,
        session: URLSession? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.anthropicVersion = anthropicVersion
        self.modelName = modelName
        self.session = session ?? URLSession.shared
    }
    
    // MARK: - ModelInterface Implementation
    
    public var maskedApiKey: String {
        guard apiKey.count > 8 else { return "***" }
        let start = apiKey.prefix(6)
        let end = apiKey.suffix(2)
        return "\(start)...\(end)"
    }
    
    public func getResponse(request: ModelRequest) async throws -> ModelResponse {
        let anthropicRequest = try convertToAnthropicRequest(request, stream: false)
        let urlRequest = try createURLRequest(endpoint: "messages", body: anthropicRequest)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PeekabooError.networkError("Invalid server response")
        }
        
        // Use NetworkErrorHandling for consistent error handling
        try session.handleErrorResponse(
            AnthropicErrorResponse.self,
            data: data,
            response: response,
            context: "Anthropic API"
        )
        
        // Debug: Print response for troubleshooting
        if let responseString = String(data: data, encoding: .utf8) {
            aiDebugPrint("DEBUG: Anthropic Response: \(responseString)")
        }
        
        do {
            let anthropicResponse = try JSONCoding.decoder.decode(AnthropicResponse.self, from: data)
            return try convertFromAnthropicResponse(anthropicResponse)
        } catch {
            aiDebugPrint("DEBUG: Failed to decode Anthropic response: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                aiDebugPrint("DEBUG: Raw response was: \(responseString)")
            }
            throw error.asPeekabooError(context: "Failed to decode Anthropic response")
        }
    }
    
    public func getStreamedResponse(request: ModelRequest) async throws -> AsyncThrowingStream<StreamEvent, Error> {
        let anthropicRequest = try convertToAnthropicRequest(request, stream: true)
        let urlRequest = try createURLRequest(endpoint: "messages", body: anthropicRequest)
        
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
                        
                        do {
                            try self.session.handleErrorResponse(
                                AnthropicErrorResponse.self,
                                data: errorData,
                                response: response,
                                context: "Anthropic API (streaming)"
                            )
                        } catch {
                            continuation.finish(throwing: error)
                            return
                        }
                    }
                    
                    // Process SSE stream
                    var currentToolCalls: [String: PartialToolCall] = [:]
                    var responseId: String?
                    // var responseModel: String? // Not used in Anthropic API
                    var accumulatedText = ""
                    var currentContentIndex = 0
                    
                    for try await line in bytes.lines {
                        // Skip empty lines
                        if line.isEmpty {
                            continue
                        }
                        
                        // Handle SSE format
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))
                            
                            // Parse the event
                            if let eventData = data.data(using: .utf8) {
                                do {
                                    let event = try JSONCoding.decoder.decode(AnthropicStreamEvent.self, from: eventData)
                                    
                                    switch event.type {
                                    case "message_start":
                                        if let message = event.message {
                                            responseId = message.id
                                            // responseModel = message.model // Not used
                                            continuation.yield(.responseStarted(StreamResponseStarted(
                                                id: message.id,
                                                model: message.model,
                                                systemFingerprint: nil
                                            )))
                                        }
                                        
                                    case "content_block_start":
                                        currentContentIndex = event.index ?? 0
                                        if let block = event.contentBlock {
                                            if block.type == "tool_use", let id = block.id, let name = block.name {
                                                // Start tracking this tool call
                                                let partialCall = PartialToolCall(
                                                    id: id,
                                                    name: name,
                                                    index: currentContentIndex
                                                )
                                                currentToolCalls[id] = partialCall
                                            }
                                        }
                                        
                                    case "content_block_delta":
                                        if let delta = event.delta {
                                            if let text = delta.text {
                                                // Text delta
                                                continuation.yield(.textDelta(StreamTextDelta(
                                                    delta: text,
                                                    index: currentContentIndex
                                                )))
                                                accumulatedText += text
                                            } else if let partialJson = delta.partialJson {
                                                // Tool use arguments delta
                                                // Find the tool call being updated
                                                if let toolCall = currentToolCalls.values.first(where: { $0.index == currentContentIndex }) {
                                                    toolCall.appendArguments(partialJson)
                                                    continuation.yield(.toolCallDelta(StreamToolCallDelta(
                                                        id: toolCall.id,
                                                        index: toolCall.index,
                                                        function: FunctionCallDelta(
                                                            name: toolCall.name,
                                                            arguments: partialJson
                                                        )
                                                    )))
                                                }
                                            }
                                        }
                                        
                                    case "content_block_stop":
                                        // Complete any tool calls at this index
                                        for (id, toolCall) in currentToolCalls {
                                            if toolCall.index == currentContentIndex {
                                                if let completed = toolCall.toCompleted() {
                                                    continuation.yield(.toolCallCompleted(
                                                        StreamToolCallCompleted(id: id, function: completed)
                                                    ))
                                                }
                                            }
                                        }
                                        
                                    case "message_delta":
                                        // Handle stop reason and usage
                                        if let stopReason = event.stopReason {
                                            let finishReason = self.convertStopReason(stopReason)
                                            if let id = responseId {
                                                continuation.yield(.responseCompleted(StreamResponseCompleted(
                                                    id: id,
                                                    usage: nil,
                                                    finishReason: finishReason
                                                )))
                                            }
                                        }
                                        
                                    case "message_stop":
                                        // Final completion
                                        continuation.finish()
                                        return
                                        
                                    case "error":
                                        if let error = event.error {
                                            continuation.finish(throwing: ModelError.requestFailed(
                                                NSError(domain: "Anthropic", code: 0, userInfo: [
                                                    NSLocalizedDescriptionKey: error.message
                                                ])
                                            ))
                                            return
                                        }
                                        
                                    default:
                                        aiDebugPrint("DEBUG: Unknown event type: \(event.type)")
                                    }
                                } catch {
                                    let peekabooError = error.asPeekabooError(context: "Failed to parse Anthropic stream event")
                                    aiDebugPrint("DEBUG: Failed to parse event: \(peekabooError)")
                                    aiDebugPrint("DEBUG: Event data: \(data)")
                                }
                            }
                        }
                    }
                    
                    aiDebugPrint("DEBUG: Stream processing completed")
                    continuation.finish()
                } catch {
                    let peekabooError = error.asPeekabooError(context: "Anthropic stream processing failed")
                    aiDebugPrint("DEBUG: Stream error: \(peekabooError)")
                    continuation.finish(throwing: peekabooError)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func createURLRequest(endpoint: String, body: Encodable) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Note: Using a custom encoder here to only have sortedKeys without prettyPrinted
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            aiDebugPrint("DEBUG: JSON Encoding failed: \(error)")
            throw error.asPeekabooError(context: "Failed to encode Anthropic request")
        }
        
        request.timeoutInterval = 60
        
        // Debug: Print request body
        if let bodyData = request.httpBody,
           let bodyString = String(data: bodyData, encoding: .utf8) {
            aiDebugPrint("DEBUG: Anthropic API Key: \(maskedApiKey)")
            aiDebugPrint("DEBUG: Anthropic Request Body:")
            aiDebugPrint(bodyString)
        }
        
        return request
    }
    
    private func convertToAnthropicRequest(_ request: ModelRequest, stream: Bool) throws -> AnthropicRequest {
        var anthropicMessages: [AnthropicMessage] = []
        var systemPrompt: String? = request.systemInstructions
        
        // Convert messages
        for message in request.messages {
            switch message.type {
            case .system:
                guard let system = message as? SystemMessageItem else {
                    throw PeekabooError.invalidInput(field: "message", reason: "Invalid system message")
                }
                // Anthropic uses a separate system parameter
                if systemPrompt == nil {
                    systemPrompt = system.content
                } else {
                    systemPrompt = (systemPrompt ?? "") + "\n\n" + system.content
                }
                
            case .user:
                guard let user = message as? UserMessageItem else {
                    throw PeekabooError.invalidInput(field: "message", reason: "Invalid user message")
                }
                let anthropicMessage = try convertUserMessage(user)
                anthropicMessages.append(anthropicMessage)
                
            case .assistant:
                guard let assistant = message as? AssistantMessageItem else {
                    throw PeekabooError.invalidInput(field: "message", reason: "Invalid assistant message")
                }
                let anthropicMessage = try convertAssistantMessage(assistant)
                anthropicMessages.append(anthropicMessage)
                
            case .tool:
                guard let tool = message as? ToolMessageItem else {
                    throw PeekabooError.invalidInput(field: "message", reason: "Invalid tool message")
                }
                // Convert tool result to user message with tool_result content block
                let toolResultBlock = AnthropicContentBlock.toolResult(
                    toolUseId: tool.toolCallId,
                    content: tool.content
                )
                anthropicMessages.append(AnthropicMessage(
                    role: .user,
                    content: .array([toolResultBlock])
                ))
                
            default:
                throw PeekabooError.invalidInput(field: "message", reason: "Unsupported message type: \(message.type)")
            }
        }
        
        // Convert tools (without cache control to avoid exceeding the 4 block limit)
        let tools = request.tools?.map { toolDef -> AnthropicTool in
            AnthropicTool(
                name: toolDef.function.name,
                description: toolDef.function.description,
                inputSchema: convertToolParameters(toolDef.function.parameters)
            )
        }
        
        // Convert tool choice
        let toolChoice = convertToolChoice(request.settings.toolChoice)
        
        // Create system content with cache control
        let systemContent: AnthropicSystemContent?
        if let systemPrompt = systemPrompt {
            // Use array format with cache control for system prompt
            systemContent = .array([
                AnthropicSystemBlock(
                    type: "text",
                    text: systemPrompt,
                    cacheControl: AnthropicCacheControl(type: "ephemeral")
                )
            ])
        } else {
            systemContent = nil
        }
        
        return AnthropicRequest(
            model: modelName ?? request.settings.modelName,
            messages: anthropicMessages,
            system: systemContent,
            maxTokens: request.settings.maxTokens ?? 4096,
            temperature: request.settings.temperature,
            topP: request.settings.topP,
            topK: request.settings.additionalParameters?["top_k"]?.value as? Int,
            stream: stream,
            stopSequences: request.settings.stopSequences,
            tools: tools,
            toolChoice: toolChoice,
            metadata: request.settings.user.map { AnthropicMetadata(userId: $0) }
        )
    }
    
    private func convertUserMessage(_ message: UserMessageItem) throws -> AnthropicMessage {
        switch message.content {
        case .text(let text):
            return AnthropicMessage(role: .user, content: .string(text))
            
        case .image(let imageContent):
            var blocks: [AnthropicContentBlock] = []
            
            if let base64 = imageContent.base64 {
                blocks.append(.image(base64: base64, mediaType: "image/jpeg"))
            } else if imageContent.url != nil {
                // For URLs, we'd need to download and convert to base64
                // For now, throw an error
                throw PeekabooError.invalidInput(field: "image", reason: "Image URLs not supported - please provide base64 data")
            }
            
            return AnthropicMessage(role: .user, content: .array(blocks))
            
        case .multimodal(let parts):
            let blocks = try parts.compactMap { part -> AnthropicContentBlock? in
                if let text = part.text {
                    return .text(text)
                } else if let image = part.imageUrl {
                    if let base64 = image.base64 {
                        return .image(base64: base64, mediaType: "image/jpeg")
                    } else if image.url != nil {
                        throw PeekabooError.invalidInput(field: "image", reason: "Image URLs not supported - please provide base64 data")
                    }
                }
                return nil
            }
            return AnthropicMessage(role: .user, content: .array(blocks))
            
        case .file:
            throw PeekabooError.invalidInput(field: "content", reason: "File content not supported in Anthropic API")
        }
    }
    
    private func convertAssistantMessage(_ message: AssistantMessageItem) throws -> AnthropicMessage {
        var blocks: [AnthropicContentBlock] = []
        
        for content in message.content {
            switch content {
            case .outputText(let text):
                blocks.append(.text(text))
                
            case .refusal(let refusal):
                blocks.append(.text(refusal))
                
            case .toolCall(let toolCall):
                // Parse arguments as JSON
                let arguments: [String: Any]
                if let data = toolCall.function.arguments.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    arguments = json
                } else {
                    arguments = [:]
                }
                
                blocks.append(.toolUse(
                    id: toolCall.id,
                    name: toolCall.function.name,
                    input: arguments
                ))
            }
        }
        
        return AnthropicMessage(role: .assistant, content: .array(blocks))
    }
    
    private func convertToolParameters(_ params: ToolParameters) -> AnthropicJSONSchema {
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
        
        return AnthropicJSONSchema(
            type: params.type,
            properties: properties,
            required: params.required
        )
    }
    
    private func convertToolChoice(_ toolChoice: ToolChoice?) -> AnthropicToolChoice? {
        guard let toolChoice = toolChoice else { return nil }
        
        switch toolChoice {
        case .auto:
            return .auto
        case .none:
            return nil  // Anthropic doesn't have a "none" option
        case .required:
            return .any
        case .specific(let toolName):
            return .tool(name: toolName)
        }
    }
    
    private func convertFromAnthropicResponse(_ response: AnthropicResponse) throws -> ModelResponse {
        var content: [AssistantContent] = []
        
        // Convert content blocks
        for block in response.content {
            switch block.type {
            case "text":
                if let text = block.text {
                    content.append(.outputText(text))
                }
                
            case "tool_use":
                if let id = block.id,
                   let name = block.name,
                   let input = block.input {
                    // Convert input dictionary to JSON string
                    let arguments: String
                    if let data = try? JSONSerialization.data(withJSONObject: input),
                       let json = String(data: data, encoding: .utf8) {
                        arguments = json
                    } else {
                        arguments = "{}"
                    }
                    
                    content.append(.toolCall(ToolCallItem(
                        id: id,
                        type: .function,
                        function: FunctionCall(
                            name: name,
                            arguments: arguments
                        )
                    )))
                }
                
            default:
                aiDebugPrint("DEBUG: Unknown content block type: \(block.type)")
            }
        }
        
        let usage = Usage(
            promptTokens: response.usage.inputTokens,
            completionTokens: response.usage.outputTokens,
            totalTokens: response.usage.inputTokens + response.usage.outputTokens,
            promptTokensDetails: nil,
            completionTokensDetails: nil
        )
        
        return ModelResponse(
            id: response.id,
            model: response.model,
            content: content,
            usage: usage,
            flagged: false,
            finishReason: convertStopReason(response.stopReason)
        )
    }
    
    private func convertStopReason(_ reason: String?) -> FinishReason? {
        guard let reason = reason else { return nil }
        
        switch reason {
        case "end_turn":
            return .stop
        case "max_tokens":
            return .length
        case "stop_sequence":
            return .stop
        case "tool_use":
            return .toolCalls
        default:
            return .stop
        }
    }
    
}

// MARK: - Helper Types

private class PartialToolCall {
    let id: String
    let name: String
    let index: Int
    var arguments: String = ""
    
    init(id: String, name: String, index: Int) {
        self.id = id
        self.name = name
        self.index = index
    }
    
    func appendArguments(_ args: String) {
        self.arguments += args
    }
    
    func toCompleted() -> FunctionCall? {
        return FunctionCall(name: name, arguments: arguments)
    }
}