import Foundation

/// Ollama model implementation conforming to ModelInterface

public final class OllamaModel: ModelInterface, Sendable {
    private let modelName: String
    private let baseURL: URL
    private let session: URLSession

    public init(
        modelName: String,
        baseURL: URL = URL(string: "http://localhost:11434")!,
        session: URLSession? = nil)
    {
        self.modelName = modelName
        self.baseURL = baseURL
        
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 300 // 5 minutes for local models
            config.timeoutIntervalForResource = 300
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - ModelInterface Implementation

    public var maskedApiKey: String {
        "local-ollama"
    }

    public func getResponse(request: ModelRequest) async throws -> ModelResponse {
        let ollamaRequest = try convertToOllamaRequest(request, stream: false)
        let urlRequest = try createURLRequest(endpoint: "api/chat", body: ollamaRequest)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(underlying: URLError(.badServerResponse))
        }

        if httpResponse.statusCode != 200 {
            try handleErrorResponse(data: data, response: httpResponse)
        }

        let ollamaResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        return try self.convertFromOllamaResponse(ollamaResponse)
    }

    public func getStreamedResponse(request: ModelRequest) async throws -> AsyncThrowingStream<StreamEvent, any Error> {
        let ollamaRequest = try convertToOllamaRequest(request, stream: true)
        let urlRequest = try createURLRequest(endpoint: "api/chat", body: ollamaRequest)

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

                    // Process JSON stream (one JSON object per line)
                    for try await line in bytes.lines {
                        if line.isEmpty { continue }
                        
                        if let data = line.data(using: .utf8),
                           let chunk = try? JSONDecoder().decode(OllamaChatChunk.self, from: data) {
                            
                            if let events = self.processOllamaChunk(chunk) {
                                for event in events {
                                    continuation.yield(event)
                                }
                            }
                            
                            // Check if done
                            if chunk.done {
                                continuation.finish()
                                return
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw TachikomaError.configurationError("Failed to encode Ollama request: \(error.localizedDescription)")
        }

        request.timeoutInterval = 300 // 5 minutes for local models

        return request
    }

    private func convertToOllamaRequest(_ request: ModelRequest, stream: Bool) throws -> OllamaChatRequest {
        // Convert messages
        let messages = try request.messages.compactMap { message -> OllamaMessage? in
            switch message {
            case let .system(_, content):
                return OllamaMessage(role: "system", content: content, images: nil)

            case let .user(_, content):
                return try convertUserMessage(content)

            case let .assistant(_, content, _):
                return convertAssistantMessage(content)

            case let .tool(_, _, content):
                // Ollama handles tool results differently - might need adaptation
                return OllamaMessage(role: "user", content: "Tool result: \(content)", images: nil)

            case .reasoning:
                // Skip reasoning messages for Ollama
                return nil
            }
        }

        // Convert tools (if supported by the model)
        let tools = request.tools?.map { toolDef -> OllamaTool in
            OllamaTool(
                type: "function",
                function: OllamaFunction(
                    name: toolDef.function.name,
                    description: toolDef.function.description,
                    parameters: convertToolParameters(toolDef.function.parameters)))
        }

        return OllamaChatRequest(
            model: self.modelName,
            messages: messages,
            tools: tools,
            stream: stream,
            options: OllamaOptions(
                temperature: request.settings.temperature,
                topP: request.settings.topP,
                stop: request.settings.stopSequences))
    }

    private func convertUserMessage(_ content: MessageContent) throws -> OllamaMessage {
        switch content {
        case let .text(text):
            return OllamaMessage(role: "user", content: text, images: nil)

        case let .image(imageContent):
            // Ollama supports base64 images
            if let base64 = imageContent.base64 {
                return OllamaMessage(role: "user", content: "", images: [base64])
            } else if imageContent.url != nil {
                throw TachikomaError.invalidRequest("Image URLs not supported in Ollama - please provide base64 data")
            } else {
                throw TachikomaError.invalidRequest("No image data provided")
            }

        case let .multimodal(parts):
            var text = ""
            var images: [String] = []
            
            for part in parts {
                if let partText = part.text {
                    text += partText
                } else if let image = part.imageUrl {
                    if let base64 = image.base64 {
                        images.append(base64)
                    } else if image.url != nil {
                        throw TachikomaError.invalidRequest("Image URLs not supported in Ollama - please provide base64 data")
                    }
                }
            }
            
            return OllamaMessage(role: "user", content: text, images: images.isEmpty ? nil : images)

        case .file:
            throw TachikomaError.invalidRequest("File content not supported in Ollama API")

        case let .audio(audioContent):
            // Ollama doesn't support native audio, use transcript if available
            if let transcript = audioContent.transcript {
                var text = transcript
                if let duration = audioContent.duration {
                    text = "[Audio transcript, duration: \(Int(duration))s] \(transcript)"
                } else {
                    text = "[Audio transcript] \(transcript)"
                }
                return OllamaMessage(role: "user", content: text, images: nil)
            } else {
                throw TachikomaError.invalidRequest("Audio content must be transcribed before sending to Ollama")
            }
        }
    }

    private func convertAssistantMessage(_ content: [AssistantContent]) -> OllamaMessage {
        var text = ""
        
        for item in content {
            switch item {
            case let .outputText(outputText):
                text += outputText
            case let .refusal(refusal):
                text += refusal
            case let .toolCall(toolCall):
                // Convert tool call to text representation for now
                text += "\n[Tool Call: \(toolCall.function.name)(\(toolCall.function.arguments))]"
            }
        }
        
        return OllamaMessage(role: "assistant", content: text, images: nil)
    }

    private func convertToolParameters(_ params: ToolParameters) -> [String: Any] {
        var properties: [String: Any] = [:]
        
        for (key, schema) in params.properties {
            properties[key] = convertParameterSchema(schema)
        }
        
        return [
            "type": params.type,
            "properties": properties,
            "required": params.required
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
        
        return result
    }

    private func convertFromOllamaResponse(_ response: OllamaChatResponse) throws -> ModelResponse {
        let content: [AssistantContent] = [.outputText(response.message.content)]
        
        // Ollama doesn't provide detailed usage info in the same format
        let usage = Usage(
            promptTokens: 0, // Not provided by Ollama
            completionTokens: 0, // Not provided by Ollama
            totalTokens: 0, // Not provided by Ollama
            promptTokensDetails: nil,
            completionTokensDetails: nil)

        return ModelResponse(
            id: UUID().uuidString, // Ollama doesn't provide response IDs
            model: response.model,
            content: content,
            usage: usage,
            flagged: false,
            finishReason: response.done ? .stop : nil)
    }

    private func processOllamaChunk(_ chunk: OllamaChatChunk) -> [StreamEvent]? {
        var events: [StreamEvent] = []

        // First chunk with model info
        if !chunk.model.isEmpty && events.isEmpty {
            events.append(.responseStarted(StreamResponseStarted(
                id: UUID().uuidString,
                model: chunk.model,
                systemFingerprint: nil)))
        }

        // Text content
        if let content = chunk.message?.content, !content.isEmpty {
            events.append(.textDelta(StreamTextDelta(delta: content, index: 0)))
        }

        // Done
        if chunk.done {
            events.append(.responseCompleted(StreamResponseCompleted(
                id: UUID().uuidString,
                usage: nil,
                finishReason: .stop)))
        }

        return events.isEmpty ? nil : events
    }

    private func handleErrorResponse(data: Data, response: HTTPURLResponse) throws {
        // Try to decode Ollama error format
        if let errorText = String(data: data, encoding: .utf8) {
            let message = errorText.isEmpty ? "HTTP \(response.statusCode)" : errorText
            
            switch response.statusCode {
            case 400:
                throw TachikomaError.invalidRequest(message)
            case 404:
                throw TachikomaError.modelNotFound(self.modelName)
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

