import Foundation
import PeekabooCore

/// Formats tool executions to match CLI's compact output format
/// This is a compatibility layer that delegates to the new modular formatter system
@MainActor
struct ToolFormatter {
    /// Format keyboard shortcuts with proper symbols
    static func formatKeyboardShortcut(_ keys: String) -> String {
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

    /// Format duration with clock symbol
    static func formatDuration(_ duration: TimeInterval?) -> String {
        guard let duration else { return "" }
        return " ⌖ " + PeekabooCore.formatDuration(duration)
    }

    /// Get compact summary of what the tool will do based on arguments
    /// Delegates to the new modular formatter system
    static func compactToolSummary(toolName: String, arguments: String) -> String {
        // Use the new registry-based system
        return MacToolFormatterRegistry.shared.formatSummary(toolName: toolName, arguments: arguments)
    }
    
    /// Get result summary for completed tool execution
    /// Delegates to the new modular formatter system
    static func toolResultSummary(toolName: String, result: String?) -> String? {
        // Use the new registry-based system
        return MacToolFormatterRegistry.shared.formatResult(toolName: toolName, result: result)
    }
}