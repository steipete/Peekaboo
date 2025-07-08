import Foundation

/// CLI-specific logger that integrates with the unified logging system and JSON output
public final class CLILogger {
    private var jsonOutput: JSONOutput?
    private var minimumLogLevel: LogLevel

    /// Log entries collected for JSON output
    private var logEntries: [LogEntry] = []

    public init(jsonOutput: JSONOutput? = nil, minimumLogLevel: LogLevel = .info) {
        self.jsonOutput = jsonOutput
        self.minimumLogLevel = minimumLogLevel

        // Set log level from environment
        if let envLevel = ProcessInfo.processInfo.environment["PEEKABOO_LOG_LEVEL"]?.lowercased() {
            switch envLevel {
            case "trace": self.minimumLogLevel = .trace
            case "debug": self.minimumLogLevel = .debug
            case "info": self.minimumLogLevel = .info
            case "warning", "warn": self.minimumLogLevel = .warning
            case "error": self.minimumLogLevel = .error
            case "critical": self.minimumLogLevel = .critical
            default: break
            }
        }
    }

    /// Log a message
    public func log(_ level: LogLevel, _ message: String, category: String = "CLI", metadata: [String: Any] = [:]) {
        guard level >= self.minimumLogLevel else { return }

        let entry = LogEntry(
            level: level,
            message: message,
            category: category,
            metadata: metadata,
            timestamp: Date())

        if let jsonOutput {
            // In JSON mode, collect logs
            self.logEntries.append(entry)
            jsonOutput.addDebugLog(self.formatLogEntry(entry))
        } else {
            // In normal mode, print to stderr
            fputs("\(self.formatLogEntry(entry))\n", stderr)
        }
    }

    /// Format a log entry for output
    private func formatLogEntry(_ entry: LogEntry) -> String {
        let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
        let levelString = self.levelToString(entry.level)
        var message = "[\(timestamp)] [\(levelString)] [\(entry.category)] \(entry.message)"

        if !entry.metadata.isEmpty {
            let metadataString = entry.metadata
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
            message += " | \(metadataString)"
        }

        if let correlationId = entry.correlationId {
            message = "[\(correlationId)] \(message)"
        }

        return message
    }

    private func levelToString(_ level: LogLevel) -> String {
        switch level {
        case .trace: "TRACE"
        case .verbose: "VERBOSE"
        case .debug: "DEBUG"
        case .info: "INFO"
        case .warning: "WARN"
        case .error: "ERROR"
        case .critical: "CRITICAL"
        }
    }

    // Convenience methods
    public func trace(_ message: String, category: String = "CLI", metadata: [String: Any] = [:]) {
        self.log(.trace, message, category: category, metadata: metadata)
    }

    public func verbose(_ message: String, category: String = "CLI", metadata: [String: Any] = [:]) {
        self.log(.verbose, message, category: category, metadata: metadata)
    }

    public func debug(_ message: String, category: String = "CLI", metadata: [String: Any] = [:]) {
        self.log(.debug, message, category: category, metadata: metadata)
    }

    public func info(_ message: String, category: String = "CLI", metadata: [String: Any] = [:]) {
        self.log(.info, message, category: category, metadata: metadata)
    }

    public func warning(_ message: String, category: String = "CLI", metadata: [String: Any] = [:]) {
        self.log(.warning, message, category: category, metadata: metadata)
    }

    public func error(_ message: String, category: String = "CLI", metadata: [String: Any] = [:]) {
        self.log(.error, message, category: category, metadata: metadata)
    }

    public func critical(_ message: String, category: String = "CLI", metadata: [String: Any] = [:]) {
        self.log(.critical, message, category: category, metadata: metadata)
    }
}

// LogLevel enum is defined in Logger.swift to avoid conflicts

/// Log entry structure (simplified version of PeekabooCore's)
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
