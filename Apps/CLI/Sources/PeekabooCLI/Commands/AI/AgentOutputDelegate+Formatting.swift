//
//  AgentOutputDelegate+Formatting.swift
//  Peekaboo
//

import Foundation
import PeekabooCore

@available(macOS 14.0, *)
extension AgentOutputDelegate {
    // MARK: - Helper Methods

    func shouldSkipCommunicationOutput(for toolType: ToolType?) -> Bool {
        guard let toolType else { return false }
        return [ToolType.taskCompleted, .needMoreInformation, .needInfo].contains(toolType)
    }

    func printToolCallStart(
        displayName: String,
        args: [String: Any],
        rawArguments: String,
        formatter: any ToolFormatter
    ) {
        let sanitizedName = self.cleanToolPrefix(displayName)
        switch self.outputMode {
        case .minimal:
            print(sanitizedName, terminator: "")

        case .verbose:
            print("\(TerminalColor.blue)\(TerminalColor.bold)\(sanitizedName)\(TerminalColor.reset)")
            if rawArguments.isEmpty || rawArguments == "{}" {
                print("\(TerminalColor.gray)Arguments: (none)\(TerminalColor.reset)")
            } else if let formatted = formatJSON(rawArguments) {
                print("\(TerminalColor.gray)Arguments:\(TerminalColor.reset)")
                print(formatted)
            }

        case .enhanced:
            let startMessage = self.cleanToolPrefix(formatter.formatStarting(arguments: args))
            print(
                "\(TerminalColor.blue)\(TerminalColor.bold)\(startMessage)\(TerminalColor.reset)",
                terminator: ""
            )

        default: // .normal, .compact
            print(
                "\(TerminalColor.blue)\(TerminalColor.bold)\(sanitizedName)\(TerminalColor.reset)",
                terminator: ""
            )
            let summary = formatter.formatCompactSummary(arguments: args)
            if !summary.isEmpty {
                print(" \(TerminalColor.gray)\(summary)\(TerminalColor.reset)", terminator: "")
            }
        }

        fflush(stdout)
    }

    /// Remove leading glyph tokens like "[sh]" from tool narration so agent output reads naturally.
    func cleanToolPrefix(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasPrefix("[") {
            guard let closing = result.firstIndex(of: "]") else { break }
            let next = result.index(after: closing)
            result = String(result[next...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    func successStatusLine(resultSummary: String, durationString: String) -> String {
        if resultSummary.isEmpty {
            return " \(durationString)"
        }

        let summarySegment = [
            " ",
            TerminalColor.bold,
            resultSummary,
            TerminalColor.reset
        ].joined()

        return "\(summarySegment)\(durationString)"
    }

    func failureStatusLine(message: String, durationString: String) -> String {
        let statusPrefix = [
            " ",
            TerminalColor.red,
            AgentDisplayTokens.Status.failure
        ].joined()
        return [
            statusPrefix,
            " ",
            message,
            TerminalColor.reset,
            durationString
        ].joined()
    }

    func completionSummaryLine(totalElapsed: TimeInterval, toolsText: String, tokenInfo: String) -> String {
        let summaryPrefix = "\(TerminalColor.gray)Task completed in \(formatDuration(totalElapsed))"
        return [
            "\n",
            summaryPrefix,
            " with \(toolsText)\(tokenInfo)",
            TerminalColor.reset
        ].joined()
    }

    func durationString(for toolName: String) -> String {
        if let startTime = self.toolStartTimes[toolName] {
            self.toolStartTimes.removeValue(forKey: toolName)
            let elapsed = Date().timeIntervalSince(startTime)
            return " \(TerminalColor.gray)(\(formatDuration(elapsed)))\(TerminalColor.reset)"
        }
        return ""
    }

    func printInvalidResult(rawResult: String, durationString: String) {
        if self.outputMode == .verbose {
            let failureBadge = [
                " ",
                TerminalColor.red,
                AgentDisplayTokens.Status.failure
            ].joined()
            let invalidJsonMessage = [
                failureBadge,
                " Invalid JSON result",
                TerminalColor.reset,
                durationString
            ].joined()
            print(invalidJsonMessage)

            let rawResultLine = [
                TerminalColor.gray,
                "Raw result: \(rawResult.prefix(200))",
                TerminalColor.reset
            ].joined()
            print(rawResultLine)
        } else {
            let failureBadge = [
                " ",
                TerminalColor.red,
                AgentDisplayTokens.Status.failure
            ].joined()
            let invalidResultMessage = [
                failureBadge,
                " Invalid result",
                TerminalColor.reset,
                durationString
            ].joined()
            print(invalidResultMessage)
        }
    }

    func toolFormatter(for name: String) -> (any ToolFormatter, ToolType?) {
        if let type = ToolType(rawValue: name) {
            return (ToolFormatterRegistry.shared.formatter(for: type), type)
        }
        return (UnknownToolFormatter(toolName: name), nil)
    }

    /// Produce a compact diff summary between previous and new arguments for the same tool name.
    func diffSummary(for toolName: String, newArgs: [String: Any]) -> String? {
        guard let previous = self.lastToolArguments[toolName] else { return nil }

        var changes: [String] = []
        for (key, newValue) in newArgs {
            guard let prevValue = previous[key] else {
                changes.append("+\(key)")
                continue
            }
            if !self.valuesEqual(prevValue, newValue) {
                let rendered = self.renderValue(newValue)
                changes.append("\(key): \(rendered)")
            }
            if changes.count >= 3 { break }
        }

        if changes.isEmpty {
            return nil
        }

        return changes.joined(separator: ", ")
    }

    func valuesEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        switch (lhs, rhs) {
        case let (l as String, r as String): l == r
        case let (l as Int, r as Int): l == r
        case let (l as Double, r as Double): l == r
        case let (l as Bool, r as Bool): l == r
        default:
            false
        }
    }

    func dictionariesEqual(_ lhs: [String: Any], _ rhs: [String: Any]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (key, lval) in lhs {
            guard let rval = rhs[key], self.valuesEqual(lval, rval) else { return false }
        }
        return true
    }

    func renderValue(_ value: Any) -> String {
        switch value {
        case let str as String:
            let max = 40
            if str.count > max {
                let idx = str.index(str.startIndex, offsetBy: max)
                return String(str[..<idx]) + "…"
            }
            return str
        case let num as Int: return String(num)
        case let num as Double: return String(format: "%.3f", num)
        case let bool as Bool: return bool ? "true" : "false"
        default:
            if let data = try? JSONSerialization.data(withJSONObject: ["v": value], options: []),
               let text = String(data: data, encoding: .utf8) {
                return text.replacingOccurrences(of: "{\"v\":", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "}"))
            }
            return "…"
        }
    }

    func resultSummary(
        for name: String,
        json: [String: Any],
        formatter: any ToolFormatter,
        summary: ToolEventSummary?
    ) -> String {
        if let summaryText = summary?.shortDescription(toolName: name) {
            return summaryText
        }

        var fallback = formatter.formatResultSummary(result: json)

        guard name == "app" else {
            return self.cleanToolPrefix(fallback)
        }

        if let meta = json["meta"] as? [String: Any],
           let appName = meta["app_name"] as? String,
           let content = json["content"] as? [[String: Any]],
           let firstContent = content.first,
           let text = firstContent["text"] as? String {
            switch text {
            case let value where value.contains("Launched"):
                fallback = "→ \(appName) launched"
            case let value where value.contains("Quit"):
                fallback = "→ \(appName) quit"
            case let value where value.contains("Focused") || value.contains("Switched"):
                fallback = "→ \(appName) focused"
            case let value where value.contains("Hidden"):
                fallback = "→ \(appName) hidden"
            case let value where value.contains("Unhidden"):
                fallback = "→ \(appName) shown"
            default:
                break
            }
        }

        return self.cleanToolPrefix(fallback)
    }

    func handleSuccess(
        resultSummary: String,
        durationString: String,
        result: String,
        json: [String: Any]
    ) {
        switch self.outputMode {
        case .minimal:
            let prefix = resultSummary.isEmpty ? "" : " \(resultSummary)"
            print("\(prefix)\(durationString)")

        case .verbose:
            print(" \(durationString)")
            if let formatted = formatJSON(result) {
                print("\(TerminalColor.gray)Result:\(TerminalColor.reset)")
                print(formatted)
            }

        default:
            print(self.successStatusLine(resultSummary: resultSummary, durationString: durationString))
            self.printResultDetails(from: json)
        }
    }

    func handleFailure(message: String, durationString: String, json: [String: Any], tool: String) {
        if self.outputMode == .minimal {
            print(" FAILED\(durationString)")
        } else {
            print(self.failureStatusLine(message: message, durationString: durationString))
        }
        self.displayEnhancedError(tool: tool, json: json)
    }

    func handleCommunicationToolComplete(name: String, toolType: ToolType) {
        if self.outputMode == .verbose {
            let toolName = toolType.rawValue
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
            print("\n\(AgentDisplayTokens.Status.success) \(toolName) completed")
        }
    }

    func displayEnhancedError(tool: String, json: [String: Any]) {
        guard self.outputMode != .minimal && self.outputMode != .quiet else { return }

        if let error = json["error"] as? String {
            print("   \(TerminalColor.gray)Error: \(error)\(TerminalColor.reset)")
        }

        if let suggestion = json["suggestion"] as? String {
            print("   \(TerminalColor.yellow)💡 Suggestion: \(suggestion)\(TerminalColor.reset)")
        }

        if self.outputMode == .verbose,
           let details = json["details"] as? [String: Any],
           let formatted = try? JSONSerialization.data(withJSONObject: details, options: .prettyPrinted),
           let detailsStr = String(data: formatted, encoding: .utf8) {
            print("   \(TerminalColor.gray)Details:\(TerminalColor.reset)")
            print(detailsStr)
        }
    }

    func printResultDetails(from json: [String: Any]) {
        guard self.outputMode != .minimal && self.outputMode != .quiet else { return }
        guard let detail = self.primaryResultMessage(from: json) else { return }
        let snippet = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = self.cleanToolPrefix(snippet)
        guard !sanitized.isEmpty else { return }
        print("\n   \(TerminalColor.gray)\(sanitized.prefix(240))\(TerminalColor.reset)")
    }

    func primaryResultMessage(from json: [String: Any]) -> String? {
        if let message = json["message"] as? String, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }

        if let content = json["content"] as? [[String: Any]] {
            for item in content {
                if let text = item["text"] as? String,
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return text
                }
            }
        }

        if let meta = json["meta"] as? [String: Any],
           let message = meta["message"] as? String,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }

        return nil
    }
}

// MARK: - Supporting Types

/// Formatter for unknown tools.
private class UnknownToolFormatter: BaseToolFormatter {
    private let toolName: String

    override nonisolated init(toolType: ToolType) {
        fatalError("Use init(toolName:)")
    }

    init(toolName: String) {
        self.toolName = toolName
        // Use wait as the inert placeholder so unknown tools still get a formatter base.
        super.init(toolType: .wait)
    }

    override nonisolated func formatStarting(arguments: [String: Any]) -> String {
        "\(self.toolName.replacingOccurrences(of: "_", with: " ").capitalized)"
    }

    override nonisolated func formatCompleted(result: [String: Any], duration: TimeInterval) -> String {
        "→ completed"
    }

    override nonisolated func formatError(error: String, result: [String: Any]) -> String {
        "\(AgentDisplayTokens.Status.failure) \(error)"
    }

    override nonisolated func formatCompactSummary(arguments: [String: Any]) -> String {
        ""
    }

    override nonisolated func formatResultSummary(result: [String: Any]) -> String {
        ""
    }

    override nonisolated func formatForTitle(arguments: [String: Any]) -> String {
        self.toolName
    }
}
