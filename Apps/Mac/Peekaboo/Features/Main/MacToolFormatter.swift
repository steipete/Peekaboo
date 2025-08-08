//
//  MacToolFormatter.swift
//  Peekaboo
//

import Foundation
import PeekabooCore

/// Adapts the CLI tool formatter system for use in the Mac app
/// Now delegates to shared FormattingUtilities from PeekabooCore
@MainActor
struct MacToolFormatter {
    
    // MARK: - Keyboard Shortcut Formatting
    
    /// Format keyboard shortcuts with proper symbols
    /// Delegates to shared FormattingUtilities from PeekabooCore
    static func formatKeyboardShortcut(_ keys: String) -> String {
        FormattingUtilities.formatKeyboardShortcut(keys)
    }
    
    // MARK: - Duration Formatting
    
    /// Format duration with clock symbol
    static func formatDuration(_ duration: TimeInterval?) -> String {
        guard let duration else { return "" }
        return " ⌖ " + PeekabooCore.formatDuration(duration)
    }
    
    // MARK: - Tool Summary Formatting
    
    /// Get compact summary of what the tool will do based on arguments
    static func compactToolSummary(toolName: String, arguments: String) -> String {
        // Parse arguments to dictionary
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return toolName
        }
        
        // Try to get formatter from the registry
        if let toolType = ToolType(rawValue: toolName) {
            let formatter = ToolFormatterRegistry.shared.formatter(for: toolType)
            let summary = formatter.formatCompactSummary(arguments: args)
            
            // If we got a meaningful summary, use it
            if !summary.isEmpty {
                return summary
            }
            
            // Otherwise fall back to display name
            return formatter.displayName
        }
        
        // Unknown tool - use capitalized name
        return toolName.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    /// Get result summary for completed tool execution
    static func toolResultSummary(toolName: String, result: String?) -> String? {
        guard let result = result,
              let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        
        // Try to get formatter from the registry
        if let toolType = ToolType(rawValue: toolName) {
            let formatter = ToolFormatterRegistry.shared.formatter(for: toolType)
            let summary = formatter.formatResultSummary(result: json)
            
            // Return summary if meaningful
            if !summary.isEmpty {
                return summary
            }
        }
        
        // Fallback - check for common result patterns
        if let success = json["success"] as? Bool {
            return success ? "Completed" : "Failed"
        }
        
        return nil
    }
    
    // MARK: - Tool Icon
    
    /// Get icon for tool name
    static func iconForTool(_ toolName: String) -> String {
        if let toolType = ToolType(rawValue: toolName) {
            return toolType.icon
        }
        
        // Fallback for unknown tools
        return "⚙️"
    }
    
    // MARK: - Tool Display Name
    
    /// Get human-readable display name for tool
    static func displayNameForTool(_ toolName: String) -> String {
        if let toolType = ToolType(rawValue: toolName) {
            return toolType.displayName
        }
        
        // Fallback for unknown tools
        return toolName.replacingOccurrences(of: "_", with: " ").capitalized
    }
}