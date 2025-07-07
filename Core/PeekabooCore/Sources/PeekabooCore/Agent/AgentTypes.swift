import CoreGraphics
import Foundation

// MARK: - Error Types

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

// MARK: - JSON Response Types

public struct AgentJSONResponse<T: Codable>: Codable {
    public let success: Bool
    public let data: T?
    public let error: AgentErrorInfo?

    public init(success: Bool, data: T?, error: AgentErrorInfo? = nil) {
        self.success = success
        self.data = data
        self.error = error
    }
}

public struct AgentErrorInfo: Codable {
    public let message: String
    public let code: String
    public let details: [String: String]?

    public init(message: String, code: String, details: [String: String]? = nil) {
        self.message = message
        self.code = code
        self.details = details
    }

    public init(from error: AgentError) {
        self.message = error.localizedDescription
        self.code = error.errorCode
        self.details = nil
    }
}

// MARK: - Helper Functions

public func createAgentErrorResponse(_ error: AgentError) -> AgentJSONResponse<EmptyData> {
    AgentJSONResponse(
        success: false,
        data: nil,
        error: AgentErrorInfo(from: error))
}

public struct EmptyData: Codable {
    public init() {}
}

// MARK: - Session Management

public actor AgentSessionManager {
    public static let shared = AgentSessionManager()

    private var sessions: [String: SessionData] = [:]

    public struct SessionData: Sendable {
        public let id: String
        public let createdAt: Date
        public var elementMappings: [String: ElementMapping]
        public var screenshots: [ScreenshotData]
        public var context: [String: String]

        public mutating func addMapping(_ mapping: ElementMapping) {
            self.elementMappings[mapping.id] = mapping
        }

        public mutating func addScreenshot(_ screenshot: ScreenshotData) {
            self.screenshots.append(screenshot)
            // Keep only last 10 screenshots to manage memory
            if self.screenshots.count > 10 {
                self.screenshots.removeFirst()
            }
        }
    }

    public struct ElementMapping: Codable, Sendable {
        public let id: String
        public let description: String
        public let bounds: CGRect
        public let type: String
        public let confidence: Double

        public init(id: String, description: String, bounds: CGRect, type: String, confidence: Double) {
            self.id = id
            self.description = description
            self.bounds = bounds
            self.type = type
            self.confidence = confidence
        }
    }

    public struct ScreenshotData: Sendable {
        public let timestamp: Date
        public let path: String
        public let elements: [ElementMapping]

        public init(timestamp: Date, path: String, elements: [ElementMapping]) {
            self.timestamp = timestamp
            self.path = path
            self.elements = elements
        }
    }

    public func createSession() -> String {
        let sessionId = UUID().uuidString
        self.sessions[sessionId] = SessionData(
            id: sessionId,
            createdAt: Date(),
            elementMappings: [:],
            screenshots: [],
            context: [:])
        return sessionId
    }

    public func getSession(_ id: String) -> SessionData? {
        self.sessions[id]
    }

    public func updateSession(_ id: String, with data: SessionData) {
        self.sessions[id] = data
    }

    public func removeSession(_ id: String) {
        self.sessions.removeValue(forKey: id)
    }

    public func cleanupOldSessions() {
        let cutoffDate = Date().addingTimeInterval(-3600) // 1 hour
        self.sessions = self.sessions.filter { $0.value.createdAt > cutoffDate }
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

// MARK: - Agent Execution Delegate

public protocol AgentExecutionDelegate: AnyObject {
    func agentDidStartTask(_ description: String)
    func agentDidCompleteTask(_ description: String, success: Bool)
    func agentDidReceiveOutput(_ output: String)
    func agentDidEncounterError(_ error: Error)
    func agentDidUpdateProgress(_ progress: Double, message: String?)
}

// MARK: - Tool Execution Result

public struct ToolExecutionResult: Codable {
    public let toolName: String
    public let success: Bool
    public let output: String?
    public let error: String?
    public let timestamp: Date

    public init(toolName: String, success: Bool, output: String? = nil, error: String? = nil) {
        self.toolName = toolName
        self.success = success
        self.output = output
        self.error = error
        self.timestamp = Date()
    }
}
