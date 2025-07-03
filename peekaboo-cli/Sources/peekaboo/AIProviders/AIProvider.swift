import Foundation

protocol AIProvider {
    var name: String { get }
    var model: String { get }
    var isAvailable: Bool { get async }
    
    func analyze(imageBase64: String, question: String) async throws -> String
    func checkAvailability() async -> AIProviderStatus
}

struct AIProviderStatus {
    let available: Bool
    let error: String?
    let details: AIProviderDetails?
}

struct AIProviderDetails {
    let modelAvailable: Bool?
    let serverReachable: Bool?
    let apiKeyPresent: Bool?
    let modelList: [String]?
}

enum AIProviderError: LocalizedError {
    case notConfigured(String)
    case serverUnreachable(String)
    case invalidResponse(String)
    case modelNotAvailable(String)
    case apiKeyMissing(String)
    case analysisTimeout
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured(let message):
            return "Provider not configured: \(message)"
        case .serverUnreachable(let message):
            return "Server unreachable: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .modelNotAvailable(let message):
            return "Model not available: \(message)"
        case .apiKeyMissing(let message):
            return "API key missing: \(message)"
        case .analysisTimeout:
            return "Analysis request timed out"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

struct AIProviderConfig {
    let provider: String
    let model: String
    
    init(from string: String) {
        let parts = string.split(separator: "/", maxSplits: 1)
        self.provider = String(parts.first ?? "")
        self.model = String(parts.count > 1 ? parts[1] : "")
    }
    
    var isValid: Bool {
        !provider.isEmpty && !model.isEmpty
    }
}

func parseAIProviders(from env: String?) -> [AIProviderConfig] {
    guard let env = env, !env.isEmpty else { return [] }
    
    return env
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .map { AIProviderConfig(from: $0) }
        .filter { $0.isValid }
}