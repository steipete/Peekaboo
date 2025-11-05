//
//  MacToolFormatterRegistry.swift
//  Peekaboo
//

import Foundation

/// Registry that manages all tool formatters for the Mac app
@MainActor
final class MacToolFormatterRegistry {
    static let shared = MacToolFormatterRegistry()

    private let formatters: [MacToolFormatterProtocol]
    private let toolToFormatterMap: [String: MacToolFormatterProtocol]

    private init() {
        // Initialize all formatters
        let allFormatters: [MacToolFormatterProtocol] = [
            VisionToolFormatter(),
            UIAutomationToolFormatter(),
            ApplicationToolFormatter(),
            SystemToolFormatter(),
            ElementToolFormatter(),
            MenuToolFormatter(),
        ]

        self.formatters = allFormatters

        // Build tool name to formatter mapping
        var map: [String: MacToolFormatterProtocol] = [:]
        for formatter in allFormatters {
            for tool in formatter.handledTools {
                map[tool] = formatter
            }
        }
        self.toolToFormatterMap = map
    }

    /// Get the formatter for a specific tool
    func formatter(for toolName: String) -> MacToolFormatterProtocol? {
        self.toolToFormatterMap[toolName]
    }

    /// Format tool execution summary
    func formatSummary(toolName: String, arguments: String) -> String {
        // Parse arguments
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return toolName.replacingOccurrences(of: "_", with: " ").capitalized
        }

        // Try to get formatter
        if let formatter = formatter(for: toolName),
           let summary = formatter.formatSummary(toolName: toolName, arguments: args)
        {
            return summary
        }

        // Fallback to generic formatting
        return toolName.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Format tool result summary
    func formatResult(toolName: String, result: String?) -> String? {
        guard let result,
              let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        // Try to get formatter
        if let formatter = formatter(for: toolName) {
            return formatter.formatResult(toolName: toolName, result: json)
        }

        // Fallback - check for common result patterns
        if let success = json["success"] as? Bool {
            return success ? "Completed" : "Failed"
        }

        return nil
    }
}
