import Foundation

/// Anthropic model implementation conforming to ModelInterface
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class AnthropicModel: ModelInterface, Sendable {
    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession
    private let anthropicVersion: String
    private let modelName: String?
    private let customHeaders: [String: String]?

    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.anthropic.com/v1")!,
        anthropicVersion: String = "2023-06-01",
        modelName: String? = nil,
        session: URLSession? = nil)
    {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.anthropicVersion = anthropicVersion
        self.modelName = modelName
        self.customHeaders = nil
        
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 120 // 2 minutes
            config.timeoutIntervalForResource = 120
            self.session = URLSession(configuration: config)
        }
    }
    
    /// Initialize with custom provider configuration
    public init(
        apiKey: String,
        baseURL: String,
        modelName: String? = nil,
        headers: [String: String]? = nil,
        anthropicVersion: String = "2023-06-01",
        session: URLSession? = nil)
    {
        self.apiKey = apiKey
        self.baseURL = URL(string: baseURL) ?? URL(string: "https://api.anthropic.com/v1")!
        self.anthropicVersion = anthropicVersion
        self.modelName = modelName
        self.customHeaders = headers
        
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 120 // 2 minutes
            config.timeoutIntervalForResource = 120
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - ModelInterface Implementation

    public var maskedApiKey: String {
        guard self.apiKey.count > 8 else { return "***" }
        let start = self.apiKey.prefix(6)
        let end = self.apiKey.suffix(2)
        return "\(start)...\(end)"
    }

    public func getResponse(request: ModelRequest) async throws -> ModelResponse {
        let anthropicRequest = try convertToAnthropicRequest(request, stream: false)
        let urlRequest = try createURLRequest(endpoint: "messages", body: anthropicRequest)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(underlying: URLError(.badServerResponse))
        }

        if httpResponse.statusCode != 200 {
            try handleErrorResponse(data: data, response: httpResponse)
        }

        do {
            let anthropicResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            return try self.convertFromAnthropicResponse(anthropicResponse)
        } catch {
            throw TachikomaError.decodingError(underlying: error)
        }
    }

    public func getStreamedResponse(request: ModelRequest) async throws -> AsyncThrowingStream<StreamEvent, any Error> {
        let anthropicRequest = try convertToAnthropicRequest(request, stream: true)
        let urlRequest = try createURLRequest(endpoint: "messages", body: anthropicRequest)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await session.bytes(for: urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: TachikomaError.networkError(underlying: URLError(.badServerResponse)))
                        return
                    }

                    if httpResponse.statusCode != 200 {
                        var errorData = Data()
                        for try await byte in bytes.prefix(1024) {
                            errorData.append(byte)
                        }
                        try self.handleErrorResponse(data: errorData, response: httpResponse)
                    }

                    // Process SSE stream
                    var currentToolCalls: [String: PartialToolCall] = [:]
                    var responseId: String?
                    var accumulatedText = ""
                    var currentContentIndex = 0
                    var pendingUsage: Usage?

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
                                    let event = try JSONDecoder().decode(
                                        AnthropicStreamEvent.self,
                                        from: eventData)

                                    switch event.type {
                                    case "message_start":
                                        if let message = event.message {
                                            responseId = message.id
                                            continuation.yield(.responseStarted(StreamResponseStarted(
                                                id: message.id,
                                                model: message.model,
                                                systemFingerprint: nil)))
                                        }

                                    case "content_block_start":
                                        currentContentIndex = event.index ?? 0
                                        if let block = event.contentBlock {
                                            if block.type == "tool_use", let id = block.id, let name = block.name {
                                                // Start tracking this tool call
                                                let partialCall = PartialToolCall(
                                                    id: id,
                                                    name: name,
                                                    index: currentContentIndex)
                                                currentToolCalls[id] = partialCall
                                            }
                                        }

                                    case "content_block_delta":
                                        if let delta = event.delta {
                                            if let text = delta.text {
                                                // Text delta
                                                continuation.yield(.textDelta(StreamTextDelta(
                                                    delta: text,
                                                    index: currentContentIndex)))
                                                accumulatedText += text
                                            } else if let partialJson = delta.partialJson {
                                                // Tool use arguments delta
                                                // Find the tool call being updated
                                                if let toolCall = currentToolCalls.values
                                                    .first(where: { $0.index == currentContentIndex })
                                                {
                                                    toolCall.appendArguments(partialJson)
                                                    continuation.yield(.toolCallDelta(StreamToolCallDelta(
                                                        id: toolCall.id,
                                                        index: toolCall.index,
                                                        function: FunctionCallDelta(
                                                            name: toolCall.name,
                                                            arguments: partialJson))))
                                                }
                                            }
                                        }

                                    case "content_block_stop":
                                        // Complete any tool calls at this index
                                        for (id, toolCall) in currentToolCalls {
                                            if toolCall.index == currentContentIndex {
                                                if let completed = toolCall.toCompleted() {
                                                    continuation.yield(.toolCallCompleted(
                                                        StreamToolCallCompleted(id: id, function: completed)))
                                                }
                                            }
                                        }

                                    case "message_delta":
                                        // Skip regular parsing - will handle in catch block for usage data
                                        break

                                    case "message_stop":
                                        // Final completion - emit responseCompleted with usage if available
                                        if let id = responseId {
                                            continuation.yield(.responseCompleted(StreamResponseCompleted(
                                                id: id,
                                                usage: pendingUsage,
                                                finishReason: .stop)))
                                        }
                                        continuation.finish()
                                        return

                                    case "error":
                                        if let error = event.error {
                                            continuation.finish(throwing: TachikomaError.apiError(
                                                message: error.message))
                                            return
                                        }

                                    default:
                                        // Unknown event type, ignore
                                        break
                                    }
                                } catch {
                                    // Special handling for message_delta events with usage
                                    if let jsonData = data.data(using: .utf8) {
                                        do {
                                            if let json = try JSONSerialization
                                                .jsonObject(with: jsonData) as? [String: Any]
                                            {
                                                if json["type"] as? String == "message_delta" {
                                                    if let usage = json["usage"] as? [String: Any] {
                                                        if let outputTokens = usage["output_tokens"] as? Int {
                                                            // Extract input tokens if available
                                                            let inputTokens = usage["input_tokens"] as? Int ?? 0

                                                            // Create Usage object
                                                            let tokenUsage = Usage(
                                                                promptTokens: inputTokens,
                                                                completionTokens: outputTokens,
                                                                totalTokens: inputTokens + outputTokens,
                                                                promptTokensDetails: nil,
                                                                completionTokensDetails: nil)

                                                            // Store the usage for later
                                                            pendingUsage = tokenUsage
                                                        }
                                                    }
                                                }
                                            }
                                        } catch {
                                            // Failed to parse JSON, ignore
                                        }
                                    }
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: TachikomaError.streamingError(error.localizedDescription))
                }
            }
        }
    }

    // MARK: - Private Methods

    private func createURLRequest(endpoint: String, body: any Encodable) throws -> URLRequest {
        let url = self.baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(self.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(self.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add custom headers from provider configuration
        customHeaders?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw TachikomaError.configurationError("Failed to encode Anthropic request: \(error.localizedDescription)")
        }

        request.timeoutInterval = 120

        return request
    }

    private func convertToAnthropicRequest(_ request: ModelRequest, stream: Bool) throws -> AnthropicRequest {
        var anthropicMessages: [AnthropicMessage] = []
        var systemPrompt: String? = nil

        // Convert messages
        for message in request.messages {
            switch message {
            case let .system(_, content):
                // Anthropic uses a separate system parameter
                if systemPrompt == nil {
                    systemPrompt = content
                } else {
                    systemPrompt = (systemPrompt ?? "") + "\n\n" + content
                }

            case let .user(_, content):
                let anthropicMessage = try convertUserMessage(content)
                anthropicMessages.append(anthropicMessage)

            case let .assistant(_, content, status):
                let anthropicMessage = try convertAssistantMessage(content, status: status)
                anthropicMessages.append(anthropicMessage)

            case let .tool(_, toolCallId, content):
                // Convert tool result to user message with tool_result content block
                let toolResultBlock = AnthropicContentBlock.toolResult(
                    toolUseId: toolCallId,
                    content: content)
                anthropicMessages.append(AnthropicMessage(
                    role: .user,
                    content: .array([toolResultBlock])))

            case let .reasoning(_, content):
                // Treat reasoning as a system message for now
                if systemPrompt == nil {
                    systemPrompt = "[Reasoning] " + content
                } else {
                    systemPrompt = (systemPrompt ?? "") + "\n\n[Reasoning] " + content
                }
            }
        }

        // Convert tools
        let tools = request.tools?.map { toolDef -> AnthropicTool in
            AnthropicTool(
                name: toolDef.function.name,
                description: toolDef.function.description,
                inputSchema: self.convertToolParameters(toolDef.function.parameters))
        }

        // Convert tool choice
        let toolChoice = self.convertToolChoice(request.settings.toolChoice)

        // Create system content with cache control
        let systemContent: AnthropicSystemContent? = if let systemPrompt {
            // Use array format with cache control for system prompt
            .array([
                AnthropicSystemBlock(
                    type: "text",
                    text: systemPrompt,
                    cacheControl: AnthropicCacheControl(type: "ephemeral")),
            ])
        } else {
            nil
        }

        return AnthropicRequest(
            model: self.modelName ?? request.settings.modelName,
            messages: anthropicMessages,
            system: systemContent,
            maxTokens: request.settings.maxTokens ?? 4096,
            temperature: request.settings.temperature,
            topP: request.settings.topP,
            topK: request.settings.additionalParameters?.int("top_k"),
            stream: stream,
            stopSequences: request.settings.stopSequences,
            tools: tools,
            toolChoice: toolChoice,
            metadata: request.settings.user.map { AnthropicMetadata(userId: $0) })
    }

    private func convertUserMessage(_ content: MessageContent) throws -> AnthropicMessage {
        switch content {
        case let .text(text):
            return AnthropicMessage(role: .user, content: .string(text))

        case let .image(imageContent):
            var blocks: [AnthropicContentBlock] = []

            if let base64 = imageContent.base64 {
                blocks.append(.image(base64: base64, mediaType: "image/jpeg"))
            } else if imageContent.url != nil {
                // For URLs, we'd need to download and convert to base64
                // For now, throw an error
                throw TachikomaError.invalidRequest("Image URLs not supported - please provide base64 data")
            }

            return AnthropicMessage(role: .user, content: .array(blocks))

        case let .multimodal(parts):
            let blocks = try parts.compactMap { part -> AnthropicContentBlock? in
                if let text = part.text {
                    return .text(text)
                } else if let image = part.imageUrl {
                    if let base64 = image.base64 {
                        return .image(base64: base64, mediaType: "image/jpeg")
                    } else if image.url != nil {
                        throw TachikomaError.invalidRequest("Image URLs not supported - please provide base64 data")
                    }
                }
                return nil
            }
            return AnthropicMessage(role: .user, content: .array(blocks))

        case .file:
            throw TachikomaError.invalidRequest("File content not supported in Anthropic API")

        case let .audio(audioContent):
            // Claude doesn't support native audio, so we need to use the transcript
            if let transcript = audioContent.transcript {
                // Include metadata about the audio source
                var text = transcript
                if let duration = audioContent.duration {
                    text = "[Audio transcript, duration: \(Int(duration))s] \(transcript)"
                } else {
                    text = "[Audio transcript] \(transcript)"
                }
                return AnthropicMessage(role: .user, content: .string(text))
            } else {
                throw TachikomaError.invalidRequest("Audio content must be transcribed before sending to Claude. Please ensure transcript is provided.")
            }
        }
    }

    private func convertAssistantMessage(
        _ content: [AssistantContent],
        status: MessageStatus) throws -> AnthropicMessage
    {
        var blocks: [AnthropicContentBlock] = []

        for content in content {
            switch content {
            case let .outputText(text):
                blocks.append(.text(text))

            case let .refusal(refusal):
                blocks.append(.text(refusal))

            case let .toolCall(toolCall):
                // Parse arguments as JSON
                let arguments: [String: Any] = if let data = toolCall.function.arguments.data(using: .utf8),
                                                  let json = try? JSONSerialization
                                                      .jsonObject(with: data) as? [String: Any]
                {
                    json
                } else {
                    [:]
                }

                blocks.append(.toolUse(
                    id: toolCall.id,
                    name: toolCall.function.name,
                    input: arguments))
            }
        }

        return AnthropicMessage(role: .assistant, content: .array(blocks))
    }

    private func convertToolParameters(_ params: ToolParameters) -> AnthropicJSONSchema {
        var properties: [String: AnthropicPropertySchema] = [:]

        for (key, schema) in params.properties {
            properties[key] = self.convertParameterSchema(schema)
        }

        return AnthropicJSONSchema(
            type: params.type,
            properties: properties,
            required: params.required)
    }

    private func convertParameterSchema(_ schema: ParameterSchema) -> AnthropicPropertySchema {
        // Handle nested items for arrays
        let items: AnthropicPropertySchema? = if schema.type == .array, let schemaItems = schema.items {
            self.convertParameterSchema(schemaItems.value)
        } else {
            nil
        }

        // Handle nested properties for objects
        let properties: [String: AnthropicPropertySchema]?
        if schema.type == .object, let schemaProps = schema.properties {
            var convertedProps: [String: AnthropicPropertySchema] = [:]
            for (key, nestedSchema) in schemaProps {
                convertedProps[key] = self.convertParameterSchema(nestedSchema)
            }
            properties = convertedProps
        } else {
            properties = nil
        }

        return AnthropicPropertySchema(
            type: schema.type.rawValue,
            description: schema.description,
            enum: schema.enumValues,
            items: items,
            properties: properties,
            required: nil // ParameterSchema doesn't have required field at this level
        )
    }

    private func convertToolChoice(_ toolChoice: ToolChoice?) -> AnthropicToolChoice? {
        guard let toolChoice else { return nil }

        switch toolChoice {
        case .auto:
            return .auto
        case .none:
            return nil // Anthropic doesn't have a "none" option
        case .required:
            return .any
        case let .specific(toolName):
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
                   let input = block.input
                {
                    // Convert input dictionary to JSON string
                    let arguments: String = if let data = try? JSONSerialization.data(withJSONObject: input.mapValues { $0.toAny() }),
                                               let json = String(data: data, encoding: .utf8)
                    {
                        json
                    } else {
                        "{}"
                    }

                    content.append(.toolCall(ToolCallItem(
                        id: id,
                        type: .function,
                        function: FunctionCall(
                            name: name,
                            arguments: arguments))))
                }

            default:
                // Unknown content block type, ignore
                break
            }
        }

        let usage = Usage(
            promptTokens: response.usage.inputTokens,
            completionTokens: response.usage.outputTokens,
            totalTokens: response.usage.inputTokens + response.usage.outputTokens,
            promptTokensDetails: nil,
            completionTokensDetails: nil)

        return ModelResponse(
            id: response.id,
            model: response.model,
            content: content,
            usage: usage,
            flagged: false,
            finishReason: self.convertStopReason(response.stopReason))
    }

    private func convertStopReason(_ reason: String?) -> FinishReason? {
        guard let reason else { return nil }

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

    private func handleErrorResponse(data: Data, response: HTTPURLResponse) throws {
        if let errorResponse = try? JSONDecoder().decode(AnthropicErrorResponse.self, from: data) {
            let message = errorResponse.error.message
            
            switch response.statusCode {
            case 401:
                throw TachikomaError.authenticationFailed
            case 429:
                throw TachikomaError.rateLimited
            case 400:
                if message.contains("credit") || message.contains("usage") {
                    throw TachikomaError.insufficientQuota
                } else {
                    throw TachikomaError.invalidRequest(message)
                }
            case 500...599:
                throw TachikomaError.modelOverloaded
            default:
                throw TachikomaError.apiError(message: message)
            }
        } else {
            throw TachikomaError.apiError(message: "HTTP \(response.statusCode)")
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
        FunctionCall(name: self.name, arguments: self.arguments)
    }
}