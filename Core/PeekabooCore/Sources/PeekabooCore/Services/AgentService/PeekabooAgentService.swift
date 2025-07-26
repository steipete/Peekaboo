import Foundation
import CoreGraphics
import AXorcist

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
        defaultModelName: String = "o3"
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
                sessionId: sessionId,
                streamHandler: { chunk in
                    // Convert streaming chunks to events
                    await eventHandler.send(.assistantMessage(content: chunk))
                },
                eventHandler: { toolEvent in
                    // Convert tool events to agent events
                    switch toolEvent {
                    case .started(let name, let arguments):
                        await eventHandler.send(.toolCallStarted(name: name, arguments: arguments))
                    case .completed(let name, let result):
                        await eventHandler.send(.toolCallCompleted(name: name, result: result))
                    }
                }
            )
            
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
        modelName: String = "o3"
    ) -> PeekabooAgent<PeekabooServices> {
        let agent = PeekabooAgent<PeekabooServices>(
            name: name,
            instructions: generateSystemPrompt(),
            tools: createPeekabooTools(),
            modelSettings: ModelSettings(
                modelName: modelName,
                temperature: modelName.hasPrefix(AgentConfiguration.o3ModelPrefix) ? nil : nil,  // o3 doesn't support temperature
                maxTokens: modelName.hasPrefix(AgentConfiguration.o3ModelPrefix) ? AgentConfiguration.o3MaxTokens : AgentConfiguration.defaultMaxTokens,
                toolChoice: .auto,  // Let model decide when to use tools
                additionalParameters: modelName.hasPrefix(AgentConfiguration.o3ModelPrefix) ? [
                    "reasoning_effort": AnyCodable(AgentConfiguration.o3ReasoningEffort),
                    "max_completion_tokens": AnyCodable(AgentConfiguration.o3MaxCompletionTokens)
                ] : nil
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
        modelName: String = "o3",
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
                sessionId: sessionId,
                streamHandler: { chunk in
                    // Convert streaming chunks to events
                    await eventHandler.send(.assistantMessage(content: chunk))
                },
                eventHandler: { toolEvent in
                    // Convert tool events to agent events
                    switch toolEvent {
                    case .started(let name, let arguments):
                        await eventHandler.send(.toolCallStarted(name: name, arguments: arguments))
                    case .completed(let name, let result):
                        await eventHandler.send(.toolCallCompleted(name: name, result: result))
                    }
                }
            )
            
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
        modelName: String = "o3",
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
        tools.append(createSeeTool())  // Primary tool for capturing and analyzing UI
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
        
        // Menu tools
        tools.append(createMenuClickTool())
        tools.append(createListMenusTool())
        
        // Dialog tools
        tools.append(createDialogClickTool())
        tools.append(createDialogInputTool())
        
        // Dock tools
        tools.append(createDockLaunchTool())
        tools.append(createListDockTool())
        
        // Shell command tool for system operations
        tools.append(createShellTool())
        
        return tools
    }
    
    // MARK: - Individual Tool Definitions
    
    private func createSeeTool() -> Tool<PeekabooServices> {
        Tool(
            name: "see",
            description: "Capture and analyze the current screen state with UI element detection. This is the primary tool for understanding what's on screen.",
            parameters: .object(
                properties: [
                    "mode": .enumeration(
                        ["screen", "window", "frontmost"],
                        description: "What to capture (default: frontmost)"
                    ),
                    "app": .string(
                        description: "Optional application name to capture"
                    ),
                    "analyze": .string(
                        description: "Optional AI analysis prompt for the captured content"
                    )
                ],
                required: []
            ),
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
                let mode: String = input.value(for: "mode") ?? "frontmost"
                let appName: String? = input.value(for: "app")
                let analyzePrompt: String? = input.value(for: "analyze")
                
                do {
                    // Capture the screen based on mode
                    let captureResult: CaptureResult
                    
                    if let appName = appName {
                        captureResult = try await services.screenCapture.captureWindow(
                            appIdentifier: appName,
                            windowIndex: 0
                        )
                    } else {
                        switch mode {
                        case "screen":
                            captureResult = try await services.screenCapture.captureScreen(displayIndex: 0)
                        case "window", "frontmost":
                            captureResult = try await services.screenCapture.captureFrontmost()
                        default:
                            captureResult = try await services.screenCapture.captureFrontmost()
                        }
                    }
                    
                    // Generate a session ID for element detection
                    let sessionId = UUID().uuidString
                    
                    // Detect UI elements in the captured image
                    let detectionResult = try await services.automation.detectElements(
                        in: captureResult.imageData,
                        sessionId: sessionId
                    )
                    
                    // Store the detection result for future use
                    try await services.sessions.storeDetectionResult(
                        sessionId: sessionId,
                        result: detectionResult
                    )
                    
                    // Build response
                    var response: [String: Any] = [
                        "success": true,
                        "sessionId": sessionId,
                        "path": captureResult.savedPath ?? "captured in memory",
                        "size": [
                            "width": captureResult.metadata.size.width,
                            "height": captureResult.metadata.size.height
                        ],
                        "elements": [
                            "total": detectionResult.elements.all.count,
                            "buttons": detectionResult.elements.buttons.count,
                            "textFields": detectionResult.elements.textFields.count,
                            "other": detectionResult.elements.other.count,
                            "links": detectionResult.elements.links.count
                        ]
                    ]
                    
                    // Add application info if available
                    if let appInfo = captureResult.metadata.applicationInfo {
                        response["application"] = [
                            "name": appInfo.name,
                            "bundleId": appInfo.bundleIdentifier ?? ""
                        ]
                    }
                    
                    // If analysis was requested, perform it
                    if let prompt = analyzePrompt {
                        // This would integrate with the AI analysis service
                        // For now, we'll just note that analysis was requested
                        response["analysisRequested"] = prompt
                    }
                    
                    return .dictionary(response)
                } catch {
                    // Enhanced error handling for capture operations
                    var errorResponse: [String: Any] = [
                        "success": false,
                        "error": error.localizedDescription
                    ]
                    
                    var context: [String: Any] = [:]
                    
                    // Check for permission errors
                    if error.localizedDescription.lowercased().contains("permission") ||
                       error.localizedDescription.lowercased().contains("denied") {
                        
                        let permissions = await getPermissionDiagnostics()
                        
                        context["currentState"] = "Permission denied for screen capture"
                        context["requiredState"] = "Screen Recording permission must be granted"
                        context["permissions"] = permissions
                        context["fix"] = "Grant Screen Recording permission in System Settings > Privacy & Security > Screen Recording"
                        
                        errorResponse["errorDetails"] = [
                            "category": "permission",
                            "context": context
                        ]
                    } else if appName != nil && (error.localizedDescription.contains("not found") ||
                                                 error.localizedDescription.contains("no such")) {
                        // App not found
                        let similarApps = try? await findSimilarApps(appName!)
                        context["available"] = similarApps ?? []
                        context["suggestions"] = ["Application '\(appName!)' not found"]
                        context["fix"] = "Check the app name or use 'list_apps' to see running applications"
                        
                        errorResponse["errorDetails"] = [
                            "category": "notFound",
                            "context": context
                        ]
                    } else if error.localizedDescription.contains("no window") {
                        context["currentState"] = "No active window to capture"
                        context["fix"] = "Ensure an application window is open and focused"
                        context["suggestions"] = ["Try mode: 'screen' to capture the entire screen instead"]
                        
                        errorResponse["errorDetails"] = [
                            "category": "state",
                            "context": context
                        ]
                    }
                    
                    return .dictionary(errorResponse)
                }
            }
        )
    }
    
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
                let target: String = input.value(for: "target") ?? ""
                let clickType: String = input.value(for: "clickType") ?? "single"
                let sessionId: String? = input.value(for: "sessionId")
                
                let clickTypeEnum: ClickType = clickType == "double" ? .double :
                                               clickType == "right" ? .right : .single
                
                do {
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
                } catch {
                    // Enhanced error handling for click operations
                    if errorContains(error, keywords: ["not found", "no element"]) {
                        // Get available elements
                        let availableButtons = try? await getAvailableElements(sessionId: sessionId, type: .button)
                        let availableElements = try? await getAvailableElements(sessionId: sessionId, type: nil)
                        
                        var suggestions: [String] = []
                        var available: [String] = []
                        
                        if let buttons = availableButtons, !buttons.isEmpty {
                            available = buttons
                            if let firstButton = buttons.first {
                                let elementId = firstButton.components(separatedBy: "(").last?.dropLast() ?? ""
                                suggestions = ["Did you mean \(firstButton)? Try: click \(elementId)"]
                            }
                        } else if let elements = availableElements, !elements.isEmpty {
                            available = elements
                            suggestions = ["No buttons found. Available elements: \(elements.prefix(3).joined(separator: ", "))"]
                        }
                        
                        let context = createNotFoundContext(
                            available: available.isEmpty ? nil : available,
                            suggestions: suggestions.isEmpty ? nil : suggestions,
                            fix: sessionId == nil ? "Use 'see' tool first to capture screen and detect elements" : nil
                        )
                        
                        return .dictionary(createEnhancedError(error, category: .notFound, context: context))
                    }
                    
                    // Default error response
                    return .dictionary(["success": false, "error": error.localizedDescription])
                }
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
                let text: String = input.value(for: "text") ?? ""
                let delay: Int = input.value(for: "delay") ?? 20
                
                do {
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
                } catch {
                    // Enhanced error handling for type operations
                    if errorContains(error, keywords: ["no element", "not focused"]) {
                        // Get focus information
                        let focusInfo = await MainActor.run {
                            services.automation.getFocusedElement()
                        }
                        
                        if focusInfo == nil {
                            var suggestions: [String] = []
                            var available: [String]? = nil
                            
                            // Try to find available text fields
                            if let sessionId = input.value(for: "sessionId") as? String {
                                let textFields = try? await getAvailableElements(sessionId: sessionId, type: .textField)
                                if let fields = textFields, !fields.isEmpty {
                                    available = fields
                                    if let firstField = fields.first {
                                        let elementId = firstField.components(separatedBy: "(").last?.dropLast() ?? ""
                                        suggestions = ["Click on a text field first. Try: click \(elementId)"]
                                    }
                                }
                            } else {
                                suggestions = ["Use 'see' tool first, then click on a text field"]
                            }
                            
                            let context = createStateContext(
                                currentState: "No text field is currently focused",
                                requiredState: "A text field must be focused to type",
                                fix: "Click on a text field first before typing",
                                suggestions: suggestions.isEmpty ? nil : suggestions
                            )
                            
                            if let available = available {
                                var mutableContext = context
                                mutableContext["available"] = available
                                return .dictionary(createEnhancedError(error, category: .state, context: mutableContext))
                            }
                            
                            return .dictionary(createEnhancedError(error, category: .state, context: context))
                        } else if let info = focusInfo, !info.isEditable {
                            let context = createStateContext(
                                currentState: "Focused element: \(info.elementType) - '\(info.title ?? "")'",
                                requiredState: "Element must be editable",
                                fix: "The focused element is not a text input field"
                            )
                            return .dictionary(createEnhancedError(error, category: .state, context: context))
                        }
                    } else if text.isEmpty {
                        let context = createInvalidInputContext(
                            currentState: "Empty text provided",
                            requiredState: "Text must not be empty",
                            example: "type \"Hello, World!\""
                        )
                        return .dictionary(createEnhancedError(error, category: .invalidInput, context: context))
                    }
                    
                    // Default error response
                    return .dictionary(["success": false, "error": error.localizedDescription])
                }
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
                let text: String? = input.value(for: "text")
                let elementType: String = input.value(for: "elementType") ?? "any"
                let sessionId: String = input.value(for: "sessionId") ?? UUID().uuidString
                
                do {
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
                    
                    if elements.isEmpty {
                        // No exact matches found - provide helpful context
                        var errorResponse: [String: Any] = [
                            "success": false,
                            "error": "No elements found matching '\(query)'"
                        ]
                        
                        var context: [String: Any] = [:]
                        
                        // Get all available elements for suggestions
                        let allElements = try? await getAvailableElements(sessionId: sessionId, type: nil)
                        
                        if let available = allElements, !available.isEmpty {
                            context["available"] = available
                            
                            // If searching by text, suggest partial matches
                            if let searchText = text {
                                let partialMatches = available.filter { element in
                                    element.lowercased().contains(searchText.lowercased())
                                }
                                if !partialMatches.isEmpty {
                                    context["suggestions"] = ["Found partial matches: \(partialMatches.first!)"]
                                }
                            }
                            
                            // If searching by type, show what types are available
                            if text == nil {
                                let detectionResult = try? await services.sessions.getDetectionResult(sessionId: sessionId)
                                if let result = detectionResult {
                                    var availableTypes: [String] = []
                                    if !result.elements.buttons.isEmpty { availableTypes.append("button (\(result.elements.buttons.count))") }
                                    if !result.elements.textFields.isEmpty { availableTypes.append("textField (\(result.elements.textFields.count))") }
                                    if !result.elements.links.isEmpty { availableTypes.append("link (\(result.elements.links.count))") }
                                    if !result.elements.other.isEmpty { availableTypes.append("other (\(result.elements.other.count))") }
                                    
                                    context["available"] = availableTypes
                                    context["suggestions"] = ["No '\(elementType)' elements found. Try one of the available types."]
                                }
                            }
                        } else {
                            context["fix"] = "Use 'see' tool first to capture and detect elements"
                        }
                        
                        errorResponse["errorDetails"] = [
                            "category": "notFound",
                            "context": context
                        ]
                        
                        return .dictionary(errorResponse)
                    }
                    
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
                } catch {
                    return .dictionary([
                        "success": false,
                        "error": error.localizedDescription,
                        "errorDetails": [
                            "category": "system",
                            "context": [
                                "fix": "Use 'see' tool first to capture screen and detect elements"
                            ]
                        ]
                    ])
                }
            }
        )
    }
    
    // MARK: - System Prompt
    
    private func generateSystemPrompt() -> String {
        """
        You are Peekaboo Assistant, an AI agent specialized in macOS automation and UI interaction.
        
        IMPORTANT: You MUST use the provided tools to accomplish tasks. Do not describe what you would do - actually do it using the tools.
        
        ## Communication Style
        
        **CRITICAL REQUIREMENT**: You MUST communicate with the user throughout the process. This is not optional.
        
        Before EVERY tool use, you MUST:
        1. Explain what you're about to do
        2. Explain why you're doing it
        3. Share your current understanding of the task progress
        
        For example:
        - "I'll check what ODS files are in your Downloads folder..."
        - "I need to convert the file to markdown. Let me check what tools are available..."
        - "The conversion failed with pandoc, so I'll try using LibreOffice instead..."
        
        After EVERY tool result, you MUST:
        1. Interpret what the result means
        2. Explain what you learned
        3. State your next step
        
        The user cannot see the tool outputs directly - they rely on your explanations to understand what's happening. Silent tool execution without explanation is a failure mode.
        
        ## Task Completion Requirements
        
        When completing tasks, you MUST:
        
        1. **Follow ALL instructions literally**
           - If asked to "say" something, use the `say` command
           - If asked to "send" something, complete the action fully - creating a draft is NOT sufficient
           - Complete every part of multi-step requests
        
        2. **Verify task completion**
           - After automating UI actions, verify the expected result occurred
           - For sending messages/emails: confirm the compose window closed or the send action completed
           - For file operations: verify the output file exists and has content
        
        3. **Use appropriate tools for each action**
           - "say X" → use shell tool with `say "X"` command
           - "send email" → create draft AND click Send button
           - "delete file" → verify file no longer exists after deletion
        
        ## Tool Selection Guidelines
        
        When a command fails with "command not found":
        - This means the tool/program is NOT installed on the system
        - Do NOT attempt to use it again
        - Find an alternative approach using available tools
        - The error message is definitive - trust it
        
        Example workflow for missing tools:
        1. Try: pandoc file.ods -o file.md
        2. Get: "pandoc: command not found" 
        3. Conclusion: pandoc is NOT available
        4. Action: Use alternative conversion method (e.g., via installed applications)
        
        ## UI Automation Best Practices
        
        When automating applications:
        
        1. **Complete the full user journey**
           - Opening a compose window is not "sending" 
           - Creating a document is not "saving"
           - Always perform the final action (Send, Save, Submit, etc.)
        
        2. **Verify UI state before and after actions**
           - Use see tool to confirm windows/dialogs are present
           - After clicking buttons, verify the expected change occurred
           - If a window should close after an action, confirm it closed
        
        3. **Handle multi-step workflows completely**
           - Draft → Send (not just Draft)
           - Open → Edit → Save (not just Open → Edit)
           - Create → Fill → Submit (not just Create → Fill)
        
        ## Shell Command Best Practices
        
        When using shell commands:
        
        1. **Text-to-speech requests**
           - "say [phrase]" in instructions → use `say "[phrase]"` command
           - This applies to any verbal output request
        
        2. **Command availability is binary**
           - "command not found" = definitely not installed
           - No need to check multiple times or try variations
           - Move to alternative approaches immediately
        
        3. **Escape and quote properly**
           - Use proper escaping for spaces in filenames
           - Handle special characters in shell commands
           - Test commands incrementally when building complex pipelines
        
        ## Critical Guidelines
        
        1. **Be Resilient**: If a tool fails, try alternative approaches. Don't give up at the first error.
        2. **Communicate Your Actions**: Before using each tool, briefly explain what you're about to do and why. This helps the user understand your process.
        3. **Verify UI State**: ALWAYS take a screenshot after launching apps to see their current state (dialogs, intro screens, etc.)
        4. **Complete ALL Tasks**: Read the user's request carefully and ensure you complete EVERY part, including any specific phrases they want you to say.
        5. **Error Recovery**: When operations fail, analyze why and adapt your approach. If AppleScript fails, check your quoting!
        6. **Dialog Handling**: Apps often show intro/welcome dialogs. Take a screenshot to see them, then click "Continue", "Get Started", or dismiss them.
        7. **Progress Updates**: After completing significant steps, briefly summarize what was accomplished before moving to the next step.
        8. **Final Response**: ALWAYS end with what you accomplished, what failed, and ANY requested output (like specific phrases the user wants).
        
        ## Your Capabilities
        
        You have access to powerful tools for:
        - **Shell Commands**: Execute any shell command including file operations, AppleScript, and system utilities
        - **UI Automation**: Click, type, scroll, and interact with any UI element
        - **Window Management**: Launch apps, focus windows, resize, and control window states
        - **Screen Capture**: Take screenshots of screens, windows, or specific applications
        - **Element Detection**: Find and interact with specific UI elements by text or type
        
        ## CRITICAL: Screenshot After App Launch
        
        **ALWAYS** use the `see` tool after launching any application to:
        - See if the app launched successfully
        - Check for intro dialogs, welcome screens, or permission prompts
        - Verify the app is ready for interaction
        - Understand the current UI state before proceeding
        - Get a session ID for subsequent interactions
        
        Example workflow:
        1. `launch_app "Numbers"`
        2. `see` to capture current state and detect UI elements
        3. If dialog present, click appropriate button (Continue, Skip, etc.)
        4. Proceed with main task
        
        The `see` tool is your primary way to understand what's on screen. It combines screenshot capture with UI element detection, giving you a complete picture of the current state.
        
        ## Creative Problem Solving
        
        Use your tools creatively to accomplish complex tasks:
        
        ### File Operations via Shell
        - List files: `ls ~/Downloads/*.ods`
        - Check file existence: `test -f ~/Downloads/file.ods && echo "exists"`
        - Move/copy files: `cp source.txt destination.txt`
        - Read file contents: `cat filename.txt`
        - Convert files using command-line tools: `pandoc input.ods -o output.md`
        
        ### Application Automation via AppleScript
        
        **IMPORTANT AppleScript Quoting Rules:**
        - Use single quotes for the outer shell command
        - Use double quotes inside AppleScript strings
        - Escape inner quotes properly: `osascript -e 'tell application "Mail" to make new outgoing message with properties {subject:"Test", content:"Hello", visible:true}'`
        - For complex scripts with quotes, use heredoc:
          ```
          osascript <<EOF
          tell application "Mail"
              make new outgoing message with properties {subject:"My Subject", content:"My content with 'quotes'", visible:true}
          end tell
          EOF
          ```
        
        Common AppleScript commands:
        - Navigate Finder: `osascript -e 'tell application "Finder" to open folder "Downloads" of home'`
        - Control any app: `osascript -e 'tell application "AppName" to activate'`
        - Wait for app: After launching, ALWAYS screenshot to verify state
        - Interact with menus: `osascript -e 'tell application "System Events" to click menu item "Save As..." of menu "File" of menu bar 1 of process "AppName"'`
        - Dismiss dialogs: `osascript -e 'tell application "System Events" to click button "Continue" of window 1 of process "AppName"'`
        
        ### Email Automation
        
        For sending emails:
        1. **Simple approach**: `open "mailto:email@example.com?subject=Subject&body=Body"`
        2. **Full control with Mail app**:
           ```
           osascript -e 'tell application "Mail"
               set newMessage to make new outgoing message with properties {subject:"Your Subject", content:"Your message content", visible:true}
               tell newMessage
                   make new to recipient with properties {address:"recipient@example.com"}
               end tell
           end tell'
           ```
        3. **After creating email**: Take a screenshot to verify, then:
           - Use UI automation to add attachments if needed
           - Click the Send button or use: `osascript -e 'tell application "Mail" to send the front outgoing message'`
        
        ### Handling Common Scenarios
        
        **App Welcome Screens:**
        1. Launch app
        2. Take screenshot
        3. Look for buttons like: "Continue", "Get Started", "Skip", "Next", "Close"
        4. Click appropriate button
        5. Take another screenshot to verify you're past the intro
        
        **File Conversion Tasks:**
        1. Find the file
        2. Try command-line tools first (pandoc, textutil, etc.)
        3. If unavailable, use GUI apps:
           - Launch appropriate app
           - Screenshot to see state
           - Handle any dialogs
           - Open file via File menu or drag-drop
           - Export/Save As to desired format
        
        **Complex Multi-Step Tasks:**
        - Break down the request into ALL components
        - Track what needs to be done (file conversion, email composition, specific output phrases)
        - Complete each step methodically
        - Verify success with screenshots
        - ALWAYS complete with ALL requested outputs
        
        ## Task Completion Checklist
        
        Before finishing, verify:
        ✓ Did I complete the main task?
        ✓ Did I include all requested elements? (poems, specific phrases, etc.)
        ✓ Did I verify my actions worked? (screenshots, file existence checks)
        ✓ Did I say any specific phrases the user requested?
        ✓ Did I handle any errors gracefully and try alternatives?
        
        ## Speech Output
        
        When the user asks you to "say" something, they mean using the macOS text-to-speech command:
        - Use the `say` command: `say "Your text here"`
        - For example: `say "YOWZA YOWZA BO-BOWZA"`
        - This will speak the text aloud through the system's audio output
        - You can also specify a voice: `say -v "Samantha" "Hello world"`
        
        Remember: You have full system access through the shell tool. Use it creatively alongside UI automation to accomplish any task. Take screenshots liberally to understand UI state. Don't just describe what to do - DO IT using your tools!
        
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
                sessionId: effectiveSessionId,
                streamHandler: { chunk in
                    // Only emit assistant message events for actual text content
                    // Tool call events are handled separately
                    if !chunk.isEmpty {
                        eventContinuation.yield(.assistantMessage(content: chunk))
                    }
                },
                eventHandler: { toolEvent in
                    // Convert tool events to agent events
                    switch toolEvent {
                    case .started(let name, let arguments):
                        eventContinuation.yield(.toolCallStarted(name: name, arguments: arguments))
                    case .completed(let name, let result):
                        eventContinuation.yield(.toolCallCompleted(name: name, result: result))
                    }
                }
            )
            
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
                let appName: String = input.value(for: "appName") ?? ""
                let windowIndex: Int? = input.value(for: "windowIndex")
                
                do {
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
                } catch {
                    // Enhanced error handling for window capture
                    var errorResponse: [String: Any] = [
                        "success": false,
                        "error": error.localizedDescription
                    ]
                    
                    var context: [String: Any] = [:]
                    
                    // Check window state
                    let windowState = try? await getWindowState(appName: appName)
                    
                    if let state = windowState {
                        if !state.appRunning {
                            let similarApps = try? await findSimilarApps(appName)
                            context["available"] = similarApps ?? []
                            context["suggestions"] = ["App '\(appName)' not found. Did you mean one of these?"]
                            context["fix"] = "Use exact app name or launch it first"
                        } else if state.windows.isEmpty {
                            context["currentState"] = "App is running but has no windows"
                            context["fix"] = "Open a window in \(appName) first"
                        } else {
                            // Show available windows
                            let windowInfo = state.windows.enumerated().map { index, window in
                                "\(index): \(window.title)" + (window.isMinimized ? " (minimized)" : "")
                            }
                            context["available"] = windowInfo
                            
                            if let idx = windowIndex, idx >= state.windows.count {
                                context["currentState"] = "Window index \(idx) out of range"
                                context["suggestions"] = ["Valid indices: 0 to \(state.windows.count - 1)"]
                            }
                        }
                    }
                    
                    // Check permissions if needed
                    if error.localizedDescription.lowercased().contains("permission") {
                        let permissions = await getPermissionDiagnostics()
                        context["currentState"] = "Permission denied"
                        context["requiredState"] = "Screen Recording permission required"
                        context["fix"] = "Grant Screen Recording permission in System Settings > Privacy & Security"
                        context["permissions"] = permissions
                    }
                    
                    errorResponse["errorDetails"] = [
                        "category": error.localizedDescription.contains("permission") ? "permission" : "notFound",
                        "context": context
                    ]
                    
                    return .dictionary(errorResponse)
                }
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
                let keys: String = input.value(for: "keys") ?? ""
                let holdDuration: Int = input.value(for: "holdDuration") ?? 100
                
                do {
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
                } catch {
                    // Enhanced error handling for hotkey operations
                    var errorResponse: [String: Any] = [
                        "success": false,
                        "error": error.localizedDescription
                    ]
                    
                    var context: [String: Any] = [:]
                    
                    // Check for invalid key format
                    if error.localizedDescription.lowercased().contains("invalid") ||
                       error.localizedDescription.lowercased().contains("unknown key") ||
                       keys.isEmpty {
                        
                        context["currentState"] = "Invalid key combination: '\(keys)'"
                        context["requiredState"] = "Valid comma-separated key combination"
                        
                        // Provide examples based on common mistakes
                        var examples = [
                            "cmd,c - Copy",
                            "cmd,v - Paste",
                            "cmd,tab - Switch apps",
                            "cmd,shift,4 - Screenshot",
                            "cmd,space - Spotlight",
                            "cmd,option,esc - Force quit"
                        ]
                        
                        // Add specific suggestions based on the input
                        if keys.contains("+") {
                            context["suggestions"] = ["Use commas instead of '+' to separate keys"]
                            examples.insert("cmd,shift,a (not cmd+shift+a)", at: 0)
                        } else if keys.contains(" and ") || keys.contains("&") {
                            context["suggestions"] = ["Use commas to separate keys"]
                        }
                        
                        context["example"] = examples.joined(separator: ", ")
                        context["fix"] = "Valid modifiers: cmd, shift, option/alt, control/ctrl, fn"
                        
                        errorResponse["errorDetails"] = [
                            "category": "invalidInput",
                            "context": context
                        ]
                    } else if holdDuration < 0 || holdDuration > 5000 {
                        context["currentState"] = "Invalid hold duration: \(holdDuration)ms"
                        context["requiredState"] = "Duration must be between 0 and 5000 milliseconds"
                        context["example"] = "hotkey \"cmd,c\" 100"
                        
                        errorResponse["errorDetails"] = [
                            "category": "invalidInput",
                            "context": context
                        ]
                    }
                    
                    return .dictionary(errorResponse)
                }
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
                let appName: String = input.value(for: "appName") ?? ""
                let windowTitle: String? = input.value(for: "windowTitle")
                
                do {
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
                } catch {
                    // Enhanced error handling for window operations
                    var errorResponse: [String: Any] = [
                        "success": false,
                        "error": error.localizedDescription
                    ]
                    
                    // Check window state
                    let windowState = try? await getWindowState(appName: appName)
                    
                    var context: [String: Any] = [:]
                    
                    if let state = windowState {
                        if !state.appRunning {
                            // App not running
                            let similarApps = try? await findSimilarApps(appName)
                            if let similar = similarApps, !similar.isEmpty {
                                context["available"] = similar
                                context["suggestions"] = ["App '\(appName)' not running. Did you mean: \(similar.first!)?"]
                                context["fix"] = "Launch the app first with: launch_app \"\(appName)\""
                            }
                        } else if state.windows.isEmpty {
                            // App running but no windows
                            context["currentState"] = "App is running but has no windows"
                            context["suggestions"] = ["The app is running but has no open windows"]
                            context["fix"] = "Create a new window in the app or check if windows are minimized"
                        } else {
                            // Windows exist, show them
                            let windowTitles = state.windows.prefix(3).map { window in
                                let status = window.isMinimized ? " (minimized)" : ""
                                return "\(window.title)\(status)"
                            }
                            context["available"] = windowTitles
                            
                            if state.windows.allSatisfy({ $0.isMinimized }) {
                                context["currentState"] = "All windows are minimized"
                                context["fix"] = "Windows are minimized. They will be restored when focused."
                            }
                        }
                    }
                    
                    errorResponse["errorDetails"] = [
                        "category": "state",
                        "context": context
                    ]
                    
                    return .dictionary(errorResponse)
                }
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
                let appName: String = input.value(for: "appName") ?? ""
                let width: Double = input.value(for: "width") ?? 800
                let height: Double = input.value(for: "height") ?? 600
                let windowTitle: String? = input.value(for: "windowTitle")
                
                do {
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
                } catch {
                    // Enhanced error handling for resize operations
                    var errorResponse: [String: Any] = [
                        "success": false,
                        "error": error.localizedDescription
                    ]
                    
                    var context: [String: Any] = [:]
                    
                    // Check if dimensions are valid
                    if width <= 0 || height <= 0 {
                        context["currentState"] = "Invalid dimensions: width=\(width), height=\(height)"
                        context["requiredState"] = "Width and height must be positive numbers"
                        context["example"] = "resize_window \"Safari\" 1200 800"
                        
                        errorResponse["errorDetails"] = [
                            "category": "invalidInput",
                            "context": context
                        ]
                    } else {
                        // Check window state for other errors
                        let windowState = try? await getWindowState(appName: appName)
                        
                        if let state = windowState {
                            if !state.appRunning {
                                let similarApps = try? await findSimilarApps(appName)
                                context["available"] = similarApps ?? []
                                context["suggestions"] = ["App '\(appName)' not found"]
                                context["fix"] = "Check app name or use 'list_apps' to see available apps"
                            } else if state.windows.isEmpty {
                                context["currentState"] = "App has no windows"
                                context["fix"] = "Open a window in \(appName) first"
                            } else if state.windows.allSatisfy({ $0.isMinimized }) {
                                context["currentState"] = "All windows are minimized"
                                context["suggestions"] = ["Windows will be restored and resized"]
                            }
                        }
                        
                        errorResponse["errorDetails"] = [
                            "category": "state",
                            "context": context
                        ]
                    }
                    
                    return .dictionary(errorResponse)
                }
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
                let appName: String = input.value(for: "appName") ?? ""
                
                do {
                    _ = try await services.applications.launchApplication(identifier: appName)
                    
                    return .dictionary([
                        "success": true,
                        "action": "launched",
                        "appName": appName
                    ])
                } catch {
                    // Enhanced error handling for app launch
                    var errorResponse: [String: Any] = [
                        "success": false,
                        "error": error.localizedDescription
                    ]
                    
                    // Check if it's an app not found error
                    if error.localizedDescription.lowercased().contains("not found") ||
                       error.localizedDescription.lowercased().contains("no such") ||
                       error.localizedDescription.lowercased().contains("unable to find") {
                        
                        // Find similar apps
                        let similarApps = try? await findSimilarApps(appName)
                        
                        var context: [String: Any] = [:]
                        
                        if let similar = similarApps, !similar.isEmpty {
                            context["available"] = similar
                            context["suggestions"] = ["Did you mean: \(similar.first!)? Try: launch_app \"\(similar.first!)\""]
                        } else {
                            // Get all running apps
                            let allApps = try? await services.applications.listApplications()
                            if let apps = allApps, !apps.isEmpty {
                                let appNames = apps.prefix(5).map { $0.name }
                                context["available"] = appNames
                                context["suggestions"] = ["Use 'list_apps' to see all available applications"]
                            }
                        }
                        
                        context["example"] = "launch_app \"Safari\" or launch_app \"com.apple.Safari\""
                        
                        errorResponse["errorDetails"] = [
                            "category": "notFound",
                            "context": context
                        ]
                    }
                    
                    return .dictionary(errorResponse)
                }
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
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
                        // For failed commands, combine output and error for better context
                        var errorMessage = ""
                        
                        // Include stdout if it has content (e.g., "pandoc not found" from which)
                        if !output.isEmpty {
                            errorMessage = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        
                        // Add stderr if present
                        if !errorOutput.isEmpty {
                            if !errorMessage.isEmpty {
                                errorMessage += "\n"
                            }
                            errorMessage += errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        
                        // Fallback if both are empty
                        if errorMessage.isEmpty {
                            errorMessage = "Command failed with exit code \(process.terminationStatus)"
                        }
                        
                        return .dictionary([
                            "success": false,
                            "output": output, // Still include raw output for completeness
                            "error": errorMessage,
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
                let appName: String? = input.value(for: "appName")
                let menuPath: String = input.value(for: "menuPath") ?? ""
                
                do {
                    let targetApp: String
                    if let app = appName {
                        targetApp = app
                    } else {
                        // Get frontmost app
                        let frontmostApp = try await services.applications.getFrontmostApplication()
                        targetApp = frontmostApp.name
                    }
                    
                    try await services.menu.clickMenuItem(app: targetApp, itemPath: menuPath)
                    
                    return .dictionary([
                        "success": true,
                        "menuPath": menuPath,
                        "app": targetApp
                    ])
                } catch {
                    // Enhanced error handling for menu operations
                    var errorResponse: [String: Any] = [
                        "success": false,
                        "error": error.localizedDescription
                    ]
                    
                    var context: [String: Any] = [:]
                    
                    // Check if it's a menu not found error
                    if error.localizedDescription.lowercased().contains("not found") ||
                       error.localizedDescription.lowercased().contains("menu") {
                        
                        // Try to get available menus
                        let targetApp = appName ?? (try? await services.applications.getFrontmostApplication().name) ?? ""
                        
                        if !targetApp.isEmpty {
                            if let menuStructure = try? await services.menu.listMenus(for: targetApp) {
                                // Extract some available menu paths
                                var availablePaths: [String] = []
                                for menu in menuStructure.menus.prefix(3) {
                                    for item in menu.items.prefix(3) {
                                        availablePaths.append("\(menu.title) > \(item.title)")
                                    }
                                }
                                
                                if !availablePaths.isEmpty {
                                    context["available"] = availablePaths
                                }
                                
                                // Suggest correct format
                                context["example"] = "File > New, Edit > Copy, or just Copy"
                                context["suggestions"] = ["Menu path not found. Check the exact menu names."]
                            }
                        }
                        
                        context["fix"] = "Use 'list_menus' to see all available menu items"
                        
                        errorResponse["errorDetails"] = [
                            "category": "notFound",
                            "context": context
                        ]
                    } else if error.localizedDescription.lowercased().contains("disabled") {
                        context["currentState"] = "Menu item is disabled"
                        context["requiredState"] = "Menu item must be enabled"
                        context["suggestions"] = ["The menu item exists but is currently disabled"]
                        
                        errorResponse["errorDetails"] = [
                            "category": "state",
                            "context": context
                        ]
                    }
                    
                    return .dictionary(errorResponse)
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
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
                    // Enhanced error handling for dialog operations
                    var errorResponse: [String: Any] = [
                        "success": false,
                        "error": error.localizedDescription
                    ]
                    
                    var context: [String: Any] = [:]
                    
                    // Check if it's a dialog not found error
                    if error.localizedDescription.lowercased().contains("no dialog") ||
                       error.localizedDescription.lowercased().contains("not found") {
                        
                        context["currentState"] = "No dialog window found"
                        context["requiredState"] = "An active dialog or alert must be present"
                        
                        // Try to detect what dialogs might be present
                        if let activeDialogs = try? await services.dialogs.detectActiveDialogs() {
                            if !activeDialogs.isEmpty {
                                let dialogInfo = activeDialogs.map { dialog in
                                    "\(dialog.title) - buttons: \(dialog.buttons.joined(separator: ", "))"
                                }
                                context["available"] = dialogInfo
                                context["suggestions"] = ["Found dialogs with different buttons. Check the exact button text."]
                            }
                        }
                        
                        context["fix"] = "Ensure a dialog is open before trying to click buttons"
                        
                        errorResponse["errorDetails"] = [
                            "category": "notFound",
                            "context": context
                        ]
                    } else if error.localizedDescription.lowercased().contains("button") {
                        context["currentState"] = "Button '\(buttonText)' not found in dialog"
                        
                        // Try to get available buttons
                        if let activeDialogs = try? await services.dialogs.detectActiveDialogs(),
                           let firstDialog = activeDialogs.first {
                            context["available"] = firstDialog.buttons
                            context["suggestions"] = ["Available buttons in the dialog"]
                        }
                        
                        context["example"] = "Common buttons: OK, Cancel, Save, Don't Save, Continue"
                        
                        errorResponse["errorDetails"] = [
                            "category": "notFound",
                            "context": context
                        ]
                    }
                    
                    return .dictionary(errorResponse)
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
            execute: { [weak self] input, services in
                guard let self = self else { return .dictionary(["success": false, "error": "Internal error"]) }
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

// MARK: - Error Enhancement Helpers

extension PeekabooAgentService {
    /// Create an enhanced error response with detailed context
    private func createEnhancedError(
        _ error: Error,
        category: ErrorCategory,
        context: [String: Any]
    ) -> [String: Any] {
        return [
            "success": false,
            "error": error.localizedDescription,
            "errorDetails": [
                "category": category.rawValue,
                "context": context
            ]
        ]
    }
    
    /// Error categories for consistent error handling
    private enum ErrorCategory: String {
        case notFound = "notFound"
        case permission = "permission"
        case state = "state"
        case invalidInput = "invalidInput"
        case system = "system"
    }
    
    /// Check if error message contains any of the given keywords (case insensitive)
    private func errorContains(_ error: Error, keywords: [String]) -> Bool {
        let errorLower = error.localizedDescription.lowercased()
        return keywords.contains { errorLower.contains($0.lowercased()) }
    }
    
    /// Create a "not found" error context with suggestions
    private func createNotFoundContext(
        available: [String]? = nil,
        suggestions: [String]? = nil,
        fix: String? = nil,
        example: String? = nil
    ) -> [String: Any] {
        var context: [String: Any] = [:]
        if let available = available { context["available"] = available }
        if let suggestions = suggestions { context["suggestions"] = suggestions }
        if let fix = fix { context["fix"] = fix }
        if let example = example { context["example"] = example }
        return context
    }
    
    /// Create a "state" error context
    private func createStateContext(
        currentState: String,
        requiredState: String? = nil,
        fix: String? = nil,
        suggestions: [String]? = nil
    ) -> [String: Any] {
        var context: [String: Any] = ["currentState": currentState]
        if let requiredState = requiredState { context["requiredState"] = requiredState }
        if let fix = fix { context["fix"] = fix }
        if let suggestions = suggestions { context["suggestions"] = suggestions }
        return context
    }
    
    /// Create an "invalid input" error context
    private func createInvalidInputContext(
        currentState: String,
        requiredState: String,
        example: String,
        suggestions: [String]? = nil
    ) -> [String: Any] {
        var context: [String: Any] = [
            "currentState": currentState,
            "requiredState": requiredState,
            "example": example
        ]
        if let suggestions = suggestions { context["suggestions"] = suggestions }
        return context
    }

// MARK: - Original Helper Functions
    
    /// Find applications with names similar to the given name
    private func findSimilarApps(_ searchName: String) async throws -> [String] {
        let apps = try await services.applications.listApplications()
        let appNames = apps.map { $0.name }
        
        // Simple fuzzy matching - find apps that contain the search term or vice versa
        let searchLower = searchName.lowercased()
        var matches: [(name: String, score: Int)] = []
        
        for appName in appNames {
            let appLower = appName.lowercased()
            
            // Exact match
            if appLower == searchLower {
                matches.append((appName, 100))
            }
            // App name contains search
            else if appLower.contains(searchLower) {
                matches.append((appName, 80))
            }
            // Search contains app name
            else if searchLower.contains(appLower) {
                matches.append((appName, 70))
            }
            // Levenshtein distance for typos
            else {
                let distance = levenshteinDistance(searchLower, appLower)
                if distance <= 3 {
                    matches.append((appName, 60 - distance * 10))
                }
            }
        }
        
        // Sort by score and return top 3
        return matches
            .sorted { $0.score > $1.score }
            .prefix(3)
            .map { $0.name }
    }
    
    /// Simple Levenshtein distance implementation for fuzzy matching
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        
        if s1Array.isEmpty { return s2Array.count }
        if s2Array.isEmpty { return s1Array.count }
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: s2Array.count + 1), count: s1Array.count + 1)
        
        for i in 0...s1Array.count {
            matrix[i][0] = i
        }
        
        for j in 0...s2Array.count {
            matrix[0][j] = j
        }
        
        for i in 1...s1Array.count {
            for j in 1...s2Array.count {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,     // deletion
                    matrix[i][j-1] + 1,     // insertion
                    matrix[i-1][j-1] + cost // substitution
                )
            }
        }
        
        return matrix[s1Array.count][s2Array.count]
    }
    
    /// Get available UI elements for error context
    private func getAvailableElements(sessionId: String?, type: ElementType? = nil) async throws -> [String] {
        guard let sessionId = sessionId,
              let detectionResult = try await services.sessions.getDetectionResult(sessionId: sessionId) else {
            return []
        }
        
        let elements: [DetectedElement]
        switch type {
        case .button:
            elements = detectionResult.elements.buttons
        case .textField:
            elements = detectionResult.elements.textFields
        case .link:
            elements = detectionResult.elements.links
        default:
            elements = detectionResult.elements.all
        }
        
        // Return formatted element descriptions
        return elements.prefix(5).map { element in
            if let label = element.label, !label.isEmpty {
                return "'\(label)' (\(element.identifier))"
            } else {
                return "\(element.type.rawValue) (\(element.identifier))"
            }
        }
    }
    
    /// Get window state information for an application
    private func getWindowState(appName: String) async throws -> (windows: [ServiceWindowInfo], appRunning: Bool) {
        do {
            let windows = try await services.applications.listWindows(for: appName)
            return (windows, true)
        } catch {
            // Check if app is running
            let apps = try await services.applications.listApplications()
            let appRunning = apps.contains { $0.name.lowercased() == appName.lowercased() }
            return ([], appRunning)
        }
    }
    
    /// Get current permission status
    private func getPermissionDiagnostics() async -> [String: Any] {
        var diagnostics: [String: Any] = [:]
        
        // Check screen recording permission
        diagnostics["screenRecording"] = await services.permissions?.hasScreenRecordingPermission() ?? false
        
        // Check accessibility permission
        diagnostics["accessibility"] = await services.permissions?.hasAccessibilityPermission() ?? false
        
        return diagnostics
    }
    
    /// Format element suggestions for click operations
    private func formatElementSuggestion(_ element: DetectedElement) -> String {
        if let label = element.label, !label.isEmpty {
            return "Try: click \(element.identifier) for '\(label)'"
        } else {
            return "Try: click \(element.identifier)"
        }
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