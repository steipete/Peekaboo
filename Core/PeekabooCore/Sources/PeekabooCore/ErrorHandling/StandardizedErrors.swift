import Foundation

// MARK: - Error Code Protocol

/// Standard error codes used across Peekaboo
public enum StandardErrorCode: String, Sendable {
    // Permission errors
    case screenRecordingPermissionDenied = "PERMISSION_DENIED_SCREEN_RECORDING"
    case accessibilityPermissionDenied = "PERMISSION_DENIED_ACCESSIBILITY"
    
    // Not found errors
    case applicationNotFound = "APP_NOT_FOUND"
    case windowNotFound = "WINDOW_NOT_FOUND"
    case elementNotFound = "ELEMENT_NOT_FOUND"
    case sessionNotFound = "SESSION_NOT_FOUND"
    case fileNotFound = "FILE_NOT_FOUND"
    case menuNotFound = "MENU_NOT_FOUND"
    
    // Operation errors
    case captureFailed = "CAPTURE_FAILED"
    case interactionFailed = "INTERACTION_FAILED"
    case timeout = "TIMEOUT"
    case cancelled = "CANCELLED"
    
    // Input errors
    case invalidInput = "INVALID_INPUT"
    case invalidCoordinates = "INVALID_COORDINATES"
    case invalidDisplayIndex = "INVALID_DISPLAY_INDEX"
    case invalidWindowIndex = "INVALID_WINDOW_INDEX"
    case ambiguousAppIdentifier = "AMBIGUOUS_APP_IDENTIFIER"
    
    // System errors
    case fileIOError = "FILE_IO_ERROR"
    case configurationError = "CONFIGURATION_ERROR"
    case unknownError = "UNKNOWN_ERROR"
    
    // AI errors
    case aiProviderUnavailable = "AI_PROVIDER_UNAVAILABLE"
    case aiAnalysisFailed = "AI_ANALYSIS_FAILED"
}

// MARK: - Base Error Protocol

/// Base protocol for standardized Peekaboo errors
public protocol StandardizedError: LocalizedError, Sendable {
    var code: StandardErrorCode { get }
    var userMessage: String { get }
    var context: [String: String] { get }
}

extension StandardizedError {
    public var errorDescription: String? {
        userMessage
    }
}

// MARK: - Error Context Builder

/// Helper for building error context
public struct ErrorContext {
    private var items: [String: String] = [:]
    
    public init() {}
    
    public mutating func add(_ key: String, _ value: String) {
        items[key] = value
    }
    
    public mutating func add(_ key: String, _ value: Any) {
        items[key] = String(describing: value)
    }
    
    public func build() -> [String: String] {
        items
    }
}

// MARK: - Common Error Types

/// Permission-related errors
public struct PermissionError: StandardizedError {
    public let code: StandardErrorCode
    public let userMessage: String
    public let context: [String: String]
    
    public static func screenRecording() -> PermissionError {
        PermissionError(
            code: .screenRecordingPermissionDenied,
            userMessage: "Screen Recording permission is required. Please grant permission in System Settings > Privacy & Security > Screen Recording.",
            context: ["permission": "screen_recording"]
        )
    }
    
    public static func accessibility() -> PermissionError {
        PermissionError(
            code: .accessibilityPermissionDenied,
            userMessage: "Accessibility permission is required for this operation. Please grant permission in System Settings > Privacy & Security > Accessibility.",
            context: ["permission": "accessibility"]
        )
    }
}

/// Resource not found errors
public struct NotFoundError: StandardizedError {
    public let code: StandardErrorCode
    public let userMessage: String
    public let context: [String: String]
    
    public static func application(_ identifier: String) -> NotFoundError {
        NotFoundError(
            code: .applicationNotFound,
            userMessage: "Application '\(identifier)' not found or not running.",
            context: ["identifier": identifier]
        )
    }
    
    public static func window(app: String, index: Int? = nil) -> NotFoundError {
        let message = if let index = index {
            "Window at index \(index) not found for application '\(app)'."
        } else {
            "No windows found for application '\(app)'."
        }
        
        var context = ErrorContext()
        context.add("app", app)
        if let index = index {
            context.add("window_index", index)
        }
        
        return NotFoundError(
            code: .windowNotFound,
            userMessage: message,
            context: context.build()
        )
    }
    
    public static func element(_ description: String) -> NotFoundError {
        NotFoundError(
            code: .elementNotFound,
            userMessage: "UI element '\(description)' not found.",
            context: ["element": description]
        )
    }
    
    public static func session(_ id: String) -> NotFoundError {
        NotFoundError(
            code: .sessionNotFound,
            userMessage: "Session '\(id)' not found or expired.",
            context: ["session_id": id]
        )
    }
}

/// Operation failure errors
public struct OperationError: StandardizedError {
    public let code: StandardErrorCode
    public let userMessage: String
    public let context: [String: String]
    
    public static func captureFailed(reason: String) -> OperationError {
        OperationError(
            code: .captureFailed,
            userMessage: "Failed to capture screen: \(reason)",
            context: ["reason": reason]
        )
    }
    
    public static func interactionFailed(action: String, reason: String) -> OperationError {
        OperationError(
            code: .interactionFailed,
            userMessage: "Failed to perform \(action): \(reason)",
            context: ["action": action, "reason": reason]
        )
    }
    
    public static func timeout(operation: String, duration: TimeInterval) -> OperationError {
        OperationError(
            code: .timeout,
            userMessage: "Operation '\(operation)' timed out after \(Int(duration)) seconds.",
            context: ["operation": operation, "timeout_seconds": String(duration)]
        )
    }
}

/// Input validation errors
public struct ValidationError: StandardizedError {
    public let code: StandardErrorCode
    public let userMessage: String
    public let context: [String: String]
    
    public static func invalidInput(field: String, reason: String) -> ValidationError {
        ValidationError(
            code: .invalidInput,
            userMessage: "Invalid \(field): \(reason)",
            context: ["field": field, "reason": reason]
        )
    }
    
    public static func invalidCoordinates(x: Double, y: Double) -> ValidationError {
        ValidationError(
            code: .invalidCoordinates,
            userMessage: "Invalid coordinates (\(x), \(y)). Coordinates must be within screen bounds.",
            context: ["x": String(x), "y": String(y)]
        )
    }
    
    public static func ambiguousAppIdentifier(_ identifier: String, matches: [String]) -> ValidationError {
        ValidationError(
            code: .ambiguousAppIdentifier,
            userMessage: "Multiple applications match '\(identifier)': \(matches.joined(separator: ", "))",
            context: ["identifier": identifier, "matches": matches.joined(separator: ",")]
        )
    }
}

// MARK: - Error Conversion

/// Convert various error types to standardized errors
public struct ErrorStandardizer {
    public static func standardize(_ error: Error) -> StandardizedError {
        // If already standardized, return as-is
        if let standardized = error as? StandardizedError {
            return standardized
        }
        
        // Convert known error types
        switch error {
        case let nsError as NSError:
            return standardizeNSError(nsError)
        default:
            return OperationError(
                code: .unknownError,
                userMessage: error.localizedDescription,
                context: ["type": String(describing: type(of: error))]
            )
        }
    }
    
    private static func standardizeNSError(_ error: NSError) -> StandardizedError {
        // Handle common Cocoa errors
        switch error.domain {
        case NSCocoaErrorDomain:
            if error.code == NSFileNoSuchFileError {
                return NotFoundError(
                    code: .fileNotFound,
                    userMessage: "File not found: \(error.localizedDescription)",
                    context: ["path": error.userInfo[NSFilePathErrorKey] as? String ?? "unknown"]
                )
            }
        default:
            break
        }
        
        return OperationError(
            code: .unknownError,
            userMessage: error.localizedDescription,
            context: [
                "domain": error.domain,
                "code": String(error.code)
            ]
        )
    }
}

// MARK: - Error Recovery Suggestions

public extension StandardizedError {
    var recoverySuggestion: String? {
        switch code {
        case .screenRecordingPermissionDenied:
            return "Grant Screen Recording permission in System Settings"
        case .accessibilityPermissionDenied:
            return "Grant Accessibility permission in System Settings"
        case .applicationNotFound:
            return "Ensure the application is installed and running"
        case .windowNotFound:
            return "Check that the application has open windows"
        case .timeout:
            return "Try the operation again or increase the timeout"
        case .ambiguousAppIdentifier:
            return "Use a more specific application name or bundle ID"
        default:
            return nil
        }
    }
}