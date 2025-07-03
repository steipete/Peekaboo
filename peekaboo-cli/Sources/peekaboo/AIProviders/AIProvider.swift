import Foundation

/// Protocol for AI vision model providers.
///
/// Defines the interface that all AI providers must implement to analyze images.
/// Providers can be cloud-based (like OpenAI) or local (like Ollama).
protocol AIProvider {
    var name: String { get }
    var model: String { get }
    var isAvailable: Bool { get async }
    
    func analyze(imageBase64: String, question: String) async throws -> String
    func checkAvailability() async -> AIProviderStatus
}

/// Status information about an AI provider's availability.
///
/// Contains availability status, error messages if unavailable,
/// and detailed diagnostic information.
struct AIProviderStatus {
    let available: Bool
    let error: String?
    let details: AIProviderDetails?
}

/// Detailed diagnostic information about an AI provider.
///
/// Provides granular information about why a provider might be unavailable,
/// including server connectivity, API key presence, and model availability.
struct AIProviderDetails {
    let modelAvailable: Bool?
    let serverReachable: Bool?
    let apiKeyPresent: Bool?
    let modelList: [String]?
}

/// Errors that can occur when using AI providers.
///
/// Comprehensive error enumeration covering configuration issues,
/// connectivity problems, and API-specific failures.
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

/// Configuration for an AI provider instance.
///
/// Parses provider/model strings like "openai/gpt-4o" or "ollama/llava:latest"
/// into separate provider and model components.
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