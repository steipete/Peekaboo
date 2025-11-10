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

        // Parse arguments
        let args = self.parseArguments(arguments)

        // Get formatter for this tool
        let formatter: any ToolFormatter
        let toolType: ToolType?

        if let type = ToolType(rawValue: name) {
            toolType = type
            // Use main formatter registry with detailed formatters
            formatter = ToolFormatterRegistry.shared.formatter(for: type)
        } else {
            // Unknown tool - use a default formatter
            toolType = nil
            formatter = UnknownToolFormatter(toolName: name)
        }

        // Get proper display name
        var displayName = toolType?.displayName ?? name.replacingOccurrences(of: "_", with: " ").capitalized

        // Special handling for app tool to show the action
        if name == "app", let action = args["action"] as? String {
            let appName = (args["name"] as? String) ?? (args["bundleId"] as? String) ?? ""
            displayName = "App \(action.capitalized)\(appName.isEmpty ? "" : ": \(appName)")"
        }

        // Update terminal title
        let titleSummary = formatter.formatForTitle(arguments: args)
        self.updateTerminalTitle("\(displayName): \(titleSummary) - \(self.task?.prefix(30) ?? "")")

        // Skip output for quiet mode
        guard self.outputMode != .quiet else { return }

        // Stop animations
        self.spinner?.stop()
        self.spinner = nil
        self.isThinking = false

        // Skip display for communication tools
        if let t = toolType, [ToolType.taskCompleted, .needMoreInformation, .needInfo].contains(t) {
            return
        }

        // Add newline for spacing if needed
        if self.hasReceivedContent {
            print()
            self.hasReceivedContent = false
        }

        // Format output based on mode
        let icon = toolType?.icon ?? "⚙️"

        switch self.outputMode {
        case .minimal:
            print(displayName, terminator: "")

        case .verbose:
            print("\(TerminalColor.blue)\(TerminalColor.bold)\(icon) \(displayName)\(TerminalColor.reset)")
            if arguments.isEmpty || arguments == "{}" {
                print("\(TerminalColor.gray)Arguments: (none)\(TerminalColor.reset)")
            } else if let formatted = formatJSON(arguments) {
                print("\(TerminalColor.gray)Arguments:\(TerminalColor.reset)")
                print(formatted)
            }

        case .enhanced:
            let startMessage = formatter.formatStarting(arguments: args)
            print(
                "\(TerminalColor.blue)\(TerminalColor.bold)\(icon) \(startMessage)\(TerminalColor.reset)",
                terminator: ""
            )

        default: // .normal, .compact
            print(
                "\(TerminalColor.blue)\(TerminalColor.bold)\(icon) \(displayName)\(TerminalColor.reset)",
                terminator: ""
            )
            let summary = formatter.formatCompactSummary(arguments: args)
            if !summary.isEmpty {
                print(" \(TerminalColor.gray)\(summary)\(TerminalColor.reset)", terminator: "")
            }
        }

        fflush(stdout)
    }

    private func handleToolCallCompleted(name: String, result: String) {
        // Calculate duration
        let elapsed: TimeInterval
        let durationString: String

        if let startTime = toolStartTimes[name] {
            elapsed = Date().timeIntervalSince(startTime)
            durationString = " \(TerminalColor.gray)(\(self.formatDuration(elapsed)))\(TerminalColor.reset)"
            self.toolStartTimes.removeValue(forKey: name)
        } else {
            elapsed = 0
            durationString = ""
        }

        // Skip output for quiet mode
        guard self.outputMode != .quiet else { return }

        // Parse result
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Log the actual result for debugging in verbose mode
            if self.outputMode == .verbose {
                print(
                    " \(TerminalColor.red)\(AgentDisplayTokens.Status.failure) Invalid JSON result\(TerminalColor.reset)\(durationString)"
                )
                print("\(TerminalColor.gray)Raw result: \(result.prefix(200))\(TerminalColor.reset)")
            } else {
                print(
                    " \(TerminalColor.red)\(AgentDisplayTokens.Status.failure) Invalid result\(TerminalColor.reset)\(durationString)"
                )
            }
            return
        }

        // Get formatter for this tool
        let formatter: any ToolFormatter
        let toolType: ToolType?

        if let type = ToolType(rawValue: name) {
            toolType = type
            // Use main formatter registry with detailed formatters
            formatter = ToolFormatterRegistry.shared.formatter(for: type)
        } else {
            toolType = nil
            formatter = UnknownToolFormatter(toolName: name)
        }

        // Handle communication tools specially
        if let t = toolType, [ToolType.taskCompleted, .needMoreInformation, .needInfo].contains(t) {
            self.handleCommunicationToolComplete(name: name, toolType: t)
            return
        }

        // Check for success/failure
        let success = (json["success"] as? Bool) ?? true

        if success {
            // Special handling for app tool results
            var resultSummary = formatter.formatResultSummary(result: json)
            if name == "app" {
                if let meta = json["meta"] as? [String: Any],
                   let appName = meta["app_name"] as? String {
                    if let content = json["content"] as? [[String: Any]],
                       let firstContent = content.first,
                       let text = firstContent["text"] as? String {
                        // Extract the key info from the result
                        if text.contains("Launched") {
                            resultSummary = "→ \(appName) launched"
                        } else if text.contains("Quit") {
                            resultSummary = "→ \(appName) quit"
                        } else if text.contains("Focused") || text.contains("Switched") {
                            resultSummary = "→ \(appName) focused"
                        } else if text.contains("Hidden") {
                            resultSummary = "→ \(appName) hidden"
                        } else if text.contains("Unhidden") {
                            resultSummary = "→ \(appName) shown"
                        }
                    }
                }
            }

            switch self.outputMode {
            case .minimal:
                if !resultSummary.isEmpty {
                    print(" OK \(resultSummary)\(durationString)")
                } else {
                    print(" OK\(durationString)")
                }

            case .enhanced:
                if !resultSummary.isEmpty {
                    print(
                        " \(TerminalColor.bgGreen)\(TerminalColor.bold) \(AgentDisplayTokens.Status.success) \(TerminalColor.reset) \(TerminalColor.bold)\(resultSummary)\(TerminalColor.reset)\(durationString)"
                    )
                } else {
                    print(
                        " \(TerminalColor.bgGreen)\(TerminalColor.bold) \(AgentDisplayTokens.Status.success) \(TerminalColor.reset)\(durationString)"
                    )
                }

            case .verbose:
                print(
                    " \(TerminalColor.green)\(AgentDisplayTokens.Status.success)\(TerminalColor.reset)\(durationString)"
                )
                if let formatted = formatJSON(result) {
                    print("\(TerminalColor.gray)Result:\(TerminalColor.reset)")
                    print(formatted)
                }

            default: // .normal, .compact
                if !resultSummary.isEmpty {
                    print(
                        " \(TerminalColor.bgGreen)\(TerminalColor.bold) \(AgentDisplayTokens.Status.success) \(TerminalColor.reset) \(TerminalColor.bold)\(resultSummary)\(TerminalColor.reset)\(durationString)"
                    )
                } else {
                    print(
                        " \(TerminalColor.bgGreen)\(TerminalColor.bold) \(AgentDisplayTokens.Status.success) \(TerminalColor.reset)\(durationString)"
                    )
                }
            }
        } else {
            let errorMessage = (json["error"] as? String) ?? "Failed"

            if self.outputMode == .minimal {
                print(" FAILED\(durationString)")
            } else {
                print(
                    " \(TerminalColor.red)\(AgentDisplayTokens.Status.failure) \(errorMessage)\(TerminalColor.reset)\(durationString)"
                )
            }

            // Display enhanced error information
            self.displayEnhancedError(tool: name, json: json)
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
        if self.outputMode == .verbose {
            print("\n\(AgentDisplayTokens.Status.planning) Thinking: \(content)")
        } else if self.outputMode == .compact || self.outputMode == .enhanced {
            if self.spinner != nil {
                self.spinner?.stop()
                self.spinner = nil
                print()
            }

            if !self.isThinking {
                self.isThinking = true
                print("\n\(TerminalColor.gray)💭 ", terminator: "")
            }

            print(content, terminator: "")
            fflush(stdout)
        } else if self.outputMode == .minimal {
            if !self.isThinking {
                self.isThinking = true
                print("Thinking: ", terminator: "")
            }
            print(content, terminator: "")
            fflush(stdout)
        }
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

        print(
            "\n\(TerminalColor.gray)Task completed in \(self.formatDuration(totalElapsed)) with \(toolsText)\(tokenInfo)\(TerminalColor.reset)"
        )
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

        print(
            "\n\(TerminalColor.gray)Task completed in \(self.formatDuration(totalElapsed)) with \(toolsText)\(tokenInfo)\(TerminalColor.reset)"
        )
        self.hasShownFinalSummary = true
    }

    // MARK: - Helper Methods

    private func parseArguments(_ arguments: String) -> [String: Any] {
        guard let data = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return args
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
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

    private func formatJSON(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let formatted = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
              let result = String(data: formatted, encoding: .utf8) else {
            return nil
        }
        return result
    }

    private func updateTerminalTitle(_ title: String) {
        print("\u{001B}]0;\(title)\u{0007}", terminator: "")
        fflush(stdout)
    }

    private func handleCommunicationToolComplete(name: String, toolType: ToolType) {
        if self.outputMode == .verbose {
            print(
                "\n\(AgentDisplayTokens.Status.success) \(toolType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized) completed"
            )
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
}

// MARK: - Supporting Types

/// Formatter for unknown tools
private class UnknownToolFormatter: BaseToolFormatter {
    private let toolName: String

    nonisolated override init(toolType: ToolType) {
        fatalError("Use init(toolName:)")
    }

    init(toolName: String) {
        self.toolName = toolName
        // Create a synthetic ToolType for unknown tools
        // We'll use wait as a placeholder since it's a simple tool
        super.init(toolType: .wait)
    }

    nonisolated override func formatStarting(arguments: [String: Any]) -> String {
        "\(self.toolName.replacingOccurrences(of: "_", with: " ").capitalized)"
    }

    nonisolated override func formatCompleted(result: [String: Any], duration: TimeInterval) -> String {
        "→ completed"
    }

    nonisolated override func formatError(error: String, result: [String: Any]) -> String {
        "\(AgentDisplayTokens.Status.failure) \(error)"
    }

    nonisolated override func formatCompactSummary(arguments: [String: Any]) -> String {
        ""
    }

    nonisolated override func formatResultSummary(result: [String: Any]) -> String {
        ""
    }

    nonisolated override func formatForTitle(arguments: [String: Any]) -> String {
        self.toolName
    }
}
