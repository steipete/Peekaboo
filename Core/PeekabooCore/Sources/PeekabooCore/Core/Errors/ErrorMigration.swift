import Foundation

// MARK: - Error Migration Support

/// Temporary struct to support gradual migration from struct-based errors to PeekabooError
public struct NotFoundError {
    public let code: StandardErrorCode
    public let userMessage: String
    public let context: [String: String]
    
    public init(code: StandardErrorCode, userMessage: String, context: [String: String]) {
        self.code = code
        self.userMessage = userMessage
        self.context = context
    }
    
    // Factory methods that return PeekabooError
    public static func application(_ identifier: String) -> PeekabooError {
        .appNotFound(identifier)
    }
    
    public static func window(app: String, index: Int? = nil) -> PeekabooError {
        .windowNotFound()
    }
    
    public static func element(_ description: String) -> PeekabooError {
        .elementNotFound(description)
    }
    
    public static func session(_ id: String) -> PeekabooError {
        .sessionNotFound(id)
    }
}

// Make NotFoundError throwable by converting to PeekabooError
extension NotFoundError: Error {
    public var asPeekabooError: PeekabooError {
        switch code {
        case .applicationNotFound:
            if let app = context["identifier"] ?? context["app"] {
                return .appNotFound(app)
            }
            return .operationError(message: userMessage)
        case .windowNotFound:
            return .windowNotFound(criteria: nil)
        case .elementNotFound:
            if let element = context["element"] {
                return .elementNotFound(element)
            }
            return .operationError(message: userMessage)
        case .sessionNotFound:
            if let id = context["session_id"] {
                return .sessionNotFound(id)
            }
            return .operationError(message: userMessage)
        case .menuNotFound:
            if let app = context["application"] {
                return .menuNotFound(app)
            }
            return .operationError(message: userMessage)
        default:
            return .operationError(message: userMessage)
        }
    }
}

/// Temporary struct for ValidationError migration
public struct LegacyValidationError {
    public let code: StandardErrorCode
    public let userMessage: String
    public let context: [String: String]
    
    public init(code: StandardErrorCode, userMessage: String, context: [String: String]) {
        self.code = code
        self.userMessage = userMessage
        self.context = context
    }
    
    public static func invalidInput(field: String, reason: String) -> PeekabooError {
        PeekabooError.invalidInput(field: field, reason: reason)
    }
    
    public static func invalidCoordinates(x: Double, y: Double) -> PeekabooError {
        PeekabooError.invalidCoordinates(x: x, y: y)
    }
    
    public static func ambiguousAppIdentifier(_ identifier: String, matches: [String]) -> PeekabooError {
        PeekabooError.ambiguousAppIdentifier(identifier, matches: matches)
    }
}

// Make ValidationError throwable
extension LegacyValidationError: Error {
    public var asPeekabooError: PeekabooError {
        switch code {
        case .invalidInput:
            return .invalidInput(userMessage)
        case .invalidCoordinates:
            return .invalidCoordinates
        case .ambiguousAppIdentifier:
            if let id = context["identifier"], let matches = context["matches"]?.split(separator: ",").map(String.init) {
                return .ambiguousAppIdentifier(id, suggestions: matches)
            }
            return .operationError(message: userMessage)
        default:
            return .operationError(message: userMessage)
        }
    }
}

/// Temporary struct for PermissionError migration
public struct PermissionError {
    public static func screenRecording() -> PeekabooError {
        .permissionDeniedScreenRecording
    }
    
    public static func accessibility() -> PeekabooError {
        .permissionDeniedAccessibility
    }
}

