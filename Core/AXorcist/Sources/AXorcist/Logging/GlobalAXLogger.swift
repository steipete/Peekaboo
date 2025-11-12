import Foundation
import Logging
import os // For OSLog specific configurations if ever needed directly.

// Ensure AXLogEntry is Sendable - this might not be strictly necessary if logger is fully synchronous
// and not passing entries across actor boundaries, but good for robustness.
// public struct AXLogEntry: Codable, Identifiable, Sendable { ... }

@MainActor
public class GlobalAXLogger {
    // MARK: Lifecycle

    private init() {
        if self.shouldEnableJSONLogging() {
            self.isJSONLoggingEnabled = true
            fputs(Self.jsonInitializationMessage + "\n", stderr)
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
        guard self.shouldLog(entry) else { return }

        let condensedMessage = self.condensedMessage(for: entry.message)
        if self.shouldSkipDueToDuplicate(message: condensedMessage, entry: entry) { return }

        let processedEntry = entry.withMessage(condensedMessage)
        self.logEntries.append(processedEntry)
        self.emitJSONIfNeeded(processedEntry)
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
                    return """
                    {"error": "Failed to serialize log entry to JSON: \(error.localizedDescription)"}
                    """
                    .trimmingCharacters(in: .whitespacesAndNewlines)
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

    private static let jsonInitializationMessage = """
    {"axorc_log_stream_type": "json_objects",
     "status": "AXGlobalLogger initialized with JSON output to stderr."}
    """

    private func shouldEnableJSONLogging() -> Bool {
        guard let envVar = ProcessInfo.processInfo.environment["AXORC_JSON_LOG_ENABLED"] else { return false }
        return envVar.lowercased() == "true"
    }

    private func shouldLog(_ entry: AXLogEntry) -> Bool {
        guard self.isLoggingEnabled else { return false }
        guard entry.level == .debug else { return true }

        switch self.detailLevel {
        case .verbose:
            return true
        case .normal, .minimal:
            return false
        }
    }

    private func condensedMessage(for message: String) -> String {
        guard message.count > self.maxMessageLength else { return message }
        let prefix = message.prefix(self.maxMessageLength)
        return "\(prefix)… (\(message.count) chars)"
    }

    private func shouldSkipDueToDuplicate(message: String, entry: AXLogEntry) -> Bool {
        if self.lastCondensedMessage == message {
            self.incrementDuplicateCount(entry: entry)
            return true
        }

        self.appendTotalDuplicateSummaryIfNeeded(entry: entry)
        self.lastCondensedMessage = message
        self.duplicateCount = 0
        return false
    }

    private func incrementDuplicateCount(entry: AXLogEntry) {
        self.duplicateCount += 1
        guard self.duplicateCount % self.duplicateSummaryThreshold == 0 else { return }
        let summaryMessage = "⟳ Previous message repeated \(self.duplicateSummaryThreshold) more times"
        self.logEntries.append(self.summaryEntry(message: summaryMessage, sourceEntry: entry))
    }

    private func appendTotalDuplicateSummaryIfNeeded(entry: AXLogEntry) {
        guard self.duplicateCount >= self.duplicateSummaryThreshold, self.lastCondensedMessage != nil else { return }
        let summaryMessage = "⟳ Previous message repeated \(self.duplicateCount) times in total"
        self.logEntries.append(self.summaryEntry(message: summaryMessage, sourceEntry: entry))
    }

    private func summaryEntry(message: String, sourceEntry: AXLogEntry) -> AXLogEntry {
        AXLogEntry(
            level: .debug,
            message: message,
            file: sourceEntry.file,
            function: sourceEntry.function,
            line: sourceEntry.line,
            details: nil
        )
    }

    private func emitJSONIfNeeded(_ entry: AXLogEntry) {
        guard self.isJSONLoggingEnabled else { return }
        do {
            let jsonData = try JSONEncoder().encode(entry)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                fputs(jsonString + "\n", stderr)
            }
        } catch {
            let errorMessage = """
            {"error": "Failed to serialize AXLogEntry to JSON: \(error.localizedDescription)"}
            """
            fputs(errorMessage.trimmingCharacters(in: .whitespacesAndNewlines) + "\n", stderr)
        }
    }
}

// MARK: - Logger Convenience Overloads

extension Logging.Logger {
    @inlinable
    public func debug(_ message: @autoclosure () -> String) {
        self.log(level: .debug, "\(message())")
    }

    @inlinable
    public func info(_ message: @autoclosure () -> String) {
        self.log(level: .info, "\(message())")
    }

    @inlinable
    public func warning(_ message: @autoclosure () -> String) {
        self.log(level: .warning, "\(message())")
    }

    @inlinable
    public func error(_ message: @autoclosure () -> String) {
        self.log(level: .error, "\(message())")
    }
}

private extension AXLogEntry {
    func withMessage(_ message: String) -> AXLogEntry {
        AXLogEntry(
            level: self.level,
            message: message,
            file: self.file,
            function: self.function,
            line: self.line,
            details: self.details
        )
    }
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
        let entry = AXLogEntry(
            level: .info,
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
    return [] // Return empty for now to avoid concurrency issues
}

nonisolated
public func axClearLogs() {
    Task { @MainActor in
        GlobalAXLogger.shared.clearEntries()
    }
}

nonisolated
public func axGetLogsAsStrings(format: AXLogOutputFormat = .text) -> [String] {
    return [] // Return empty for now to avoid concurrency issues
}

// Assuming AXLogEntry and its formattedForTextBasedOutput() method are defined elsewhere
// and compatible with synchronous, main-thread only logging.
