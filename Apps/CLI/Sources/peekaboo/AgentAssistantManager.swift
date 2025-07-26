import Foundation

/// Manages a shared, reusable OpenAI Assistant for Peekaboo agents
/// Instead of creating/deleting assistants for each command, we maintain one persistent assistant
@available(macOS 14.0, *)
actor AgentAssistantManager {
    private var cachedAssistant: Assistant?
    private let apiKey: String
    private let model: String
    private let session = URLSession.shared
    private let retryConfig = RetryConfiguration.default
    
    // Configuration hash to detect when we need to recreate the assistant
    private var lastConfigHash: String?
    
    init(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model
    }
    
    /// Get or create the shared assistant, recreating only if configuration changed
    func getOrCreateAssistant() async throws -> Assistant {
        let currentConfigHash = generateConfigHash()
        
        // If we have a cached assistant and config hasn't changed, reuse it
        if let existing = cachedAssistant, lastConfigHash == currentConfigHash {
            // Verify the assistant still exists on OpenAI's side
            if await verifyAssistantExists(existing.id) {
                return existing
            } else {
                // Assistant was deleted externally, clear cache
                cachedAssistant = nil
                lastConfigHash = nil
            }
        }
        
        // Create new assistant
        let assistant = try await createNewAssistant()
        cachedAssistant = assistant
        lastConfigHash = currentConfigHash
        
        return assistant
    }
    
    /// Clean up the shared assistant (call this on app termination)
    func cleanup() async {
        if let assistant = cachedAssistant {
            try? await deleteAssistant(assistant.id)
            cachedAssistant = nil
            lastConfigHash = nil
        }
    }
    
    // MARK: - Private Methods
    
    private func generateConfigHash() -> String {
        // Hash the configuration that affects assistant behavior
        let configString = "\(model)-\(getToolsDefinition())-\(getSystemPrompt())"
        return String(configString.hashValue)
    }
    
    private func verifyAssistantExists(_ assistantId: String) async -> Bool {
        let url = URL(string: "https://api.openai.com/v1/assistants/\(assistantId)")!
        let request = URLRequest.openAIRequest(
            url: url,
            method: "GET", 
            apiKey: apiKey,
            betaHeader: "assistants=v2")
        
        do {
            _ = try await session.retryableDataTask(
                for: request,
                decodingType: Assistant.self,
                retryConfig: retryConfig)
            return true
        } catch {
            return false
        }
    }
    
    private func createNewAssistant() async throws -> Assistant {
        let tools = getToolsDefinition()
        
        let assistantRequest = CreateAssistantRequest(
            model: model,
            name: "Peekaboo Agent",
            description: "An AI agent that can see and interact with macOS UI",
            instructions: getSystemPrompt(),
            tools: tools)
        
        let url = URL(string: "https://api.openai.com/v1/assistants")!
        var request = URLRequest.openAIRequest(url: url, apiKey: apiKey, betaHeader: "assistants=v2")
        try request.setJSONBody(assistantRequest)
        
        return try await session.retryableDataTask(
            for: request,
            decodingType: Assistant.self,
            retryConfig: retryConfig)
    }
    
    private func deleteAssistant(_ assistantId: String) async throws {
        let url = URL(string: "https://api.openai.com/v1/assistants/\(assistantId)")!
        let request = URLRequest.openAIRequest(
            url: url,
            method: "DELETE",
            apiKey: apiKey,
            betaHeader: "assistants=v2")
        
        _ = try await session.retryableData(for: request, retryConfig: retryConfig)
    }
    
    private func getToolsDefinition() -> [Tool] {
        return [
            OpenAIAgent.makePeekabooTool("see", "Capture screenshot and analyze what's visible with vision AI"),
            OpenAIAgent.makePeekabooTool("click", "Click on UI elements or coordinates"),
            OpenAIAgent.makePeekabooTool("type", "Type text into UI elements"),
            OpenAIAgent.makePeekabooTool("scroll", "Scroll content in any direction"),
            OpenAIAgent.makePeekabooTool("hotkey", "Press keyboard shortcuts"),
            OpenAIAgent.makePeekabooTool("image", "Capture screenshots of apps or screen"),
            OpenAIAgent.makePeekabooTool(
                "window",
                "Manipulate application windows (close, minimize, maximize, move, resize, focus)"),
            OpenAIAgent.makePeekabooTool("app", "Control applications (launch, quit, focus, hide, unhide)"),
            OpenAIAgent.makePeekabooTool("wait", "Wait for a specified duration in seconds"),
            OpenAIAgent.makePeekabooTool(
                "analyze_screenshot",
                "Analyze a screenshot using vision AI to understand UI elements and content"),
            OpenAIAgent.makePeekabooTool(
                "list",
                "List all running applications on macOS. Use with target='apps' to get a list of all running applications."),
            OpenAIAgent.makePeekabooTool(
                "menu",
                "Interact with menu bar: use 'list' subcommand to discover all menus, 'click' to click menu items"),
            OpenAIAgent.makePeekabooTool(
                "dialog",
                "Interact with system dialogs and alerts (click buttons, input text, dismiss)"),
            OpenAIAgent.makePeekabooTool("drag", "Perform drag and drop operations between UI elements or coordinates"),
            OpenAIAgent.makePeekabooTool("dock", "Interact with the macOS Dock (launch apps, right-click items)"),
            OpenAIAgent.makePeekabooTool("swipe", "Perform swipe gestures for navigation and scrolling"),
            OpenAIAgent.makePeekabooTool("shell", "Execute shell commands (use for opening URLs with 'open', running CLI tools, etc)"),
        ]
    }
    
    private func getSystemPrompt() -> String {
        return """
        You are a helpful AI agent that can see and interact with the macOS desktop.
        You have access to comprehensive Peekaboo commands for UI automation:

        DECISION MAKING PRIORITY:
        1. ALWAYS attempt to make reasonable decisions with available information
        2. Use context clues, common patterns, and best practices to infer intent  
        3. Only ask questions when you genuinely cannot proceed without user input

        WHEN TO ASK QUESTIONS:
        - Ambiguous requests where multiple valid interpretations exist
        - Missing critical information that cannot be reasonably inferred
        - Potentially destructive actions that need confirmation

        QUESTION FORMAT:
        When you must ask a question, end your response with:
        "❓ QUESTION: [specific question]"

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
        
        APPLESCRIPT AUTOMATION via shell:
        - shell(command="osascript -e 'tell application \"Safari\" to activate'") - Activate Safari
        - shell(command="osascript -e 'tell application \"TextEdit\" to make new document'") - Create new document
        - shell(command="osascript -e 'tell application \"Finder\" to get selection as alias list'") - Get selected files
        - shell(command="osascript -e 'tell application \"Safari\" to get URL of current tab of front window'") - Get current URL
        - shell(command="osascript -e 'tell application \"Safari\" to get URL of every tab of front window'") - Get all tab URLs
        - shell(command="osascript -e 'tell application \"Safari\" to get name of every tab of front window'") - Get all tab titles
        - shell(command="osascript -e 'tell application \"System Events\" to keystroke \"v\" using command down'") - Send keyboard shortcut
        - shell(command="osascript -e 'set volume output volume 50'") - Control system volume
        - shell(command="osascript -e 'display dialog \"Hello World\"'") - Show dialog box
        - shell(command="osascript ~/my-script.scpt") - Run AppleScript file
        - Use AppleScript when native Peekaboo commands don't provide enough control
        - AppleScript can access app-specific features not available through UI automation
        
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
        """
    }
}

// Global shared instance to avoid recreating assistants
@available(macOS 14.0, *)
private actor SharedAssistantStorage {
    private var manager: AgentAssistantManager?
    
    func getOrCreate(apiKey: String, model: String) -> AgentAssistantManager {
        if let existing = manager {
            return existing
        }
        let newManager = AgentAssistantManager(apiKey: apiKey, model: model)
        manager = newManager
        return newManager
    }
    
    func cleanup() async {
        await manager?.cleanup()
        manager = nil
    }
}

@available(macOS 14.0, *)
private let sharedStorage = SharedAssistantStorage()

@available(macOS 14.0, *)
extension AgentAssistantManager {
    static func shared(apiKey: String, model: String) async -> AgentAssistantManager {
        return await sharedStorage.getOrCreate(apiKey: apiKey, model: model)
    }
    
    static func cleanupShared() async {
        await sharedStorage.cleanup()
    }
}