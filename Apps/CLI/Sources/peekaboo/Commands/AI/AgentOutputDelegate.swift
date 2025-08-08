//
//  AgentOutputDelegate.swift
//  Peekaboo
//

import Foundation
import PeekabooCore
import Tachikoma
import Spinner

/// Handles agent output formatting and display for different output modes
@available(macOS 14.0, *)
@MainActor
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
    private var spinner: Spinner? = nil
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
        guard !jsonOutput else { return }
        
        switch event {
        case let .started(task):
            handleStarted(task)
            
        case let .toolCallStarted(name, arguments):
            handleToolCallStarted(name: name, arguments: arguments)
            
        case let .toolCallCompleted(name, result):
            handleToolCallCompleted(name: name, result: result)
            
        case let .assistantMessage(content):
            handleAssistantMessage(content)
            
        case let .thinkingMessage(content):
            handleThinkingMessage(content)
            
        case let .error(message):
            handleError(message)
            
        case let .completed(summary, usage):
            handleCompleted(summary: summary, usage: usage)
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleStarted(_ task: String) {
        guard outputMode != .quiet else { return }
        
        if outputMode == .verbose {
            print("\n🚀 Starting agent task: \(task)")
        } else if outputMode == .enhanced || outputMode == .compact {
            // Start spinner animation (fallback color)
            spinner = Spinner(.dots, "Thinking...", color: .default)
            spinner?.start()
        } else if outputMode == .minimal {
            print("Starting: \(task)")
        }
    }
    
    private func handleToolCallStarted(name: String, arguments: String) {
        currentTool = name
        toolStartTimes[name] = Date()
        toolCallCount += 1
        
        // Parse arguments
        let args = parseArguments(arguments)
        
        // Get formatter for this tool
        let formatter: ToolFormatter
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
        
        // Update terminal title
        let titleSummary = formatter.formatForTitle(arguments: args)
        let display = name.replacingOccurrences(of: "_", with: " ").capitalized
        updateTerminalTitle("\(display): \(titleSummary) - \(task?.prefix(30) ?? "")")
        
        // Skip output for quiet mode
        guard outputMode != .quiet else { return }
        
        // Stop animations
        spinner?.stop()
        spinner = nil
        isThinking = false
        
        // Skip display for communication tools
        if let t = toolType, [ToolType.taskCompleted, .needMoreInformation, .needInfo].contains(t) {
            return
        }
        
        // Add newline for spacing if needed
        if hasReceivedContent {
            print()
            hasReceivedContent = false
        }
        
        // Format output based on mode
        let icon = "⚙️"
        
        switch outputMode {
        case .minimal:
            print(name, terminator: "")
            
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
            print("\(TerminalColor.blue)\(TerminalColor.bold)\(icon) \(startMessage)\(TerminalColor.reset)", terminator: "")
            
        default: // .normal, .compact
            print("\(TerminalColor.blue)\(TerminalColor.bold)\(icon) \(name)\(TerminalColor.reset)", terminator: "")
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
            durationString = " \(TerminalColor.gray)(\(formatDuration(elapsed)))\(TerminalColor.reset)"
            toolStartTimes.removeValue(forKey: name)
        } else {
            elapsed = 0
            durationString = ""
        }
        
        // Skip output for quiet mode
        guard outputMode != .quiet else { return }
        
        // Parse result
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print(" \(TerminalColor.red)✗ Invalid result\(TerminalColor.reset)\(durationString)")
            return
        }
        
        // Get formatter for this tool
        let formatter: ToolFormatter
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
            handleCommunicationToolComplete(name: name, toolType: t)
            return
        }
        
        // Check for success/failure
        let success = (json["success"] as? Bool) ?? true
        
        if success {
            let resultSummary = formatter.formatResultSummary(result: json)
            
            switch outputMode {
            case .minimal:
                if !resultSummary.isEmpty {
                    print(" OK \(resultSummary)\(durationString)")
                } else {
                    print(" OK\(durationString)")
                }
                
            case .enhanced:
                if !resultSummary.isEmpty {
                    print(" \(TerminalColor.bgGreen)\(TerminalColor.bold) ✅ \(TerminalColor.reset) \(TerminalColor.bold)\(resultSummary)\(TerminalColor.reset)\(durationString)")
                } else {
                    print(" \(TerminalColor.bgGreen)\(TerminalColor.bold) ✅ \(TerminalColor.reset)\(durationString)")
                }
                
            case .verbose:
                print(" \(TerminalColor.green)✓\(TerminalColor.reset)\(durationString)")
                if let formatted = formatJSON(result) {
                    print("\(TerminalColor.gray)Result:\(TerminalColor.reset)")
                    print(formatted)
                }
                
            default: // .normal, .compact
                if !resultSummary.isEmpty {
                    print(" \(TerminalColor.bgGreen)\(TerminalColor.bold) ✓ \(TerminalColor.reset) \(TerminalColor.bold)\(resultSummary)\(TerminalColor.reset)\(durationString)")
                } else {
                    print(" \(TerminalColor.bgGreen)\(TerminalColor.bold) ✓ \(TerminalColor.reset)\(durationString)")
                }
            }
        } else {
            let errorMessage = (json["error"] as? String) ?? "Failed"
            
            if outputMode == .minimal {
                print(" FAILED\(durationString)")
            } else {
                print(" \(TerminalColor.red)✗ \(errorMessage)\(TerminalColor.reset)\(durationString)")
            }
            
            // Display enhanced error information
            displayEnhancedError(tool: name, json: json)
        }
        
        fflush(stdout)
    }
    
    private func handleAssistantMessage(_ content: String) {
        hasReceivedContent = true
        
        if outputMode == .verbose {
            print("\n💬 \(content)")
        } else if outputMode != .quiet {
            // Stop animations when content arrives
            if spinner != nil {
                spinner?.stop()
                spinner = nil
                print()
            }
            
            if isThinking {
                isThinking = false
                print()
            }
            
            print(content, terminator: "")
            fflush(stdout)
        }
    }
    
    private func handleThinkingMessage(_ content: String) {
        if outputMode == .verbose {
            print("\n🤔 Thinking: \(content)")
        } else if outputMode == .compact || outputMode == .enhanced {
            if spinner != nil {
                spinner?.stop()
                spinner = nil
                print()
            }
            
            if !isThinking {
                isThinking = true
                print("\n\(TerminalColor.gray)💭 ", terminator: "")
            }
            
            print(content, terminator: "")
            fflush(stdout)
        } else if outputMode == .minimal {
            if !isThinking {
                isThinking = true
                print("Thinking: ", terminator: "")
            }
            print(content, terminator: "")
            fflush(stdout)
        }
    }
    
    private func handleError(_ message: String) {
        spinner?.stop()
        spinner = nil
        
        if outputMode == .minimal {
            print("\nError: \(message)")
        } else if outputMode != .quiet {
            print("\n\(TerminalColor.red)❌ Error: \(message)\(TerminalColor.reset)")
        }
    }
    
    private func handleCompleted(summary: String, usage: Tachikoma.Usage?) {
        spinner?.stop()
        spinner = nil
        
        // Update token count if available
        if let usage = usage {
            totalTokens = usage.inputTokens + usage.outputTokens
        }
        
        guard !hasShownFinalSummary && outputMode != .quiet else { return }
        
        let totalElapsed = Date().timeIntervalSince(startTime)
        let tokenInfo = totalTokens > 0 ? ", \(totalTokens) tokens" : ""
        let toolsText = toolCallCount == 1 ? "⚒ 1 tool" : "⚒ \(toolCallCount) tools"
        
        if !summary.isEmpty && outputMode == .verbose {
            print("\n\(TerminalColor.gray)Summary: \(summary)\(TerminalColor.reset)")
        }
        
        print("\n\(TerminalColor.gray)Task completed in \(formatDuration(totalElapsed)) with \(toolsText)\(tokenInfo)\(TerminalColor.reset)")
        hasShownFinalSummary = true
    }
    
    // MARK: - Public Methods
    
    func updateTokenCount(_ count: Int) {
        totalTokens = count
    }
    
    func showFinalSummaryIfNeeded(_ result: AgentExecutionResult) {
        guard !hasShownFinalSummary && outputMode != .quiet else { return }
        
        let totalElapsed = Date().timeIntervalSince(startTime)
        let tokenInfo = totalTokens > 0 ? ", \(totalTokens) tokens" : ""
        let toolsText = toolCallCount == 1 ? "⚒ 1 tool" : "⚒ \(toolCallCount) tools"
        
        if !result.content.isEmpty && outputMode == .verbose {
            print("\n\(TerminalColor.gray)Summary: \(result.content)\(TerminalColor.reset)")
        }
        
        print("\n\(TerminalColor.gray)Task completed in \(formatDuration(totalElapsed)) with \(toolsText)\(tokenInfo)\(TerminalColor.reset)")
        hasShownFinalSummary = true
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
        if outputMode == .verbose {
            print("\n✅ \(toolType.displayName) completed")
        }
    }
    
    private func displayEnhancedError(tool: String, json: [String: Any]) {
        guard outputMode != .minimal && outputMode != .quiet else { return }
        
        if let error = json["error"] as? String {
            print("   \(TerminalColor.gray)Error: \(error)\(TerminalColor.reset)")
        }
        
        if let suggestion = json["suggestion"] as? String {
            print("   \(TerminalColor.yellow)💡 Suggestion: \(suggestion)\(TerminalColor.reset)")
        }
        
        if outputMode == .verbose,
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
    
    init(toolName: String) {
        self.toolName = toolName
        // Create a synthetic ToolType for unknown tools
        // We'll use wait as a placeholder since it's a simple tool
        super.init(toolType: .wait)
    }
    
    override var displayName: String {
        toolName.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    override var icon: String {
        "⚙️"
    }
    
    override func formatStarting(arguments: [String: Any]) -> String {
        "\(toolName.replacingOccurrences(of: "_", with: " ").capitalized)"
    }
    
    override func formatCompleted(result: [String: Any], duration: TimeInterval) -> String {
        "→ completed"
    }
    
    override func formatError(error: String, result: [String: Any]) -> String {
        "✗ \(error)"
    }
    
    override func formatCompactSummary(arguments: [String: Any]) -> String {
        ""
    }
    
    override func formatResultSummary(result: [String: Any]) -> String {
        ""
    }
    
    override func formatForTitle(arguments: [String: Any]) -> String {
        toolName
    }
}