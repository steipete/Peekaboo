import Foundation
import os // For OSLog specific configurations if ever needed directly.

// Ensure AXLogEntry is Sendable - this might not be strictly necessary if logger is fully synchronous
// and not passing entries across actor boundaries, but good for robustness.
// public struct AXLogEntry: Codable, Identifiable, Sendable { ... }

@MainActor
public class GlobalAXLogger: Sendable {
    // MARK: Lifecycle

    private init() {
        if let envVar = ProcessInfo.processInfo.environment["AXORC_JSON_LOG_ENABLED"], envVar.lowercased() == "true" {
            isJSONLoggingEnabled = true
            fputs(
                "{\\\"axorc_log_stream_type\\\": \\\"json_objects\\\", \\\"status\\\": \\\"AXGlobalLogger initialized with JSON output to stderr.\"}\n",
                stderr
            )
        }
    }

    // MARK: Public

    public static let shared = GlobalAXLogger()

    // No DispatchQueue needed if all calls are on the main thread.
    // Callers must ensure main-thread execution for all logger interactions.

    public var isJSONLoggingEnabled: Bool = false // Direct access, assuming main-thread safety
    // Instance properties for logging control, moved from extension
    public var isLoggingEnabled: Bool = false
    public var detailLevel: AXLogDetailLevel = .normal

    // MARK: - Logging Core

    // Assumes this method is always called on the main thread.
    public func log(_ entry: AXLogEntry) {
        guard self.isLoggingEnabled else { return }
        // Use fully qualified enum cases
        if entry.level == .debug, self.detailLevel != AXLogDetailLevel.verbose {
            if self.detailLevel == AXLogDetailLevel.minimal { return }
            if self.detailLevel == AXLogDetailLevel.normal, entry.level == .debug { return }
        }

        let condensedMessage: String = {
            if entry.message.count > maxMessageLength {
                let prefix = entry.message.prefix(maxMessageLength)
                return "\(prefix)… (\(entry.message.count) chars)"
            } else {
                return entry.message
            }
        }()

        if let last = self.lastCondensedMessage, last == condensedMessage {
            self.duplicateCount += 1
            if self.duplicateCount % self.duplicateSummaryThreshold != 0 {
                return
            } else {
                let summaryEntry = AXLogEntry(
                    level: .debug,
                    message: "⟳ Previous message repeated \(self.duplicateSummaryThreshold) more times",
                    file: entry.file,
                    function: entry.function,
                    line: entry.line,
                    details: nil
                )
                self.logEntries.append(summaryEntry)
            }
        } else {
            if self.duplicateCount >= self.duplicateSummaryThreshold, self.lastCondensedMessage != nil {
                let summaryEntry = AXLogEntry(
                    level: .debug,
                    message: "⟳ Previous message repeated \(self.duplicateCount) times in total",
                    file: entry.file,
                    function: entry.function,
                    line: entry.line,
                    details: nil
                )
                self.logEntries.append(summaryEntry)
            }
            self.lastCondensedMessage = condensedMessage
            self.duplicateCount = 0
        }

        let processedEntry = AXLogEntry(
            level: entry.level,
            message: condensedMessage,
            file: entry.file,
            function: entry.function,
            line: entry.line,
            details: entry.details
        )
        self.logEntries.append(processedEntry)

        if self.isJSONLoggingEnabled {
            do {
                let jsonData = try JSONEncoder().encode(processedEntry)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    fputs(jsonString + "\n", stderr)
                }
            } catch {
                fputs(
                    "{\\\"error\\\": \\\"Failed to serialize AXLogEntry to JSON: \(error.localizedDescription)\\\"}\n",
                    stderr
                )
            }
        }
    }

    // MARK: - Log Retrieval

    // Assumes these methods are always called on the main thread.
    public func getEntries() -> [AXLogEntry] {
        self.logEntries
    }

    public func clearEntries() {
        self.logEntries.removeAll()
        // Optionally log the clear action itself
        // let clearEntry = AXLogEntry(level: .info, message: "GlobalAXLogger log entries cleared.")
        // self.log(clearEntry)
    }

    public func getLogsAsStrings(format: AXLogOutputFormat = .text) -> [String] {
        let currentEntries = self.getEntries()

        switch format {
        case .json:
            return currentEntries.compactMap { entry in
                do {
                    let jsonData = try JSONEncoder().encode(entry)
                    return String(data: jsonData, encoding: .utf8)
                } catch {
                    return "{\\\"error\\\": \\\"Failed to serialize log entry to JSON: \\(error.localizedDescription)\\\"}"
                }
            }
        case .text:
            return currentEntries.map { $0.formattedForTextLog() }
        }
    }

    // MARK: Private

    private var logEntries: [AXLogEntry] = []
    // For duplicate suppression
    private var lastCondensedMessage: String?
    private var duplicateCount: Int = 0
    private let duplicateSummaryThreshold: Int = 5
    // Maximum characters to keep in a log message before truncating (for readability)
    private let maxMessageLength: Int = 300
}

// MARK: - Global Logging Functions (Convenience Wrappers)

// These are synchronous and assume GlobalAXLogger.shared.log is safe to call directly (i.e., from main thread).

nonisolated
public func axDebugLog(
    _ message: String,
    details: [String: AnyCodable]? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task { @MainActor in
        let entry = AXLogEntry(
            level: .debug,
            message: message,
            file: file,
            function: function,
            line: line,
            details: details
        )
        GlobalAXLogger.shared.log(entry)
    }
}

nonisolated
public func axInfoLog(
    _ message: String,
    details: [String: AnyCodable]? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task { @MainActor in
        let entry = AXLogEntry(level: .info, message: message, file: file, function: function, line: line, details: details)
        GlobalAXLogger.shared.log(entry)
    }
}

nonisolated
public func axWarningLog(
    _ message: String,
    details: [String: AnyCodable]? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task { @MainActor in
        let entry = AXLogEntry(
            level: .warning,
            message: message,
            file: file,
            function: function,
            line: line,
            details: details
        )
        GlobalAXLogger.shared.log(entry)
    }
}

nonisolated
public func axErrorLog(
    _ message: String,
    details: [String: AnyCodable]? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task { @MainActor in
        let entry = AXLogEntry(
            level: .error,
            message: message,
            file: file,
            function: function,
            line: line,
            details: details
        )
        GlobalAXLogger.shared.log(entry)
    }
}

nonisolated
public func axFatalLog(
    _ message: String,
    details: [String: AnyCodable]? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    Task { @MainActor in
        let entry = AXLogEntry(
            level: .critical,
            message: message,
            file: file,
            function: function,
            line: line,
            details: details
        )
        GlobalAXLogger.shared.log(entry)
    }
}

// MARK: - Global Log Access Functions

nonisolated
public func axGetLogEntries() -> [AXLogEntry] {
    return []  // Return empty for now to avoid concurrency issues
}

nonisolated
public func axClearLogs() {
    Task { @MainActor in
        GlobalAXLogger.shared.clearEntries()
    }
}

nonisolated
public func axGetLogsAsStrings(format: AXLogOutputFormat = .text) -> [String] {
    return []  // Return empty for now to avoid concurrency issues
}

// Assuming AXLogEntry and its formattedForTextBasedOutput() method are defined elsewhere
// and compatible with synchronous, main-thread only logging.
