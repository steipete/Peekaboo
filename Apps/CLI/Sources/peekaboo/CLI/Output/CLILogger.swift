import Foundation

/// Log level enumeration for structured logging
public enum LogLevel: Int, Comparable, Sendable {
    case trace = 0 // Most verbose
    case verbose = 1
    case debug = 2
    case info = 3
    case warning = 4
    case error = 5
    case critical = 6 // Most severe

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var name: String {
        switch self {
        case .trace: "TRACE"
        case .verbose: "VERBOSE"
        case .debug: "DEBUG"
        case .info: "INFO"
        case .warning: "WARN"
        case .error: "ERROR"
        case .critical: "CRITICAL"
        }
    }
}

/// Thread-safe logging utility for Peekaboo.
///
/// Provides logging functionality that can switch between stderr output (for normal operation)
/// and buffered collection (for JSON output mode) to avoid interfering with structured output.
final class Logger: @unchecked Sendable {
    static let shared = Logger()
    private var debugLogs: [String] = []
    private var isJsonOutputMode = false
    private var verboseMode = false
    private var minimumLogLevel: LogLevel = .info
    private let queue = DispatchQueue(label: "logger.queue", attributes: .concurrent)
    private let iso8601Formatter: ISO8601DateFormatter

    // Performance tracking
    private var performanceTimers: [String: Date] = [:]

    private init() {
        self.iso8601Formatter = ISO8601DateFormatter()
        self.iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Check environment for log level
        if let envLevel = ProcessInfo.processInfo.environment["PEEKABOO_LOG_LEVEL"]?.lowercased() {
            switch envLevel {
            case "trace": self.minimumLogLevel = .trace
            case "verbose": self.minimumLogLevel = .verbose
            case "debug": self.minimumLogLevel = .debug
            case "info": self.minimumLogLevel = .info
            case "warning", "warn": self.minimumLogLevel = .warning
            case "error": self.minimumLogLevel = .error
            case "critical": self.minimumLogLevel = .critical
            default: break
            }
        }
    }

    func setJsonOutputMode(_ enabled: Bool) {
        self.queue.sync(flags: .barrier) {
            self.isJsonOutputMode = enabled
            // Don't clear logs automatically - let tests manage this explicitly
        }
    }

    func setVerboseMode(_ enabled: Bool) {
        self.queue.sync(flags: .barrier) {
            self.verboseMode = enabled
            if enabled {
                self.minimumLogLevel = .verbose
            }
        }
    }

    var isVerbose: Bool {
        self.queue.sync {
            self.verboseMode
        }
    }

    /// Log a message at a specific level
    private func log(_ level: LogLevel, _ message: String, category: String? = nil, metadata: [String: Any]? = nil) {
        // Convert metadata to a string representation outside the async closure
        let metadataString: String? = metadata.flatMap { dict in
            dict.isEmpty ? nil : dict.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        }

        self.queue.async(flags: .barrier) { [metadataString] in
            guard level >= self.minimumLogLevel || (level == .verbose && self.verboseMode) else { return }

            let timestamp = self.iso8601Formatter.string(from: Date())
            var formattedMessage = "[\(timestamp)] \(level.name): \(message)"

            // Add category if provided
            if let category {
                formattedMessage = "[\(timestamp)] \(level.name) [\(category)]: \(message)"
            }

            // Add metadata if provided
            if let metadataString {
                formattedMessage += " {\(metadataString)}"
            }

            if self.isJsonOutputMode {
                self.debugLogs.append(formattedMessage)
            } else {
                fputs("\(formattedMessage)\n", stderr)
            }
        }
    }

    func verbose(_ message: String, category: String? = nil, metadata: [String: Any]? = nil) {
        self.log(.verbose, message, category: category, metadata: metadata)
    }

    func debug(_ message: String, category: String? = nil, metadata: [String: Any]? = nil) {
        self.log(.debug, message, category: category, metadata: metadata)
    }

    func info(_ message: String, category: String? = nil, metadata: [String: Any]? = nil) {
        self.log(.info, message, category: category, metadata: metadata)
    }

    func warn(_ message: String, category: String? = nil, metadata: [String: Any]? = nil) {
        self.log(.warning, message, category: category, metadata: metadata)
    }

    func error(_ message: String, category: String? = nil, metadata: [String: Any]? = nil) {
        self.log(.error, message, category: category, metadata: metadata)
    }

    // MARK: - Performance Tracking

    /// Start a performance timer
    func startTimer(_ name: String) {
        self.queue.async(flags: .barrier) {
            self.performanceTimers[name] = Date()
            if self.verboseMode {
                let timestamp = self.iso8601Formatter.string(from: Date())
                let message = "[\(timestamp)] VERBOSE [Performance]: Starting timer '\(name)'"
                if self.isJsonOutputMode {
                    self.debugLogs.append(message)
                } else {
                    fputs("\(message)\n", stderr)
                }
            }
        }
    }

    /// Stop a performance timer and log the duration
    func stopTimer(_ name: String, threshold: TimeInterval? = nil) {
        self.queue.async(flags: .barrier) {
            guard let startTime = self.performanceTimers[name] else {
                self.log(.warning, "Timer '\(name)' was not started", category: "Performance")
                return
            }

            let duration = Date().timeIntervalSince(startTime)
            self.performanceTimers.removeValue(forKey: name)

            // Only log if verbose mode or if duration exceeds threshold
            if self.verboseMode || (threshold != nil && duration > threshold!) {
                let durationMs = Int(duration * 1000)
                self.log(
                    .verbose,
                    "Timer '\(name)' completed",
                    category: "Performance",
                    metadata: ["duration_ms": durationMs]
                )
            }
        }
    }

    // MARK: - Operation Tracking

    /// Log the start of an operation
    func operationStart(_ operation: String, metadata: [String: Any]? = nil) {
        var meta = metadata ?? [:]
        meta["operation"] = operation
        self.verbose("Starting operation", category: "Operation", metadata: meta)
        self.startTimer(operation)
    }

    /// Log the completion of an operation
    func operationComplete(_ operation: String, success: Bool = true, metadata: [String: Any]? = nil) {
        var meta = metadata ?? [:]
        meta["operation"] = operation
        meta["success"] = success
        self.verbose("Operation completed", category: "Operation", metadata: meta)
        self.stopTimer(operation)
    }

    func getDebugLogs() -> [String] {
        self.queue.sync {
            self.debugLogs
        }
    }

    func clearDebugLogs() {
        self.queue.sync(flags: .barrier) {
            self.debugLogs.removeAll()
        }
    }

    /// For testing - ensures all pending operations are complete
    func flush() {
        self.queue.sync(flags: .barrier) {
            // This ensures all pending async operations are complete
        }
    }
}
