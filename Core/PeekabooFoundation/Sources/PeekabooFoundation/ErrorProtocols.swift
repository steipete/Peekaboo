import Foundation

// MARK: - Error Categories

/// Categories for organizing errors by their nature
public enum ErrorCategory: String, Sendable {
    case permissions
    case automation
    case configuration
    case ai
    case io
    case network
    case session
    case validation
    case unknown
}

// MARK: - Error Protocol

/// Enhanced error protocol with categorization and recovery suggestions
public protocol PeekabooErrorProtocol: LocalizedError, Sendable {
    /// The category this error belongs to
    nonisolated var category: ErrorCategory { get }

    /// Whether this error can potentially be recovered from
    nonisolated var isRecoverable: Bool { get }

    /// Suggested action for the user to resolve this error
    nonisolated var suggestedAction: String? { get }

    /// Additional context about the error
    nonisolated var context: [String: String] { get }

    /// Unique error code for structured responses
    nonisolated var errorCode: String { get }
}

// MARK: - Default Implementations

extension PeekabooErrorProtocol {
    public nonisolated var isRecoverable: Bool {
        switch category {
        case .permissions, .configuration, .network:
            true
        case .automation, .ai, .io, .session, .validation, .unknown:
            false
        }
    }

    public nonisolated var suggestedAction: String? {
        switch category {
        case .permissions:
            "Please grant the required permissions in System Settings"
        case .configuration:
            "Please check your configuration settings"
        case .network:
            "Please check your internet connection and try again"
        case .ai:
            "Please verify your API key and model settings"
        default:
            nil
        }
    }

    public nonisolated var context: [String: String] {
        [:]
    }
}

// MARK: - Error Recovery Protocol

/// Protocol for errors that support recovery attempts
public protocol RecoverableError: PeekabooErrorProtocol {
    /// Attempt to recover from this error
    func attemptRecovery() async throws

    /// Maximum number of recovery attempts
    nonisolated var maxRecoveryAttempts: Int { get }
}

extension RecoverableError {
    public nonisolated var maxRecoveryAttempts: Int { 3 }
}

// MARK: - Network Error Protocol

/// Specialized protocol for network-related errors
public protocol NetworkError: PeekabooErrorProtocol {
    /// The URL that failed
    nonisolated var failedURL: URL? { get }

    /// HTTP status code if applicable
    nonisolated var statusCode: Int? { get }

    /// Whether this is a temporary failure
    nonisolated var isTemporary: Bool { get }
}

extension NetworkError {
    public nonisolated var category: ErrorCategory { .network }

    public nonisolated var isTemporary: Bool {
        guard let code = statusCode else { return true }
        return code >= 500 || code == 408 || code == 429
    }

    public nonisolated var isRecoverable: Bool {
        self.isTemporary
    }
}

// MARK: - Validation Error Protocol

/// Protocol for validation-related errors
public protocol ValidationError: PeekabooErrorProtocol {
    /// The field that failed validation
    nonisolated var fieldName: String { get }

    /// The validation rule that failed
    nonisolated var failedRule: String { get }

    /// The invalid value if available
    nonisolated var invalidValue: String? { get }
}

extension ValidationError {
    public nonisolated var category: ErrorCategory { .validation }
    public nonisolated var isRecoverable: Bool { false }
}

// MARK: - Error Context Builder

/// Builder for creating error context dictionaries
public struct ErrorContextBuilder {
    private var context: [String: String] = [:]

    public init() {}

    public func with(_ key: String, _ value: String?) -> ErrorContextBuilder {
        var builder = self
        if let value {
            builder.context[key] = value
        }
        return builder
    }

    public func with(_ key: String, _ value: Any?) -> ErrorContextBuilder {
        var builder = self
        if let value {
            builder.context[key] = String(describing: value)
        }
        return builder
    }

    public func build() -> [String: String] {
        self.context
    }
}

// MARK: - Error Recovery Manager

/// Manages error recovery attempts
public actor ErrorRecoveryManager {
    private var recoveryAttempts: [String: Int] = [:]

    public init() {}

    /// Attempt to recover from an error
    public func attemptRecovery(for error: some RecoverableError) async throws {
        let errorKey = "\(type(of: error))_\(error.errorCode)"
        let attempts = self.recoveryAttempts[errorKey] ?? 0

        guard attempts < error.maxRecoveryAttempts else {
            throw ErrorRecoveryFailure(
                originalError: error,
                attempts: attempts,
                reason: "Maximum recovery attempts exceeded")
        }

        self.recoveryAttempts[errorKey] = attempts + 1

        do {
            try await error.attemptRecovery()
            // Reset attempts on success
            self.recoveryAttempts[errorKey] = 0
        } catch {
            // Preserve attempt count for next try
            throw error
        }
    }

    /// Reset recovery attempts for a specific error
    public func resetAttempts(for error: some PeekabooErrorProtocol) {
        let errorKey = "\(type(of: error))_\(error.errorCode)"
        self.recoveryAttempts.removeValue(forKey: errorKey)
    }

    /// Reset all recovery attempts
    public func resetAllAttempts() {
        self.recoveryAttempts.removeAll()
    }
}

// MARK: - Error Recovery Failure

/// Error thrown when recovery attempts fail
public nonisolated struct ErrorRecoveryFailure: PeekabooErrorProtocol {
    public let originalError: any RecoverableError
    public let attempts: Int
    public let reason: String

    public var errorDescription: String? {
        "Failed to recover from \(self.originalError.localizedDescription) after " +
            "\(self.attempts) attempts: \(self.reason)"
    }

    public var category: ErrorCategory {
        self.originalError.category
    }

    public var isRecoverable: Bool {
        false
    }

    public var suggestedAction: String? {
        self.originalError.suggestedAction
    }

    public var context: [String: String] {
        var ctx = self.originalError.context
        ctx["recovery_attempts"] = String(self.attempts)
        ctx["recovery_failure_reason"] = self.reason
        return ctx
    }

    public var errorCode: String {
        "recovery_failed_\(self.originalError.errorCode)"
    }
}
