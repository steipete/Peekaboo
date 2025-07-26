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

/// Get icon for command in compact mode
func iconForCommand(_ command: String) -> String {
    switch command {
    case "see": return "👁"
    case "click": return "👆"
    case "type": return "⌨️"
    case "app": return "📱"
    case "window": return "🪟"
    case "hotkey": return "⌨️"
    case "wait": return "⏱"
    case "shell": return "🐚"
    case "drag": return "↗️"
    case "swipe": return "👋"
    default: return "⚙️"
    }
}

/// Get compact argument summary for display
func compactArgsSummary(_ command: String, _ args: [String: Any]) -> String {
    switch command {
    case "see":
        if let app = args["app"] as? String {
            return "app: \(app)"
        }
        return ""
    case "click":
        if let element = args["element"] as? String {
            return "'\(element)'"
        } else if let x = args["x"], let y = args["y"] {
            return "(\(x), \(y))"
        }
        return ""
    case "type":
        if let text = args["text"] as? String {
            let preview = text.count > 20 ? String(text.prefix(20)) + "..." : text
            return "'\(preview)'"
        }
        return ""
    case "app":
        if let action = args["action"] as? String, let name = args["name"] as? String {
            return "\(action) \(name)"
        }
        return ""
    case "hotkey":
        if let keys = args["keys"] as? [String] {
            return keys.joined(separator: "+")
        }
        return ""
    case "shell":
        if let command = args["command"] as? String {
            // For shell commands, show more meaningful info
            if command.hasPrefix("open ") {
                if command.contains("google.com/search") || command.contains("search") {
                    return "search in browser"
                } else if command.contains("http") {
                    return "open URL in browser"
                } else {
                    return "open application/file"
                }
            } else if command.hasPrefix("curl ") {
                return "fetch web data"
            } else {
                let preview = command.count > 25 ? String(command.prefix(25)) + "..." : command
                return "'\(preview)'"
            }
        }
        return ""
    case "wait":
        if let duration = args["duration"] as? Double {
            return "\(duration)s"
        }
        return ""
    default:
        return ""
    }
}

/// AI Agent command that uses OpenAI Assistants API to automate complex tasks
@available(macOS 14.0, *)
struct AgentCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent",
        abstract: "Execute complex automation tasks using AI agent",
        discussion: """
        Uses OpenAI Assistants API to break down and execute complex automation tasks.
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

    @Argument(help: "Natural language description of the task to perform")
    var task: String

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
    
    /// Computed property for output mode based on flags
    private var outputMode: OutputMode {
        return quiet ? .quiet : (verbose ? .verbose : .compact)
    }

    mutating func run() async throws {
        // Load configuration defaults
        let config = PeekabooCore.ConfigurationManager.shared.getConfiguration()
        let agentConfig = config?.agent
        
        // Use command line args first, then config, then hardcoded defaults
        let effectiveModel = model ?? agentConfig?.defaultModel ?? "gpt-4-turbo"
        let effectiveMaxSteps = maxSteps ?? agentConfig?.maxSteps ?? 20
        // Get OpenAI API key
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            if self.jsonOutput {
                outputAgentJSON(createAgentErrorResponse(AgentError.missingAPIKey))
            } else {
                throw AgentError.missingAPIKey
            }
            return
        }

        let agent = OpenAIAgent(
            apiKey: apiKey,
            model: effectiveModel,
            verbose: self.outputMode == .verbose,
            maxSteps: effectiveMaxSteps,
            showThoughts: self.outputMode != .quiet,
            outputMode: self.outputMode)

        do {
            if self.outputMode != .quiet && !self.jsonOutput {
                switch self.outputMode {
                case .verbose:
                    print("\n═══════════════════════════════════════════════════════════════")
                    print(" PEEKABOO AGENT")
                    print("═══════════════════════════════════════════════════════════════\n")
                    print("Task: \"\(self.task)\"")
                    print("Model: \(effectiveModel)")
                    print("Max steps: \(effectiveMaxSteps)")
                    print("API Key: \(String(apiKey.prefix(10)))***")
                    print("\nInitializing agent...\n")
                case .compact:
                    print("\(TerminalColor.cyan)\(TerminalColor.bold)🤖 Peekaboo Agent\(TerminalColor.reset) \(TerminalColor.gray)(\(Version.fullVersion))\(TerminalColor.reset)")
                    print("\(TerminalColor.gray)Task: \(self.task)\(TerminalColor.reset)\n")
                case .quiet:
                    break
                }
            }

            let result = try await agent.executeTask(self.task, dryRun: self.dryRun)

            if self.jsonOutput {
                let response = AgentJSONResponse<OpenAIAgent.AgentResult>(
                    success: true,
                    data: result,
                    error: nil)
                outputAgentJSON(response)
            } else if self.outputMode == .quiet {
                // Quiet mode - only show final result
                if let summary = result.summary {
                    print(summary)
                } else {
                    print("✅ Task completed successfully!")
                }
            } else {
                // Compact mode - clean output with result
                if let summary = result.summary {
                    print("\n\(TerminalColor.green)\(TerminalColor.bold)✅ Task completed\(TerminalColor.reset)")
                    print("\(summary)")
                } else {
                    print("\n\(TerminalColor.green)\(TerminalColor.bold)✅ Task completed successfully!\(TerminalColor.reset)")
                }
            }
        } catch let error as AgentError {
            if jsonOutput {
                outputAgentJSON(createAgentErrorResponse(error))
            } else {
                throw error
            }
        } catch {
            if self.jsonOutput {
                outputAgentJSON(createAgentErrorResponse(AgentError.apiError(error.localizedDescription)))
            } else {
                throw error
            }
        }
    }
}

// MARK: - OpenAI Agent Implementation

@available(macOS 14.0, *)
struct OpenAIAgent {
    let apiKey: String
    let model: String
    let verbose: Bool
    let maxSteps: Int
    let showThoughts: Bool
    let outputMode: OutputMode

    private let session = URLSession.shared
    private let executor: AgentExecutor
    private let retryConfig = RetryConfiguration.default
    
    init(apiKey: String, model: String, verbose: Bool, maxSteps: Int, showThoughts: Bool = false, outputMode: OutputMode = .compact) {
        self.apiKey = apiKey
        self.model = model
        self.verbose = verbose
        self.maxSteps = maxSteps
        self.showThoughts = showThoughts
        self.outputMode = outputMode
        // Use direct PeekabooCore services for better performance
        self.executor = AgentExecutor(verbose: verbose)
    }

    struct AgentResult: Codable {
        let steps: [Step]
        let summary: String?
        let success: Bool

        struct Step: Codable {
            let description: String
            let command: String?
            let output: String?
            let screenshot: String? // Base64 encoded
        }
    }

    func executeTask(_ task: String, dryRun: Bool) async throws -> AgentResult {
        // Create session for this task
        let sessionId = await SessionManager.shared.createSession()

        // Create assistant
        if self.outputMode == .verbose {
            print("Setting up AI assistant...")
        }
        let assistant = try await createAssistant()
        if self.outputMode == .verbose {
            print("Assistant ready - ID: \(assistant.id)")
        }

        // Create thread
        if self.outputMode == .verbose {
            print("\nCreating conversation thread...")
        }
        let thread = try await createThread()
        if self.outputMode == .verbose {
            print("Thread created: \(thread.id)")
        }

        // Store IDs for cleanup
        let assistantId = assistant.id
        let threadId = thread.id

        defer {
            // Clean up assistant and thread
            Task {
                try? await deleteAssistant(assistantId)
                try? await deleteThread(threadId)
            }
        }

        // Add initial message
        if self.verbose {
            print("Adding task message to thread...")
        }
        try await self.addMessage(threadId: threadId, content: task)

        // Run the assistant
        var steps: [AgentResult.Step] = []
        var stepCount = 0

        // Create initial run
        if self.verbose {
            print("\nCreating initial run...")
        }
        let run = try await createRun(threadId: threadId, assistantId: assistant.id)
        if self.verbose {
            print("Run created: \(run.id) with status: \(run.status)")
        }

        // Process the run until it's completed or we hit max steps
        runLoop: while stepCount < self.maxSteps {
            // Poll for run status
            if self.verbose {
                print("Polling run status...")
            }
            var runStatus = try await getRun(threadId: threadId, runId: run.id)

            // Wait while in progress
            var pollCount = 0
            let thinkingMessages = [
                "Thinking about the best approach...",
                "Analyzing the situation...",
                "Coming up with a plan...",
                "Determining next steps...",
                "Processing the request..."
            ]
            
            while runStatus.status == .inProgress || runStatus.status == .queued {
                if self.outputMode == .compact, pollCount % 3 == 0 { // Show thinking every 3 seconds
                    let messageIndex = (pollCount / 3) % thinkingMessages.count
                    print("\r\(TerminalColor.dim)\(thinkingMessages[messageIndex])\(TerminalColor.reset)", terminator: "")
                    fflush(stdout)
                } else if self.outputMode == .verbose, pollCount % 5 == 0 { // Log every 5 seconds
                    print("Run \(run.id) status: \(runStatus.status) [\(pollCount)s]")
                }
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                runStatus = try await self.getRun(threadId: threadId, runId: run.id)
                pollCount += 1

                if pollCount > 60 { // 60 second timeout for any single wait
                    throw AgentError.timeout
                }
            }

            switch runStatus.status {
            case .requiresAction:
                // Handle function calls
                guard let toolCalls = runStatus.requiredAction?.submitToolOutputs.toolCalls else {
                    break
                }

                var toolOutputs: [(toolCallId: String, output: String)] = []

                for (_, toolCall) in toolCalls.enumerated() {
                    stepCount += 1
                    let commandName = toolCall.function.name.replacingOccurrences(of: "peekaboo_", with: "")
                    
                    // Clear any thinking message on the same line
                    if self.outputMode == .compact {
                        print("\r\(String(repeating: " ", count: 80))\r", terminator: "")
                    }
                    
                    if self.outputMode != .quiet, !dryRun {
                        switch self.outputMode {
                        case .verbose:
                            print("\n═══════════════════════════════════════════════════════")
                            print(" STEP \(stepCount): \(commandName.uppercased())")
                            print("═══════════════════════════════════════════════════════")
                        case .compact:
                            let icon = iconForCommand(commandName)
                            print("\(TerminalColor.blue)\(icon) \(commandName)\(TerminalColor.reset)", terminator: "")
                            fflush(stdout)
                        case .quiet:
                            break
                        }
                        
                        if self.outputMode == .verbose {
                            print("\nCommand: \(toolCall.function.name)")
                            print("Arguments: \(toolCall.function.arguments)")
                        } else if self.outputMode == .compact {
                            // Show compact argument summary
                            if let data = toolCall.function.arguments.data(using: .utf8),
                               let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                let summary = compactArgsSummary(commandName, args)
                                if !summary.isEmpty {
                                    print(" \(TerminalColor.gray)\(summary)\(TerminalColor.reset)", terminator: "")
                                }
                            }
                        }
                        
                        if self.outputMode != .quiet {
                            fflush(stdout)
                        }
                    }

                    let step = AgentResult.Step(
                        description: toolCall.function.name,
                        command: toolCall.function.arguments,
                        output: nil,
                        screenshot: nil)

                    if !dryRun {
                        // Add session ID to arguments only for commands that need it
                        var modifiedArgs = toolCall.function.arguments
                        let commandsNeedingSession = ["click", "type", "drag", "swipe"]
                        let commandName = toolCall.function.name.replacingOccurrences(of: "peekaboo_", with: "")

                        if commandsNeedingSession.contains(commandName) {
                            if let data = modifiedArgs.data(using: .utf8),
                               var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                            {
                                json["session_id"] = sessionId
                                if let newData = try? JSONSerialization.data(withJSONObject: json),
                                   let newString = String(data: newData, encoding: .utf8)
                                {
                                    modifiedArgs = newString
                                }
                            }
                        }

                        let output = try await executor.executeFunction(
                            name: toolCall.function.name,
                            arguments: modifiedArgs)
                        
                        if self.outputMode != .quiet {
                            // Parse output to show results nicely
                            if let data = output.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let success = json["success"] as? Bool {
                                
                                switch self.outputMode {
                                case .verbose:
                                    if success {
                                        print("\n✅ SUCCESS!")
                                    } else {
                                        print("\n❌ Command failed")
                                        if let error = json["error"] as? [String: Any],
                                           let message = error["message"] as? String {
                                            print("   Error: \(message)")
                                        }
                                    }
                                case .compact:
                                    if success {
                                        print(" \(TerminalColor.green)✓\(TerminalColor.reset)")
                                    } else {
                                        print(" \(TerminalColor.red)✗\(TerminalColor.reset)")
                                        if let error = json["error"] as? [String: Any],
                                           let message = error["message"] as? String {
                                            print(" \(TerminalColor.red)\(message)\(TerminalColor.reset)")
                                        }
                                    }
                                case .quiet:
                                    break
                                }
                            } else if self.outputMode == .verbose {
                                print("\n📝 Raw output: \(output.prefix(200))...")
                            }
                        }
                        
                        toolOutputs.append((toolCallId: toolCall.id, output: output))
                    }

                    steps.append(step)
                }

                if !dryRun {
                    // Submit tool outputs
                    if self.outputMode == .verbose {
                        print("\nSubmitting \(toolOutputs.count) tool outputs to run \(run.id)")
                        for output in toolOutputs {
                            print("  Tool \(output.toolCallId): \(output.output.prefix(100))...")
                        }
                    }
                    try await self.submitToolOutputs(
                        threadId: threadId,
                        runId: run.id,
                        toolOutputs: toolOutputs)

                    // Wait for the run to complete after submitting tool outputs
                    runStatus = try await self.getRun(threadId: threadId, runId: run.id)
                    while runStatus.status == .inProgress || runStatus.status == .queued {
                        if self.outputMode == .verbose {
                            print("Waiting for run to complete... (status: \(runStatus.status))")
                        }
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        runStatus = try await self.getRun(threadId: threadId, runId: run.id)
                    }

                    // Continue with the same run - it might need more actions
                    if self.outputMode == .verbose {
                        print("Continuing with run \(run.id) after tool outputs...")
                    }
                    // Loop will continue to poll the same run
                }

            case .completed:
                // Get the final message
                if self.outputMode == .verbose {
                    print("\n═══════════════════════════════════════════════════════")
                    print(" TASK COMPLETED")
                    print("═══════════════════════════════════════════════════════")
                }
                let messages = try await getMessages(threadId: threadId)
                let summary = messages.first?.content.first?.text?.value
                if self.outputMode == .verbose, let summary {
                    print("\n═══════════════════════════════════════════════════════")
                    print(" RESULT")
                    print("═══════════════════════════════════════════════════════")
                    print("\n\(summary)")
                }

                // Clean up session
                await SessionManager.shared.removeSession(sessionId)

                return AgentResult(
                    steps: steps,
                    summary: summary,
                    success: true)

            case .failed, .cancelled, .expired:
                throw AgentError.apiError("Assistant run failed with status: \(runStatus.status)")

            case .cancelling:
                // Wait for cancellation to complete
                if self.outputMode == .verbose {
                    print("Waiting for run cancellation...")
                }
                try await Task.sleep(nanoseconds: 1_000_000_000)
                continue

            case .queued, .inProgress:
                // Should not happen here, but continue if it does
                continue
            }
        }

        // Clean up session
        await SessionManager.shared.removeSession(sessionId)

        return AgentResult(
            steps: steps,
            summary: "I completed \(stepCount) steps but the agent did not provide a specific summary. The task appears to have been executed.",
            success: true)
    }

    // MARK: - Assistant Management

    private func createAssistant() async throws -> Assistant {
        let tools = [
            Self.makePeekabooTool("see", "Capture screenshot and analyze what's visible with vision AI"),
            Self.makePeekabooTool("click", "Click on UI elements or coordinates"),
            Self.makePeekabooTool("type", "Type text into UI elements"),
            Self.makePeekabooTool("scroll", "Scroll content in any direction"),
            Self.makePeekabooTool("hotkey", "Press keyboard shortcuts"),
            Self.makePeekabooTool("image", "Capture screenshots of apps or screen"),
            Self.makePeekabooTool(
                "window",
                "Manipulate application windows (close, minimize, maximize, move, resize, focus)"),
            Self.makePeekabooTool("app", "Control applications (launch, quit, focus, hide, unhide)"),
            Self.makePeekabooTool("wait", "Wait for a specified duration in seconds"),
            Self.makePeekabooTool(
                "analyze_screenshot",
                "Analyze a screenshot using vision AI to understand UI elements and content"),
            Self.makePeekabooTool(
                "list",
                "List all running applications on macOS. Use with target='apps' to get a list of all running applications."),
            Self.makePeekabooTool(
                "menu",
                "Interact with menu bar: use 'list' subcommand to discover all menus, 'click' to click menu items"),
            Self.makePeekabooTool(
                "dialog",
                "Interact with system dialogs and alerts (click buttons, input text, dismiss)"),
            Self.makePeekabooTool("drag", "Perform drag and drop operations between UI elements or coordinates"),
            Self.makePeekabooTool("dock", "Interact with the macOS Dock (launch apps, right-click items)"),
            Self.makePeekabooTool("swipe", "Perform swipe gestures for navigation and scrolling"),
            Self.makePeekabooTool("shell", "Execute shell commands (use for opening URLs with 'open', running CLI tools, etc)"),
        ]

        let assistantRequest = CreateAssistantRequest(
            model: model,
            name: "Peekaboo Agent",
            description: "An AI agent that can see and interact with macOS UI",
            instructions: """
            You are a helpful AI agent that can see and interact with the macOS desktop.
            You have access to comprehensive Peekaboo commands for UI automation:

            VISION & SCREENSHOTS:
            - 'see': Capture screenshots and map UI elements (use analyze=true for vision analysis)
              The see command also extracts menu bar information showing available menus
            - 'analyze_screenshot': Analyze any screenshot with vision AI
            - 'image': Take screenshots of specific apps or screens

            UI INTERACTION:
            - 'click': Click on elements or coordinates
            - 'type': Type text into the currently focused element (no element parameter needed)
              NOTE: To press Enter after typing, use a separate 'hotkey' command with ["return"]
              For efficiency, group related actions when possible
            - 'scroll': Scroll in any direction
            - 'hotkey': Press keyboard shortcuts - provide keys as array: ["cmd", "s"] or ["cmd", "shift", "d"]
              Common: ["return"] for Enter, ["tab"] for Tab, ["escape"] for Escape
            - 'drag': Drag and drop between elements
            - 'swipe': Perform swipe gestures

            APPLICATION CONTROL:
            - 'app': Launch, quit, focus, hide, or unhide applications
            - 'window': Close, minimize, maximize, move, resize, or focus windows
            - 'menu': Menu bar interaction - use subcommand='list' to discover menus, subcommand='click' to click items
              Example: menu(app="Calculator", subcommand="list") to list all menus
              Note: Use plain ellipsis "..." instead of Unicode "…" in menu paths (e.g., "Save..." not "Save…")
            - 'dock': Interact with Dock items
            - 'dialog': Handle system dialogs and alerts

            DISCOVERY & UTILITY:
            - 'list': List running apps or windows - USE THIS TO LIST APPLICATIONS!
            - 'wait': Pause execution for specified duration - AVOID USING THIS unless absolutely necessary
              Instead of waiting, use 'see' again if content seems to be loading

            When given a task:
            1. **TO LIST APPLICATIONS**: Use 'list' with target='apps' - DO NOT use Activity Monitor or screenshots!
            2. **TO LIST WINDOWS**: Use 'list' with target='windows' and app='AppName'
            3. **TO DISCOVER MENUS**: Use 'menu list --app AppName' to get full menu structure OR 'see' command which includes basic menu_bar data
            4. For UI interaction: Use 'see' to capture screenshots and map UI elements
            5. Break down complex tasks into MINIMAL specific actions
            6. Execute each action ONCE before retrying - don't repeat failed patterns
            7. Verify results only when necessary for the task
            
            FINAL RESPONSE REQUIREMENTS:
            - ALWAYS provide a meaningful final message that summarizes what you accomplished
            - For information retrieval (weather, search results, etc.): Include the actual information found
            - For actions/tasks: Describe what was done and confirm success or explain any issues
            - Be specific about the outcome - avoid generic "task completed" messages
            - Examples:
              - Information: "The weather in London is currently 15°C with cloudy skies and 70% humidity."
              - Action success: "I've opened Safari and navigated to the Apple homepage. The page is now displayed."
              - Action with issues: "I opened TextEdit but couldn't find a save button. The document remains unsaved."
            - Use 'see' with analyze=true when you need to understand or verify what's on screen
            
            IMPORTANT APP BEHAVIORS & OPTIMIZATIONS:
            - ALWAYS check window_count in app launch response BEFORE any other action
            - Safari launch pattern:
              1. Launch Safari and check window_count
              2. If window_count = 0, wait ONE second (agent processing time), then try 'see' ONCE
              3. If 'see' still fails, use 'app' focus command, then 'hotkey' ["cmd", "n"] ONCE
              4. Do NOT repeat the see/cmd+n pattern multiple times
            - STOP trying if a window is created - one window is enough
            - Browser windows may take 1-2 seconds to fully appear after launch
            - NEVER use 'wait' commands - the agent processing time provides natural delays
            - If content appears to be loading, use 'see' again instead of 'wait'
            - BE EFFICIENT: Minimize redundant commands and retries
            
            SAVING FILES:
            - After opening Save dialog, type the filename then use 'hotkey' with ["cmd", "s"] or ["return"] to save
            - To navigate to Desktop in save dialog: use 'hotkey' with ["cmd", "shift", "d"]

            EFFICIENCY & TIMING:
            - Your processing time naturally adds 1-2 seconds between commands - use this instead of 'wait'
            - One retry is usually enough - if something fails twice, try a different approach
            - For Safari/browser launches: Allow 2-3 seconds total for window to appear (your thinking time counts)
            - Reduce steps by combining related actions when possible
            - Each command costs time - optimize for minimal command count
            
            WEB SEARCH & INFORMATION RETRIEVAL:
            When asked to find information online (weather, news, facts, etc.):
            
            PREFERRED METHOD - Using shell command:
            1. Use shell(command="open https://www.google.com/search?q=weather+in+london+forecast")
               This opens the URL in the user's default browser automatically
            2. Wait a moment for the page to load
            3. Use 'see' with analyze=true to read the search results
            4. Extract and report the relevant information
            
            ALTERNATIVE METHOD - Manual browser control:
            1. First check for running browsers using: list(target="apps")
               Common browsers: Safari, Google Chrome, Firefox, Arc, Brave, Microsoft Edge, Opera
            2. If a browser is running:
               - Focus it using: app(action="focus", name="BrowserName")
               - Open new tab: hotkey(keys=["cmd", "t"])
            3. If no browser is running:
               - Try launching browsers OR use shell(command="open https://...")
            4. Once browser window is open:
               - Navigate to address bar: hotkey(keys=["cmd", "l"])
               - Type your search query
               - Press Enter: hotkey(keys=["return"])
            
            SHELL COMMAND USAGE:
            - shell(command="open https://google.com") - Opens URL in default browser
            - shell(command="open -a Safari https://example.com") - Opens in specific browser
            - shell(command="curl -s https://api.example.com") - Fetch API data directly
            - shell(command="echo 'Hello World'") - Run any shell command
            - Always check the success field in response
            - IMPORTANT: Quote URLs with special characters to prevent shell expansion errors:
              ✓ shell(command="open 'https://www.google.com/search?q=weather+forecast'")
              ✗ shell(command="open https://www.google.com/search?q=weather+forecast") - fails with "no matches found"
            
            CRITICAL INSTRUCTIONS:
            - When asked to "list applications" or "show running apps", ALWAYS use: list(target="apps")
            - Do NOT launch Activity Monitor to list apps - use the list command!
            - Do NOT take screenshots to find running apps - use the list command!
            - MINIMIZE command usage - be efficient and avoid redundant operations
            - STOP repeating failed command patterns - try something different
            - For web information: ALWAYS try to search using Safari - don't say you can't access the web!

            Always maintain session_id across related commands for element tracking.
            Be precise with UI interactions and verify the current state before acting.
            
            REMEMBER: Your final message is what the user sees as the result. Make it informative and specific to what you accomplished or discovered. For web searches, include the actual information you found.
            """,
            tools: tools)

        let url = URL(string: "https://api.openai.com/v1/assistants")!
        var request = URLRequest.openAIRequest(url: url, apiKey: self.apiKey, betaHeader: "assistants=v2")
        try request.setJSONBody(assistantRequest)

        return try await self.session.retryableDataTask(
            for: request,
            decodingType: Assistant.self,
            retryConfig: self.retryConfig)
    }

    private func deleteAssistant(_ assistantId: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/assistants/\(assistantId)")!
        let request = URLRequest.openAIRequest(
            url: url,
            method: "DELETE",
            apiKey: self.apiKey,
            betaHeader: "assistants=v2")

        _ = try await self.session.retryableData(for: request, retryConfig: self.retryConfig)
    }

    private func deleteThread(_ threadId: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)")!
        let request = URLRequest.openAIRequest(
            url: url,
            method: "DELETE",
            apiKey: self.apiKey,
            betaHeader: "assistants=v2")

        _ = try await self.session.retryableData(for: request, retryConfig: self.retryConfig)
    }

    private func createThread() async throws -> Thread {
        let url = URL(string: "https://api.openai.com/v1/threads")!
        var request = URLRequest.openAIRequest(url: url, apiKey: self.apiKey, betaHeader: "assistants=v2")
        request.httpBody = "{}".data(using: .utf8)

        return try await self.session.retryableDataTask(
            for: request,
            decodingType: Thread.self,
            retryConfig: self.retryConfig)
    }

    private func addMessage(threadId: String, content: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/messages")!
        var request = URLRequest.openAIRequest(url: url, apiKey: self.apiKey, betaHeader: "assistants=v2")

        let message = ["role": "user", "content": content]
        request.httpBody = try JSONSerialization.data(withJSONObject: message)

        _ = try await self.session.retryableData(for: request, retryConfig: self.retryConfig)
    }

    private func createRun(threadId: String, assistantId: String) async throws -> Run {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs")!
        var request = URLRequest.openAIRequest(url: url, apiKey: self.apiKey, betaHeader: "assistants=v2")

        let runData = ["assistant_id": assistantId]
        request.httpBody = try JSONSerialization.data(withJSONObject: runData)

        do {
            return try await self.session.retryableDataTask(
                for: request,
                decodingType: Run.self,
                retryConfig: self.retryConfig)
        } catch let error as AgentError {
            // If thread already has active run, wait and retry
            if case let .apiError(message) = error,
               message.contains("already has an active run")
            {
                // Extract the run ID from error message like "run_abc123"
                let components = message.components(separatedBy: " ")
                if let runIdComponent = components.last(where: { $0.starts(with: "run_") }) {
                    let existingRunId = runIdComponent.trimmingCharacters(in: .punctuationCharacters)

                    if verbose {
                        print("Found existing run: \(existingRunId), checking status...")
                    }

                    // Check the status of the existing run
                    do {
                        let existingRun = try await getRun(threadId: threadId, runId: existingRunId)

                        if verbose {
                            print("   Existing run status: \(existingRun.status)")
                        }

                        // If the run is done, try creating a new one immediately
                        if existingRun.status == .completed || existingRun.status == .failed ||
                            existingRun.status == .cancelled || existingRun.status == .expired
                        {
                            if verbose {
                                print("   Run is finished, creating new run...")
                            }
                            return try await session.retryableDataTask(
                                for: request,
                                decodingType: Run.self,
                                retryConfig: retryConfig)
                        }

                        // If run requires action, we need to handle it differently
                        if existingRun.status == .requiresAction {
                            if verbose {
                                print("   Run requires action - cancelling it...")
                            }

                            // Cancel the existing run that's waiting for tool outputs
                            try await cancelRun(threadId: threadId, runId: existingRunId)

                            // Wait a moment for cancellation to process
                            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                            // Now create a new run
                            return try await session.retryableDataTask(
                                for: request,
                                decodingType: Run.self,
                                retryConfig: retryConfig)
                        }

                        // If still in progress, wait for it
                        if existingRun.status == .inProgress || existingRun.status == .queued {
                            if verbose {
                                print("   Run still in progress, waiting...")
                            }

                            // Poll until the run completes
                            var pollCount = 0
                            while pollCount < 10 { // Max 10 seconds
                                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                                let status = try await getRun(threadId: threadId, runId: existingRunId)

                                if status.status != .inProgress, status.status != .queued {
                                    if verbose {
                                        print("   Existing run completed with status: \(status.status)")
                                    }
                                    break
                                }
                                pollCount += 1
                            }

                            // Try creating a new run now
                            return try await session.retryableDataTask(
                                for: request,
                                decodingType: Run.self,
                                retryConfig: retryConfig)
                        }
                    } catch {
                        if verbose {
                            print("   Could not check existing run status: \(error)")
                        }
                    }
                }

                // Fallback to simple wait and retry
                if verbose {
                    print("Thread has active run, waiting...")
                }
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds

                // Try once more
                return try await session.retryableDataTask(
                    for: request,
                    decodingType: Run.self,
                    retryConfig: retryConfig)
            }
            throw error
        }
    }

    private func getRun(threadId: String, runId: String) async throws -> Run {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs/\(runId)")!
        let request = URLRequest.openAIRequest(
            url: url,
            method: "GET",
            apiKey: self.apiKey,
            betaHeader: "assistants=v2")

        return try await self.session.retryableDataTask(
            for: request,
            decodingType: Run.self,
            retryConfig: self.retryConfig)
    }

    private func submitToolOutputs(
        threadId: String,
        runId: String,
        toolOutputs: [(toolCallId: String, output: String)]) async throws
    {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs/\(runId)/submit_tool_outputs")!
        var request = URLRequest.openAIRequest(url: url, apiKey: self.apiKey, betaHeader: "assistants=v2")

        let outputs = toolOutputs.map { ["tool_call_id": $0.toolCallId, "output": $0.output] }
        let data = ["tool_outputs": outputs]
        request.httpBody = try JSONSerialization.data(withJSONObject: data)

        _ = try await self.session.retryableData(for: request, retryConfig: self.retryConfig)
    }

    private func getMessages(threadId: String) async throws -> [Message] {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/messages")!
        let request = URLRequest.openAIRequest(
            url: url,
            method: "GET",
            apiKey: self.apiKey,
            betaHeader: "assistants=v2")

        let messageList = try await session.retryableDataTask(
            for: request,
            decodingType: MessageList.self,
            retryConfig: self.retryConfig)
        return messageList.data
    }

    private func cancelRun(threadId: String, runId: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/threads/\(threadId)/runs/\(runId)/cancel")!
        var request = URLRequest.openAIRequest(url: url, apiKey: self.apiKey, betaHeader: "assistants=v2")
        request.httpBody = "{}".data(using: .utf8)

        _ = try await self.session.retryableData(for: request, retryConfig: self.retryConfig)
    }
}

// MARK: - OpenAI API Types

struct Message: Codable {
    let id: String
    let role: String
    let content: [Content]

    struct Content: Codable {
        let type: String
        let text: TextContent?

        struct TextContent: Codable {
            let value: String
        }
    }
}

struct MessageList: Codable {
    let data: [Message]
}

struct Assistant: Codable {
    let id: String
    let object: String
    let createdAt: Int
}

struct Thread: Codable {
    let id: String
    let object: String
    let createdAt: Int
}

struct Run: Codable {
    let id: String
    let object: String
    let status: Status
    let requiredAction: RequiredAction?

    enum Status: String, Codable {
        case queued
        case inProgress = "in_progress"
        case requiresAction = "requires_action"
        case cancelling
        case cancelled
        case failed
        case completed
        case expired
    }

    struct RequiredAction: Codable {
        let type: String
        let submitToolOutputs: SubmitToolOutputs

        struct SubmitToolOutputs: Codable {
            let toolCalls: [ToolCall]
        }
    }

    struct ToolCall: Codable {
        let id: String
        let type: String
        let function: FunctionCall

        struct FunctionCall: Codable {
            let name: String
            let arguments: String
        }
    }
}

struct CreateAssistantRequest: Codable {
    let model: String
    let name: String
    let description: String
    let instructions: String
    let tools: [Tool]
}

struct Tool: Codable {
    let type: String
    let function: FunctionDefinition
}
