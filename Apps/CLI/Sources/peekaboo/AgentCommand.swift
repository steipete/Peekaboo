import ArgumentParser
import Foundation

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

    @Flag(name: .shortAndLong, help: "Enable verbose output showing agent reasoning")
    var verbose = false
    
    @Flag(name: .long, help: "Show detailed agent thoughts and reasoning")
    var showThoughts = false

    @Flag(name: .long, help: "Dry run - show planned steps without executing")
    var dryRun = false

    @Option(name: .long, help: "Maximum number of steps the agent can take")
    var maxSteps = 20

    @Option(name: .long, help: "OpenAI model to use")
    var model = "gpt-4-turbo"

    @Flag(name: .long, help: "Output in JSON format")
    var jsonOutput = false

    mutating func run() async throws {
        // Get OpenAI API key
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            if self.jsonOutput {
                outputAgentJSON(createAgentErrorResponse(.missingAPIKey))
            } else {
                throw AgentError.missingAPIKey
            }
            return
        }

        let agent = OpenAIAgent(
            apiKey: apiKey,
            model: model,
            verbose: verbose || showThoughts,
            maxSteps: maxSteps,
            showThoughts: showThoughts)

        do {
            if (self.verbose || self.showThoughts), !self.jsonOutput {
                print("\n🎭 ═══════════════════════════════════════════════════════════════")
                print("🎭 PEEKABOO AGENT COMEDY SHOW")
                print("🎭 ═══════════════════════════════════════════════════════════════\n")
                print("🎯 Task: \"\(self.task)\"")
                print("🧠 Model: \(self.model)")
                print("🔢 Max steps: \(self.maxSteps)")
                print("🔑 API Key: \(String(apiKey.prefix(10)))***")
                print("\n✨ Let the show begin! ✨\n")
            }

            let result = try await agent.executeTask(self.task, dryRun: self.dryRun)

            if self.jsonOutput {
                let response = AgentJSONResponse(
                    success: true,
                    data: result,
                    error: nil)
                outputAgentJSON(response)
            } else if !(self.verbose || self.showThoughts) {
                // Simple human-readable output when not in verbose/showThoughts mode
                print("\n✅ Task completed successfully!")
                print("\nSteps executed:")
                for (index, step) in result.steps.enumerated() {
                    print("\n\(index + 1). \(step.description)")
                    if let output = step.output {
                        print("   Result: \(output)")
                    }
                }

                if let summary = result.summary {
                    print("\n📝 Summary: \(summary)")
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
                outputAgentJSON(createAgentErrorResponse(.apiError(error.localizedDescription)))
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

    private let session = URLSession.shared
    private let executor: AgentInternalExecutor
    private let retryConfig = RetryConfiguration.default
    
    init(apiKey: String, model: String, verbose: Bool, maxSteps: Int, showThoughts: Bool = false) {
        self.apiKey = apiKey
        self.model = model
        self.verbose = verbose
        self.maxSteps = maxSteps
        self.showThoughts = showThoughts
        // Use internal executor for better performance
        self.executor = AgentInternalExecutor(verbose: verbose)
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
        if self.verbose || self.showThoughts {
            print("🔧 Setting up the AI assistant...")
            if self.showThoughts {
                print("   💭 \"I need to understand how to control the Mac...\"")
                print("   💭 \"Loading my knowledge about UI automation...\"")
            }
        }
        let assistant = try await createAssistant()
        if self.verbose || self.showThoughts {
            print("✅ Assistant ready! ID: \(assistant.id)")
            if self.showThoughts {
                print("   💭 \"Perfect! I can see screens, click things, and type text!\"")
            }
        }

        // Create thread
        if self.verbose || self.showThoughts {
            print("\n📋 Creating conversation thread...")
            if self.showThoughts {
                print("   💭 \"Starting a new conversation about: \(task)\"")
            }
        }
        let thread = try await createThread()
        if self.verbose || self.showThoughts {
            print("✅ Thread created: \(thread.id)")
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
            print("📝 Adding task message to thread...")
        }
        try await self.addMessage(threadId: threadId, content: task)

        // Run the assistant
        var steps: [AgentResult.Step] = []
        var stepCount = 0

        // Create initial run
        if self.verbose {
            print("\n🏃 Creating initial run...")
        }
        let run = try await createRun(threadId: threadId, assistantId: assistant.id)
        if self.verbose {
            print("✅ Run created: \(run.id) with status: \(run.status)")
        }

        // Process the run until it's completed or we hit max steps
        runLoop: while stepCount < self.maxSteps {
            // Poll for run status
            if self.verbose {
                print("🔍 Polling run status...")
            }
            var runStatus = try await getRun(threadId: threadId, runId: run.id)

            // Wait while in progress
            var pollCount = 0
            let thinkingMessages = [
                "🤔 Thinking about the best approach...",
                "🧠 Analyzing the situation...",
                "💡 Coming up with a plan...",
                "🎯 Determining next steps...",
                "✨ Working my AI magic..."
            ]
            
            while runStatus.status == .inProgress || runStatus.status == .queued {
                if self.showThoughts, pollCount % 3 == 0 { // Show thinking every 3 seconds
                    let messageIndex = (pollCount / 3) % thinkingMessages.count
                    print(thinkingMessages[messageIndex])
                } else if self.verbose, pollCount % 5 == 0 { // Log every 5 seconds
                    print("⏳ Run \(run.id) status: \(runStatus.status) [\(pollCount)s]")
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
                    
                    if self.verbose || self.showThoughts, !dryRun {
                        print("\n🎬 ═══════════════════════════════════════════════════════")
                        print("🎬 STEP \(stepCount): \(toolCall.function.name.replacingOccurrences(of: "peekaboo_", with: "").uppercased())")
                        print("🎬 ═══════════════════════════════════════════════════════")
                        
                        if self.showThoughts {
                            // Parse the command to show what the agent is thinking
                            let commandName = toolCall.function.name.replacingOccurrences(of: "peekaboo_", with: "")
                            if let data = toolCall.function.arguments.data(using: .utf8),
                               let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                
                                switch commandName {
                                case "see":
                                    print("   💭 \"Let me take a screenshot to see what's on screen...\"")
                                    if let app = args["app"] as? String {
                                        print("   💭 \"I'll focus on the \(app) application\"")
                                    }
                                case "click":
                                    if let element = args["element"] as? String {
                                        print("   💭 \"I need to click on '\(element)'...\"")
                                    } else if let x = args["x"], let y = args["y"] {
                                        print("   💭 \"I'll click at coordinates (\(x), \(y))\"")
                                    }
                                case "type":
                                    if let text = args["text"] as? String {
                                        print("   💭 \"Time to type: '\(text)'\"")
                                        print("   💭 \"I'll make sure to type it carefully...\"")
                                    }
                                case "app":
                                    if let action = args["action"] as? String, let name = args["name"] as? String {
                                        print("   💭 \"I need to \(action) the \(name) application\"")
                                    }
                                case "window":
                                    if let action = args["action"] as? String {
                                        print("   💭 \"Let me \(action) this window...\"")
                                    }
                                case "hotkey":
                                    if let keys = args["keys"] as? [String] {
                                        print("   💭 \"Pressing shortcut: \(keys.joined(separator: "+"))\"")
                                    }
                                case "wait":
                                    if let duration = args["duration"] as? Double {
                                        print("   💭 \"I'll wait \(duration) seconds for things to settle...\"")
                                    }
                                default:
                                    print("   💭 \"Executing \(commandName) command...\"")
                                }
                            }
                        }
                        
                        print("\n🔧 Command: \(toolCall.function.name)")
                        print("📊 Arguments: \(toolCall.function.arguments)")
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

                        if self.showThoughts {
                            print("\n⏳ Executing command...")
                        }
                        
                        let output = try await executor.executeFunction(
                            name: toolCall.function.name,
                            arguments: modifiedArgs)
                        
                        if self.verbose || self.showThoughts {
                            // Parse output to show results nicely
                            if let data = output.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let success = json["success"] as? Bool {
                                
                                if success {
                                    print("\n✅ SUCCESS!")
                                    
                                    if self.showThoughts {
                                        let commandName = toolCall.function.name.replacingOccurrences(of: "peekaboo_", with: "")
                                        switch commandName {
                                        case "see":
                                            if let resultData = json["data"] as? [String: Any],
                                               let elements = resultData["elements"] as? [[String: Any]] {
                                                print("   💭 \"I can see \(elements.count) UI elements on the screen!\"")
                                                if elements.count > 3 {
                                                    print("   💭 \"Let me show you the first few...\"")
                                                    for (idx, element) in elements.prefix(3).enumerated() {
                                                        if let desc = element["description"] as? String {
                                                            print("   📍 Element \(idx + 1): \(desc)")
                                                        }
                                                    }
                                                }
                                            }
                                        case "click":
                                            print("   💭 \"Click successful! The UI should be responding now...\"")
                                        case "type":
                                            print("   💭 \"Text typed successfully!\"")
                                        case "app":
                                            print("   💭 \"Application command executed!\"")
                                        case "wait":
                                            print("   💭 \"Waited patiently... Ready for the next step!\"")
                                        default:
                                            print("   💭 \"Command completed successfully!\"")
                                        }
                                    }
                                } else {
                                    print("\n❌ Command failed")
                                    if let error = json["error"] as? [String: Any],
                                       let message = error["message"] as? String {
                                        print("   Error: \(message)")
                                    }
                                }
                            } else if self.verbose {
                                print("\n📝 Raw output: \(output.prefix(200))...")
                            }
                        }
                        
                        toolOutputs.append((toolCallId: toolCall.id, output: output))
                    }

                    steps.append(step)
                }

                if !dryRun {
                    // Submit tool outputs
                    if self.verbose {
                        print("📤 Submitting \(toolOutputs.count) tool outputs to run \(run.id)")
                        for output in toolOutputs {
                            print("   Tool \(output.toolCallId): \(output.output.prefix(100))...")
                        }
                    }
                    try await self.submitToolOutputs(
                        threadId: threadId,
                        runId: run.id,
                        toolOutputs: toolOutputs)

                    // Wait for the run to complete after submitting tool outputs
                    runStatus = try await self.getRun(threadId: threadId, runId: run.id)
                    while runStatus.status == .inProgress || runStatus.status == .queued {
                        if self.verbose {
                            print("⏳ Waiting for run to complete... (status: \(runStatus.status))")
                        }
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        runStatus = try await self.getRun(threadId: threadId, runId: run.id)
                    }

                    // Continue with the same run - it might need more actions
                    if self.verbose {
                        print("🔄 Continuing with run \(run.id) after tool outputs...")
                    }
                    // Loop will continue to poll the same run
                }

            case .completed:
                // Get the final message
                if self.verbose || self.showThoughts {
                    print("\n🎉 ═══════════════════════════════════════════════════════")
                    print("🎉 TASK COMPLETED!")
                    print("🎉 ═══════════════════════════════════════════════════════")
                }
                let messages = try await getMessages(threadId: threadId)
                let summary = messages.first?.content.first?.text?.value
                if (self.verbose || self.showThoughts), let summary {
                    print("\n📋 Agent's Summary:")
                    print("   \"\(summary)\"")
                    
                    if self.showThoughts {
                        print("\n   💭 \"That was fun! I completed \(stepCount) steps to finish your task!\"")
                        print("   💭 \"Hope you enjoyed the show! 🎭\"")
                    }
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
                if self.verbose {
                    print("⏳ Waiting for run cancellation...")
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
            summary: "Task completed after \(stepCount) steps",
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
            - 'scroll': Scroll in any direction
            - 'hotkey': Press keyboard shortcuts - provide keys as array: ["cmd", "s"] or ["cmd", "shift", "d"]
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
            - 'wait': Pause execution for specified duration

            When given a task:
            1. **TO LIST APPLICATIONS**: Use 'list' with target='apps' - DO NOT use Activity Monitor or screenshots!
            2. **TO LIST WINDOWS**: Use 'list' with target='windows' and app='AppName'
            3. **TO DISCOVER MENUS**: Use 'menu list --app AppName' to get full menu structure OR 'see' command which includes basic menu_bar data
            4. For UI interaction: Use 'see' to capture screenshots and map UI elements
            5. Break down complex tasks into specific actions
            6. Execute each action using the appropriate command
            7. Verify results when needed
            
            IMPORTANT APP BEHAVIORS:
            - Check window_count in app launch response
            - If window_count is 0, the app has no windows - use 'hotkey' ["cmd", "n"] to create new document/window
            - Document-based apps (text editors, note apps, etc.) often launch without windows
            
            SAVING FILES:
            - After opening Save dialog, type the filename then use 'hotkey' with ["cmd", "s"] or ["return"] to save
            - To navigate to Desktop in save dialog: use 'hotkey' with ["cmd", "shift", "d"]

            CRITICAL INSTRUCTIONS:
            - When asked to "list applications" or "show running apps", ALWAYS use: list(target="apps")
            - Do NOT launch Activity Monitor to list apps - use the list command!
            - Do NOT take screenshots to find running apps - use the list command!

            Always maintain session_id across related commands for element tracking.
            Be precise with UI interactions and verify the current state before acting.
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
                        print("⏳ Found existing run: \(existingRunId), checking status...")
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
                    print("⏳ Thread has active run, waiting...")
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
