import Foundation

/// Helper class for managing JSON output and debug logs
public class JSONOutput {
    private var debugLogs: [String] = []

    func addDebugLog(_ message: String) {
        self.debugLogs.append(message)
    }

    func getDebugLogs() -> [String] {
        self.debugLogs
    }

    func clearDebugLogs() {
        self.debugLogs.removeAll()
    }
}

/// Standard JSON response format for Peekaboo API output.
///
/// This is now deprecated - use CodableJSONResponse with specific types instead
struct JSONResponse: Codable {
    let success: Bool
    let messages: [String]?
    let debug_logs: [String]
    let error: ErrorInfo?

    init(
        success: Bool,
        messages: [String]? = nil,
        debugLogs: [String] = [],
        error: ErrorInfo? = nil)
    {
        self.success = success
        self.messages = messages
        self.debug_logs = debugLogs
        self.error = error
    }
}

/// Error information structure for JSON responses.
///
/// Contains error details including message, standardized error code,
/// and optional additional context.
struct ErrorInfo: Codable {
    let message: String
    let code: String
    let details: String?

    init(message: String, code: ErrorCode, details: String? = nil) {
        self.message = message
        self.code = code.rawValue
        self.details = details
    }
}

/// Standardized error codes for Peekaboo operations.
///
/// Provides consistent error identification across the API for proper
/// error handling by clients and automation tools.
enum ErrorCode: String, Codable {
    case PERMISSION_ERROR_SCREEN_RECORDING
    case PERMISSION_ERROR_ACCESSIBILITY
    case PERMISSION_DENIED
    case APP_NOT_FOUND
    case AMBIGUOUS_APP_IDENTIFIER
    case WINDOW_NOT_FOUND
    case CAPTURE_FAILED
    case FILE_IO_ERROR
    case INVALID_ARGUMENT
    case SIPS_ERROR
    case INTERNAL_SWIFT_ERROR
    case UNKNOWN_ERROR
    case WINDOW_MANIPULATION_ERROR
    case VALIDATION_ERROR
    case MENU_BAR_NOT_FOUND
    case MENU_ITEM_NOT_FOUND
    case DOCK_NOT_FOUND
    case NO_ACTIVE_DIALOG
    case ELEMENT_NOT_FOUND
    case SESSION_NOT_FOUND
    case APPLICATION_NOT_FOUND
    case NO_POINT_SPECIFIED
    case INVALID_COORDINATES
    case DOCK_LIST_NOT_FOUND
    case DOCK_ITEM_NOT_FOUND
    case POSITION_NOT_FOUND
    case SCRIPT_ERROR
    case MISSING_API_KEY
    case AGENT_ERROR
    case INTERACTION_FAILED
    case TIMEOUT
    case INVALID_INPUT
}

func outputJSON(_ response: JSONResponse) {
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(response)
        if let jsonString = String(data: data, encoding: .utf8) {
            print(jsonString)
        }
    } catch {
        Logger.shared.error("Failed to encode JSON response: \(error)")
        // Fallback to simple error JSON
        print("""
        {
          "success": false,
          "error": {
            "message": "Failed to encode JSON response",
            "code": "INTERNAL_SWIFT_ERROR"
          },
          "debug_logs": []
        }
        """)
    }
}

func outputSuccessCodable(data: some Codable, messages: [String]? = nil) {
    let debugLogs = Logger.shared.getDebugLogs()
    let response = CodableJSONResponse(
        success: true, data: data, messages: messages, debug_logs: debugLogs)
    outputJSONCodable(response)
}

func outputJSONCodable(_ response: some Codable) {
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(response)
        if let jsonString = String(data: data, encoding: .utf8) {
            print(jsonString)
        }
    } catch {
        Logger.shared.error("Failed to encode JSON response: \(error)")
        // Fallback to simple error JSON
        print("""
        {
          "success": false,
          "error": {
            "message": "Failed to encode JSON response",
            "code": "INTERNAL_SWIFT_ERROR"
          },
          "debug_logs": []
        }
        """)
    }
}

/// Generic JSON response wrapper for strongly-typed data.
///
/// Provides type-safe JSON responses when the data payload type
/// is known at compile time.
struct CodableJSONResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
    let messages: [String]?
    let debug_logs: [String]
}

func outputError(message: String, code: ErrorCode, details: String? = nil) {
    let error = ErrorInfo(message: message, code: code, details: details)
    let debugLogs = Logger.shared.getDebugLogs()
    outputJSON(JSONResponse(success: false, messages: nil, debugLogs: debugLogs, error: error))
}

/// Empty type for successful responses with no data
struct Empty: Codable {}

extension Empty: ExpressibleByNilLiteral {
    init(nilLiteral: ()) {
        self.init()
    }
}