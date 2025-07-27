import Foundation
import AXorcist

/// Ollama model implementation conforming to ModelInterface
public final class OllamaModel: ModelInterface {
    private let baseURL: URL
    private let session: URLSession
    private let modelName: String
    
    public init(
        modelName: String,
        baseURL: URL = URL(string: "http://localhost:11434")!,
        session: URLSession? = nil
    ) {
        self.modelName = modelName
        self.baseURL = baseURL
        self.session = session ?? URLSession.shared
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
        urlRequest.httpBody = try JSONEncoder().encode(ollamaRequest)
        
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
        // Convert ModelRequest to Ollama format with streaming enabled
        var ollamaRequest = try convertToOllamaRequest(request)
        ollamaRequest.stream = true
        
        // Create URL request
        let url = baseURL.appendingPathComponent("/api/chat")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(ollamaRequest)
        
        // Capture immutable copy for use in closure
        let request = urlRequest
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    
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
                    
                    for try await byte in bytes {
                        buffer.append(byte)
                        
                        // Look for newline
                        if byte == 0x0A { // \n
                            if let line = String(data: buffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !line.isEmpty {
                                
                                // Parse JSON chunk
                                if let data = line.data(using: .utf8),
                                   let chunk = try? JSONDecoder().decode(OllamaStreamChunk.self, from: data) {
                                    
                                    // Convert to StreamEvent
                                    if let content = chunk.message?.content, !content.isEmpty {
                                        continuation.yield(StreamEvent.textDelta(StreamTextDelta(delta: content)))
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
                return OllamaMessage(role: "system", content: systemMsg.content, images: nil)
                
            case let userMsg as UserMessageItem:
                // Handle different content types
                switch userMsg.content {
                case .text(let text):
                    return OllamaMessage(role: "user", content: text, images: nil)
                    
                case .image(let imageContent):
                    // Ollama expects images as base64 strings
                    if let base64 = imageContent.base64 {
                        return OllamaMessage(role: "user", content: "", images: [base64])
                    } else {
                        // Can't send URL images to Ollama
                        return OllamaMessage(role: "user", content: "[Image URL not supported by Ollama]", images: nil)
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
                        images: images.isEmpty ? nil : images
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
                
                return OllamaMessage(role: "assistant", content: textContent, images: nil)
                
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
        
        return OllamaRequest(
            model: modelName,
            messages: messages,
            stream: false,
            options: options.isEmpty ? nil : options
        )
    }
    
    private func convertFromOllamaResponse(_ response: OllamaResponse) throws -> ModelResponse {
        let content = [AssistantContent.outputText(response.message.content)]
        
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

private struct OllamaRequest: Encodable {
    let model: String
    let messages: [OllamaMessage]
    var stream: Bool = false
    let options: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, stream, options
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encode(stream, forKey: .stream)
        
        if let options = options {
            // Encode options as JSON
            let jsonData = try JSONSerialization.data(withJSONObject: options)
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
            try container.encode(jsonObject as? [String: String], forKey: .options)
        }
    }
}

private struct OllamaMessage: Codable {
    let role: String
    let content: String
    let images: [String]? // Base64 encoded images
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