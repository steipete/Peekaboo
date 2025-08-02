@_exported import Foundation

// MARK: - Tachikoma Error Types

/// Main error type for the Tachikoma library
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum TachikomaError: Error, LocalizedError, Sendable {
    case modelNotFound(String)
    case authenticationFailed
    case invalidConfiguration(String)
    case networkError(underlying: any Error)
    case decodingError(underlying: any Error)
    case invalidRequest(String)
    case apiError(message: String, code: String? = nil)
    case timeout
    case rateLimited
    case insufficientQuota
    case modelOverloaded
    case contextLengthExceeded
    case contentFiltered
    case invalidToolCall(String)
    case streamingError(String)
    case configurationError(String)

    public var errorDescription: String? {
        switch self {
        case let .modelNotFound(model):
            "Model not found: \(model)"
        case .authenticationFailed:
            "Authentication failed - check your API key"
        case let .invalidConfiguration(message):
            "Invalid configuration: \(message)"
        case let .networkError(underlying):
            "Network error: \(underlying.localizedDescription)"
        case let .decodingError(underlying):
            "Failed to decode response: \(underlying.localizedDescription)"
        case let .invalidRequest(message):
            "Invalid request: \(message)"
        case let .apiError(message, code):
            if let code {
                "API error (\(code)): \(message)"
            } else {
                "API error: \(message)"
            }
        case .timeout:
            "Request timed out"
        case .rateLimited:
            "Rate limited - please slow down requests"
        case .insufficientQuota:
            "Insufficient quota - check your billing"
        case .modelOverloaded:
            "Model is currently overloaded - try again later"
        case .contextLengthExceeded:
            "Context length exceeded - reduce input size"
        case .contentFiltered:
            "Content was filtered by safety systems"
        case let .invalidToolCall(message):
            "Invalid tool call: \(message)"
        case let .streamingError(message):
            "Streaming error: \(message)"
        case let .configurationError(message):
            "Configuration error: \(message)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .modelNotFound:
            "Check available models with listModels() or verify the model name is correct"
        case .authenticationFailed:
            "Verify your API key is set correctly in environment variables or credentials file"
        case .rateLimited:
            "Wait a moment before making another request"
        case .insufficientQuota:
            "Check your billing settings and account quota"
        case .modelOverloaded:
            "Try using a different model or retry after a delay"
        case .contextLengthExceeded:
            "Reduce the length of your input messages or use a model with larger context"
        case .contentFiltered:
            "Modify your input to comply with content policies"
        case .timeout:
            "Check your network connection and try again"
        default:
            nil
        }
    }

    /// Check if this error indicates a temporary condition that might resolve with retry
    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .modelOverloaded, .timeout, .networkError:
            true
        default:
            false
        }
    }

    /// Check if this error indicates an authentication issue
    public var isAuthenticationError: Bool {
        switch self {
        case .authenticationFailed, .insufficientQuota:
            true
        default:
            false
        }
    }

    /// Check if this error indicates a client-side issue
    public var isClientError: Bool {
        switch self {
        case .invalidRequest, .invalidConfiguration, .contextLengthExceeded, .contentFiltered, .invalidToolCall:
            true
        default:
            false
        }
    }
}

// MARK: - Model Request/Response Errors

/// Specific errors for model requests and responses
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ModelError: Error, LocalizedError, Sendable {
    case invalidInput(String)
    case missingRequiredParameter(String)
    case unsupportedParameter(String)
    case invalidParameterValue(String, value: String)
    case responseTooLarge
    case emptyResponse
    case malformedResponse(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidInput(message):
            "Invalid input: \(message)"
        case let .missingRequiredParameter(param):
            "Missing required parameter: \(param)"
        case let .unsupportedParameter(param):
            "Unsupported parameter: \(param)"
        case let .invalidParameterValue(param, value):
            "Invalid value for parameter '\(param)': \(value)"
        case .responseTooLarge:
            "Response exceeds maximum size limit"
        case .emptyResponse:
            "Received empty response from API"
        case let .malformedResponse(message):
            "Malformed response: \(message)"
        }
    }
}

// MARK: - Streaming Errors

/// Errors specific to streaming operations
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum StreamingError: Error, LocalizedError, Sendable {
    case streamClosed
    case invalidEventFormat(String)
    case bufferOverflow
    case connectionLost

    public var errorDescription: String? {
        switch self {
        case .streamClosed:
            "Stream was closed unexpectedly"
        case let .invalidEventFormat(format):
            "Invalid event format: \(format)"
        case .bufferOverflow:
            "Stream buffer overflow"
        case .connectionLost:
            "Connection to stream was lost"
        }
    }
}

// MARK: - Tool Execution Errors

/// Errors for tool execution
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public enum ToolExecutionError: Error, LocalizedError, Sendable {
    case toolNotFound(String)
    case invalidArguments(String)
    case executionFailed(String)
    case timeout
    case missingContext

    public var errorDescription: String? {
        switch self {
        case let .toolNotFound(name):
            "Tool not found: \(name)"
        case let .invalidArguments(message):
            "Invalid tool arguments: \(message)"
        case let .executionFailed(message):
            "Tool execution failed: \(message)"
        case .timeout:
            "Tool execution timed out"
        case .missingContext:
            "Required context is missing for tool execution"
        }
    }
}