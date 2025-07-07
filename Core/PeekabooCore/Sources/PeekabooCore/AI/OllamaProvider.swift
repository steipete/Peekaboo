import Foundation

/// Ollama local AI provider implementation.
///
/// Provides image analysis using locally-running Ollama models for privacy-conscious users.
/// Supports vision models like LLaVA and requires Ollama server to be running locally.
open class OllamaProvider: AIProvider {
    public let name = "ollama"
    public let model: String

    open var baseURL: URL {
        let baseURLString = ConfigurationManager.shared.getOllamaBaseURL()
        return URL(string: baseURLString) ?? URL(string: "http://localhost:11434")!
    }

    public var session: URLSession {
        URLSession.shared
    }

    public init(model: String = "llava:latest") {
        self.model = model
    }

    public var isAvailable: Bool {
        get async {
            await self.checkAvailability().available
        }
    }

    public func checkAvailability() async -> AIProviderStatus {
        let tagsURL = self.baseURL.appendingPathComponent("/api/tags")
        var request = URLRequest(url: tagsURL)
        request.timeoutInterval = 3.0

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return AIProviderStatus(
                    available: false,
                    error: "Invalid response from Ollama server",
                    details: AIProviderDetails(
                        modelAvailable: nil,
                        serverReachable: false,
                        apiKeyPresent: nil,
                        modelList: nil))
            }

            guard httpResponse.statusCode == 200 else {
                return AIProviderStatus(
                    available: false,
                    error: "Ollama server returned \(httpResponse.statusCode)",
                    details: AIProviderDetails(
                        modelAvailable: nil,
                        serverReachable: false,
                        apiKeyPresent: nil,
                        modelList: nil))
            }

            let tagsResponse = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            let availableModels = tagsResponse.models.map(\.name)

            // Check if the specific model is available
            let modelAvailable = availableModels.contains { modelName in
                modelName == self.model ||
                    modelName.hasPrefix(self.model + ":") ||
                    self.model.hasPrefix(modelName.split(separator: ":")[0] + ":")
            }

            if !modelAvailable {
                return AIProviderStatus(
                    available: false,
                    error: "Model '\(self.model)' not found. Available models: \(availableModels.joined(separator: ", "))",
                    details: AIProviderDetails(
                        modelAvailable: false,
                        serverReachable: true,
                        apiKeyPresent: nil,
                        modelList: availableModels))
            }

            return AIProviderStatus(
                available: true,
                error: nil,
                details: AIProviderDetails(
                    modelAvailable: true,
                    serverReachable: true,
                    apiKeyPresent: nil,
                    modelList: availableModels))

        } catch {
            let errorMessage: String = if error is URLError {
                "Ollama server not reachable (not running or network issue)"
            } else {
                error.localizedDescription
            }

            return AIProviderStatus(
                available: false,
                error: errorMessage,
                details: AIProviderDetails(
                    modelAvailable: nil,
                    serverReachable: false,
                    apiKeyPresent: nil,
                    modelList: nil))
        }
    }

    public func analyze(imageBase64: String, question: String) async throws -> String {
        let prompt = question.isEmpty ? "Please describe what you see in this image." : question

        let requestBody = OllamaGenerateRequest(
            model: model,
            prompt: prompt,
            images: [imageBase64],
            stream: false)

        let generateURL = self.baseURL.appendingPathComponent("/api/generate")
        var request = URLRequest(url: generateURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60.0 // Ollama can be slower

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIProviderError.invalidResponse("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        let ollamaResponse = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)

        guard !ollamaResponse.response.isEmpty else {
            throw AIProviderError.invalidResponse("Empty response from Ollama")
        }

        return ollamaResponse.response
    }
}

// MARK: - Ollama API Models

private struct OllamaTagsResponse: Codable {
    let models: [OllamaModel]
}

private struct OllamaModel: Codable {
    let name: String
    let modifiedAt: String
    let size: Int64

    private enum CodingKeys: String, CodingKey {
        case name
        case modifiedAt = "modified_at"
        case size
    }
}

private struct OllamaGenerateRequest: Codable {
    let model: String
    let prompt: String
    let images: [String]
    let stream: Bool
}

private struct OllamaGenerateResponse: Codable {
    let model: String
    let createdAt: String
    let response: String
    let done: Bool
    let context: [Int]?
    let totalDuration: Int64?
    let loadDuration: Int64?
    let promptEvalCount: Int?
    let promptEvalDuration: Int64?
    let evalCount: Int?
    let evalDuration: Int64?

    private enum CodingKeys: String, CodingKey {
        case model
        case createdAt = "created_at"
        case response
        case done
        case context
        case totalDuration = "total_duration"
        case loadDuration = "load_duration"
        case promptEvalCount = "prompt_eval_count"
        case promptEvalDuration = "prompt_eval_duration"
        case evalCount = "eval_count"
        case evalDuration = "eval_duration"
    }
}