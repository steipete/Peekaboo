import Foundation

// MARK: - Ollama Request Types

struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [OllamaMessage]
    let tools: [OllamaTool]?
    let stream: Bool
    let options: OllamaOptions?
}

struct OllamaMessage: Codable {
    let role: String
    let content: String
    let images: [String]?
}

struct OllamaTool: Encodable {
    let type: String
    let function: OllamaFunction
}

struct OllamaFunction: Encodable {
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

struct OllamaOptions: Encodable {
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

struct OllamaChatResponse: Decodable {
    let model: String
    let message: OllamaMessage
    let done: Bool
}

struct OllamaChatChunk: Decodable {
    let model: String
    let message: OllamaMessage?
    let done: Bool
}
