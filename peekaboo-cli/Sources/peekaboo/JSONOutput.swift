import Foundation

struct JSONResponse: Codable {
    let success: Bool
    let data: AnyCodable?
    let messages: [String]?
    let debug_logs: [String]
    let error: ErrorInfo?

    init(success: Bool, data: Any? = nil, messages: [String]? = nil, error: ErrorInfo? = nil) {
        self.success = success
        self.data = data.map(AnyCodable.init)
        self.messages = messages
        debug_logs = Logger.shared.getDebugLogs()
        self.error = error
    }
}

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

enum ErrorCode: String {
    case PERMISSION_DENIED_SCREEN_RECORDING
    case PERMISSION_DENIED_ACCESSIBILITY
    case APP_NOT_FOUND
    case AMBIGUOUS_APP_IDENTIFIER
    case WINDOW_NOT_FOUND
    case CAPTURE_FAILED
    case FILE_IO_ERROR
    case INVALID_ARGUMENT
    case SIPS_ERROR
    case INTERNAL_SWIFT_ERROR
}

// Helper for encoding arbitrary data as JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let codable = value as? Codable {
            // Handle Codable types by encoding them directly as JSON
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(AnyEncodable(codable))
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
            try container.encode(AnyCodable(jsonObject))
        } else {
            switch value {
            case let bool as Bool:
                try container.encode(bool)
            case let int as Int:
                try container.encode(int)
            case let double as Double:
                try container.encode(double)
            case let string as String:
                try container.encode(string)
            case let array as [Any]:
                try container.encode(array.map(AnyCodable.init))
            case let dict as [String: Any]:
                try container.encode(dict.mapValues(AnyCodable.init))
            default:
                // Try to encode as a string representation
                try container.encode(String(describing: value))
            }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode value")
            )
        }
    }
}

// Helper for encoding any Codable type
private struct AnyEncodable: Encodable {
    let encodable: Encodable

    init(_ encodable: Encodable) {
        self.encodable = encodable
    }

    func encode(to encoder: Encoder) throws {
        try encodable.encode(to: encoder)
    }
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

func outputSuccess(data: Any? = nil, messages: [String]? = nil) {
    // Special handling for Codable types
    if let codableData = data as? Codable {
        outputSuccessCodable(data: codableData, messages: messages)
    } else {
        outputJSON(JSONResponse(success: true, data: data, messages: messages))
    }
}

func outputSuccessCodable(data: some Codable, messages: [String]? = nil) {
    let response = CodableJSONResponse(
        success: true, data: data, messages: messages, debug_logs: Logger.shared.getDebugLogs()
    )
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

struct CodableJSONResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
    let messages: [String]?
    let debug_logs: [String]
}

func outputError(message: String, code: ErrorCode, details: String? = nil) {
    let error = ErrorInfo(message: message, code: code, details: details)
    outputJSON(JSONResponse(success: false, error: error))
}
