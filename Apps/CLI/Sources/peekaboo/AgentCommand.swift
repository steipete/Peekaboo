import ArgumentParser
import Foundation
import PeekabooCore

/// Output modes for agent execution
enum OutputMode {
    case quiet      // Only final result
    case compact    // Clean, colorized output with tool calls (default)
    case verbose    // Full JSON debug information
}

/// ANSI color codes for terminal output
enum TerminalColor {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
    
    // Colors
    static let blue = "\u{001B}[34m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let red = "\u{001B}[31m"
    static let cyan = "\u{001B}[36m"
    static let magenta = "\u{001B}[35m"
    static let gray = "\u{001B}[90m"
    
    // Background colors
    static let bgBlue = "\u{001B}[44m"
    static let bgGreen = "\u{001B}[42m"
    static let bgYellow = "\u{001B}[43m"
    static let bgRed = "\u{001B}[41m"
}

/// Get icon for tool name in compact mode
func iconForTool(_ toolName: String) -> String {
    switch toolName {
    case "screenshot", "window_capture": return "👁"
    case "click": return "👆"
    case "type": return "⌨️"
    case "list_apps", "launch_app": return "📱"
    case "list_windows", "focus_window", "resize_window": return "🪟"
    case "hotkey": return "⌨️"
    case "wait": return "⏱"
    case "scroll": return "📜"
    case "find_element", "list_elements": return "🔍"
    case "shell": return "🐚"
    case "menu": return "📋"
    case "dialog": return "💬"
    case "analyze_screenshot": return "🤖"
    case "list": return "📋"
    default: return "⚙️"
    }
}

/// AI Agent command that uses new Chat Completions API architecture
@available(macOS 14.0, *)
struct AgentCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent",
        abstract: "Execute complex automation tasks using AI agent",
        discussion: """
        Uses OpenAI Chat Completions API to break down and execute complex automation tasks.
        The agent can see the screen, interact with UI elements, and verify results.

        EXAMPLES:
          peekaboo agent "Open TextEdit and write 'Hello World'"
          peekaboo agent "Take a screenshot of Safari and save it to Desktop"
          peekaboo agent "Click on the login button and fill the form"
          peekaboo "Find the Terminal app and run 'ls -la'" # Direct invocation

        The agent will:
        1. Analyze your request
        2. Break it down into steps
        3. Execute each step using Peekaboo commands
        4. Verify results with screenshots
        5. Retry if needed
        """)

    @Argument(help: "Natural language description of the task to perform (optional when using --resume)")
    var task: String?

    @Flag(name: .shortAndLong, help: "Enable verbose output with full JSON debug information")
    var verbose = false
    
    @Flag(name: [.short, .long], help: "Quiet mode - only show final result")
    var quiet = false

    @Flag(name: .long, help: "Dry run - show planned steps without executing")
    var dryRun = false

    @Option(name: .long, help: "Maximum number of steps the agent can take")
    var maxSteps: Int?

    @Option(name: .long, help: "OpenAI model to use")
    var model: String?

    @Flag(name: .long, help: "Output in JSON format")
    var jsonOutput = false
    
    @Option(name: .long, help: "Resume agent session: --resume (show sessions) or --resume <session-id> (resume specific)")
    var resume: String?
    
    @Flag(name: .long, help: "List available sessions")
    var listSessions = false
    
    @Flag(name: .long, help: "Disable session caching (always create new session)")
    var noCache = false
    
    /// Computed property for output mode based on flags
    private var outputMode: OutputMode {
        return quiet ? .quiet : (verbose ? .verbose : .compact)
    }

    mutating func run() async throws {
        // Initialize services
        let services = PeekabooServices.shared
        
        // Check if agent service is available
        guard let agentService = services.agent else {
            if jsonOutput {
                let error = ["success": false, "error": "Agent service not available. Please set OPENAI_API_KEY environment variable."] as [String: Any]
                let jsonData = try JSONSerialization.data(withJSONObject: error, options: .prettyPrinted)
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
            } else {
                print("\(TerminalColor.red)Error: Agent service not available. Please set OPENAI_API_KEY environment variable.\(TerminalColor.reset)")
            }
            return
        }
        
        // Handle list sessions
        if listSessions || (resume == "") {
            try await showSessions(agentService)
            return
        }
        
        // Handle session resume
        if let sessionId = resume {
            guard let continuationTask = task else {
                if jsonOutput {
                    let error = ["success": false, "error": "Task argument required when resuming session"] as [String: Any]
                    let jsonData = try JSONSerialization.data(withJSONObject: error, options: .prettyPrinted)
                    print(String(data: jsonData, encoding: .utf8) ?? "{}")
                } else {
                    print("\(TerminalColor.red)Error: Task argument required when resuming session\(TerminalColor.reset)")
                    print("Usage: peekaboo agent --resume <session-id> \"<continuation-task>\"")
                }
                return
            }
            try await resumeSession(agentService, sessionId: sessionId, task: continuationTask)
            return
        }
        
        // Regular execution requires task
        guard let executionTask = task else {
            if jsonOutput {
                let error = ["success": false, "error": "Task argument is required"] as [String: Any]
                let jsonData = try JSONSerialization.data(withJSONObject: error, options: .prettyPrinted)
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
            } else {
                print("\(TerminalColor.red)Error: Task argument is required\(TerminalColor.reset)")
                print("Usage: peekaboo agent \"<your-task>\"")
            }
            return
        }
        
        // Execute task
        try await executeTask(agentService, task: executionTask)
    }
    
    // MARK: - Task Execution
    
    private func executeTask(_ agentService: AgentServiceProtocol, task: String, sessionId: String? = nil) async throws {
        // Create event delegate for real-time updates
        let eventDelegate = CompactEventDelegate(outputMode: outputMode, jsonOutput: jsonOutput)
        
        // Show header
        if outputMode != .quiet && !jsonOutput {
            switch outputMode {
            case .verbose:
                print("\n═══════════════════════════════════════════════════════════════")
                print(" PEEKABOO AGENT")
                print("═══════════════════════════════════════════════════════════════\n")
                print("Task: \"\(task)\"")
                if let modelName = model {
                    print("Model: \(modelName)")
                }
                if let sessionId = sessionId {
                    print("Session: \(sessionId.prefix(8))... (resumed)")
                }
                print("\nInitializing agent...\n")
            case .compact:
                print("\(TerminalColor.cyan)\(TerminalColor.bold)🤖 Peekaboo Agent\(TerminalColor.reset) \(TerminalColor.gray)v\(Version.fullVersion)\(TerminalColor.reset)")
                print("\(TerminalColor.gray)📋 Task: \(task)\(TerminalColor.reset)")
                if let sessionId = sessionId {
                    print("\(TerminalColor.gray)🔄 Session: \(sessionId.prefix(8))...\(TerminalColor.reset)")
                }
                print()
            case .quiet:
                break
            }
        }
        
        do {
            // Cast to PeekabooAgentService for enhanced functionality
            guard let peekabooAgent = agentService as? PeekabooAgentService else {
                throw PeekabooError.serviceUnavailable("Agent service not properly initialized")
            }
            
            let result = try await peekabooAgent.executeTask(
                task,
                sessionId: sessionId,
                modelName: model ?? "gpt-4o",
                eventDelegate: eventDelegate
            )
            
            // Handle result display
            displayResult(result)
        } catch {
            if jsonOutput {
                let response = [
                    "success": false,
                    "error": error.localizedDescription
                ] as [String: Any]
                let jsonData = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
            } else {
                print("\n\(TerminalColor.red)\(TerminalColor.bold)❌ Error:\(TerminalColor.reset) \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    private func displayResult(_ result: AgentResult) {
        if jsonOutput {
            let response = [
                "success": true,
                "result": [
                    "steps": result.steps.map { step in
                        [
                            "action": step.action,
                            "description": step.description,
                            "toolCalls": step.toolCalls,
                            "reasoning": step.reasoning as Any,
                            "observation": step.observation as Any
                        ]
                    },
                    "summary": result.summary
                ]
            ] as [String: Any]
            if let jsonData = try? JSONSerialization.data(withJSONObject: response, options: .prettyPrinted) {
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
            }
        } else if outputMode == .quiet {
            // Quiet mode - only show final result
            print(result.summary)
        } else {
            // Compact/verbose mode - show completion message
            print("\n\(TerminalColor.green)\(TerminalColor.bold)✅ Task completed\(TerminalColor.reset)")
            if !result.summary.isEmpty {
                print(result.summary)
            }
        }
    }
    
    // MARK: - Session Management
    
    private func showSessions(_ agentService: AgentServiceProtocol) async throws {
        // Cast to PeekabooAgentService - this should always succeed
        guard let peekabooAgent = agentService as? PeekabooAgentService else {
            throw PeekabooError.serviceUnavailable("Agent service not properly initialized")
        }
        let sessions = try await peekabooAgent.listSessions()
        
        if sessions.isEmpty {
            if jsonOutput {
                let response = ["success": true, "sessions": []] as [String: Any]
                let jsonData = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
            } else {
                print("No agent sessions found.")
            }
            return
        }
        
        if jsonOutput {
            let sessionData = sessions.map { session in
                [
                    "id": session.id,
                    "createdAt": ISO8601DateFormatter().string(from: session.createdAt),
                    "updatedAt": ISO8601DateFormatter().string(from: session.updatedAt),
                    "messageCount": session.messageCount
                ]
            }
            let response = ["success": true, "sessions": sessionData] as [String: Any]
            let jsonData = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
            print(String(data: jsonData, encoding: .utf8) ?? "{}")
        } else {
            print("\(TerminalColor.cyan)\(TerminalColor.bold)Agent Sessions:\(TerminalColor.reset)\n")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            
            for (index, session) in sessions.prefix(10).enumerated() {
                let timeAgo = formatTimeAgo(session.updatedAt)
                print("\(TerminalColor.blue)\(index + 1).\(TerminalColor.reset) \(TerminalColor.bold)\(session.id.prefix(8))\(TerminalColor.reset)")
                print("   Messages: \(session.messageCount)")
                print("   Last activity: \(timeAgo)")
                if index < sessions.count - 1 {
                    print()
                }
            }
            
            if sessions.count > 10 {
                print("\n\(TerminalColor.dim)... and \(sessions.count - 10) more sessions\(TerminalColor.reset)")
            }
            
            print("\n\(TerminalColor.dim)To resume: peekaboo agent --resume <session-id> \"<continuation>\"\(TerminalColor.reset)")
        }
    }
    
    private func resumeSession(_ agentService: AgentServiceProtocol, sessionId: String, task: String) async throws {
        if !jsonOutput {
            print("\(TerminalColor.cyan)\(TerminalColor.bold)🔄 Resuming session \(sessionId.prefix(8))\(TerminalColor.reset)\n")
        }
        
        // Execute task with existing session
        try await executeTask(agentService, task: task, sessionId: sessionId)
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

// MARK: - Event Delegate for Real-time Updates

@available(macOS 14.0, *)
final class CompactEventDelegate: AgentEventDelegate {
    let outputMode: OutputMode
    let jsonOutput: Bool
    private var currentTool: String?
    
    init(outputMode: OutputMode, jsonOutput: Bool) {
        self.outputMode = outputMode
        self.jsonOutput = jsonOutput
    }
    
    func agentDidEmitEvent(_ event: AgentEvent) {
        guard !jsonOutput else { return }
        
        switch event {
        case .started(let task):
            if outputMode == .verbose {
                print("🚀 Starting: \(task)")
            }
            
        case .thinking(let message):
            if outputMode != .quiet {
                // Add thinking emoji and format the message
                let thinkingMessage = "💭 \(message)"
                print("\r\(TerminalColor.dim)\(thinkingMessage)\(TerminalColor.reset)", terminator: "")
                fflush(stdout)
            }
            
        case .toolCallStarted(let name, let arguments):
            currentTool = name
            if outputMode != .quiet {
                // Clear any thinking message
                print("\r\(String(repeating: " ", count: 80))\r", terminator: "")
                
                let icon = iconForTool(name)
                print("\(TerminalColor.blue)\(icon) \(name)\(TerminalColor.reset)", terminator: "")
                
                if outputMode == .verbose {
                    print("\n   Arguments: \(arguments)")
                } else {
                    // Show compact summary based on tool and args
                    if let data = arguments.data(using: .utf8),
                       let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let summary = compactToolSummary(name, args)
                        if !summary.isEmpty {
                            print(" \(TerminalColor.gray)\(summary)\(TerminalColor.reset)", terminator: "")
                        }
                    }
                }
                fflush(stdout)
            }
            
        case .toolCallCompleted(let name, let result):
            if outputMode != .quiet {
                if let data = result.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool {
                    if success {
                        print(" \(TerminalColor.green)✓\(TerminalColor.reset)")
                    } else {
                        print(" \(TerminalColor.red)✗\(TerminalColor.reset)")
                        if let error = json["error"] as? String {
                            print("   \(TerminalColor.red)\(error)\(TerminalColor.reset)")
                        }
                    }
                } else {
                    print(" \(TerminalColor.green)✓\(TerminalColor.reset)")
                }
            }
            currentTool = nil
            
        case .assistantMessage(let content):
            if outputMode == .verbose {
                print("\n💭 Assistant: \(content)")
            }
            
        case .error(let message):
            print("\n\(TerminalColor.red)❌ Error: \(message)\(TerminalColor.reset)")
            
        case .completed(let summary):
            // Final summary is handled by the main execution flow
            break
        }
    }
    
    private func compactToolSummary(_ toolName: String, _ args: [String: Any]) -> String {
        switch toolName {
        case "screenshot":
            if let mode = args["mode"] as? String {
                return mode == "window" ? "active window" : mode
            }
            return ""
            
        case "window_capture":
            if let app = args["appName"] as? String {
                return app
            }
            return ""
            
        case "click":
            if let target = args["target"] as? String {
                // Check if it's an element ID (like B7, O6, etc.) or text
                if target.count <= 3 && target.range(of: "^[A-Z]\\d+$", options: .regularExpression) != nil {
                    // It's an element ID - show it with a label indicator
                    return "element \(target)"
                } else {
                    // It's text or other target
                    return "'\(target)'"
                }
            } else if let element = args["element"] as? String {
                // Element ID format
                return "element \(element)"
            } else if let x = args["x"], let y = args["y"] {
                return "at (\(x), \(y))"
            }
            return ""
            
        case "type":
            if let text = args["text"] as? String {
                let preview = text.count > 30 ? String(text.prefix(30)) + "..." : text
                return "'\(preview)'"
            }
            return ""
            
        case "scroll":
            if let direction = args["direction"] as? String,
               let amount = args["amount"] as? Int {
                return "\(direction) \(amount)px"
            }
            return ""
            
        case "focus_window", "resize_window":
            if let app = args["appName"] as? String {
                return app
            }
            return ""
            
        case "launch_app":
            if let app = args["appName"] as? String {
                return app
            }
            return ""
            
        case "hotkey":
            if let keys = args["keys"] as? String {
                // Format keyboard shortcuts with proper symbols
                let formatted = keys.replacingOccurrences(of: "cmd", with: "⌘")
                    .replacingOccurrences(of: "command", with: "⌘")
                    .replacingOccurrences(of: "shift", with: "⇧")
                    .replacingOccurrences(of: "option", with: "⌥")
                    .replacingOccurrences(of: "opt", with: "⌥")
                    .replacingOccurrences(of: "alt", with: "⌥")
                    .replacingOccurrences(of: "control", with: "⌃")
                    .replacingOccurrences(of: "ctrl", with: "⌃")
                    .replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: "+", with: "")
                return formatted
            }
            return ""
            
        case "shell":
            if let command = args["command"] as? String {
                let preview = command.count > 30 ? String(command.prefix(30)) + "..." : command
                return "'\(preview)'"
            }
            return ""
            
        case "list":
            if let target = args["target"] as? String {
                switch target {
                case "apps": return "running applications"
                case "windows": 
                    if let app = args["appName"] as? String {
                        return "windows for \(app)"
                    }
                    return "all windows"
                case "elements":
                    if let type = args["type"] as? String {
                        return "\(type) elements"
                    }
                    return "UI elements"
                default: return target
                }
            }
            return ""
            
        case "menu":
            if let action = args["action"] as? String {
                if action == "click", let menuPath = args["menuPath"] as? [String] {
                    return menuPath.joined(separator: " → ")
                }
                return action
            }
            return ""
            
        default:
            return ""
        }
    }
}