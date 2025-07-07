import Foundation

/// Protocol for AI vision model providers.
///
/// Defines the interface that all AI providers must implement to analyze images.
/// Providers can be cloud-based (like OpenAI) or local (like Ollama).
public protocol AIProvider {
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
public struct AIProviderStatus {
    public let available: Bool
    public let error: String?
    public let details: AIProviderDetails?
    
    public init(available: Bool, error: String? = nil, details: AIProviderDetails? = nil) {
        self.available = available
        self.error = error
        self.details = details
    }
}

/// Detailed diagnostic information about an AI provider.
///
/// Provides granular information about why a provider might be unavailable,
/// including server connectivity, API key presence, and model availability.
public struct AIProviderDetails {
    public let modelAvailable: Bool?
    public let serverReachable: Bool?
    public let apiKeyPresent: Bool?
    public let modelList: [String]?
    
    public init(
        modelAvailable: Bool? = nil,
        serverReachable: Bool? = nil,
        apiKeyPresent: Bool? = nil,
        modelList: [String]? = nil
    ) {
        self.modelAvailable = modelAvailable
        self.serverReachable = serverReachable
        self.apiKeyPresent = apiKeyPresent
        self.modelList = modelList
    }
}

/// Errors that can occur when using AI providers.
///
/// Comprehensive error enumeration covering configuration issues,
/// connectivity problems, and API-specific failures.
public enum AIProviderError: LocalizedError {
    case notConfigured(String)
    case serverUnreachable(String)
    case invalidResponse(String)
    case modelNotAvailable(String)
    case apiKeyMissing(String)
    case analysisTimeout
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case let .notConfigured(message):
            "Provider not configured: \(message)"
        case let .serverUnreachable(message):
            "Server unreachable: \(message)"
        case let .invalidResponse(message):
            "Invalid response: \(message)"
        case let .modelNotAvailable(message):
            "Model not available: \(message)"
        case let .apiKeyMissing(message):
            "API key missing: \(message)"
        case .analysisTimeout:
            "Analysis request timed out"
        case let .unknown(message):
            "Unknown error: \(message)"
        }
    }
}

/// Configuration for an AI provider instance.
///
/// Parses provider/model strings like "openai/gpt-4o" or "ollama/llava:latest"
/// into separate provider and model components.
public struct AIProviderConfig {
    public let provider: String
    public let model: String

    public init(from string: String) {
        let parts = string.split(separator: "/", maxSplits: 1)
        self.provider = String(parts.first ?? "")
        self.model = String(parts.count > 1 ? parts[1] : "")
    }

    public var isValid: Bool {
        !self.provider.isEmpty && !self.model.isEmpty
    }
}

public func parseAIProviders(from env: String?) -> [AIProviderConfig] {
    guard let env, !env.isEmpty else { return [] }

    return env
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .map { AIProviderConfig(from: $0) }
        .filter(\.isValid)
}