import Foundation

/// Grok model implementation using OpenAI-compatible Chat Completions API
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public final class GrokModel: ModelInterface, Sendable {
    private let apiKey: String
    private let modelName: String
    private let baseURL: URL
    private let session: URLSession

    public init(
        apiKey: String,
        modelName: String = "grok-4-0709",
        baseURL: URL = URL(string: "https://api.x.ai/v1")!,
        session: URLSession? = nil)
    {
        self.apiKey = apiKey
        self.modelName = modelName
        self.baseURL = baseURL

        // Create custom session with appropriate timeout
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 300 // 5 minutes
            config.timeoutIntervalForResource = 300
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
        let grokRequest = try convertToGrokRequest(request, stream: false)
        let urlRequest = try createURLRequest(endpoint: "chat/completions", body: grokRequest)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(underlying: URLError(.badServerResponse))
        }

        if httpResponse.statusCode != 200 {
            try handleErrorResponse(data: data, response: httpResponse)
        }

        let chatResponse = try JSONDecoder().decode(GrokChatCompletionResponse.self, from: data)
        return try self.convertFromGrokResponse(chatResponse)
    }

    public func getStreamedResponse(request: ModelRequest) async throws -> AsyncThrowingStream<StreamEvent, any Error> {
        let grokRequest = try convertToGrokRequest(request, stream: true)
        let urlRequest = try createURLRequest(endpoint: "chat/completions", body: grokRequest)

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
                    var currentToolCalls: [String: GrokPartialToolCall] = [:]

                    for try await line in bytes.lines {
                        // Handle SSE format
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))

                            if data == "[DONE]" {
                                // Send any pending tool calls
                                for (id, toolCall) in currentToolCalls {
                                    if let completed = toolCall.toCompleted() {
                                        continuation.yield(.toolCallCompleted(
                                            StreamToolCallCompleted(id: id, function: completed)))
                                    }
                                }
                                continuation.finish()
                                return
                            }

                            // Parse chunk
                            if let chunkData = data.data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(
                                   GrokChatCompletionChunk.self,
                                   from: chunkData)
                            {
                                if let events = self.processGrokChunk(chunk, toolCalls: &currentToolCalls) {
                                    for event in events {
                                        continuation.yield(event)
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

    // MARK: - Private Helper Methods

    private func createURLRequest(endpoint: String, body: any Encodable) throws -> URLRequest {
        let url = self.baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw TachikomaError.configurationError("Failed to encode Grok request: \(error.localizedDescription)")
        }

        request.timeoutInterval = 300 // 5 minutes for Grok

        return request
    }

    private func convertToGrokRequest(_ request: ModelRequest, stream: Bool) throws -> GrokChatCompletionRequest {
        // Convert messages to OpenAI-compatible format
        let messages = try request.messages.map { message -> GrokMessage in
            switch message {
            case let .system(_, content):
                return GrokMessage(role: "system", content: .string(content), toolCalls: nil, toolCallId: nil)

            case let .user(_, content):
                return try self.convertUserMessageContent(content)

            case let .assistant(_, content, _):
                return try self.convertAssistantMessageContent(content)

            case let .tool(_, toolCallId, content):
                return GrokMessage(
                    role: "tool",
                    content: .string(content),
                    toolCalls: nil,
                    toolCallId: toolCallId)

            case .reasoning:
                throw TachikomaError.invalidRequest("Reasoning messages not supported in Grok")
            }
        }

        // Convert tools to OpenAI-compatible format if present
        let tools = request.tools?.map { toolDef -> GrokTool in
            GrokTool(
                type: "function",
                function: GrokTool.Function(
                    name: toolDef.function.name,
                    description: toolDef.function.description,
                    parameters: self.convertToolParameters(toolDef.function.parameters)))
        }

        // Filter parameters for Grok 4
        let temperature = request.settings.temperature
        var frequencyPenalty = request.settings.frequencyPenalty
        var presencePenalty = request.settings.presencePenalty
        var stop = request.settings.stopSequences

        if self.modelName.contains("grok-4") || self.modelName.contains("grok-3") {
            // Grok 3 and 4 models don't support these parameters
            frequencyPenalty = nil
            presencePenalty = nil
            stop = nil
        }

        return GrokChatCompletionRequest(
            model: self.modelName,
            messages: messages,
            tools: tools,
            toolChoice: self.convertToolChoice(request.settings.toolChoice),
            temperature: temperature,
            maxTokens: request.settings.maxTokens,
            stream: stream,
            frequencyPenalty: frequencyPenalty,
            presencePenalty: presencePenalty,
            stop: stop)
    }

    private func convertUserMessageContent(_ content: MessageContent) throws -> GrokMessage {
        switch content {
        case let .text(text):
            return GrokMessage(role: "user", content: .string(text), toolCalls: nil, toolCallId: nil)

        case let .image(imageContent):
            var content: [GrokMessageContentPart] = []

            if let url = imageContent.url {
                content.append(GrokMessageContentPart(
                    type: "image_url",
                    text: nil,
                    imageUrl: GrokImageUrl(
                        url: url,
                        detail: imageContent.detail?.rawValue)))
            } else if let base64 = imageContent.base64 {
                content.append(GrokMessageContentPart(
                    type: "image_url",
                    text: nil,
                    imageUrl: GrokImageUrl(
                        url: "data:image/jpeg;base64,\(base64)",
                        detail: imageContent.detail?.rawValue)))
            }

            return GrokMessage(role: "user", content: .array(content), toolCalls: nil, toolCallId: nil)

        case let .multimodal(parts):
            let content = parts.compactMap { part -> GrokMessageContentPart? in
                if let text = part.text {
                    return GrokMessageContentPart(
                        type: "text",
                        text: text,
                        imageUrl: nil)
                } else if let image = part.imageUrl {
                    if let url = image.url {
                        return GrokMessageContentPart(
                            type: "image_url",
                            text: nil,
                            imageUrl: GrokImageUrl(url: url, detail: image.detail?.rawValue))
                    } else if let base64 = image.base64 {
                        return GrokMessageContentPart(
                            type: "image_url",
                            text: nil,
                            imageUrl: GrokImageUrl(
                                url: "data:image/jpeg;base64,\(base64)",
                                detail: image.detail?.rawValue))
                    }
                }
                return nil
            }
            return GrokMessage(role: "user", content: .array(content), toolCalls: nil, toolCallId: nil)

        case .file:
            throw TachikomaError.invalidRequest("File content not supported in Grok chat completions")

        case let .audio(audioContent):
            // Grok doesn't support native audio, so we need to use the transcript
            if let transcript = audioContent.transcript {
                // Include metadata about the audio source
                var text = transcript
                if let duration = audioContent.duration {
                    text = "[Audio transcript, duration: \(Int(duration))s] \(transcript)"
                } else {
                    text = "[Audio transcript] \(transcript)"
                }
                return GrokMessage(role: "user", content: .string(text), toolCalls: nil, toolCallId: nil)
            } else {
                throw TachikomaError.invalidRequest("Audio content must be transcribed before sending to Grok. Please ensure transcript is provided.")
            }
        }
    }

    private func convertAssistantMessageContent(_ contentArray: [AssistantContent]) throws -> GrokMessage {
        var textContent = ""
        var toolCalls: [GrokToolCall] = []

        for content in contentArray {
            switch content {
            case let .outputText(text):
                textContent += text

            case let .refusal(refusal):
                return GrokMessage(role: "assistant", content: .string(refusal), toolCalls: nil, toolCallId: nil)

            case let .toolCall(toolCall):
                toolCalls.append(GrokToolCall(
                    id: toolCall.id,
                    type: toolCall.type.rawValue,
                    function: GrokFunctionCall(
                        name: toolCall.function.name,
                        arguments: toolCall.function.arguments)))
            }
        }

        // Include tool calls if present
        if !toolCalls.isEmpty {
            return GrokMessage(
                role: "assistant",
                content: textContent.isEmpty ? nil : .string(textContent),
                toolCalls: toolCalls,
                toolCallId: nil)
        }

        return GrokMessage(role: "assistant", content: .string(textContent), toolCalls: nil, toolCallId: nil)
    }

    private func convertToolParameters(_ params: ToolParameters) -> GrokTool.Parameters {
        let (type, properties, required) = params.toGrokParameters()
        return GrokTool.Parameters(
            type: type,
            properties: properties,
            required: required)
    }

    private func convertToolChoice(_ toolChoice: ToolChoice?) -> GrokToolChoice? {
        guard let toolChoice else { return nil }

        switch toolChoice {
        case .auto:
            return .string("auto")
        case .none:
            return .string("none")
        case .required:
            return .string("required")
        case let .specific(toolName):
            return .object(GrokToolChoiceObject(
                type: "function",
                function: GrokToolChoiceFunction(name: toolName)))
        }
    }

    private func convertFromGrokResponse(_ response: GrokChatCompletionResponse) throws -> ModelResponse {
        guard let choice = response.choices.first else {
            throw TachikomaError.apiError(message: "No choices in response")
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
                        arguments: toolCall.function.arguments))))
            }
        }

        let usage = response.usage.map { usage in
            Usage(
                promptTokens: usage.promptTokens,
                completionTokens: usage.completionTokens,
                totalTokens: usage.totalTokens,
                promptTokensDetails: nil,
                completionTokensDetails: nil)
        }

        return ModelResponse(
            id: response.id,
            model: response.model,
            content: content,
            usage: usage,
            flagged: false,
            finishReason: self.convertFinishReason(choice.finishReason))
    }

    private func convertFinishReason(_ reason: String?) -> FinishReason? {
        guard let reason else { return nil }
        return FinishReason(rawValue: reason)
    }

    private func processGrokChunk(
        _ chunk: GrokChatCompletionChunk,
        toolCalls: inout [String: GrokPartialToolCall]) -> [StreamEvent]?
    {
        var events: [StreamEvent] = []

        // First chunk often contains metadata
        if !chunk.id.isEmpty, chunk.model.isEmpty == false {
            events.append(.responseStarted(StreamResponseStarted(
                id: chunk.id,
                model: chunk.model,
                systemFingerprint: chunk.systemFingerprint)))
        }

        for choice in chunk.choices {
            let delta = choice.delta

            // Handle text content
            if let content = delta.content, !content.isEmpty {
                events.append(.textDelta(StreamTextDelta(delta: content, index: choice.index)))
            }

            // Handle tool calls
            if let deltaToolCalls = delta.toolCalls {
                for toolCallDelta in deltaToolCalls {
                    let toolCallId = toolCallDelta.id ?? ""

                    if toolCalls[toolCallId] == nil {
                        let partialCall = GrokPartialToolCall(from: toolCallDelta)
                        toolCalls[toolCallId] = partialCall
                    } else {
                        toolCalls[toolCallId]?.update(with: toolCallDelta)
                    }

                    // Emit delta event
                    if let functionDelta = toolCallDelta.function {
                        events.append(.toolCallDelta(StreamToolCallDelta(
                            id: toolCallId,
                            index: toolCallDelta.index,
                            function: FunctionCallDelta(
                                name: functionDelta.name,
                                arguments: functionDelta.arguments))))
                    }
                }
            }

            // Handle finish reason
            if let finishReason = choice.finishReason {
                // If this is a tool call finish, emit completed events
                if finishReason == "tool_calls" {
                    for (id, toolCall) in toolCalls {
                        if let completed = toolCall.toCompleted() {
                            events.append(.toolCallCompleted(
                                StreamToolCallCompleted(id: id, function: completed)))
                        }
                    }
                }

                events.append(.responseCompleted(StreamResponseCompleted(
                    id: chunk.id,
                    usage: nil,
                    finishReason: FinishReason(rawValue: finishReason))))
            }
        }

        return events.isEmpty ? nil : events
    }

    private func handleErrorResponse(data: Data, response: HTTPURLResponse) throws {
        if let errorResponse = try? JSONDecoder().decode(GrokErrorResponse.self, from: data) {
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
                throw TachikomaError.apiError(message: message, code: errorResponse.error.code)
            }
        } else {
            throw TachikomaError.apiError(message: "HTTP \(response.statusCode)")
        }
    }
}

