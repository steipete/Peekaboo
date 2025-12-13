import Algorithms
import Foundation
import PeekabooFoundation

// MARK: - Error Formatter

/// Formats errors for consistent presentation across Peekaboo
public enum ErrorFormatter {
    /// Format an error for CLI output
    public static func formatForCLI(_ error: any Error, verbose: Bool = false) -> String {
        // Format an error for CLI output
        let standardized = ErrorStandardizer.standardize(error)

        var output = standardized.userMessage

        if let suggestion = standardized.recoverySuggestion {
            output += "\n\nSuggestion: \(suggestion)"
        }

        if verbose, !standardized.context.isEmpty {
            output += "\n\nContext:"
            for (key, value) in standardized.context.sorted(by: { $0.key < $1.key }) {
                output += "\n  \(key): \(value)"
            }
        }

        return output
    }

    /// Format an error for JSON output
    public static func formatForJSON(_ error: any Error) -> [String: Any] {
        // Format an error for JSON output
        let standardized = ErrorStandardizer.standardize(error)

        var json: [String: Any] = [
            "error_code": standardized.code.rawValue,
            "message": standardized.userMessage,
            "context": standardized.context,
        ]

        if let suggestion = standardized.recoverySuggestion {
            json["recovery_suggestion"] = suggestion
        }

        return json
    }

    /// Format an error for logging
    public static func formatForLog(_ error: any Error) -> String {
        // Format an error for logging
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
    public static func formatMultipleErrors(_ errors: [any Error]) -> String {
        // Format multiple errors into a summary
        guard !errors.isEmpty else { return "No errors" }

        if errors.count == 1 {
            return self.formatForCLI(errors[0])
        }

        var output = "Multiple errors occurred (\(errors.count)):\n"

        for (index, error) in errors.indexed() {
            let standardized = ErrorStandardizer.standardize(error)
            output += "\n\(index + 1). \(standardized.userMessage)"
        }

        return output
    }
}

// MARK: - Error Code Formatting

extension StandardErrorCode {
    /// Human-readable description of the error code
    public var description: String {
        switch self {
        case .screenRecordingPermissionDenied:
            "Screen Recording Permission Denied"
        case .accessibilityPermissionDenied:
            "Accessibility Permission Denied"
        case .applicationNotFound:
            "Application Not Found"
        case .windowNotFound:
            "Window Not Found"
        case .elementNotFound:
            "UI Element Not Found"
        case .sessionNotFound:
            "Session Not Found"
        case .fileNotFound:
            "File Not Found"
        case .menuNotFound:
            "Menu Not Found"
        case .captureFailed:
            "Screen Capture Failed"
        case .interactionFailed:
            "Interaction Failed"
        case .timeout:
            "Operation Timed Out"
        case .cancelled:
            "Operation Cancelled"
        case .invalidInput:
            "Invalid Input"
        case .invalidCoordinates:
            "Invalid Coordinates"
        case .invalidDisplayIndex:
            "Invalid Display Index"
        case .invalidWindowIndex:
            "Invalid Window Index"
        case .ambiguousAppIdentifier:
            "Ambiguous Application Identifier"
        case .fileIOError:
            "File I/O Error"
        case .configurationError:
            "Configuration Error"
        case .unknownError:
            "Unknown Error"
        case .aiProviderUnavailable:
            "AI Provider Unavailable"
        case .aiAnalysisFailed:
            "AI Analysis Failed"
        }
    }

    /// Error category for grouping
    public var category: String {
        switch self {
        case .screenRecordingPermissionDenied, .accessibilityPermissionDenied:
            "Permission"
        case .applicationNotFound, .windowNotFound, .elementNotFound, .sessionNotFound, .fileNotFound, .menuNotFound:
            "Not Found"
        case .captureFailed, .interactionFailed, .timeout, .cancelled:
            "Operation"
        case .invalidInput, .invalidCoordinates, .invalidDisplayIndex, .invalidWindowIndex, .ambiguousAppIdentifier:
            "Validation"
        case .fileIOError, .configurationError, .unknownError:
            "System"
        case .aiProviderUnavailable, .aiAnalysisFailed:
            "AI"
        }
    }
}
