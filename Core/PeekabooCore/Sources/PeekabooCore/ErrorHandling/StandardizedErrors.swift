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

/// Operation failure errors - using PeekabooError for simpler API
public typealias OperationError = PeekabooError

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
        case let peekabooError as PeekabooError:
            return peekabooError
        case let nsError as NSError:
            return standardizeNSError(nsError)
        default:
            return PeekabooError.operationError(message: error.localizedDescription)
        }
    }
    
    private static func standardizeNSError(_ error: NSError) -> StandardizedError {
        // Handle common Cocoa errors
        switch error.domain {
        case NSCocoaErrorDomain:
            if error.code == NSFileNoSuchFileError {
                let path = error.userInfo[NSFilePathErrorKey] as? String ?? "unknown"
                return PeekabooError.fileIOError("File not found: \(path)")
            }
        default:
            break
        }
        
        return PeekabooError.operationError(message: error.localizedDescription)
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