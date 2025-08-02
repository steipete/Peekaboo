import Foundation

/// OpenAI model implementation conforming to ModelInterface

public final class OpenAIModel: ModelInterface, Sendable {
    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession
    private let organizationId: String?
    private let customHeaders: [String: String]?
    private let customModelName: String?

    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        organizationId: String? = nil,
        modelName: String? = nil,
        headers: [String: String]? = nil,
        session: URLSession? = nil)
    {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.organizationId = organizationId
        self.customHeaders = headers
        self.customModelName = modelName
        
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 600 // 10 minutes for o3 models
            config.timeoutIntervalForResource = 600
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
        let openAIRequest = try convertToOpenAIRequest(request, stream: false)
        let endpoint = getEndpointForModel(request.settings.modelName)
        let urlRequest = try createURLRequest(endpoint: endpoint, body: openAIRequest)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(underlying: URLError(.badServerResponse))
        }

        if httpResponse.statusCode != 200 {
            try handleErrorResponse(data: data, response: httpResponse)
        }

        do {
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            return try convertFromOpenAIResponse(openAIResponse)
        } catch {
            throw TachikomaError.decodingError(underlying: error)
        }
    }

    public func getStreamedResponse(request: ModelRequest) async throws -> AsyncThrowingStream<StreamEvent, any Error> {
        let openAIRequest = try convertToOpenAIRequest(request, stream: true)
        let endpoint = getEndpointForModel(request.settings.modelName)
        let urlRequest = try createURLRequest(endpoint: endpoint, body: openAIRequest)

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
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))

                            if data == "[DONE]" {
                                continuation.finish()
                                return
                            }

                            if let chunkData = data.data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: chunkData) {
                                if let events = processStreamChunk(chunk) {
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

    // MARK: - Private Methods

    private func getEndpointForModel(_ modelName: String) -> String {
        // Use Responses API for o3/o4 models, Chat Completions for others
        if modelName.hasPrefix("o3") || modelName.hasPrefix("o4") {
            return "responses"
        } else {
            return "chat/completions"
        }
    }

    private func createURLRequest(endpoint: String, body: any Encodable) throws -> URLRequest {
        let url = self.baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let orgId = organizationId {
            request.setValue(orgId, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        customHeaders?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw TachikomaError.configurationError("Failed to encode OpenAI request: \(error.localizedDescription)")
        }

        // Set timeout for different API types
        if endpoint == "responses" {
            request.timeoutInterval = 600 // 10 minutes for o3 models
        } else {
            request.timeoutInterval = 120 // 2 minutes for other models
        }

        return request
    }

    private func convertToOpenAIRequest(_ request: ModelRequest, stream: Bool) throws -> any Encodable {
        let modelName = customModelName ?? request.settings.modelName
        
        if modelName.hasPrefix("o3") || modelName.hasPrefix("o4") {
            return try convertToResponsesRequest(request, stream: stream)
        } else {
            return try convertToChatRequest(request, stream: stream)
        }
    }

    private func convertToChatRequest(_ request: ModelRequest, stream: Bool) throws -> OpenAIChatRequest {
        let messages = try request.messages.map { message -> OpenAIMessage in
            switch message {
            case let .system(_, content):
                return OpenAIMessage(role: "system", content: .string(content))
            case let .user(_, content):
                return try convertUserMessage(content)
            case let .assistant(_, content, _):
                return try convertAssistantMessage(content)
            case let .tool(_, toolCallId, content):
                return OpenAIMessage(role: "tool", content: .string(content), toolCallId: toolCallId)
            case .reasoning:
                throw TachikomaError.invalidRequest("Reasoning messages not supported in Chat Completions API")
            }
        }

        let tools = request.tools?.map { tool in
            OpenAITool(
                type: "function",
                function: OpenAIFunction(
                    name: tool.function.name,
                    description: tool.function.description,
                    parameters: convertToolParameters(tool.function.parameters)))
        }

        return OpenAIChatRequest(
            model: customModelName ?? request.settings.modelName,
            messages: messages,
            tools: tools,
            toolChoice: convertToolChoice(request.settings.toolChoice),
            temperature: request.settings.temperature,
            topP: request.settings.topP,
            stream: stream,
            maxTokens: request.settings.maxTokens)
    }

    private func convertToResponsesRequest(_ request: ModelRequest, stream: Bool) throws -> OpenAIResponsesRequest {
        let messages = try request.messages.compactMap { message -> OpenAIMessage? in
            switch message {
            case let .system(_, content):
                return OpenAIMessage(role: "system", content: .string(content))
            case let .user(_, content):
                return try convertUserMessage(content)
            case let .assistant(_, content, _):
                return try convertAssistantMessage(content)
            case let .tool(_, _, content):
                return OpenAIMessage(role: "user", content: .string(content))
            case .reasoning:
                return nil // Skip reasoning messages
            }
        }

        let tools = request.tools?.map { tool in
            OpenAIResponsesTool(
                type: "function",
                name: tool.function.name,
                description: tool.function.description,
                parameters: convertToolParameters(tool.function.parameters))
        }

        let modelName = customModelName ?? request.settings.modelName
        
        return OpenAIResponsesRequest(
            model: modelName,
            input: messages,
            tools: tools,
            toolChoice: convertToolChoice(request.settings.toolChoice),
            temperature: nil, // o3/o4 models don't support temperature
            topP: request.settings.topP,
            stream: stream,
            maxOutputTokens: request.settings.maxTokens ?? 65536,
            reasoning: (modelName.hasPrefix("o3") || modelName.hasPrefix("o4")) ? 
                OpenAIReasoning(
                    effort: request.settings.additionalParameters?.string("reasoning_effort") ?? "medium",
                    summary: "detailed") : nil)
    }

    private func convertUserMessage(_ content: MessageContent) throws -> OpenAIMessage {
        switch content {
        case let .text(text):
            return OpenAIMessage(role: "user", content: .string(text))
        case let .image(imageContent):
            var parts: [OpenAIMessageContentPart] = []
            
            if let url = imageContent.url {
                parts.append(OpenAIMessageContentPart(
                    type: "image_url",
                    text: nil,
                    imageUrl: OpenAIImageUrl(url: url, detail: imageContent.detail?.rawValue)))
            } else if let base64 = imageContent.base64 {
                parts.append(OpenAIMessageContentPart(
                    type: "image_url", 
                    text: nil,
                    imageUrl: OpenAIImageUrl(url: "data:image/jpeg;base64,\(base64)", detail: imageContent.detail?.rawValue)))
            }
            
            return OpenAIMessage(role: "user", content: .array(parts))
        case let .multimodal(parts):
            let contentParts = parts.compactMap { part -> OpenAIMessageContentPart? in
                if let text = part.text {
                    return OpenAIMessageContentPart(type: "text", text: text, imageUrl: nil)
                } else if let image = part.imageUrl {
                    if let url = image.url {
                        return OpenAIMessageContentPart(
                            type: "image_url",
                            text: nil,
                            imageUrl: OpenAIImageUrl(url: url, detail: image.detail?.rawValue))
                    } else if let base64 = image.base64 {
                        return OpenAIMessageContentPart(
                            type: "image_url",
                            text: nil,
                            imageUrl: OpenAIImageUrl(url: "data:image/jpeg;base64,\(base64)", detail: image.detail?.rawValue))
                    }
                }
                return nil
            }
            return OpenAIMessage(role: "user", content: .array(contentParts))
        case .file:
            throw TachikomaError.invalidRequest("File content not supported in OpenAI API")
        case let .audio(audioContent):
            if let transcript = audioContent.transcript {
                var text = transcript
                if let duration = audioContent.duration {
                    text = "[Audio transcript, duration: \(Int(duration))s] \(transcript)"
                } else {
                    text = "[Audio transcript] \(transcript)"
                }
                return OpenAIMessage(role: "user", content: .string(text))
            } else {
                throw TachikomaError.invalidRequest("Audio content must be transcribed before sending to OpenAI")
            }
        }
    }

    private func convertAssistantMessage(_ content: [AssistantContent]) throws -> OpenAIMessage {
        var textContent = ""
        var toolCalls: [OpenAIToolCall] = []

        for item in content {
            switch item {
            case let .outputText(text):
                textContent += text
            case let .refusal(refusal):
                return OpenAIMessage(role: "assistant", content: .string(refusal))
            case let .toolCall(toolCall):
                toolCalls.append(OpenAIToolCall(
                    id: toolCall.id,
                    type: "function",
                    function: OpenAIFunction(
                        name: toolCall.function.name,
                        description: nil,
                        parameters: nil,
                        arguments: toolCall.function.arguments)))
            }
        }

        if !toolCalls.isEmpty {
            return OpenAIMessage(role: "assistant", content: .string(textContent), toolCalls: toolCalls)
        } else {
            return OpenAIMessage(role: "assistant", content: .string(textContent))
        }
    }

    private func convertToolParameters(_ params: ToolParameters) -> [String: Any] {
        var properties: [String: Any] = [:]
        
        for (key, schema) in params.properties {
            properties[key] = convertParameterSchema(schema)
        }
        
        return [
            "type": params.type,
            "properties": properties,
            "required": params.required,
            "additionalProperties": params.additionalProperties
        ]
    }

    private func convertParameterSchema(_ schema: ParameterSchema) -> [String: Any] {
        var result: [String: Any] = [
            "type": schema.type.rawValue
        ]
        
        if let description = schema.description {
            result["description"] = description
        }
        
        if let enumValues = schema.enumValues {
            result["enum"] = enumValues
        }
        
        if let minimum = schema.minimum {
            result["minimum"] = minimum
        }
        
        if let maximum = schema.maximum {
            result["maximum"] = maximum
        }
        
        if let pattern = schema.pattern {
            result["pattern"] = pattern
        }
        
        if let items = schema.items {
            result["items"] = convertParameterSchema(items.value)
        }
        
        if let properties = schema.properties {
            result["properties"] = properties.mapValues { convertParameterSchema($0) }
        }
        
        return result
    }

    private func convertToolChoice(_ toolChoice: ToolChoice?) -> String? {
        guard let toolChoice else { return nil }

        switch toolChoice {
        case .auto:
            return "auto"
        case .none:
            return "none"
        case .required:
            return "required"
        case let .specific(toolName):
            return toolName
        }
    }

    private func convertFromOpenAIResponse(_ response: OpenAIResponse) throws -> ModelResponse {
        guard let choice = response.choices.first else {
            throw TachikomaError.apiError(message: "No choices in OpenAI response")
        }

        var content: [AssistantContent] = []

        if let messageContent = choice.message.content {
            switch messageContent {
            case let .string(text):
                content.append(.outputText(text))
            case let .array(parts):
                // Extract text from content parts
                let text = parts.compactMap { $0.text }.joined()
                if !text.isEmpty {
                    content.append(.outputText(text))
                }
            }
        }

        if let toolCalls = choice.message.toolCalls {
            for toolCall in toolCalls {
                content.append(.toolCall(ToolCallItem(
                    id: toolCall.id,
                    type: .function,
                    function: FunctionCall(
                        name: toolCall.function.name,
                        arguments: toolCall.function.arguments ?? ""))))
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
            finishReason: convertFinishReason(choice.finishReason))
    }

    private func convertFinishReason(_ reason: String?) -> FinishReason? {
        guard let reason else { return nil }
        return FinishReason(rawValue: reason)
    }

    private func processStreamChunk(_ chunk: OpenAIStreamChunk) -> [StreamEvent]? {
        var events: [StreamEvent] = []

        if let delta = chunk.choices?.first?.delta {
            if let content = delta.content {
                events.append(.textDelta(StreamTextDelta(delta: content, index: 0)))
            }

            if let toolCalls = delta.toolCalls {
                for toolCall in toolCalls {
                    if let id = toolCall.id, let function = toolCall.function {
                        events.append(.toolCallDelta(StreamToolCallDelta(
                            id: id,
                            index: toolCall.index ?? 0,
                            function: FunctionCallDelta(
                                name: function.name,
                                arguments: function.arguments))))
                    }
                }
            }
        }

        if let finishReason = chunk.choices?.first?.finishReason {
            events.append(.responseCompleted(StreamResponseCompleted(
                id: chunk.id ?? "",
                usage: nil,
                finishReason: convertFinishReason(finishReason))))
        }

        return events.isEmpty ? nil : events
    }

    private func handleErrorResponse(data: Data, response: HTTPURLResponse) throws {
        if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
            let message = errorResponse.error.message
            let code = errorResponse.error.code
            
            switch response.statusCode {
            case 401:
                throw TachikomaError.authenticationFailed
            case 429:
                throw TachikomaError.rateLimited
            case 400:
                if message.contains("context_length_exceeded") {
                    throw TachikomaError.contextLengthExceeded
                } else {
                    throw TachikomaError.invalidRequest(message)
                }
            case 500...599:
                throw TachikomaError.modelOverloaded
            default:
                throw TachikomaError.apiError(message: message, code: code)
            }
        } else {
            throw TachikomaError.apiError(message: "HTTP \(response.statusCode)", code: "\(response.statusCode)")
        }
    }
}