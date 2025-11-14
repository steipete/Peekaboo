//
//  AgentOutputDelegate.swift
//  Peekaboo
//

import Foundation
import PeekabooCore
import Spinner
import Tachikoma

/// Handles agent output formatting and display for different output modes
@available(macOS 14.0, *)
final class AgentOutputDelegate: PeekabooCore.AgentEventDelegate {
    // MARK: - Properties

    private let outputMode: OutputMode
    private let jsonOutput: Bool
    private let task: String?

    // Tool tracking
    private var currentTool: String?
    private var toolStartTimes: [String: Date] = [:]
    private var toolCallCount = 0
    private var totalTokens = 0

    // Animation and UI
    private var spinner: Spinner?
    private var hasReceivedContent = false
    private var isThinking = false
    private var hasShownFinalSummary = false
    private let startTime = Date()

    // MARK: - Initialization

    init(outputMode: OutputMode, jsonOutput: Bool, task: String?) {
        self.outputMode = outputMode
        self.jsonOutput = jsonOutput
        self.task = task
    }
}

@available(macOS 14.0, *)
extension AgentOutputDelegate {
    // MARK: - AgentEventDelegate

    func agentDidEmitEvent(_ event: PeekabooCore.AgentEvent) {
        guard !self.jsonOutput else { return }

        switch event {
        case let .started(task):
            self.handleStarted(task)

        case let .toolCallStarted(name, arguments):
            self.handleToolCallStarted(name: name, arguments: arguments)

        case let .toolCallCompleted(name, result):
            self.handleToolCallCompleted(name: name, result: result)

        case let .assistantMessage(content):
            self.handleAssistantMessage(content)

        case let .thinkingMessage(content):
            self.handleThinkingMessage(content)

        case let .error(message):
            self.handleError(message)

        case let .completed(summary, usage):
            self.handleCompleted(summary: summary, usage: usage)
        }
    }

    // MARK: - Event Handlers

    private func handleStarted(_ task: String) {
        guard self.outputMode != .quiet else { return }

        if self.outputMode == .verbose {
            print("\n🚀 Starting agent task: \(task)")
        } else if self.outputMode == .enhanced || self.outputMode == .compact {
            // Start spinner animation (fallback color)
            self.spinner = Spinner(.dots, "Thinking...", color: .default)
            self.spinner?.start()
        } else if self.outputMode == .minimal {
            print("Starting: \(task)")
        }
    }

    private func handleToolCallStarted(name: String, arguments: String) {
        self.currentTool = name
        self.toolStartTimes[name] = Date()
        self.toolCallCount += 1

        let args = parseArguments(arguments)
        let (formatter, toolType) = self.toolFormatter(for: name)

        var displayName = toolType?.displayName ?? name.replacingOccurrences(of: "_", with: " ").capitalized
        if name == "app", let action = args["action"] as? String {
            let appName = (args["name"] as? String) ?? (args["bundleId"] as? String) ?? ""
            displayName = "App \(action.capitalized)\(appName.isEmpty ? "" : ": \(appName)")"
        }

        let titleSummary = formatter.formatForTitle(arguments: args)
        updateTerminalTitle("\(displayName): \(titleSummary) - \(self.task?.prefix(30) ?? "")")

        guard self.outputMode != .quiet else { return }

        self.spinner?.stop()
        self.spinner = nil
        self.isThinking = false

        guard !self.shouldSkipCommunicationOutput(for: toolType) else { return }

        if self.hasReceivedContent {
            print()
            self.hasReceivedContent = false
        }

        self.printToolCallStart(
            displayName: displayName,
            args: args,
            rawArguments: arguments,
            formatter: formatter
        )
    }

    private func handleToolCallCompleted(name: String, result: String) {
        let durationString = self.durationString(for: name)

        guard self.outputMode != .quiet else { return }
        guard let json = parseResult(result) else {
            self.printInvalidResult(rawResult: result, durationString: durationString)
            return
        }

        let (formatter, toolType) = self.toolFormatter(for: name)

        if let toolType, [ToolType.taskCompleted, .needMoreInformation, .needInfo].contains(toolType) {
            self.handleCommunicationToolComplete(name: name, toolType: toolType)
            return
        }

        let success = (json["success"] as? Bool) ?? true

        if success {
            let resultSummary = self.resultSummary(for: name, json: json, formatter: formatter)
            self.handleSuccess(
                resultSummary: resultSummary,
                durationString: durationString,
                result: result,
                json: json
            )
        } else {
            let errorMessage = (json["error"] as? String) ?? "Failed"
            self.handleFailure(message: errorMessage, durationString: durationString, json: json, tool: name)
        }

        fflush(stdout)
    }

    private func handleAssistantMessage(_ content: String) {
        self.hasReceivedContent = true

        if self.outputMode == .verbose {
            print("\n\(AgentDisplayTokens.Status.dialog) \(content)")
        } else if self.outputMode != .quiet {
            // Stop animations when content arrives
            if self.spinner != nil {
                self.spinner?.stop()
                self.spinner = nil
                print()
            }

            if self.isThinking {
                self.isThinking = false
                print()
            }

            print(content, terminator: "")
            fflush(stdout)
        }
    }

    private func handleThinkingMessage(_ content: String) {
        self.hasReceivedContent = true
        if self.outputMode == .verbose {
            print("\n\(AgentDisplayTokens.Status.planning) Thinking: \(content)")
            return
        }

        if self.spinner != nil {
            self.spinner?.stop()
            self.spinner = nil
            print()
        }

        if !self.isThinking {
            self.isThinking = true
            print("\n\(TerminalColor.gray)", terminator: "")
        }

        print(content)
        fflush(stdout)
    }

    private func handleError(_ message: String) {
        self.spinner?.stop()
        self.spinner = nil

        if self.outputMode == .minimal {
            print("\nError: \(message)")
        } else if self.outputMode != .quiet {
            print("\n\(TerminalColor.red)\(AgentDisplayTokens.Status.failure) Error: \(message)\(TerminalColor.reset)")
        }
    }

    private func handleCompleted(summary: String, usage: Tachikoma.Usage?) {
        self.spinner?.stop()
        self.spinner = nil

        // Update token count if available
        if let usage {
            self.totalTokens = usage.inputTokens + usage.outputTokens
        }

        guard !self.hasShownFinalSummary && self.outputMode != .quiet else { return }

        let totalElapsed = Date().timeIntervalSince(self.startTime)
        let tokenInfo = self.totalTokens > 0 ? ", \(self.totalTokens) tokens" : ""
        let toolsText = self.toolCallCount == 1 ? "⚒ 1 tool" : "⚒ \(self.toolCallCount) tools"

        if !summary.isEmpty && self.outputMode == .verbose {
            print("\n\(TerminalColor.gray)Summary: \(summary)\(TerminalColor.reset)")
        }

        print(self.completionSummaryLine(
            totalElapsed: totalElapsed,
            toolsText: toolsText,
            tokenInfo: tokenInfo
        ))
        self.hasShownFinalSummary = true
    }

    // MARK: - Public Methods

    func updateTokenCount(_ count: Int) {
        self.totalTokens = count
    }

    func showFinalSummaryIfNeeded(_ result: AgentExecutionResult) {
        guard !self.hasShownFinalSummary && self.outputMode != .quiet else { return }

        let totalElapsed = Date().timeIntervalSince(self.startTime)
        let tokenInfo = self.totalTokens > 0 ? ", \(self.totalTokens) tokens" : ""
        let toolsText = self.toolCallCount == 1 ? "⚒ 1 tool" : "⚒ \(self.toolCallCount) tools"

        if !result.content.isEmpty && self.outputMode == .verbose {
            print("\n\(TerminalColor.gray)Summary: \(result.content)\(TerminalColor.reset)")
        }

        print(self.completionSummaryLine(
            totalElapsed: totalElapsed,
            toolsText: toolsText,
            tokenInfo: tokenInfo
        ))
        self.hasShownFinalSummary = true
    }

    // MARK: - Helper Methods

    private func shouldSkipCommunicationOutput(for toolType: ToolType?) -> Bool {
        guard let toolType else { return false }
        return [ToolType.taskCompleted, .needMoreInformation, .needInfo].contains(toolType)
    }

    private func printToolCallStart(
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
    private func cleanToolPrefix(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasPrefix("[") {
            guard let closing = result.firstIndex(of: "]") else { break }
            let next = result.index(after: closing)
            result = String(result[next...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    private func successStatusLine(resultSummary: String, durationString: String) -> String {
        let statusPrefix = [
            " ",
            TerminalColor.bgGreen,
            TerminalColor.bold,
            " ",
            AgentDisplayTokens.Status.success,
            " ",
            TerminalColor.reset
        ].joined()

        guard !resultSummary.isEmpty else {
            return "\(statusPrefix)\(durationString)"
        }

        let summarySegment = [
            " ",
            TerminalColor.bold,
            resultSummary,
            TerminalColor.reset
        ].joined()

        return "\(statusPrefix)\(summarySegment)\(durationString)"
    }

    private func failureStatusLine(message: String, durationString: String) -> String {
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

    private func completionSummaryLine(totalElapsed: TimeInterval, toolsText: String, tokenInfo: String) -> String {
        let summaryPrefix = "\(TerminalColor.gray)Task completed in \(formatDuration(totalElapsed))"
        return [
            "\n",
            summaryPrefix,
            " with \(toolsText)\(tokenInfo)",
            TerminalColor.reset
        ].joined()
    }

    private func durationString(for toolName: String) -> String {
        if let startTime = self.toolStartTimes[toolName] {
            self.toolStartTimes.removeValue(forKey: toolName)
            let elapsed = Date().timeIntervalSince(startTime)
            return " \(TerminalColor.gray)(\(formatDuration(elapsed)))\(TerminalColor.reset)"
        }
        return ""
    }

    private func printInvalidResult(rawResult: String, durationString: String) {
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

    private func toolFormatter(for name: String) -> (any ToolFormatter, ToolType?) {
        if let type = ToolType(rawValue: name) {
            return (ToolFormatterRegistry.shared.formatter(for: type), type)
        }
        return (UnknownToolFormatter(toolName: name), nil)
    }

    private func resultSummary(for name: String, json: [String: Any], formatter: any ToolFormatter) -> String {
        var summary = formatter.formatResultSummary(result: json)

        guard name == "app" else {
            return summary
        }

        if let meta = json["meta"] as? [String: Any],
           let appName = meta["app_name"] as? String,
           let content = json["content"] as? [[String: Any]],
           let firstContent = content.first,
           let text = firstContent["text"] as? String {
            switch text {
            case let value where value.contains("Launched"):
                summary = "→ \(appName) launched"
            case let value where value.contains("Quit"):
                summary = "→ \(appName) quit"
            case let value where value.contains("Focused") || value.contains("Switched"):
                summary = "→ \(appName) focused"
            case let value where value.contains("Hidden"):
                summary = "→ \(appName) hidden"
            case let value where value.contains("Unhidden"):
                summary = "→ \(appName) shown"
            default:
                break
            }
        }

        return summary
    }

    private func handleSuccess(
        resultSummary: String,
        durationString: String,
        result: String,
        json: [String: Any]
    ) {
        switch self.outputMode {
        case .minimal:
            if !resultSummary.isEmpty {
                print(" OK \(resultSummary)\(durationString)")
            } else {
                print(" OK\(durationString)")
            }

        case .verbose:
            print(
                " \(TerminalColor.green)\(AgentDisplayTokens.Status.success)\(TerminalColor.reset)\(durationString)"
            )
            if let formatted = formatJSON(result) {
                print("\(TerminalColor.gray)Result:\(TerminalColor.reset)")
                print(formatted)
            }

        default:
            print(self.successStatusLine(resultSummary: resultSummary, durationString: durationString))
            self.printResultDetails(from: json)
        }
    }

    private func handleFailure(message: String, durationString: String, json: [String: Any], tool: String) {
        if self.outputMode == .minimal {
            print(" FAILED\(durationString)")
        } else {
            print(self.failureStatusLine(message: message, durationString: durationString))
        }
        self.displayEnhancedError(tool: tool, json: json)
    }

    private func handleCommunicationToolComplete(name: String, toolType: ToolType) {
        if self.outputMode == .verbose {
            let toolName = toolType.rawValue
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
            print("\n\(AgentDisplayTokens.Status.success) \(toolName) completed")
        }
    }

    private func displayEnhancedError(tool: String, json: [String: Any]) {
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

    private func printResultDetails(from json: [String: Any]) {
        guard self.outputMode != .minimal && self.outputMode != .quiet else { return }
        guard let detail = self.primaryResultMessage(from: json) else { return }
        let snippet = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !snippet.isEmpty else { return }
        print("\n   \(TerminalColor.gray)\(snippet.prefix(240))\(TerminalColor.reset)")
    }

    private func primaryResultMessage(from json: [String: Any]) -> String? {
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

/// Formatter for unknown tools
private class UnknownToolFormatter: BaseToolFormatter {
    private let toolName: String

    override nonisolated init(toolType: ToolType) {
        fatalError("Use init(toolName:)")
    }

    init(toolName: String) {
        self.toolName = toolName
        // Create a synthetic ToolType for unknown tools
        // We'll use wait as a placeholder since it's a simple tool
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
