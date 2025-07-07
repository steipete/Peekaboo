import Foundation

/// OpenAI GPT-4 Vision provider implementation.
///
/// Provides image analysis capabilities using OpenAI's GPT-4 Vision API.
/// Requires an OpenAI API key configured via environment variable or config file.
class OpenAIProvider: AIProvider {
    let name = "openai"
    let model: String
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    var apiKey: String? {
        ConfigurationManager.shared.getOpenAIAPIKey()
    }

    var session: URLSession {
        URLSession.shared
    }

    init(model: String = "gpt-4o") {
        self.model = model
    }

    var isAvailable: Bool {
        get async {
            await self.checkAvailability().available
        }
    }

    func checkAvailability() async -> AIProviderStatus {
        guard let apiKey, !apiKey.isEmpty else {
            return AIProviderStatus(
                available: false,
                error: "OpenAI API key not configured (OPENAI_API_KEY environment variable missing)",
                details: AIProviderDetails(
                    modelAvailable: nil,
                    serverReachable: nil,
                    apiKeyPresent: false,
                    modelList: nil))
        }

        // For now, we'll assume OpenAI is available if API key is present
        // In a more robust implementation, we could make a test API call
        return AIProviderStatus(
            available: true,
            error: nil,
            details: AIProviderDetails(
                modelAvailable: true,
                serverReachable: true,
                apiKeyPresent: true,
                modelList: nil))
    }

    func analyze(imageBase64: String, question: String) async throws -> String {
        guard let apiKey else {
            throw AIProviderError.apiKeyMissing("OPENAI_API_KEY environment variable not set")
        }

        let prompt = question.isEmpty ? "Please describe what you see in this image." : question

        let requestBody = OpenAIRequest(
            model: model,
            messages: [
                OpenAIMessage(
                    role: "user",
                    content: [
                        .text(OpenAITextContent(text: prompt)),
                        .imageURL(OpenAIImageContent(
                            imageURL: OpenAIImageURL(url: "data:image/jpeg;base64,\(imageBase64)"))),
                    ]),
            ],
            maxTokens: 1000)

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse("Invalid HTTP response")
        }

        if httpResponse.statusCode == 401 {
            throw AIProviderError.apiKeyMissing("Invalid OpenAI API key")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIProviderError.invalidResponse("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let openAIResponse = try decoder.decode(OpenAIResponse.self, from: data)

        guard let content = openAIResponse.choices.first?.message.content else {
            throw AIProviderError.invalidResponse("No content in OpenAI response")
        }

        return content
    }
}

// MARK: - OpenAI API Models

private struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let maxTokens: Int
}

private struct OpenAIMessage: Codable {
    let role: String
    let content: [OpenAIContent]
}

private enum OpenAIContent: Codable {
    case text(OpenAITextContent)
    case imageURL(OpenAIImageContent)

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(content):
            try container.encode("text", forKey: .type)
            try container.encode(content.text, forKey: .text)
        case let .imageURL(content):
            try container.encode("image_url", forKey: .type)
            try container.encode(content.imageURL, forKey: .imageURL)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(OpenAITextContent(text: text))
        case "image_url":
            let imageURL = try container.decode(OpenAIImageURL.self, forKey: .imageURL)
            self = .imageURL(OpenAIImageContent(imageURL: imageURL))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content type: \(type)")
        }
    }
}

private struct OpenAITextContent: Codable {
    let text: String
}

private struct OpenAIImageContent: Codable {
    let imageURL: OpenAIImageURL
}

private struct OpenAIImageURL: Codable {
    let url: String
}

private struct OpenAIResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIChoice]
}

private struct OpenAIChoice: Codable {
    let index: Int
    let message: OpenAIResponseMessage
    let finishReason: String?
}

private struct OpenAIResponseMessage: Codable {
    let role: String
    let content: String
}
