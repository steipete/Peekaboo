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
        // Create custom session with longer timeout for o3 models
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 600  // 10 minutes
            config.timeoutIntervalForResource = 600
            self.session = URLSession(configuration: config)
        }
    }
    
    // MARK: - ModelInterface Implementation
    
    public var maskedApiKey: String {
        guard apiKey.count > 8 else { return "***" }
        let start = apiKey.prefix(6)
        let end = apiKey.suffix(2)
        return "\(start)...\(end)"
    }
    
    public func getResponse(request: ModelRequest) async throws -> ModelResponse {
        let openAIRequest = try convertToOpenAIRequest(request, stream: false)
        let endpoint = getEndpointForModel(request.settings.modelName)
        let urlRequest = try createURLRequest(endpoint: endpoint, body: openAIRequest)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard response is HTTPURLResponse else {
            throw PeekabooError.networkError("Invalid server response")
        }
        
        // Use NetworkErrorHandling for consistent error handling
        try session.handleErrorResponse(
            OpenAIErrorResponse.self,
            data: data,
            response: response,
            context: "OpenAI API"
        )
        
        // Debug: Print response for troubleshooting
        if let responseString = String(data: data, encoding: .utf8) {
            aiDebugPrint("DEBUG: OpenAI Response: \(responseString)")
        }
        
        do {
            // Always expect Responses API format
            let responsesResponse = try JSONCoding.decoder.decode(OpenAIResponsesResponse.self, from: data)
            return try convertFromOpenAIResponsesResponse(responsesResponse)
        } catch {
            aiDebugPrint("DEBUG: Failed to decode OpenAI response: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                aiDebugPrint("DEBUG: Raw response was: \(responseString)")
            }
            throw error.asPeekabooError(context: "Failed to decode OpenAI response")
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
                        
                        do {
                            try self.session.handleErrorResponse(
                                OpenAIErrorResponse.self,
                                data: errorData,
                                response: response,
                                context: "OpenAI API (streaming)"
                            )
                        } catch {
                            continuation.finish(throwing: error)
                            return
                        }
                    }
                    
                    // Process SSE stream
                    let currentToolCalls: [String: PartialToolCall] = [:]
                    // var toolCallIndexMap: [Int: String] = [:]  // Not used in current implementation
                    
                    for try await line in bytes.lines {
                        aiDebugPrint("DEBUG: SSE line: \(line)")
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
                                // Try to decode as structured chunk first
                                if let chunk = try? JSONCoding.decoder.decode(OpenAIStreamChunk.self, from: chunkData) {
                                    let chunkType = chunk.type
                                    
                                    // Handle text delta events directly
                                    if chunkType == "response.output_text.delta" {
                                        if let delta = chunk.delta, let outputIndex = chunk.outputIndex {
                                            aiDebugPrint("DEBUG: Yielding text delta: '\(delta)'")
                                            let event = StreamEvent.textDelta(StreamTextDelta(delta: delta, index: outputIndex))
                                            continuation.yield(event)
                                        } else {
                                            aiDebugPrint("DEBUG: response.output_text.delta missing delta or outputIndex")
                                        }
                                    } else if chunkType == "response.reasoning_summary.delta" || chunkType == "response.reasoning_text.delta" || chunkType == "response.reasoning_summary_text.delta" {
                                        // Handle reasoning deltas
                                        if let delta = chunk.delta {
                                            aiDebugPrint("DEBUG: Yielding reasoning delta (\(chunkType)): '\(delta)'")
                                            let event = StreamEvent.reasoningSummaryDelta(StreamReasoningSummaryDelta(delta: delta))
                                            continuation.yield(event)
                                        }
                                    } else if chunkType == "response.created" || chunkType == "response.in_progress" {
                                        if let responseData = chunk.response,
                                           let id = responseData.id,
                                           let model = responseData.model {
                                            let event = StreamEvent.responseStarted(StreamResponseStarted(
                                                id: id,
                                                model: model,
                                                systemFingerprint: nil
                                            ))
                                            continuation.yield(event)
                                        }
                                    } else if chunkType == "response.completed" {
                                        if let responseData = chunk.response,
                                           let id = responseData.id {
                                            
                                            // Check for tool calls in the output array
                                            if let outputArray = responseData.output {
                                                for (index, outputItem) in outputArray.enumerated() {
                                                    if let item = outputItem.item,
                                                       item.type == "function_call",
                                                       let itemId = item.id,
                                                       let name = item.name,
                                                       let arguments = item.arguments {
                                                        
                                                        aiDebugPrint("DEBUG: Found tool call in response.completed: \(name)")
                                                        
                                                        // First emit a delta event to populate the pending tool calls
                                                        let deltaEvent = StreamEvent.toolCallDelta(StreamToolCallDelta(
                                                            id: itemId,
                                                            index: index,
                                                            function: FunctionCallDelta(name: name, arguments: arguments)
                                                        ))
                                                        continuation.yield(deltaEvent)
                                                        
                                                        // Then emit the completed event
                                                        let completedEvent = StreamEvent.toolCallCompleted(StreamToolCallCompleted(
                                                            id: itemId,
                                                            function: FunctionCall(name: name, arguments: arguments)
                                                        ))
                                                        continuation.yield(completedEvent)
                                                    }
                                                }
                                            }
                                            
                                            // Extract usage if available
                                            var usage: Usage? = nil
                                            if let usageData = responseData.usage {
                                                aiDebugPrint("DEBUG: Found usage in response.completed: input=\(usageData.inputTokens ?? 0), output=\(usageData.outputTokens ?? 0), total=\(usageData.totalTokens ?? 0)")
                                                usage = Usage(
                                                    promptTokens: usageData.inputTokens ?? 0,
                                                    completionTokens: usageData.outputTokens ?? 0,
                                                    totalTokens: usageData.totalTokens ?? 0,
                                                    promptTokensDetails: nil,
                                                    completionTokensDetails: nil
                                                )
                                            }
                                            
                                            let event = StreamEvent.responseCompleted(StreamResponseCompleted(
                                                id: id,
                                                usage: usage,
                                                finishReason: nil
                                            ))
                                            continuation.yield(event)
                                        }
                                    } else if chunkType == "response.output_item.added" {
                                        // Handle when a new output item is added (reasoning, message, or function call)
                                        if let item = chunk.item,
                                           let itemType = item.type {
                                            aiDebugPrint("DEBUG: Output item added - type: \(itemType)")
                                            if itemType == "reasoning" {
                                                // Reasoning will be streamed via response.reasoning_text.delta
                                            } else if itemType == "message" {
                                                // Message text will be streamed via response.output_text.delta
                                            } else if itemType == "function_call" {
                                                // Function call args will be streamed via response.function_call_arguments.delta
                                            }
                                        }
                                    } else if chunkType == "response.output_item.done" {
                                        // Handle when an output item is completed
                                        if let item = chunk.item,
                                           item.type == "reasoning" {
                                            // For reasoning summaries, we need to handle the raw output
                                            // This is a special case where output contains the summary text
                                            if let output = item.output, !output.isEmpty {
                                                aiDebugPrint("DEBUG: Yielding reasoning summary completed: '\(output)'")
                                                let event = StreamEvent.reasoningSummaryCompleted(StreamReasoningSummaryCompleted(
                                                    summary: output,
                                                    reasoningTokens: nil
                                                ))
                                                continuation.yield(event)
                                            }
                                        }
                                    } else if chunkType == "response.function_call_arguments.delta" {
                                        // Handle function call arguments delta
                                        if let itemId = chunk.itemId,
                                           let delta = chunk.delta {
                                            aiDebugPrint("DEBUG: Yielding function call arguments delta: '\(delta)'")
                                            let event = StreamEvent.functionCallArgumentsDelta(StreamFunctionCallArgumentsDelta(
                                                id: itemId,
                                                arguments: delta
                                            ))
                                            continuation.yield(event)
                                        }
                                    } else if chunkType == "response.content_part.added" {
                                        // Handle content part added (signals start of text output)
                                        aiDebugPrint("DEBUG: Content part added")
                                    } else if chunkType == "response.output_text.done" {
                                        // Handle when text output is complete
                                        if let text = chunk.text {
                                            aiDebugPrint("DEBUG: Output text completed: '\(text)'")
                                        }
                                    } else {
                                        // Log unhandled event types
                                        aiDebugPrint("DEBUG: Unhandled event type: \(chunkType)")
                                        if let item = chunk.item {
                                            aiDebugPrint("DEBUG: Event item type: \(item.type ?? "unknown")")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    aiDebugPrint("DEBUG: Stream processing completed")
                    continuation.finish()
                } catch {
                    let peekabooError = error.asPeekabooError(context: "OpenAI stream processing failed")
                    aiDebugPrint("DEBUG: Stream error: \(peekabooError)")
                    continuation.finish(throwing: peekabooError)
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
        
        // Note: Using a custom encoder here to only have sortedKeys without prettyPrinted
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            aiDebugPrint("DEBUG: JSON Encoding failed: \(error)")
            throw error.asPeekabooError(context: "Failed to encode OpenAI request")
        }
        
        // o3 models need much longer timeouts for complex reasoning
        if endpoint == "responses" {
            request.timeoutInterval = 600  // 10 minutes for o3 models
        } else {
            request.timeoutInterval = 120  // 2 minutes for other models
        }
        
        // Debug: Print request body
        if let bodyData = request.httpBody,
           let bodyString = String(data: bodyData, encoding: .utf8) {
            aiDebugPrint("DEBUG: OpenAI API Key: \(maskedApiKey)")
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
            switch message {
            case .system(_, let content):
                return OpenAIMessage(role: "system", content: .string(content))
                
            case .user(_, let content):
                return try convertUserMessage(content)
                
            case .assistant(_, let content, let status):
                return try convertAssistantMessage(content, status: status)
                
            case .tool(_, _, let content):
                // Responses API doesn't support 'tool' role, use 'user' instead
                // Tool results are sent as user messages in the Responses API
                return OpenAIMessage(
                    role: "user", 
                    content: .string(content)
                )
                
            case .reasoning(_, _):
                // Skip reasoning messages for now - they may not be supported by the API
                throw PeekabooError.invalidInput(field: "message", reason: "Reasoning messages not supported in OpenAI API")
            }
        }
        
        // Convert tools to flatter Responses API format
        let tools = request.tools?.map { tool in
            OpenAIResponsesTool(
                type: "function",
                name: tool.function.name,
                description: tool.function.description,
                parameters: convertToolParameters(tool.function.parameters)
            )
        }
        
        return OpenAIResponsesRequest(
            model: request.settings.modelName,
            input: messages,  // Note: 'input' not 'messages' for Responses API
            tools: tools,
            toolChoice: convertToolChoice(request.settings.toolChoice),
            temperature: (request.settings.modelName.hasPrefix("o3") || request.settings.modelName.hasPrefix("o4")) ? nil : request.settings.temperature,
            topP: request.settings.topP,
            stream: stream,
            maxOutputTokens: request.settings.maxTokens ?? 65536,
            reasoningEffort: nil,  // Removed - now part of reasoning object
            reasoning: (request.settings.modelName.hasPrefix("o3") || request.settings.modelName.hasPrefix("o4")) ? 
                OpenAIReasoning(
                    effort: request.settings.additionalParameters?.string("reasoning_effort") ?? "low",
                    summary: extractReasoningSummary(from: request.settings.additionalParameters)
                ) : nil
        )
    }
    
    private func convertUserMessage(_ content: MessageContent) throws -> OpenAIMessage {
        switch content {
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
            throw PeekabooError.invalidInput(field: "content", reason: "File content not supported in OpenAI chat completions")
        }
    }
    
    private func convertAssistantMessage(_ content: [AssistantContent], status: MessageStatus) throws -> OpenAIMessage {
        var textContent = ""
        
        for content in content {
            switch content {
            case .outputText(let text):
                textContent += text
                
            case .refusal(let refusal):
                return OpenAIMessage(role: "assistant", content: .string(refusal))
                
            case .toolCall(_):
                // For Responses API, we don't include tool_calls in assistant messages
                // Tool calls are handled differently in the Responses API
                // They appear in the output array of the response, not in messages
                continue
            }
        }
        
        // For Responses API, we only return text content for assistant messages
        return OpenAIMessage(role: "assistant", content: .string(textContent))
    }
    
    private func convertToolParameters(_ params: ToolParameters) -> OpenAITool.Parameters {
        // Convert ToolParameters to PropertySchema
        var properties: [String: PropertySchema] = [:]
        
        for (key, schema) in params.properties {
            properties[key] = convertParameterSchema(schema)
        }
        
        return OpenAITool.Parameters(
            type: params.type,
            properties: properties,
            required: params.required,
            additionalProperties: params.additionalProperties ? true : nil
        )
    }
    
    private func convertParameterSchema(_ schema: ParameterSchema) -> PropertySchema {
        var items: PropertySchema? = nil
        if let schemaItems = schema.items {
            items = convertParameterSchema(schemaItems.value)
        }
        
        var properties: [String: PropertySchema]? = nil
        if let schemaProperties = schema.properties {
            properties = schemaProperties.mapValues { convertParameterSchema($0) }
        }
        
        return PropertySchema(
            type: schema.type.rawValue,
            description: schema.description,
            enum: schema.enumValues,
            items: items,
            properties: properties,
            minimum: schema.minimum,
            maximum: schema.maximum,
            pattern: schema.pattern
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
            if let data = try? JSONCoding.encoder.encode(obj),
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
            // Convert JSONSchema to OpenAI format
            // For now, create a basic object schema
            let openAISchema = OpenAIJSONSchemaDefinition(
                type: "object",
                properties: [:],
                required: []
            )
            return OpenAIResponseFormat(
                type: "json_schema",
                jsonSchema: OpenAIJSONSchema(
                    name: schema.name,
                    strict: schema.strict,
                    schema: openAISchema
                )
            )
        }
    }
    
    private func convertFromOpenAIResponsesResponse(_ response: OpenAIResponsesResponse) throws -> ModelResponse {
        guard let choice = response.choices.first else {
            throw PeekabooError.operationError(message: "No choices in OpenAI response")
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
            
        case "response.output_item.added":
            // Handle when a new output item is added (reasoning or function call)
            if let item = chunk.item, item.type == "reasoning" {
                // This signals the start of reasoning output
                aiDebugPrint("DEBUG: Reasoning output started for item: \(item.id)")
            } else if let item = chunk.item, item.type == "function_call" {
                // Initialize the function call in our tracking
                if let itemId = chunk.itemId, let outputIndex = chunk.outputIndex {
                    let partialCall = PartialToolCall()
                    partialCall.id = itemId
                    partialCall.type = "function"
                    partialCall.index = outputIndex
                    partialCall.name = item.name // Get the function name from the item
                    toolCalls[itemId] = partialCall
                }
            }
            
        case "response.output_item.done":
            // Handle when an output item is completed
            if let item = chunk.item, item.type == "reasoning" {
                // Reasoning is complete - we might get summary in item.summary
                if let summary = item.summary?.joined(separator: "\n"), !summary.isEmpty {
                    events.append(.reasoningSummaryCompleted(StreamReasoningSummaryCompleted(
                        summary: summary,
                        reasoningTokens: nil
                    )))
                }
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
                let toolCallId = itemId
                
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
                aiDebugPrint("DEBUG: response.completed - has response, checking usage...")
                aiDebugPrint("DEBUG: response.usage = \(response.usage != nil ? "present" : "nil")")
                
                // Extract usage if available
                var usage: Usage? = nil
                if let responseUsage = response.usage {
                    aiDebugPrint("DEBUG: Found usage in response: input=\(responseUsage.promptTokens), output=\(responseUsage.completionTokens), total=\(responseUsage.totalTokens)")
                    usage = Usage(
                        promptTokens: responseUsage.promptTokens,
                        completionTokens: responseUsage.completionTokens,
                        totalTokens: responseUsage.totalTokens,
                        promptTokensDetails: responseUsage.promptTokensDetails.map { details in
                            TokenDetails(
                                cachedTokens: details.cachedTokens,
                                audioTokens: details.audioTokens,
                                reasoningTokens: details.reasoningTokens
                            )
                        },
                        completionTokensDetails: responseUsage.completionTokensDetails.map { details in
                            TokenDetails(
                                cachedTokens: details.cachedTokens,
                                audioTokens: details.audioTokens,
                                reasoningTokens: details.reasoningTokens
                            )
                        }
                    )
                }
                
                // Emit completion event with usage
                events.append(.responseCompleted(StreamResponseCompleted(
                    id: response.id,
                    usage: usage,
                    finishReason: nil
                )))
            }
            
        default:
            // Ignore other event types for now
            break
        }
        
        
        return events.isEmpty ? nil : events
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
    
    /// Extract reasoning summary from additionalParameters
    private func extractReasoningSummary(from params: ModelParameters?) -> String? {
        guard let params = params else { return nil }
        
        // The reasoning parameter is a dictionary with "summary" key
        // Since ModelParameters stores the raw value, we need to access it differently
        if let reasoningValue = params["reasoning"],
           case .dictionary(let reasoningDict) = reasoningValue,
           case .string(let summary) = reasoningDict["summary"] {
            return summary
        }
        
        return nil
    }

} // End of OpenAIModel class