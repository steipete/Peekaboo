import Foundation
import CoreGraphics

// MARK: - Peekaboo Agent Service

/// Service that integrates the new agent architecture with PeekabooCore services
@available(macOS 14.0, *)
public final class PeekabooAgentService: AgentServiceProtocol {
    private let services: PeekabooServices
    private let modelProvider: ModelProvider
    private let sessionManager: AgentSessionManager
    private let defaultModelName: String
    
    
    public init(
        services: PeekabooServices = .shared,
        defaultModelName: String = "gpt-4-turbo-preview"
    ) {
        self.services = services
        self.modelProvider = .shared
        self.sessionManager = AgentSessionManager()
        self.defaultModelName = defaultModelName
    }
    
    // MARK: - AgentServiceProtocol Conformance
    
    /// Execute a task using the AI agent
    public func executeTask(
        _ task: String,
        dryRun: Bool = false,
        eventDelegate: AgentEventDelegate? = nil
    ) async throws -> AgentExecutionResult {
        // For dry run, just return a simulated result
        if dryRun {
            return AgentExecutionResult(
                content: "Dry run completed. Task would be: \(task)",
                messages: [],
                sessionId: UUID().uuidString,
                usage: nil,
                toolCalls: [],
                metadata: AgentMetadata(
                    startTime: Date(),
                    endTime: Date(),
                    toolCallCount: 0,
                    modelName: defaultModelName,
                    isResumed: false
                )
            )
        }
        
        // Use the new architecture internally
        let agent = createAutomationAgent(modelName: defaultModelName)
        
        // Create a new session for this task
        let sessionId = UUID().uuidString
        
        // Execute with streaming if we have an event delegate
        if eventDelegate != nil {
            // SAFETY: We ensure that the delegate is only accessed on MainActor
            // This is a legacy API pattern that predates Swift's strict concurrency
            let unsafeDelegate = UnsafeTransfer(eventDelegate!)
            
            // Create event stream infrastructure
            let (eventStream, eventContinuation) = AsyncStream<AgentEvent>.makeStream()
            
            // Start processing events on MainActor
            let eventTask = Task { @MainActor in
                let delegate = unsafeDelegate.wrappedValue
                for await event in eventStream {
                    delegate.agentDidEmitEvent(event)
                }
            }
            
            // Create the event handler
            let eventHandler = EventHandler { event in
                eventContinuation.yield(event)
            }
            
            defer {
                eventContinuation.finish()
                eventTask.cancel()
            }
            
            // Run the agent with streaming
            let result = try await AgentRunner.runStreaming(
                agent: agent,
                input: task,
                context: services,
                sessionId: sessionId
            ) { chunk in
                // Convert streaming chunks to events
                await eventHandler.send(.assistantMessage(content: chunk))
            }
            
            // Send completion event
            await eventHandler.send(.completed(summary: result.content))
            
            return result
        } else {
            // Execute without streaming
            return try await AgentRunner.run(
                agent: agent,
                input: task,
                context: services,
                sessionId: sessionId
            )
        }
    }
    
    /// Clean up any cached sessions or resources
    public func cleanup() async {
        // Clean up old sessions (older than 7 days)
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        try? await sessionManager.cleanupSessions(olderThan: oneWeekAgo)
    }
    
    // MARK: - Agent Creation
    
    /// Create a Peekaboo automation agent with all available tools
    public func createAutomationAgent(
        name: String = "Peekaboo Assistant",
        modelName: String = "gpt-4-turbo-preview"
    ) -> PeekabooAgent<PeekabooServices> {
        let agent = PeekabooAgent<PeekabooServices>(
            name: name,
            instructions: generateSystemPrompt(),
            tools: createPeekabooTools(),
            modelSettings: ModelSettings(
                modelName: modelName,
                toolChoice: .auto  // Let model decide when to use tools
            ),
            description: "An AI assistant for macOS automation using Peekaboo"
        )
        
        return agent
    }
    
    // MARK: - Execution Methods
    
    /// Execute a task with the automation agent (with session support)
    public func executeTask(
        _ task: String,
        sessionId: String? = nil,
        modelName: String = "gpt-4-turbo-preview",
        eventDelegate: AgentEventDelegate? = nil
    ) async throws -> AgentExecutionResult {
        let agent = createAutomationAgent(modelName: modelName)
        
        // If we have an event delegate, use streaming
        if eventDelegate != nil {
            // SAFETY: We ensure that the delegate is only accessed on MainActor
            // This is a legacy API pattern that predates Swift's strict concurrency
            let unsafeDelegate = UnsafeTransfer(eventDelegate!)
            
            // Create event stream infrastructure
            let (eventStream, eventContinuation) = AsyncStream<AgentEvent>.makeStream()
            
            // Start processing events on MainActor
            let eventTask = Task { @MainActor in
                let delegate = unsafeDelegate.wrappedValue
                
                // Send start event
                delegate.agentDidEmitEvent(.started(task: task))
                
                for await event in eventStream {
                    delegate.agentDidEmitEvent(event)
                }
            }
            
            // Create the event handler
            let eventHandler = EventHandler { event in
                eventContinuation.yield(event)
            }
            
            defer {
                eventContinuation.finish()
                eventTask.cancel()
            }
            
            // Run the agent with streaming
            let result = try await AgentRunner.runStreaming(
                agent: agent,
                input: task,
                context: services,
                sessionId: sessionId
            ) { chunk in
                // Convert streaming chunks to events
                await eventHandler.send(.assistantMessage(content: chunk))
            }
            
            // Emit tool call events from the result
            for toolCall in result.toolCalls {
                await eventHandler.send(
                    .toolCallStarted(name: toolCall.function.name, arguments: toolCall.function.arguments)
                )
            }
            
            // Send completion event
            await eventHandler.send(.completed(summary: result.content))
            
            return result
        } else {
            // Non-streaming execution
            return try await AgentRunner.run(
                agent: agent,
                input: task,
                context: services,
                sessionId: sessionId
            )
        }
    }
    
    
    /// Execute a task with streaming output
    public func executeTaskStreaming(
        _ task: String,
        sessionId: String? = nil,
        modelName: String = "gpt-4-turbo-preview",
        streamHandler: @Sendable @escaping (String) async -> Void
    ) async throws -> AgentExecutionResult {
        let agent = createAutomationAgent(modelName: modelName)
        
        return try await AgentRunner.runStreaming(
            agent: agent,
            input: task,
            context: services,
            sessionId: sessionId,
            streamHandler: streamHandler
        )
    }
    
    // MARK: - Tool Creation
    
    private func createPeekabooTools() -> [Tool<PeekabooServices>] {
        var tools: [Tool<PeekabooServices>] = []
        
        // Screen capture tools
        tools.append(createScreenshotTool())
        tools.append(createWindowCaptureTool())
        
        // UI automation tools
        tools.append(createClickTool())
        tools.append(createTypeTool())
        tools.append(createScrollTool())
        tools.append(createHotkeyTool())
        
        // Window management tools
        tools.append(createListWindowsTool())
        tools.append(createFocusWindowTool())
        tools.append(createResizeWindowTool())
        
        // Application tools
        tools.append(createListAppsTool())
        tools.append(createLaunchAppTool())
        
        // Element detection tools
        tools.append(createFindElementTool())
        tools.append(createListElementsTool())
        
        // Focus detection tool
        tools.append(createFocusedTool())
        
        // Shell command tool for system operations
        tools.append(createShellTool())
        
        return tools
    }
    
    // MARK: - Individual Tool Definitions
    
    private func createScreenshotTool() -> Tool<PeekabooServices> {
        Tool(
            name: "screenshot",
            description: "Capture a screenshot of the current screen or active window",
            parameters: .object(
                properties: [
                    "mode": .enumeration(
                        ["screen", "window", "area"],
                        description: "What to capture"
                    ),
                    "path": .string(
                        description: "Optional path to save the screenshot"
                    ),
                    "displayIndex": .integer(
                        description: "Display index for screen mode (0 for main)"
                    )
                ],
                required: ["mode"]
            ),
            execute: { input, services in
                let mode: String = input.value(for: "mode") ?? "screen"
                let _: String? = input.value(for: "path")
                let displayIndex: Int? = input.value(for: "displayIndex")
                
                let result: CaptureResult
                
                switch mode {
                case "screen":
                    result = try await services.screenCapture.captureScreen(displayIndex: displayIndex)
                case "window":
                    result = try await services.screenCapture.captureFrontmost()
                case "area":
                    // For now, capture the whole screen
                    result = try await services.screenCapture.captureScreen(displayIndex: displayIndex)
                default:
                    throw PeekabooError.invalidInput("Invalid capture mode: \(mode)")
                }
                
                // The image is already saved by the capture service if a path was provided
                
                return .dictionary([
                    "success": true,
                    "path": result.savedPath ?? "captured in memory",
                    "width": result.metadata.size.width,
                    "height": result.metadata.size.height
                ])
            }
        )
    }
    
    private func createClickTool() -> Tool<PeekabooServices> {
        Tool(
            name: "click",
            description: "Click on a UI element by text, coordinates, or element type",
            parameters: .object(
                properties: [
                    "target": .string(description: "Text to find and click, or 'coordinates' to use x,y"),
                    "x": .number(description: "X coordinate (when target is 'coordinates')"),
                    "y": .number(description: "Y coordinate (when target is 'coordinates')"),
                    "clickType": .enumeration(
                        ["single", "double", "right"],
                        description: "Type of click"
                    ),
                    "sessionId": .string(description: "Optional session ID for element caching")
                ],
                required: ["target"]
            ),
            execute: { input, services in
                let target: String = input.value(for: "target") ?? ""
                let clickType: String = input.value(for: "clickType") ?? "single"
                let sessionId: String? = input.value(for: "sessionId")
                
                let clickTypeEnum: ClickType = clickType == "double" ? .double :
                                               clickType == "right" ? .right : .single
                
                if target == "coordinates" {
                    guard let x: Double = input.value(for: "x"),
                          let y: Double = input.value(for: "y") else {
                        throw PeekabooError.invalidInput("Coordinates required when target is 'coordinates'")
                    }
                    
                    try await services.automation.click(
                        target: .coordinates(CGPoint(x: x, y: y)),
                        clickType: clickTypeEnum,
                        sessionId: sessionId
                    )
                } else {
                    // Click by text
                    try await services.automation.click(
                        target: .query(target),
                        clickType: clickTypeEnum,
                        sessionId: sessionId
                    )
                }
                
                
                let response: [String: Any] = [
                    "success": true,
                    "action": "clicked",
                    "target": target
                ]
                
                
                return .dictionary(response)
            }
        )
    }
    
    private func createTypeTool() -> Tool<PeekabooServices> {
        Tool(
            name: "type",
            description: "Type text into the currently focused element",
            parameters: .object(
                properties: [
                    "text": .string(description: "Text to type"),
                    "delay": .number(
                        description: "Delay between keystrokes in milliseconds",
                        minimum: 0,
                        maximum: 1000
                    )
                ],
                required: ["text"]
            ),
            execute: { input, services in
                let text: String = input.value(for: "text") ?? ""
                let delay: Int = input.value(for: "delay") ?? 20
                
                try await services.automation.type(
                    text: text,
                    target: nil,
                    clearExisting: false,
                    typingDelay: delay,
                    sessionId: nil
                )
                
                
                let response: [String: Any] = [
                    "success": true,
                    "action": "typed",
                    "text": text
                ]
                
                return .dictionary(response)
            }
        )
    }
    
    private func createListWindowsTool() -> Tool<PeekabooServices> {
        Tool(
            name: "list_windows",
            description: "List all windows for an application",
            parameters: .object(
                properties: [
                    "appName": .string(description: "Name of the application (optional, lists all if not provided)")
                ],
                required: []
            ),
            execute: { input, services in
                let appName: String? = input.value(for: "appName")
                
                let windows: [ServiceWindowInfo]
                if let appName = appName {
                    windows = try await services.applications.listWindows(for: appName)
                } else {
                    // List all windows
                    let apps = try await services.applications.listApplications()
                    var allWindows: [ServiceWindowInfo] = []
                    for app in apps {
                        if let appWindows = try? await services.applications.listWindows(for: app.name) {
                            allWindows.append(contentsOf: appWindows)
                        }
                    }
                    windows = allWindows
                }
                
                let windowData = windows.map { window in
                    [
                        "title": window.title,
                        "windowID": window.windowID,
                        "bounds": [
                            "x": window.bounds.origin.x,
                            "y": window.bounds.origin.y,
                            "width": window.bounds.width,
                            "height": window.bounds.height
                        ],
                        "isMinimized": window.isMinimized,
                        "isMainWindow": window.isMainWindow
                    ]
                }
                
                return .dictionary([
                    "success": true,
                    "windows": windowData,
                    "count": windows.count
                ])
            }
        )
    }
    
    private func createFindElementTool() -> Tool<PeekabooServices> {
        Tool(
            name: "find_element",
            description: "Find UI elements by text or type",
            parameters: .object(
                properties: [
                    "text": .string(description: "Text to search for"),
                    "elementType": .enumeration(
                        ["button", "textField", "staticText", "any"],
                        description: "Type of element to find"
                    ),
                    "sessionId": .string(description: "Session ID for caching")
                ],
                required: []
            ),
            execute: { input, services in
                let text: String? = input.value(for: "text")
                let elementType: String = input.value(for: "elementType") ?? "any"
                let sessionId: String = input.value(for: "sessionId") ?? UUID().uuidString
                
                let query: String
                if let text = text {
                    query = text
                } else {
                    query = "type:\(elementType)"
                }
                
                let elements = try await services.sessions.findElements(
                    sessionId: sessionId,
                    matching: query
                )
                
                let elementData = elements.map { element in
                    [
                        "text": element.label ?? "",
                        "type": element.role,
                        "bounds": [
                            "x": element.frame.origin.x,
                            "y": element.frame.origin.y,
                            "width": element.frame.width,
                            "height": element.frame.height
                        ],
                        "isActionable": element.isActionable
                    ]
                }
                
                return .dictionary([
                    "success": true,
                    "elements": elementData,
                    "count": elements.count,
                    "sessionId": sessionId
                ])
            }
        )
    }
    
    // MARK: - System Prompt
    
    private func generateSystemPrompt() -> String {
        """
        You are Peekaboo Assistant, an AI agent specialized in macOS automation and UI interaction.
        
        IMPORTANT: You MUST use the provided tools to accomplish tasks. Do not describe what you would do - actually do it using the tools.
        
        ## Your Capabilities
        
        You have access to powerful tools for:
        - **Shell Commands**: Execute any shell command including file operations, AppleScript, and system utilities
        - **UI Automation**: Click, type, scroll, and interact with any UI element
        - **Window Management**: Launch apps, focus windows, resize, and control window states
        - **Screen Capture**: Take screenshots of screens, windows, or specific applications
        - **Element Detection**: Find and interact with specific UI elements by text or type
        
        ## Creative Problem Solving
        
        Use your tools creatively to accomplish complex tasks:
        
        ### File Operations via Shell
        - List files: `ls ~/Downloads/*.ods`
        - Check file existence: `test -f ~/Downloads/file.ods && echo "exists"`
        - Move/copy files: `cp source.txt destination.txt`
        - Read file contents: `cat filename.txt`
        - Convert files using command-line tools: `pandoc input.ods -o output.md`
        
        ### Application Automation via AppleScript
        - Navigate Finder: `osascript -e 'tell application "Finder" to open folder "Downloads" of home'`
        - Control any app: `osascript -e 'tell application "AppName" to activate'`
        - Interact with menus: `osascript -e 'tell application "System Events" to click menu item "Save As..." of menu "File" of menu bar 1 of process "AppName"'`
        - Get window properties: `osascript -e 'tell application "AppName" to get bounds of window 1'`
        
        ### Email Automation
        - Open Mail with recipient: `open "mailto:email@example.com?subject=Subject&body=Body"`
        - Use AppleScript for complex email tasks: `osascript -e 'tell application "Mail" to make new outgoing message with properties {subject:"Test", content:"Hello", visible:true}'`
        
        ### Web Automation
        - Open URLs: `open "https://example.com"`
        - Download files: `curl -O https://example.com/file.pdf`
        - Use online converters by opening them in browser and automating the UI
        
        ### Process Management
        - Check running processes: `ps aux | grep AppName`
        - Kill processes: `killall AppName`
        - Launch applications: Use launch_app tool or `open -a "Application Name"`
        
        ## Best Practices
        
        1. **Chain Commands**: Use shell operators (&&, ||, ;) to chain multiple commands
        2. **Check Before Acting**: Verify files exist, apps are running, etc. before interacting
        3. **Use Both UI and Shell**: Combine UI automation with shell commands for maximum effectiveness
        4. **Error Handling**: Check command exit codes and handle failures gracefully
        5. **Path Expansion**: Use ~ for home directory, handle spaces in paths with quotes
        
        ## Example Approaches
        
        For "Convert ODS to Markdown and email it":
        1. Use shell to find the file: `ls ~/Downloads/*.ods`
        2. Check for conversion tools: `which pandoc || which libreoffice`
        3. Convert using available tools or open in app and export
        4. Compose email using Mail app or `open "mailto:..."` with the file
        
        For "Organize files on desktop":
        1. List files: `ls ~/Desktop`
        2. Create folders: `mkdir -p ~/Desktop/Documents ~/Desktop/Images`
        3. Move files by type: `mv ~/Desktop/*.pdf ~/Desktop/Documents/`
        4. Or use Finder with AppleScript for visual feedback
        
        Remember: You have full system access through the shell tool. Use it creatively alongside UI automation to accomplish any task. Don't just describe what to do - DO IT using your tools!
        
        You are running on macOS with full automation permissions granted to Peekaboo.
        """
    }
}

// MARK: - Convenience Methods

extension PeekabooAgentService {
    /// List available agent sessions
    public func listSessions() async throws -> [SessionSummary] {
        return try await sessionManager.listSessions()
    }
    
    /// Delete an agent session
    public func deleteSession(id: String) async throws {
        try await sessionManager.deleteSession(id: id)
    }
    
    /// Clean up old sessions
    public func cleanupSessions(olderThan date: Date) async throws {
        try await sessionManager.cleanupSessions(olderThan: date)
    }
    
    /// Execute a task with enhanced options
    public func executeTask(
        _ task: String,
        sessionId: String? = nil,
        modelName: String? = nil,
        eventDelegate: AgentEventDelegate? = nil
    ) async throws -> AgentExecutionResult {
        let effectiveModelName = modelName ?? defaultModelName
        let agent = createAutomationAgent(modelName: effectiveModelName)
        let effectiveSessionId = sessionId ?? UUID().uuidString
        
        // Execute with streaming if we have an event delegate
        if let eventDelegate = eventDelegate {
            // SAFETY: We ensure that the delegate is only accessed on MainActor
            // This is a legacy API pattern that predates Swift's strict concurrency
            let unsafeDelegate = UnsafeTransfer(eventDelegate)
            
            // Create event stream infrastructure
            let (eventStream, eventContinuation) = AsyncStream<AgentEvent>.makeStream()
            
            // Start processing events on MainActor
            let eventTask = Task { @MainActor in
                let delegate = unsafeDelegate.wrappedValue
                for await event in eventStream {
                    delegate.agentDidEmitEvent(event)
                }
            }
            
            defer {
                eventContinuation.finish()
                eventTask.cancel()
            }
            
            // Send start event
            eventContinuation.yield(.started(task: task))
            
            // Run the agent with streaming
            let result = try await AgentRunner.runStreaming(
                agent: agent,
                input: task,
                context: services,
                sessionId: effectiveSessionId
            ) { chunk in
                // Only emit assistant message events for actual text content
                // Tool call events are handled separately
                if !chunk.isEmpty {
                    eventContinuation.yield(.assistantMessage(content: chunk))
                }
            }
            
            // Note: Tool call events are emitted directly from the agent runner
            // through the event stream infrastructure
            
            // Send completion event
            eventContinuation.yield(.completed(summary: result.content))
            
            return result
        } else {
            // Execute without streaming
            return try await AgentRunner.run(
                agent: agent,
                input: task,
                context: services,
                sessionId: effectiveSessionId
            )
        }
    }
}


// MARK: - Additional Tool Implementations

extension PeekabooAgentService {
    private func createWindowCaptureTool() -> Tool<PeekabooServices> {
        Tool(
            name: "window_capture",
            description: "Capture a screenshot of a specific application window",
            parameters: .object(
                properties: [
                    "appName": .string(description: "Name of the application"),
                    "windowIndex": .integer(description: "Window index (0 for first window)")
                ],
                required: ["appName"]
            ),
            execute: { input, services in
                let appName: String = input.value(for: "appName") ?? ""
                let windowIndex: Int? = input.value(for: "windowIndex")
                
                let result = try await services.screenCapture.captureWindow(
                    appIdentifier: appName,
                    windowIndex: windowIndex
                )
                
                return .dictionary([
                    "success": true,
                    "path": result.savedPath ?? "captured in memory",
                    "width": result.metadata.size.width,
                    "height": result.metadata.size.height,
                    "appName": result.metadata.applicationInfo?.name ?? appName
                ])
            }
        )
    }
    
    private func createScrollTool() -> Tool<PeekabooServices> {
        Tool(
            name: "scroll",
            description: "Scroll in a window or element",
            parameters: .object(
                properties: [
                    "direction": .enumeration(
                        ["up", "down", "left", "right"],
                        description: "Direction to scroll"
                    ),
                    "amount": .integer(
                        description: "Amount to scroll (in pixels)",
                        minimum: 1,
                        maximum: 10000
                    ),
                    "target": .string(description: "Optional target element text"),
                    "sessionId": .string(description: "Optional session ID for element caching")
                ],
                required: ["direction", "amount"]
            ),
            execute: { input, services in
                let direction: String = input.value(for: "direction") ?? "down"
                let amount: Int = input.value(for: "amount") ?? 100
                let target: String? = input.value(for: "target")
                let sessionId: String? = input.value(for: "sessionId")
                
                let scrollDirection: ScrollDirection = {
                    switch direction {
                    case "up": return .up
                    case "down": return .down
                    case "left": return .left
                    case "right": return .right
                    default: return .down
                    }
                }()
                
                try await services.automation.scroll(
                    direction: scrollDirection,
                    amount: amount,
                    target: target,
                    smooth: true,
                    delay: 50,
                    sessionId: sessionId
                )
                
                return .dictionary([
                    "success": true,
                    "action": "scrolled",
                    "direction": direction,
                    "amount": amount
                ])
            }
        )
    }
    
    private func createHotkeyTool() -> Tool<PeekabooServices> {
        Tool(
            name: "hotkey",
            description: "Send keyboard shortcuts (hotkeys) to the system",
            parameters: .object(
                properties: [
                    "keys": .string(
                        description: "Comma-separated key combination (e.g., 'cmd,c' for Cmd+C, 'cmd,shift,4' for Cmd+Shift+4)"
                    ),
                    "holdDuration": .integer(
                        description: "Duration to hold the keys in milliseconds",
                        minimum: 0,
                        maximum: 5000
                    )
                ],
                required: ["keys"]
            ),
            execute: { input, services in
                let keys: String = input.value(for: "keys") ?? ""
                let holdDuration: Int = input.value(for: "holdDuration") ?? 100
                
                try await services.automation.hotkey(
                    keys: keys,
                    holdDuration: holdDuration
                )
                
                let response: [String: Any] = [
                    "success": true,
                    "action": "hotkey",
                    "keys": keys
                ]
                
                return .dictionary(response)
            }
        )
    }
    
    private func createFocusWindowTool() -> Tool<PeekabooServices> {
        Tool(
            name: "focus_window",
            description: "Focus (bring to front) a specific window",
            parameters: .object(
                properties: [
                    "appName": .string(description: "Name of the application"),
                    "windowTitle": .string(description: "Optional window title to match")
                ],
                required: ["appName"]
            ),
            execute: { input, services in
                let appName: String = input.value(for: "appName") ?? ""
                let windowTitle: String? = input.value(for: "windowTitle")
                
                let target: WindowTarget
                if let windowTitle = windowTitle {
                    target = .title(windowTitle)
                } else {
                    target = .application(appName)
                }
                
                try await services.windows.focusWindow(target: target)
                
                return .dictionary([
                    "success": true,
                    "action": "focused",
                    "appName": appName
                ])
            }
        )
    }
    
    private func createResizeWindowTool() -> Tool<PeekabooServices> {
        Tool(
            name: "resize_window",
            description: "Resize a window to specific dimensions",
            parameters: .object(
                properties: [
                    "appName": .string(description: "Name of the application"),
                    "width": .number(description: "New width in pixels"),
                    "height": .number(description: "New height in pixels"),
                    "windowTitle": .string(description: "Optional window title to match")
                ],
                required: ["appName", "width", "height"]
            ),
            execute: { input, services in
                let appName: String = input.value(for: "appName") ?? ""
                let width: Double = input.value(for: "width") ?? 800
                let height: Double = input.value(for: "height") ?? 600
                let windowTitle: String? = input.value(for: "windowTitle")
                
                let target: WindowTarget
                if let windowTitle = windowTitle {
                    target = .title(windowTitle)
                } else {
                    target = .application(appName)
                }
                
                try await services.windows.resizeWindow(
                    target: target,
                    to: CGSize(width: width, height: height)
                )
                
                return .dictionary([
                    "success": true,
                    "action": "resized",
                    "appName": appName,
                    "newSize": ["width": width, "height": height]
                ])
            }
        )
    }
    
    private func createListAppsTool() -> Tool<PeekabooServices> {
        Tool(
            name: "list_apps",
            description: "List all running applications",
            parameters: .object(properties: [:], required: []),
            execute: { _, services in
                let apps = try await services.applications.listApplications()
                
                let appData = apps.map { app in
                    [
                        "name": app.name,
                        "bundleId": app.bundleIdentifier ?? "",
                        "processId": app.processIdentifier,
                        "isActive": app.isActive
                    ]
                }
                
                return .dictionary([
                    "success": true,
                    "apps": appData,
                    "count": apps.count
                ])
            }
        )
    }
    
    private func createLaunchAppTool() -> Tool<PeekabooServices> {
        Tool(
            name: "launch_app",
            description: "Launch an application",
            parameters: .object(
                properties: [
                    "appName": .string(description: "Name of the application to launch")
                ],
                required: ["appName"]
            ),
            execute: { input, services in
                let appName: String = input.value(for: "appName") ?? ""
                
                _ = try await services.applications.launchApplication(identifier: appName)
                
                return .dictionary([
                    "success": true,
                    "action": "launched",
                    "appName": appName
                ])
            }
        )
    }
    
    private func createListElementsTool() -> Tool<PeekabooServices> {
        Tool(
            name: "list_elements",
            description: "List all UI elements in the current context",
            parameters: .object(
                properties: [
                    "sessionId": .string(description: "Optional session ID for element detection"),
                    "elementType": .enumeration(
                        ["all", "buttons", "textFields", "labels", "links"],
                        description: "Type of elements to list"
                    )
                ],
                required: []
            ),
            execute: { input, services in
                let sessionId: String = input.value(for: "sessionId") ?? UUID().uuidString
                let elementType: String = input.value(for: "elementType") ?? "all"
                
                // Get the latest detection result from the session
                guard let detectionResult = try await services.sessions.getDetectionResult(sessionId: sessionId) else {
                    // Need to capture and detect first
                    let captureResult = try await services.screenCapture.captureFrontmost()
                    let detection = try await services.automation.detectElements(
                        in: captureResult.imageData,
                        sessionId: sessionId
                    )
                    try await services.sessions.storeDetectionResult(sessionId: sessionId, result: detection)
                    
                    return formatElementList(detection.elements, filterType: elementType)
                }
                
                return formatElementList(detectionResult.elements, filterType: elementType)
            }
        )
    }
    
    private func createFocusedTool() -> Tool<PeekabooServices> {
        Tool(
            name: "focused",
            description: "Get information about the currently focused UI element that would receive keyboard input",
            parameters: .object(properties: [:], required: []),
            execute: { _, services in
                await MainActor.run {
                    guard let focusInfo = services.automation.getFocusedElement() else {
                        return .dictionary([
                            "success": true,
                            "focused": false,
                            "message": "No UI element is currently focused"
                        ])
                    }
                    
                    return .dictionary([
                        "success": true,
                        "focused": true,
                        "focusInfo": focusInfo.toDictionary()
                    ])
                }
            }
        )
    }
    
    private func createShellTool() -> Tool<PeekabooServices> {
        Tool(
            name: "shell",
            description: "Execute shell commands for file operations, AppleScript automation, and system tasks",
            parameters: .object(
                properties: [
                    "command": .string(
                        description: "Shell command to execute (e.g., 'ls ~/Downloads/*.ods', 'osascript -e \"tell application \\\"Finder\\\" to activate\"')"
                    ),
                    "workingDirectory": .string(
                        description: "Optional working directory for the command (defaults to home directory)"
                    )
                ],
                required: ["command"]
            ),
            execute: { input, services in
                let command: String = input.value(for: "command") ?? ""
                let workingDir: String? = input.value(for: "workingDirectory")
                
                // Create a Process to run the shell command
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", command]
                
                if let dir = workingDir {
                    process.currentDirectoryURL = URL(fileURLWithPath: dir)
                }
                
                let pipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = pipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let output = String(data: data, encoding: .utf8) ?? ""
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    
                    if process.terminationStatus == 0 {
                        return .dictionary([
                            "success": true,
                            "output": output,
                            "exitCode": Int(process.terminationStatus)
                        ])
                    } else {
                        return .dictionary([
                            "success": false,
                            "output": output,
                            "error": errorOutput.isEmpty ? "Command failed with exit code \(process.terminationStatus)" : errorOutput,
                            "exitCode": Int(process.terminationStatus)
                        ])
                    }
                } catch {
                    return .dictionary([
                        "success": false,
                        "error": error.localizedDescription,
                        "exitCode": -1
                    ])
                }
            }
        )
    }
    
    // MARK: - Menu Tools
    
    private func createMenuClickTool() -> Tool<PeekabooServices> {
        Tool(
            name: "menu_click",
            description: "Click a menu item in an application's menu bar",
            parameters: .object(
                properties: [
                    "appName": .string(
                        description: "Application name (defaults to frontmost app if not specified)"
                    ),
                    "menuPath": .string(
                        description: "Menu item path (e.g., 'File > New', 'Edit > Copy', or just 'Copy')"
                    )
                ],
                required: ["menuPath"]
            ),
            execute: { input, services in
                let appName: String? = input.value(for: "appName")
                let menuPath: String = input.value(for: "menuPath") ?? ""
                
                do {
                    if let app = appName {
                        try await services.menu.clickMenuItem(app: app, itemPath: menuPath)
                    } else {
                        // Get frontmost app and click menu
                        let frontmostApp = try await services.applications.getFrontmostApplication()
                        try await services.menu.clickMenuItem(app: frontmostApp.name, itemPath: menuPath)
                    }
                    
                    return .dictionary([
                        "success": true,
                        "menuPath": menuPath,
                        "app": appName ?? "frontmost"
                    ])
                } catch {
                    return .dictionary([
                        "success": false,
                        "error": error.localizedDescription
                    ])
                }
            }
        )
    }
    
    private func createListMenusTool() -> Tool<PeekabooServices> {
        Tool(
            name: "list_menus",
            description: "List all menu items for an application",
            parameters: .object(
                properties: [
                    "appName": .string(
                        description: "Application name (defaults to frontmost app if not specified)"
                    )
                ],
                required: []
            ),
            execute: { input, services in
                let appName: String? = input.value(for: "appName")
                
                do {
                    let menuStructure: MenuStructure
                    
                    if let app = appName {
                        menuStructure = try await services.menu.listMenus(for: app)
                    } else {
                        menuStructure = try await services.menu.listFrontmostMenus()
                    }
                    
                    // Convert menu structure to simple format
                    var menuItems: [[String: Any]] = []
                    for menu in menuStructure.menus {
                        menuItems.append(contentsOf: flattenMenuItems(menu: menu, parentPath: menu.title))
                    }
                    
                    return .dictionary([
                        "success": true,
                        "app": menuStructure.application.name,
                        "totalItems": menuStructure.totalItems,
                        "items": menuItems
                    ])
                } catch {
                    return .dictionary([
                        "success": false,
                        "error": error.localizedDescription
                    ])
                }
            }
        )
    }
    
    // MARK: - Dock Tools
    
    private func createDockLaunchTool() -> Tool<PeekabooServices> {
        Tool(
            name: "dock_launch",
            description: "Launch an application from the Dock",
            parameters: .object(
                properties: [
                    "appName": .string(
                        description: "Name of the application in the Dock"
                    )
                ],
                required: ["appName"]
            ),
            execute: { input, services in
                let appName: String = input.value(for: "appName") ?? ""
                
                do {
                    try await services.dock.launchFromDock(appName: appName)
                    
                    return .dictionary([
                        "success": true,
                        "launched": appName
                    ])
                } catch {
                    return .dictionary([
                        "success": false,
                        "error": error.localizedDescription
                    ])
                }
            }
        )
    }
    
    private func createListDockTool() -> Tool<PeekabooServices> {
        Tool(
            name: "list_dock",
            description: "List all items in the Dock",
            parameters: .object(
                properties: [
                    "includeAll": .boolean(
                        description: "Include separators and spacers (default: false)"
                    )
                ],
                required: []
            ),
            execute: { input, services in
                let includeAll: Bool = input.value(for: "includeAll") ?? false
                
                do {
                    let dockItems = try await services.dock.listDockItems(includeAll: includeAll)
                    
                    let items = dockItems.map { item in
                        [
                            "index": item.index,
                            "title": item.title,
                            "type": item.itemType.rawValue,
                            "isRunning": item.isRunning as Any
                        ]
                    }
                    
                    return .dictionary([
                        "success": true,
                        "count": dockItems.count,
                        "items": items
                    ])
                } catch {
                    return .dictionary([
                        "success": false,
                        "error": error.localizedDescription
                    ])
                }
            }
        )
    }
    
    // MARK: - Dialog Tools
    
    private func createDialogClickTool() -> Tool<PeekabooServices> {
        Tool(
            name: "dialog_click",
            description: "Click a button in an active dialog or alert",
            parameters: .object(
                properties: [
                    "buttonText": .string(
                        description: "Text of the button to click (e.g., 'OK', 'Cancel', 'Save')"
                    ),
                    "windowTitle": .string(
                        description: "Optional specific dialog window title to target"
                    )
                ],
                required: ["buttonText"]
            ),
            execute: { input, services in
                let buttonText: String = input.value(for: "buttonText") ?? ""
                let windowTitle: String? = input.value(for: "windowTitle")
                
                do {
                    let result = try await services.dialogs.clickButton(
                        buttonText: buttonText,
                        windowTitle: windowTitle
                    )
                    
                    return .dictionary([
                        "success": result.success,
                        "action": result.action.rawValue,
                        "details": result.details
                    ])
                } catch {
                    return .dictionary([
                        "success": false,
                        "error": error.localizedDescription
                    ])
                }
            }
        )
    }
    
    private func createDialogInputTool() -> Tool<PeekabooServices> {
        Tool(
            name: "dialog_input",
            description: "Enter text in a dialog field",
            parameters: .object(
                properties: [
                    "text": .string(
                        description: "Text to enter in the field"
                    ),
                    "fieldIdentifier": .string(
                        description: "Field label, placeholder, or index to target (optional)"
                    ),
                    "clearExisting": .boolean(
                        description: "Whether to clear existing text first (default: true)"
                    ),
                    "windowTitle": .string(
                        description: "Optional specific dialog window title to target"
                    )
                ],
                required: ["text"]
            ),
            execute: { input, services in
                let text: String = input.value(for: "text") ?? ""
                let fieldIdentifier: String? = input.value(for: "fieldIdentifier")
                let clearExisting: Bool = input.value(for: "clearExisting") ?? true
                let windowTitle: String? = input.value(for: "windowTitle")
                
                do {
                    let result = try await services.dialogs.enterText(
                        text: text,
                        fieldIdentifier: fieldIdentifier,
                        clearExisting: clearExisting,
                        windowTitle: windowTitle
                    )
                    
                    return .dictionary([
                        "success": result.success,
                        "action": result.action.rawValue,
                        "details": result.details
                    ])
                } catch {
                    return .dictionary([
                        "success": false,
                        "error": error.localizedDescription
                    ])
                }
            }
        )
    }
}

// MARK: - Helper Functions

private func flattenMenuItems(menu: Menu, parentPath: String) -> [[String: Any]] {
    var items: [[String: Any]] = []
    
    for item in menu.items {
        let path = "\(parentPath) > \(item.title)"
        items.append([
            "path": path,
            "title": item.title,
            "enabled": item.isEnabled,
            "hasSubmenu": !item.submenu.isEmpty
        ])
        
        // Recursively add submenu items
        if !item.submenu.isEmpty {
            let submenu = Menu(title: item.title, items: item.submenu)
            items.append(contentsOf: flattenMenuItems(menu: submenu, parentPath: path))
        }
    }
    
    return items
}

private func formatElementList(_ elements: DetectedElements, filterType: String) -> ToolOutput {
    let filteredElements: [DetectedElement]
    
    switch filterType {
    case "buttons":
        filteredElements = elements.buttons
    case "textFields":
        filteredElements = elements.textFields
    case "labels":
        filteredElements = elements.other // Use other for labels/static texts
    case "links":
        filteredElements = elements.links
    default:
        filteredElements = elements.all
    }
    
    let elementData = filteredElements.map { element in
        [
            "text": element.label ?? "",
            "type": element.type.rawValue,
            "bounds": [
                "x": element.bounds.origin.x,
                "y": element.bounds.origin.y,
                "width": element.bounds.width,
                "height": element.bounds.height
            ]
        ]
    }
    
    return .dictionary([
        "success": true,
        "elements": elementData,
        "count": filteredElements.count,
        "type": filterType
    ])
}

// MARK: - Event Handler

/// A sendable wrapper for handling events from async contexts
private struct EventHandler: Sendable {
    private let sendEvent: @Sendable (AgentEvent) async -> Void
    
    init(sendEvent: @escaping @Sendable (AgentEvent) async -> Void) {
        self.sendEvent = sendEvent
    }
    
    func send(_ event: AgentEvent) async {
        await sendEvent(event)
    }
}

/// Helper to transfer non-Sendable values across isolation boundaries
/// SAFETY: The caller must ensure the value is only accessed in the correct isolation domain
private struct UnsafeTransfer<Value>: @unchecked Sendable {
    let wrappedValue: Value
    
    init(_ value: Value) {
        self.wrappedValue = value
    }
}