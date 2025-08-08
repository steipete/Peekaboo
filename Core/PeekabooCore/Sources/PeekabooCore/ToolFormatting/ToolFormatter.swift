//
//  ToolFormatter.swift
//  PeekabooCore
//

import Foundation

/// Protocol for formatting tool execution information
public protocol ToolFormatter {
    /// The tool type this formatter handles
    var toolType: ToolType { get }
    
    /// The display name for this tool
    var displayName: String { get }
    
    /// Format the tool execution start message
    func formatStarting(arguments: [String: Any]) -> String
    
    /// Format the tool completion message
    func formatCompleted(result: [String: Any], duration: TimeInterval) -> String
    
    /// Format an error message
    func formatError(error: String, result: [String: Any]) -> String
    
    /// Format a compact summary for the tool arguments (used in concise mode)
    func formatCompactSummary(arguments: [String: Any]) -> String
    
    /// Format the result summary (shown after the checkmark)
    func formatResultSummary(result: [String: Any]) -> String
    
    /// Format for terminal title
    func formatForTitle(arguments: [String: Any]) -> String
}

/// Base implementation of ToolFormatter with common functionality
open class BaseToolFormatter: ToolFormatter {
    public let toolType: ToolType
    
    public init(toolType: ToolType) {
        self.toolType = toolType
    }
    
    /// The icon for this tool
    public var icon: String {
        toolType.icon
    }
    
    /// The display name for this tool
    public var displayName: String {
        toolType.displayName
    }
    
    // MARK: - Default Implementations
    
    open func formatStarting(arguments: [String: Any]) -> String {
        let summary = formatCompactSummary(arguments: arguments)
        if !summary.isEmpty {
            return "\(displayName): \(summary)"
        }
        return displayName
    }
    
    open func formatCompleted(result: [String: Any], duration: TimeInterval) -> String {
        let summary = formatResultSummary(result: result)
        if !summary.isEmpty {
            return summary
        }
        return "→ completed"
    }
    
    open func formatError(error: String, result: [String: Any]) -> String {
        "✗ \(error)"
    }
    
    open func formatCompactSummary(arguments: [String: Any]) -> String {
        // Default: no summary
        return ""
    }
    
    open func formatResultSummary(result: [String: Any]) -> String {
        // Default: check for common patterns
        if let count = ToolResultExtractor.int("count", from: result) {
            return "→ \(count) items"
        }
        return ""
    }
    
    open func formatForTitle(arguments: [String: Any]) -> String {
        formatCompactSummary(arguments: arguments)
    }
    
    // MARK: - Helper Methods
    
    /// Format duration in a human-readable way
    func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 0.001 {
            return String(format: "%.0fµs", seconds * 1_000_000)
        } else if seconds < 1.0 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60.0 {
            return String(format: "%.1fs", seconds)
        } else {
            let minutes = Int(seconds / 60)
            let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
            return String(format: "%dmin %ds", minutes, remainingSeconds)
        }
    }
    
    /// Format keyboard shortcuts with proper symbols
    func formatKeyboardShortcut(_ keys: String) -> String {
        keys.replacingOccurrences(of: "cmd", with: "⌘")
            .replacingOccurrences(of: "command", with: "⌘")
            .replacingOccurrences(of: "shift", with: "⇧")
            .replacingOccurrences(of: "option", with: "⌥")
            .replacingOccurrences(of: "opt", with: "⌥")
            .replacingOccurrences(of: "alt", with: "⌥")
            .replacingOccurrences(of: "control", with: "⌃")
            .replacingOccurrences(of: "ctrl", with: "⌃")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "+", with: "")
    }
    
    /// Truncate text if too long
    func truncate(_ text: String, maxLength: Int = 30) -> String {
        if text.count > maxLength {
            return String(text.prefix(maxLength)) + "..."
        }
        return text
    }
}