//
//  LoggingHelpers.swift
//  AXorcist
//

import Foundation

// MARK: - Logging Utilities

/// Joins log message segments with comma separators for cleaner multi-part messages
public func logSegments(_ parts: String...) -> String {
    parts.joined(separator: ", ")
}

/// Joins log message segments from an array with comma separators
public func logSegments(_ parts: [String]) -> String {
    parts.joined(separator: ", ")
}

/// Formats log message segments with pipe separators (alternative style)
public func formatLogSegments(_ parts: String...) -> String {
    parts.joined(separator: " | ")
}

/// Describes a PID for logging (nil becomes "system")
public func describePid(_ pid: pid_t?) -> String {
    let pidValue = pid.map(String.init) ?? "system"
    return "PID \(pidValue)"
}
