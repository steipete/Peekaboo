import Foundation

public enum AgentError: LocalizedError, Codable, Sendable {
    case missingAPIKey
    case apiError(String)
    case commandFailed(String)
    case invalidResponse(String)
    case rateLimited(retryAfter: TimeInterval?)
    case timeout
    case invalidArguments(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OPENAI_API_KEY environment variable not set"
        case let .apiError(message):
            return "API Error: \(message)"
        case let .commandFailed(message):
            return "Command failed: \(message)"
        case let .invalidResponse(message):
            return "Invalid response: \(message)"
        case let .rateLimited(retryAfter):
            if let retryAfter {
                return "Rate limited. Retry after \(retryAfter) seconds"
            }
            return "Rate limited"
        case .timeout:
            return "Request timed out"
        case let .invalidArguments(message):
            return "Invalid arguments: \(message)"
        }
    }

    public var errorCode: String {
        switch self {
        case .missingAPIKey: "MISSING_API_KEY"
        case .apiError: "API_ERROR"
        case .commandFailed: "COMMAND_FAILED"
        case .invalidResponse: "INVALID_RESPONSE"
        case .rateLimited: "RATE_LIMITED"
        case .timeout: "TIMEOUT"
        case .invalidArguments: "INVALID_ARGS"
        }
    }
}

// MARK: - Agent Result Types

public struct AgentResult: Codable, Sendable {
    public let steps: [Step]
    public let summary: String?
    public let success: Bool

    public struct Step: Codable, Sendable {
        public let description: String
        public let command: String?
        public let output: String?
        public let screenshot: String? // Base64 encoded

        public init(description: String, command: String? = nil, output: String? = nil, screenshot: String? = nil) {
            self.description = description
            self.command = command
            self.output = output
            self.screenshot = screenshot
        }
    }

    public init(steps: [Step], summary: String? = nil, success: Bool) {
        self.steps = steps
        self.summary = summary
        self.success = success
    }
}

// MARK: - Retry Configuration

public struct RetryConfiguration: Sendable {
    public let maxAttempts: Int
    public let initialDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let backoffMultiplier: Double

    public static let `default` = RetryConfiguration(
        maxAttempts: 3,
        initialDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0)

    public init(maxAttempts: Int, initialDelay: TimeInterval, maxDelay: TimeInterval, backoffMultiplier: Double) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.backoffMultiplier = backoffMultiplier
    }

    public func delay(for attempt: Int) -> TimeInterval {
        let delay = self.initialDelay * pow(self.backoffMultiplier, Double(attempt))
        return min(delay, self.maxDelay)
    }
}
