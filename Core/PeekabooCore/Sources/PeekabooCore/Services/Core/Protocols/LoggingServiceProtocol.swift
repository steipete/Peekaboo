import Foundation
import os

/// Log levels for the unified logging system
public enum LogLevel: Int, Comparable {
    case trace = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Structured log entry with metadata
public struct LogEntry {
    public let level: LogLevel
    public let message: String
    public let category: String
    public let metadata: [String: Any]
    public let timestamp: Date
    public let correlationId: String?

    public init(
        level: LogLevel,
        message: String,
        category: String,
        metadata: [String: Any] = [:],
        timestamp: Date = Date(),
        correlationId: String? = nil)
    {
        self.level = level
        self.message = message
        self.category = category
        self.metadata = metadata
        self.timestamp = timestamp
        self.correlationId = correlationId
    }
}

/// Protocol for the unified logging service
public protocol LoggingServiceProtocol: Sendable {
    /// Current minimum log level
    var minimumLogLevel: LogLevel { get set }

    /// Log a message with structured metadata
    func log(_ entry: LogEntry)

    /// Convenience methods for different log levels
    func trace(_ message: String, category: String, metadata: [String: Any], correlationId: String?)
    func debug(_ message: String, category: String, metadata: [String: Any], correlationId: String?)
    func info(_ message: String, category: String, metadata: [String: Any], correlationId: String?)
    func warning(_ message: String, category: String, metadata: [String: Any], correlationId: String?)
    func error(_ message: String, category: String, metadata: [String: Any], correlationId: String?)
    func critical(_ message: String, category: String, metadata: [String: Any], correlationId: String?)

    /// Start a performance measurement
    func startPerformanceMeasurement(operation: String, correlationId: String?) -> String

    /// End a performance measurement and log the duration
    func endPerformanceMeasurement(measurementId: String, metadata: [String: Any])

    /// Create a child logger with a specific category
    func logger(category: String) -> CategoryLogger
}

/// Convenience extensions with default parameters
extension LoggingServiceProtocol {
    public func trace(
        _ message: String,
        category: String,
        metadata: [String: Any] = [:],
        correlationId: String? = nil)
    {
        log(LogEntry(
            level: .trace,
            message: message,
            category: category,
            metadata: metadata,
            correlationId: correlationId))
    }

    public func debug(
        _ message: String,
        category: String,
        metadata: [String: Any] = [:],
        correlationId: String? = nil)
    {
        log(LogEntry(
            level: .debug,
            message: message,
            category: category,
            metadata: metadata,
            correlationId: correlationId))
    }

    public func info(
        _ message: String,
        category: String,
        metadata: [String: Any] = [:],
        correlationId: String? = nil)
    {
        log(LogEntry(
            level: .info,
            message: message,
            category: category,
            metadata: metadata,
            correlationId: correlationId))
    }

    public func warning(
        _ message: String,
        category: String,
        metadata: [String: Any] = [:],
        correlationId: String? = nil)
    {
        log(LogEntry(
            level: .warning,
            message: message,
            category: category,
            metadata: metadata,
            correlationId: correlationId))
    }

    public func error(
        _ message: String,
        category: String,
        metadata: [String: Any] = [:],
        correlationId: String? = nil)
    {
        log(LogEntry(
            level: .error,
            message: message,
            category: category,
            metadata: metadata,
            correlationId: correlationId))
    }

    public func critical(
        _ message: String,
        category: String,
        metadata: [String: Any] = [:],
        correlationId: String? = nil)
    {
        log(LogEntry(
            level: .critical,
            message: message,
            category: category,
            metadata: metadata,
            correlationId: correlationId))
    }
}

/// Category-specific logger for cleaner API
public struct CategoryLogger: Sendable {
    private let service: any LoggingServiceProtocol
    private let category: String
    private let defaultCorrelationId: String?

    init(service: any LoggingServiceProtocol, category: String, defaultCorrelationId: String? = nil) {
        self.service = service
        self.category = category
        self.defaultCorrelationId = defaultCorrelationId
    }

    public func trace(_ message: String, metadata: [String: Any] = [:], correlationId: String? = nil) {
        self.service.trace(
            message,
            category: self.category,
            metadata: metadata,
            correlationId: correlationId ?? self.defaultCorrelationId)
    }

    public func debug(_ message: String, metadata: [String: Any] = [:], correlationId: String? = nil) {
        self.service.debug(
            message,
            category: self.category,
            metadata: metadata,
            correlationId: correlationId ?? self.defaultCorrelationId)
    }

    public func info(_ message: String, metadata: [String: Any] = [:], correlationId: String? = nil) {
        self.service.info(
            message,
            category: self.category,
            metadata: metadata,
            correlationId: correlationId ?? self.defaultCorrelationId)
    }

    public func warning(_ message: String, metadata: [String: Any] = [:], correlationId: String? = nil) {
        self.service.warning(
            message,
            category: self.category,
            metadata: metadata,
            correlationId: correlationId ?? self.defaultCorrelationId)
    }

    public func error(_ message: String, metadata: [String: Any] = [:], correlationId: String? = nil) {
        self.service.error(
            message,
            category: self.category,
            metadata: metadata,
            correlationId: correlationId ?? self.defaultCorrelationId)
    }

    public func critical(_ message: String, metadata: [String: Any] = [:], correlationId: String? = nil) {
        self.service.critical(
            message,
            category: self.category,
            metadata: metadata,
            correlationId: correlationId ?? self.defaultCorrelationId)
    }

    public func startPerformanceMeasurement(operation: String, correlationId: String? = nil) -> String {
        self.service.startPerformanceMeasurement(
            operation: operation,
            correlationId: correlationId ?? self.defaultCorrelationId)
    }

    public func endPerformanceMeasurement(measurementId: String, metadata: [String: Any] = [:]) {
        self.service.endPerformanceMeasurement(measurementId: measurementId, metadata: metadata)
    }

    /// Create a child logger with the same category but different correlation ID
    public func withCorrelationId(_ correlationId: String) -> CategoryLogger {
        // Create a child logger with the same category but different correlation ID
        CategoryLogger(service: self.service, category: self.category, defaultCorrelationId: correlationId)
    }
}
