import Foundation

// MARK: - Ollama Request Types

internal struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [OllamaMessage]
    let tools: [OllamaTool]?
    let stream: Bool
    let options: OllamaOptions?
}

internal struct OllamaMessage: Codable {
    let role: String
    let content: String
    let images: [String]?
}

internal struct OllamaTool: Encodable {
    let type: String
    let function: OllamaFunction
}

internal struct OllamaFunction: Encodable {
    let name: String
    let description: String
    let parameters: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case name, description, parameters
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        
        // Encode parameters as JSON
        let data = try JSONSerialization.data(withJSONObject: parameters)
        let jsonString = String(data: data, encoding: .utf8) ?? "{}"
        try container.encode(jsonString, forKey: .parameters)
    }
}

internal struct OllamaOptions: Encodable {
    let temperature: Double?
    let topP: Double?
    let stop: [String]?
    
    enum CodingKeys: String, CodingKey {
        case temperature
        case topP = "top_p"
        case stop
    }
}

// MARK: - Ollama Response Types

internal struct OllamaChatResponse: Decodable {
    let model: String
    let message: OllamaMessage
    let done: Bool
}

internal struct OllamaChatChunk: Decodable {
    let model: String
    let message: OllamaMessage?
    let done: Bool
}