// LoggingExtensions.swift - Convenience extensions for logging

import Foundation

// MARK: - Convenience Logging Functions

/// Log a debug message
@MainActor
public func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: message,
        file: file,
        function: function,
        line: line
    ))
}

/// Log an info message
@MainActor
public func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .info,
        message: message,
        file: file,
        function: function,
        line: line
    ))
}

/// Log a warning message
@MainActor
public func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .warning,
        message: message,
        file: file,
        function: function,
        line: line
    ))
}

/// Log an error message
@MainActor
public func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .error,
        message: message,
        file: file,
        function: function,
        line: line
    ))
}

/// Log a critical message
@MainActor
public func logCritical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .critical,
        message: message,
        file: file,
        function: function,
        line: line
    ))
}
