import Foundation

// MARK: - AI Provider Protocol

public protocol AIProvider {
    var name: String { get }
    var model: String { get }
    var isAvailable: Bool { get async }
    
    func checkAvailability() async -> AIProviderStatus
    func analyze(imageBase64: String, question: String) async throws -> String
}

// MARK: - AI Provider Configuration

public struct AIProviderConfig {
    public let provider: String
    public let model: String
    public let isValid: Bool
    
    public init(from string: String) {
        let parts = string.split(separator: "/", maxSplits: 1).map(String.init)
        if parts.count == 2 && !parts[0].isEmpty && !parts[1].isEmpty {
            self.provider = parts[0]
            self.model = parts[1]
            self.isValid = true
        } else {
            self.provider = parts.first ?? ""
            self.model = parts.count > 1 ? parts[1] : ""
            self.isValid = false
        }
    }
}

// MARK: - AI Provider Status

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

public struct AIProviderDetails {
    public let modelAvailable: Bool
    public let serverReachable: Bool
    public let apiKeyPresent: Bool
    public let modelList: [String]?
    
    public init(
        modelAvailable: Bool,
        serverReachable: Bool,
        apiKeyPresent: Bool,
        modelList: [String]? = nil
    ) {
        self.modelAvailable = modelAvailable
        self.serverReachable = serverReachable
        self.apiKeyPresent = apiKeyPresent
        self.modelList = modelList
    }
}

// MARK: - AI Provider Errors

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
        case .notConfigured(let message):
            return "Provider not configured: \(message)"
        case .serverUnreachable(let message):
            return "Server unreachable: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .modelNotAvailable(let model):
            return "Model not available: \(model)"
        case .apiKeyMissing(let message):
            return "API key missing: \(message)"
        case .analysisTimeout:
            return "Analysis request timed out"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Helper Functions

public func parseAIProviders(_ string: String?) -> [AIProviderConfig] {
    guard let string = string, !string.isEmpty else { return [] }
    
    return string.split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .compactMap { part in
            let config = AIProviderConfig(from: part)
            return config.isValid ? config : nil
        }
}