//
//  ToolFormatterBridge.swift
//  Peekaboo
//

import Foundation
import PeekabooCore

/// Bridge to connect the CLI formatter system to the Mac app
@MainActor
class ToolFormatterBridge {
    static let shared = ToolFormatterBridge()

    private init() {}

    /// Format tool call for display in the Mac app
    func formatToolCall(name: String, arguments: String, result: String? = nil) -> String {
        // Parse tool type
        guard let toolType = ToolType(rawValue: name) else {
            return self.formatUnknownTool(name: name, arguments: arguments, result: result)
        }

        // Get formatter from registry
        let formatter = ToolFormatterRegistry.shared.formatter(for: toolType)

        // Parse arguments
        let args = self.parseArguments(arguments)

        if let result {
            // Format completed tool call
            let resultDict = self.parseArguments(result)
            let success = (resultDict["success"] as? Bool) ?? true
            let summaryText = ToolEventSummary.from(resultJSON: resultDict)?
                .shortDescription(toolName: name) ?? formatter.formatResultSummary(result: resultDict)

            if success {
                if !summaryText.isEmpty {
                    return "\(AgentDisplayTokens.Status.success) \(toolType.displayName): \(summaryText)"
                }
                return "\(AgentDisplayTokens.Status.success) \(toolType.displayName) completed"
            } else {
                let error = (resultDict["error"] as? String) ?? "Failed"
                return "\(AgentDisplayTokens.Status.failure) \(toolType.displayName): \(error)"
            }
        } else {
            // Format tool call in progress
            let summary = formatter.formatCompactSummary(arguments: args)
            if !summary.isEmpty {
                return "\(AgentDisplayTokens.Status.running) \(toolType.displayName): \(summary)"
            } else {
                return "\(AgentDisplayTokens.Status.running) \(toolType.displayName)"
            }
        }
    }

    /// Format tool arguments for detailed view
    func formatArguments(name: String, arguments: String) -> String {
        guard let toolType = ToolType(rawValue: name) else {
            return arguments
        }

        let formatter = ToolFormatterRegistry.shared.formatter(for: toolType)
        let args = self.parseArguments(arguments)

        let summary = formatter.formatCompactSummary(arguments: args)
        if !summary.isEmpty {
            return summary
        }

        // Fall back to formatted JSON
        return self.formatJSON(arguments)
    }

    /// Format tool result for detailed view
    func formatResult(name: String, result: String) -> String {
        guard let toolType = ToolType(rawValue: name) else {
            return result
        }

        let formatter = ToolFormatterRegistry.shared.formatter(for: toolType)
        let resultDict = self.parseArguments(result)
        if let summary = ToolEventSummary.from(resultJSON: resultDict)?.shortDescription(toolName: name),
           !summary.isEmpty
        {
            return summary
        }

        let summary = formatter.formatResultSummary(result: resultDict)
        if !summary.isEmpty {
            return summary
        }

        // Fall back to formatted JSON
        return self.formatJSON(result)
    }

    /// Get icon for tool
    func toolIcon(for name: String) -> String {
        AgentDisplayTokens.icon(for: name)
    }

    /// Get display name for tool
    func toolDisplayName(for name: String) -> String {
        if let toolType = ToolType(rawValue: name) {
            return toolType.displayName
        }

        // Format unknown tool name
        return name.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map(\.capitalized)
            .joined(separator: " ")
    }

    // MARK: - Private Helpers

    private func parseArguments(_ arguments: String) -> [String: Any] {
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        return args
    }

    private func formatJSON(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
              let result = String(data: formatted, encoding: .utf8)
        else {
            return json
        }
        return result
    }

    private func formatUnknownTool(name: String, arguments: String, result: String?) -> String {
        let displayName = self.toolDisplayName(for: name)

        if let result {
            let resultDict = self.parseArguments(result)
            let success = (resultDict["success"] as? Bool) ?? true
            let summaryText = ToolEventSummary.from(resultJSON: resultDict)?.shortDescription(toolName: name)

            if success {
                if let summaryText, !summaryText.isEmpty {
                    return "\(AgentDisplayTokens.Status.success) \(displayName): \(summaryText)"
                }
                return "\(AgentDisplayTokens.Status.success) \(displayName) completed"
            } else {
                let error = (resultDict["error"] as? String) ?? "Failed"
                return "\(AgentDisplayTokens.Status.failure) \(displayName): \(error)"
            }
        } else {
            return "\(AgentDisplayTokens.Status.running) \(displayName)"
        }
    }
}

// MARK: - ToolType Extension for Mac App

extension ToolType {
    /// Icon to use in Mac app UI
    var icon: String {
        AgentDisplayTokens.icon(for: self.rawValue)
    }
}
