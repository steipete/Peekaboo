import Foundation

class OllamaProvider: AIProvider {
    let name = "ollama"
    let model: String
    
    var baseURL: URL {
        let baseURLString = ProcessInfo.processInfo.environment["PEEKABOO_OLLAMA_BASE_URL"] ?? "http://localhost:11434"
        return URL(string: baseURLString) ?? URL(string: "http://localhost:11434")!
    }
    
    var session: URLSession {
        URLSession.shared
    }
    
    init(model: String = "llava:latest") {
        self.model = model
    }
    
    var isAvailable: Bool {
        get async {
            await checkAvailability().available
        }
    }
    
    func checkAvailability() async -> AIProviderStatus {
        let tagsURL = baseURL.appendingPathComponent("/api/tags")
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
                        modelList: nil
                    )
                )
            }
            
            guard httpResponse.statusCode == 200 else {
                return AIProviderStatus(
                    available: false,
                    error: "Ollama server returned \(httpResponse.statusCode)",
                    details: AIProviderDetails(
                        modelAvailable: nil,
                        serverReachable: false,
                        apiKeyPresent: nil,
                        modelList: nil
                    )
                )
            }
            
            let tagsResponse = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            let availableModels = tagsResponse.models.map { $0.name }
            
            // Check if the specific model is available
            let modelAvailable = availableModels.contains { modelName in
                modelName == model || 
                modelName.hasPrefix(model + ":") || 
                model.hasPrefix(modelName.split(separator: ":")[0] + ":")
            }
            
            if !modelAvailable {
                return AIProviderStatus(
                    available: false,
                    error: "Model '\(model)' not found. Available models: \(availableModels.joined(separator: ", "))",
                    details: AIProviderDetails(
                        modelAvailable: false,
                        serverReachable: true,
                        apiKeyPresent: nil,
                        modelList: availableModels
                    )
                )
            }
            
            return AIProviderStatus(
                available: true,
                error: nil,
                details: AIProviderDetails(
                    modelAvailable: true,
                    serverReachable: true,
                    apiKeyPresent: nil,
                    modelList: availableModels
                )
            )
            
        } catch {
            let errorMessage: String
            if error is URLError {
                errorMessage = "Ollama server not reachable (not running or network issue)"
            } else {
                errorMessage = error.localizedDescription
            }
            
            return AIProviderStatus(
                available: false,
                error: errorMessage,
                details: AIProviderDetails(
                    modelAvailable: nil,
                    serverReachable: false,
                    apiKeyPresent: nil,
                    modelList: nil
                )
            )
        }
    }
    
    func analyze(imageBase64: String, question: String) async throws -> String {
        let prompt = question.isEmpty ? "Please describe what you see in this image." : question
        
        let requestBody = OllamaGenerateRequest(
            model: model,
            prompt: prompt,
            images: [imageBase64],
            stream: false
        )
        
        let generateURL = baseURL.appendingPathComponent("/api/generate")
        var request = URLRequest(url: generateURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60.0 // Ollama can be slower
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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