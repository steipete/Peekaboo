import Foundation

// MARK: - Error Formatter

/// Formats errors for consistent presentation across Peekaboo
public struct ErrorFormatter {
    
    /// Format an error for CLI output
    public static func formatForCLI(_ error: Error, verbose: Bool = false) -> String {
        let standardized = ErrorStandardizer.standardize(error)
        
        var output = standardized.userMessage
        
        if let suggestion = standardized.recoverySuggestion {
            output += "\n\nSuggestion: \(suggestion)"
        }
        
        if verbose && !standardized.context.isEmpty {
            output += "\n\nContext:"
            for (key, value) in standardized.context.sorted(by: { $0.key < $1.key }) {
                output += "\n  \(key): \(value)"
            }
        }
        
        return output
    }
    
    /// Format an error for JSON output
    public static func formatForJSON(_ error: Error) -> [String: Any] {
        let standardized = ErrorStandardizer.standardize(error)
        
        var json: [String: Any] = [
            "error_code": standardized.code.rawValue,
            "message": standardized.userMessage,
            "context": standardized.context
        ]
        
        if let suggestion = standardized.recoverySuggestion {
            json["recovery_suggestion"] = suggestion
        }
        
        return json
    }
    
    /// Format an error for logging
    public static func formatForLog(_ error: Error) -> String {
        let standardized = ErrorStandardizer.standardize(error)
        
        var output = "[\(standardized.code.rawValue)] \(standardized.userMessage)"
        
        if !standardized.context.isEmpty {
            let contextStr = standardized.context
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ", ")
            output += " | Context: \(contextStr)"
        }
        
        return output
    }
    
    /// Format multiple errors into a summary
    public static func formatMultipleErrors(_ errors: [Error]) -> String {
        guard !errors.isEmpty else { return "No errors" }
        
        if errors.count == 1 {
            return formatForCLI(errors[0])
        }
        
        var output = "Multiple errors occurred (\(errors.count)):\n"
        
        for (index, error) in errors.enumerated() {
            let standardized = ErrorStandardizer.standardize(error)
            output += "\n\(index + 1). \(standardized.userMessage)"
        }
        
        return output
    }
}

// MARK: - Error Code Formatting

public extension StandardErrorCode {
    /// Human-readable description of the error code
    var description: String {
        switch self {
        case .screenRecordingPermissionDenied:
            return "Screen Recording Permission Denied"
        case .accessibilityPermissionDenied:
            return "Accessibility Permission Denied"
        case .applicationNotFound:
            return "Application Not Found"
        case .windowNotFound:
            return "Window Not Found"
        case .elementNotFound:
            return "UI Element Not Found"
        case .sessionNotFound:
            return "Session Not Found"
        case .fileNotFound:
            return "File Not Found"
        case .menuNotFound:
            return "Menu Not Found"
        case .captureFailed:
            return "Screen Capture Failed"
        case .interactionFailed:
            return "Interaction Failed"
        case .timeout:
            return "Operation Timed Out"
        case .cancelled:
            return "Operation Cancelled"
        case .invalidInput:
            return "Invalid Input"
        case .invalidCoordinates:
            return "Invalid Coordinates"
        case .invalidDisplayIndex:
            return "Invalid Display Index"
        case .invalidWindowIndex:
            return "Invalid Window Index"
        case .ambiguousAppIdentifier:
            return "Ambiguous Application Identifier"
        case .fileIOError:
            return "File I/O Error"
        case .configurationError:
            return "Configuration Error"
        case .unknownError:
            return "Unknown Error"
        case .aiProviderUnavailable:
            return "AI Provider Unavailable"
        case .aiAnalysisFailed:
            return "AI Analysis Failed"
        }
    }
    
    /// Error category for grouping
    var category: String {
        switch self {
        case .screenRecordingPermissionDenied, .accessibilityPermissionDenied:
            return "Permission"
        case .applicationNotFound, .windowNotFound, .elementNotFound, .sessionNotFound, .fileNotFound, .menuNotFound:
            return "Not Found"
        case .captureFailed, .interactionFailed, .timeout, .cancelled:
            return "Operation"
        case .invalidInput, .invalidCoordinates, .invalidDisplayIndex, .invalidWindowIndex, .ambiguousAppIdentifier:
            return "Validation"
        case .fileIOError, .configurationError, .unknownError:
            return "System"
        case .aiProviderUnavailable, .aiAnalysisFailed:
            return "AI"
        }
    }
}