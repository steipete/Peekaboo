import Foundation
import PeekabooCore

/// Formats tool executions to match CLI's compact output format
/// This is a compatibility layer that delegates to the new modular formatter system
@MainActor
struct ToolFormatter {
    /// Format keyboard shortcuts with proper symbols
    /// Uses the shared FormattingUtilities from PeekabooCore
    static func formatKeyboardShortcut(_ keys: String) -> String {
        FormattingUtilities.formatKeyboardShortcut(keys)
    }

    /// Format duration with clock symbol
    /// Uses the shared FormattingUtilities from PeekabooCore
    static func formatDuration(_ duration: TimeInterval?) -> String {
        guard let duration else { return "" }
        return " ⌖ " + FormattingUtilities.formatDetailedDuration(duration)
    }
    
    /// Format file sizes using shared utilities
    static func formatFileSize(_ bytes: Int) -> String {
        FormattingUtilities.formatFileSize(bytes)
    }
    
    /// Truncate text using shared utilities
    static func truncate(_ text: String, maxLength: Int = 50) -> String {
        FormattingUtilities.truncate(text, maxLength: maxLength)
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