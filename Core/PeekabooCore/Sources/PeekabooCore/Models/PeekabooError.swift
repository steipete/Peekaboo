import Foundation

/// Main error type for Peekaboo operations
public enum PeekabooError: LocalizedError, StandardizedError {
    // Permission errors
    case permissionDeniedScreenRecording
    case permissionDeniedAccessibility
    
    // App and window errors
    case appNotFound(String)
    case ambiguousAppIdentifier(String, suggestions: [String])
    case windowNotFound
    case displayNotFound
    
    // Element errors
    case elementNotFound(String)
    case ambiguousElement(String)
    
    // Menu errors
    case menuNotFound(String)
    case menuItemNotFound(String)
    
    // Session errors  
    case sessionNotFound(String)
    
    // Operation errors
    case captureTimeout
    case captureFailed(String)
    case clickFailed(String)
    case typeFailed(String)
    case invalidCoordinates
    case fileIOError(String)
    case commandFailed(String)
    case timeout(String)
    
    // Input errors
    case invalidInput(String)
    case encodingError(String)
    
    // AI errors
    case noAIProviderAvailable
    case aiProviderError(String)
    
    // Service errors
    case serviceUnavailable(String)
    
    // Generic errors - removed context since it can't be Sendable
    case operationError(message: String)
    
    public var errorDescription: String? {
        switch self {
        case .permissionDeniedScreenRecording:
            return "Screen Recording permission is required"
        case .permissionDeniedAccessibility:
            return "Accessibility permission is required"
        case .appNotFound(let name):
            return "Application '\(name)' not found"
        case .ambiguousAppIdentifier(let name, let suggestions):
            return "Multiple apps match '\(name)'. Did you mean: \(suggestions.joined(separator: ", "))"
        case .windowNotFound:
            return "Window not found"
        case .displayNotFound:
            return "Display not found"
        case .elementNotFound(let id):
            return "Element not found: \(id)"
        case .ambiguousElement(let id):
            return "Multiple elements match: \(id)"
        case .menuNotFound(let app):
            return "Menu not found for application: \(app)"
        case .menuItemNotFound(let item):
            return "Menu item not found: \(item)"
        case .sessionNotFound(let id):
            return "Session not found or expired: \(id)"
        case .captureTimeout:
            return "Screen capture timed out"
        case .captureFailed(let reason):
            return "Capture failed: \(reason)"
        case .clickFailed(let reason):
            return "Click failed: \(reason)"
        case .typeFailed(let reason):
            return "Type failed: \(reason)"
        case .invalidCoordinates:
            return "Invalid coordinates provided"
        case .fileIOError(let reason):
            return "File I/O error: \(reason)"
        case .commandFailed(let reason):
            return "Command failed: \(reason)"
        case .timeout(let reason):
            return "Operation timed out: \(reason)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .encodingError(let message):
            return "Encoding error: \(message)"
        case .noAIProviderAvailable:
            return "No AI provider available"
        case .aiProviderError(let message):
            return "AI provider error: \(message)"
        case .serviceUnavailable(let message):
            return "Service unavailable: \(message)"
        case .operationError(let message):
            return message
        }
    }
    
    /// StandardizedError conformance
    public var code: StandardErrorCode {
        switch self {
        case .permissionDeniedScreenRecording:
            return .screenRecordingPermissionDenied
        case .permissionDeniedAccessibility:
            return .accessibilityPermissionDenied
        case .appNotFound:
            return .applicationNotFound
        case .ambiguousAppIdentifier:
            return .ambiguousAppIdentifier
        case .windowNotFound:
            return .windowNotFound
        case .displayNotFound:
            return .invalidDisplayIndex
        case .elementNotFound:
            return .elementNotFound
        case .ambiguousElement:
            return .elementNotFound
        case .menuNotFound:
            return .menuNotFound
        case .menuItemNotFound:
            return .menuNotFound
        case .sessionNotFound:
            return .sessionNotFound
        case .captureTimeout:
            return .timeout
        case .captureFailed:
            return .captureFailed
        case .clickFailed:
            return .interactionFailed
        case .typeFailed:
            return .interactionFailed
        case .invalidCoordinates:
            return .invalidCoordinates
        case .fileIOError:
            return .fileIOError
        case .commandFailed:
            return .interactionFailed
        case .timeout:
            return .timeout
        case .invalidInput:
            return .invalidInput
        case .encodingError:
            return .unknownError
        case .noAIProviderAvailable:
            return .aiProviderUnavailable
        case .aiProviderError:
            return .aiAnalysisFailed
        case .serviceUnavailable:
            return .unknownError
        case .operationError:
            return .unknownError
        }
    }
    
    public var userMessage: String {
        return self.errorDescription ?? "Unknown error"
    }
    
    public var context: [String: String] {
        switch self {
        case .ambiguousAppIdentifier(let name, let suggestions):
            return ["identifier": name, "suggestions": suggestions.joined(separator: ", ")]
        case .appNotFound(let name):
            return ["app": name]
        case .elementNotFound(let id):
            return ["element": id]
        case .ambiguousElement(let id):
            return ["element": id]
        case .menuNotFound(let app):
            return ["application": app]
        case .menuItemNotFound(let item):
            return ["item": item]
        case .sessionNotFound(let id):
            return ["session_id": id]
        case .captureFailed(let reason):
            return ["reason": reason]
        case .clickFailed(let reason):
            return ["reason": reason]
        case .typeFailed(let reason):
            return ["reason": reason]
        case .fileIOError(let reason):
            return ["reason": reason]
        case .commandFailed(let reason):
            return ["reason": reason]
        case .timeout(let reason):
            return ["reason": reason]
        case .invalidInput(let message):
            return ["message": message]
        case .encodingError(let message):
            return ["message": message]
        case .aiProviderError(let message):
            return ["message": message]
        case .serviceUnavailable(let message):
            return ["message": message]
        case .operationError(let message):
            return ["message": message]
        default:
            return [:]
        }
    }
    
    /// Error code for structured error responses
    public var errorCode: String {
        return code.rawValue
    }
}

// MARK: - Convenience Factory Methods

extension PeekabooError {
    /// Create a capture failed error
    public static func captureFailed(reason: String) -> PeekabooError {
        .captureFailed(reason)
    }
    
    /// Create an interaction failed error
    public static func interactionFailed(action: String, reason: String) -> PeekabooError {
        .operationError(message: "Failed to perform \(action): \(reason)")
    }
    
    /// Create a timeout error
    public static func timeout(operation: String, duration: TimeInterval) -> PeekabooError {
        .timeout("Operation '\(operation)' timed out after \(Int(duration)) seconds")
    }
    
    /// Create an ambiguous app identifier error
    public static func ambiguousAppIdentifier(_ identifier: String, matches: [String]) -> PeekabooError {
        .ambiguousAppIdentifier(identifier, suggestions: matches)
    }
    
    /// Create an invalid input error
    public static func invalidInput(field: String, reason: String) -> PeekabooError {
        .invalidInput("Invalid \(field): \(reason)")
    }
    
    /// Create an invalid coordinates error
    public static func invalidCoordinates(x: Double, y: Double) -> PeekabooError {
        .invalidCoordinates
    }
}