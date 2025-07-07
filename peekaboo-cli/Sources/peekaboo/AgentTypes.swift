import CoreGraphics
import Foundation

// MARK: - Error Types

enum AgentError: LocalizedError, Codable {
    case missingAPIKey
    case apiError(String)
    case commandFailed(String)
    case invalidResponse(String)
    case rateLimited(retryAfter: TimeInterval?)
    case timeout
    case invalidArguments(String)

    var errorDescription: String? {
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

    var errorCode: String {
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

struct AgentJSONResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: AgentErrorInfo?
}

struct AgentErrorInfo: Codable {
    let message: String
    let code: String
    let details: [String: String]?

    init(message: String, code: String, details: [String: String]? = nil) {
        self.message = message
        self.code = code
        self.details = details
    }

    init(from error: AgentError) {
        self.message = error.localizedDescription
        self.code = error.errorCode
        self.details = nil
    }
}

// MARK: - Helper Functions

func outputAgentJSON(_ value: some Encodable) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    do {
        let data = try encoder.encode(value)
        if let string = String(data: data, encoding: .utf8) {
            print(string)
        }
    } catch {
        print("{\"error\": \"Failed to encode JSON: \(error.localizedDescription)\"}")
    }
}

func createAgentErrorResponse(_ error: AgentError) -> AgentJSONResponse<EmptyData> {
    AgentJSONResponse(
        success: false,
        data: nil,
        error: AgentErrorInfo(from: error))
}

struct EmptyData: Codable {}

// MARK: - Session Management

actor SessionManager {
    static let shared = SessionManager()

    private var sessions: [String: SessionData] = [:]

    struct SessionData: Sendable {
        let id: String
        let createdAt: Date
        var elementMappings: [String: ElementMapping]
        var screenshots: [ScreenshotData]
        var context: [String: String]

        mutating func addMapping(_ mapping: ElementMapping) {
            self.elementMappings[mapping.id] = mapping
        }

        mutating func addScreenshot(_ screenshot: ScreenshotData) {
            self.screenshots.append(screenshot)
            // Keep only last 10 screenshots to manage memory
            if self.screenshots.count > 10 {
                self.screenshots.removeFirst()
            }
        }
    }

    struct ElementMapping: Codable, Sendable {
        let id: String
        let description: String
        let bounds: CGRect
        let type: String
        let confidence: Double
    }

    struct ScreenshotData: Sendable {
        let timestamp: Date
        let path: String
        let elements: [ElementMapping]
    }

    func createSession() -> String {
        let sessionId = UUID().uuidString
        self.sessions[sessionId] = SessionData(
            id: sessionId,
            createdAt: Date(),
            elementMappings: [:],
            screenshots: [],
            context: [:])
        return sessionId
    }

    func getSession(_ id: String) -> SessionData? {
        self.sessions[id]
    }

    func updateSession(_ id: String, with data: SessionData) {
        self.sessions[id] = data
    }

    func removeSession(_ id: String) {
        self.sessions.removeValue(forKey: id)
    }

    func cleanupOldSessions() {
        let cutoffDate = Date().addingTimeInterval(-3600) // 1 hour
        self.sessions = self.sessions.filter { $0.value.createdAt > cutoffDate }
    }
}

// MARK: - API Types Extensions

extension Tool {
    func encodeParameters() throws -> Data {
        let params = function.parameters.dictionary
        guard JSONSerialization.isValidJSONObject(params) else {
            throw AgentError.invalidArguments("Invalid function parameters")
        }
        return try JSONSerialization.data(withJSONObject: params, options: [])
    }
}

// MARK: - Retry Configuration

struct RetryConfiguration {
    let maxAttempts: Int
    let initialDelay: TimeInterval
    let maxDelay: TimeInterval
    let backoffMultiplier: Double

    static let `default` = RetryConfiguration(
        maxAttempts: 3,
        initialDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0)

    func delay(for attempt: Int) -> TimeInterval {
        let delay = self.initialDelay * pow(self.backoffMultiplier, Double(attempt))
        return min(delay, self.maxDelay)
    }
}
