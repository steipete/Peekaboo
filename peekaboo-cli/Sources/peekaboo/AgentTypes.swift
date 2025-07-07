import Foundation
import CoreGraphics

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
        case .apiError(let message):
            return "API Error: \(message)"
        case .commandFailed(let message):
            return "Command failed: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited. Retry after \(retryAfter) seconds"
            }
            return "Rate limited"
        case .timeout:
            return "Request timed out"
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        }
    }
    
    var errorCode: String {
        switch self {
        case .missingAPIKey: return "MISSING_API_KEY"
        case .apiError: return "API_ERROR"
        case .commandFailed: return "COMMAND_FAILED"
        case .invalidResponse: return "INVALID_RESPONSE"
        case .rateLimited: return "RATE_LIMITED"
        case .timeout: return "TIMEOUT"
        case .invalidArguments: return "INVALID_ARGS"
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

func outputAgentJSON<T: Encodable>(_ value: T) {
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
    return AgentJSONResponse(
        success: false,
        data: nil,
        error: AgentErrorInfo(from: error)
    )
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
            elementMappings[mapping.id] = mapping
        }
        
        mutating func addScreenshot(_ screenshot: ScreenshotData) {
            screenshots.append(screenshot)
            // Keep only last 10 screenshots to manage memory
            if screenshots.count > 10 {
                screenshots.removeFirst()
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
        sessions[sessionId] = SessionData(
            id: sessionId,
            createdAt: Date(),
            elementMappings: [:],
            screenshots: [],
            context: [:]
        )
        return sessionId
    }
    
    func getSession(_ id: String) -> SessionData? {
        return sessions[id]
    }
    
    func updateSession(_ id: String, with data: SessionData) {
        sessions[id] = data
    }
    
    func removeSession(_ id: String) {
        sessions.removeValue(forKey: id)
    }
    
    func cleanupOldSessions() {
        let cutoffDate = Date().addingTimeInterval(-3600) // 1 hour
        sessions = sessions.filter { $0.value.createdAt > cutoffDate }
    }
}

// MARK: - API Types Extensions

extension Tool {
    func encodeParameters() throws -> Data {
        guard let params = function.parameters as? [String: Any],
              JSONSerialization.isValidJSONObject(params) else {
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
        backoffMultiplier: 2.0
    )
    
    func delay(for attempt: Int) -> TimeInterval {
        let delay = initialDelay * pow(backoffMultiplier, Double(attempt))
        return min(delay, maxDelay)
    }
}