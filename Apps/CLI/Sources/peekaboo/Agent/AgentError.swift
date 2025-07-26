import Foundation

public enum AgentError: LocalizedError, CustomStringConvertible {
    case missingAPIKey
    case apiError(String)
    case commandFailed(String)
    case invalidResponse(String)
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OPENAI_API_KEY environment variable not set"
        case .apiError(let message):
            return "API Error: \(message)"
        case .commandFailed(let message):
            return "Command failed: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .timeout:
            return "Request timed out"
        }
    }
    
    public var description: String {
        errorDescription ?? "Unknown error"
    }
    
    public var errorCode: String {
        switch self {
        case .missingAPIKey:
            return "MISSING_API_KEY"
        case .apiError:
            return "API_ERROR"
        case .commandFailed:
            return "COMMAND_FAILED"
        case .invalidResponse:
            return "INVALID_RESPONSE"
        case .timeout:
            return "TIMEOUT"
        }
    }
}