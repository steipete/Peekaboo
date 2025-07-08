import Foundation
import AppKit
import AXorcist

/// Implementation of ProcessServiceProtocol for executing Peekaboo scripts
@available(macOS 14.0, *)
public actor ProcessService: ProcessServiceProtocol {
    private let applicationService: ApplicationServiceProtocol
    private let screenCaptureService: ScreenCaptureServiceProtocol
    private let sessionManager: SessionManagerProtocol
    private let uiAutomationService: UIAutomationServiceProtocol
    private let windowManagementService: WindowManagementServiceProtocol
    private let menuService: MenuServiceProtocol
    private let dockService: DockServiceProtocol
    
    public init(
        applicationService: ApplicationServiceProtocol,
        screenCaptureService: ScreenCaptureServiceProtocol,
        sessionManager: SessionManagerProtocol,
        uiAutomationService: UIAutomationServiceProtocol,
        windowManagementService: WindowManagementServiceProtocol,
        menuService: MenuServiceProtocol,
        dockService: DockServiceProtocol
    ) {
        self.applicationService = applicationService
        self.screenCaptureService = screenCaptureService
        self.sessionManager = sessionManager
        self.uiAutomationService = uiAutomationService
        self.windowManagementService = windowManagementService
        self.menuService = menuService
        self.dockService = dockService
    }
    
    public func loadScript(from path: String) async throws -> PeekabooScript {
        let url = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NotFoundError(
                code: .fileNotFound,
                userMessage: "Script file not found: \(path)",
                context: ["path": path]
            )
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(PeekabooScript.self, from: data)
        } catch {
            throw ValidationError(
                code: .invalidInput,
                userMessage: "Invalid script format: \(error.localizedDescription)",
                context: ["field": "script", "reason": error.localizedDescription]
            )
        }
    }
    
    public func executeScript(
        _ script: PeekabooScript,
        failFast: Bool,
        verbose: Bool
    ) async throws -> [StepResult] {
        var results: [StepResult] = []
        var currentSessionId: String?
        
        for (index, step) in script.steps.enumerated() {
            let stepNumber = index + 1
            let stepStartTime = Date()
            
            do {
                // Execute the step
                let executionResult = try await executeStep(step, sessionId: currentSessionId)
                
                // Update session ID if a new one was created
                if let newSessionId = executionResult.sessionId {
                    currentSessionId = newSessionId
                }
                
                let result = StepResult(
                    stepId: step.stepId,
                    stepNumber: stepNumber,
                    command: step.command,
                    success: true,
                    output: AnyCodable(executionResult.output),
                    error: nil,
                    executionTime: Date().timeIntervalSince(stepStartTime)
                )
                
                results.append(result)
                
            } catch {
                let result = StepResult(
                    stepId: step.stepId,
                    stepNumber: stepNumber,
                    command: step.command,
                    success: false,
                    output: nil,
                    error: error.localizedDescription,
                    executionTime: Date().timeIntervalSince(stepStartTime)
                )
                
                results.append(result)
                
                if failFast {
                    break
                }
            }
        }
        
        return results
    }
    
    public func executeStep(
        _ step: ScriptStep,
        sessionId: String?
    ) async throws -> StepExecutionResult {
        // Map command to appropriate service method
        switch step.command.lowercased() {
        case "see":
            return try await executeSeeCommand(step, sessionId: sessionId)
            
        case "click":
            return try await executeClickCommand(step, sessionId: sessionId)
            
        case "type":
            return try await executeTypeCommand(step, sessionId: sessionId)
            
        case "scroll":
            return try await executeScrollCommand(step, sessionId: sessionId)
            
        case "swipe":
            return try await executeSwipeCommand(step, sessionId: sessionId)
            
        case "drag":
            return try await executeDragCommand(step, sessionId: sessionId)
            
        case "hotkey":
            return try await executeHotkeyCommand(step, sessionId: sessionId)
            
        case "sleep":
            return try await executeSleepCommand(step)
            
        case "window":
            return try await executeWindowCommand(step, sessionId: sessionId)
            
        case "menu":
            return try await executeMenuCommand(step, sessionId: sessionId)
            
        case "dock":
            return try await executeDockCommand(step)
            
        case "app":
            return try await executeAppCommand(step)
            
        default:
            throw ValidationError(
                code: .invalidInput,
                userMessage: "Unknown command: \(step.command)",
                context: ["field": "command", "value": step.command]
            )
        }
    }
    
    // MARK: - Command Implementations
    
    private func executeSeeCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        // Extract parameters
        let mode = step.params?["mode"]?.value as? String ?? "window"
        let app = step.params?["app"]?.value as? String
        let window = step.params?["window"]?.value as? String
        let outputPath = step.params?["path"]?.value as? String
        let annotate = step.params?["annotate"]?.value as? Bool ?? true
        
        // Capture screenshot based on mode
        let captureResult: CaptureResult
        switch mode {
        case "fullscreen":
            captureResult = try await screenCaptureService.captureScreen(displayIndex: nil)
        case "frontmost":
            captureResult = try await screenCaptureService.captureFrontmost()
        case "window":
            if let appName = app {
                let windowIndex = window.flatMap { title in
                    // Try to parse as index
                    Int(title)
                }
                captureResult = try await screenCaptureService.captureWindow(
                    appIdentifier: appName,
                    windowIndex: windowIndex
                )
            } else {
                captureResult = try await screenCaptureService.captureFrontmost()
            }
        default:
            captureResult = try await screenCaptureService.captureFrontmost()
        }
        
        // Save to output path if specified
        let screenshotPath: String
        if let outputPath = outputPath {
            try captureResult.imageData.write(to: URL(fileURLWithPath: outputPath))
            screenshotPath = outputPath
        } else {
            screenshotPath = captureResult.savedPath ?? ""
        }
        
        // Create or update session
        let newSessionId: String
        if let existingSessionId = sessionId {
            newSessionId = existingSessionId
            // Store screenshot in existing session
            if let appInfo = captureResult.metadata.applicationInfo,
               let windowInfo = captureResult.metadata.windowInfo {
                try await sessionManager.storeScreenshot(
                    sessionId: existingSessionId,
                    screenshotPath: screenshotPath,
                    applicationName: appInfo.name,
                    windowTitle: windowInfo.title,
                    windowBounds: windowInfo.bounds
                )
            } else {
                try await sessionManager.storeScreenshot(
                    sessionId: existingSessionId,
                    screenshotPath: screenshotPath,
                    applicationName: nil,
                    windowTitle: nil,
                    windowBounds: nil
                )
            }
        } else {
            // Create new session
            newSessionId = try await sessionManager.createSession()
            // Store screenshot in new session
            if let appInfo = captureResult.metadata.applicationInfo,
               let windowInfo = captureResult.metadata.windowInfo {
                try await sessionManager.storeScreenshot(
                    sessionId: newSessionId,
                    screenshotPath: screenshotPath,
                    applicationName: appInfo.name,
                    windowTitle: windowInfo.title,
                    windowBounds: windowInfo.bounds
                )
            } else {
                try await sessionManager.storeScreenshot(
                    sessionId: newSessionId,
                    screenshotPath: screenshotPath,
                    applicationName: nil,
                    windowTitle: nil,
                    windowBounds: nil
                )
            }
        }
        
        // Build UI map if annotate is true
        if annotate {
            let detectionResult = try await uiAutomationService.detectElements(
                in: captureResult.imageData,
                sessionId: newSessionId
            )
            
            // Store detection result in session
            try await sessionManager.storeDetectionResult(
                sessionId: newSessionId,
                result: detectionResult
            )
        }
        
        return StepExecutionResult(
            output: ["session_id": newSessionId, "screenshot_path": screenshotPath],
            sessionId: newSessionId
        )
    }
    
    private func executeClickCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        guard let effectiveSessionId = sessionId ?? step.params?["session"]?.value as? String else {
            throw ValidationError(
                code: .invalidInput,
                userMessage: "Missing required parameter 'session' for command 'click'",
                context: ["command": "click", "parameter": "session"]
            )
        }
        
        let query = step.params?["query"]?.value as? String
        let elementId = step.params?["element"]?.value as? String
        let rightClick = step.params?["right-click"]?.value as? Bool ?? false
        let doubleClick = step.params?["double-click"]?.value as? Bool ?? false
        let _ = parseModifiers(from: step.params) // Currently unused in click
        
        // Get session detection result
        guard let _ = try await sessionManager.getDetectionResult(sessionId: effectiveSessionId) else {
            throw NotFoundError(
                code: .sessionNotFound,
                userMessage: "Session not found: \(effectiveSessionId)",
                context: ["session_id": effectiveSessionId]
            )
        }
        
        // Determine click target
        let clickTarget: ClickTarget
        if let elementId = elementId {
            clickTarget = .elementId(elementId)
        } else if let query = query {
            clickTarget = .query(query)
        } else {
            throw ValidationError(
                code: .invalidInput,
                userMessage: "Missing required parameter 'query' or 'element' for command 'click'",
                context: ["command": "click", "parameters": "query or element"]
            )
        }
        
        // Perform click
        let clickType: ClickType = doubleClick ? .double : (rightClick ? .right : .single)
        try await uiAutomationService.click(
            target: clickTarget,
            clickType: clickType,
            sessionId: effectiveSessionId
        )
        
        return StepExecutionResult(
            output: ["clicked": true],
            sessionId: effectiveSessionId
        )
    }
    
    private func executeTypeCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        guard let text = step.params?["text"]?.value as? String else {
            throw ValidationError(
                code: .invalidInput,
                userMessage: "Missing required parameter 'text' for command 'type'",
                context: ["command": "type", "parameter": "text"]
            )
        }
        
        let clearFirst = step.params?["clear-first"]?.value as? Bool ?? false
        let pressEnter = step.params?["press-enter"]?.value as? Bool ?? false
        
        if clearFirst {
            // Select all and delete
            // Clear is handled by clearExisting parameter
        }
        
        // Type the text
        try await uiAutomationService.type(
            text: text,
            target: nil,
            clearExisting: clearFirst,
            typingDelay: 50,
            sessionId: sessionId
        )
        
        if pressEnter {
            try await uiAutomationService.hotkey(keys: "return", holdDuration: 0)
        }
        
        return StepExecutionResult(
            output: ["typed": text, "cleared": clearFirst, "enter_pressed": pressEnter],
            sessionId: sessionId
        )
    }
    
    private func executeScrollCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        let direction = step.params?["direction"]?.value as? String ?? "down"
        let amount = step.params?["amount"]?.value as? Int ?? 5
        let smooth = step.params?["smooth"]?.value as? Bool ?? false
        let delay = step.params?["delay"]?.value as? Int ?? 100
        
        let scrollDirection: ScrollDirection
        switch direction.lowercased() {
        case "up": scrollDirection = .up
        case "down": scrollDirection = .down
        case "left": scrollDirection = .left
        case "right": scrollDirection = .right
        default: scrollDirection = .down
        }
        
        let targetElement = step.params?["on"]?.value as? String
        
        try await uiAutomationService.scroll(
            direction: scrollDirection,
            amount: amount,
            target: targetElement,
            smooth: smooth,
            delay: delay,
            sessionId: sessionId ?? step.params?["session"]?.value as? String
        )
        
        return StepExecutionResult(
            output: ["scrolled": direction, "amount": amount, "smooth": smooth],
            sessionId: sessionId
        )
    }
    
    private func executeSwipeCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        let direction = step.params?["direction"]?.value as? String ?? "right"
        let distance = step.params?["distance"]?.value as? Double ?? 100.0
        let duration = step.params?["duration"]?.value as? Double ?? 0.5
        
        let swipeDirection: SwipeDirection
        switch direction.lowercased() {
        case "up": swipeDirection = .up
        case "down": swipeDirection = .down
        case "left": swipeDirection = .left
        case "right": swipeDirection = .right
        default: swipeDirection = .right
        }
        
        // If coordinates are specified, use them as the starting point
        var startPoint: CGPoint?
        if let x = step.params?["from-x"]?.value as? Double,
           let y = step.params?["from-y"]?.value as? Double {
            startPoint = CGPoint(x: x, y: y)
        }
        
        // Calculate end point based on direction and distance
        let endPoint: CGPoint
        if let start = startPoint {
            switch swipeDirection {
            case .up:
                endPoint = CGPoint(x: start.x, y: start.y - distance)
            case .down:
                endPoint = CGPoint(x: start.x, y: start.y + distance)
            case .left:
                endPoint = CGPoint(x: start.x - distance, y: start.y)
            case .right:
                endPoint = CGPoint(x: start.x + distance, y: start.y)
            }
        } else {
            // Default starting point at center of screen
            let screenBounds = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
            let center = CGPoint(x: screenBounds.midX, y: screenBounds.midY)
            switch swipeDirection {
            case .up:
                startPoint = center
                endPoint = CGPoint(x: center.x, y: center.y - distance)
            case .down:
                startPoint = center
                endPoint = CGPoint(x: center.x, y: center.y + distance)
            case .left:
                startPoint = center
                endPoint = CGPoint(x: center.x - distance, y: center.y)
            case .right:
                startPoint = center
                endPoint = CGPoint(x: center.x + distance, y: center.y)
            }
        }
        
        try await uiAutomationService.swipe(
            from: startPoint ?? CGPoint.zero,
            to: endPoint,
            duration: Int(duration * 1000), // Convert to milliseconds
            steps: 30
        )
        
        return StepExecutionResult(
            output: ["swiped": direction, "distance": distance, "duration": duration],
            sessionId: sessionId
        )
    }
    
    private func executeDragCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        guard let fromX = step.params?["from-x"]?.value as? Double,
              let fromY = step.params?["from-y"]?.value as? Double,
              let toX = step.params?["to-x"]?.value as? Double,
              let toY = step.params?["to-y"]?.value as? Double else {
            throw ValidationError(
                code: .invalidInput,
                userMessage: "Missing required coordinates for drag command",
                context: ["command": "drag", "parameters": "from-x, from-y, to-x, to-y"]
            )
        }
        
        let duration = step.params?["duration"]?.value as? Double ?? 1.0
        let modifiers = parseModifiers(from: step.params)
        
        let modifierString = modifiers.map { $0.rawValue }.joined(separator: ",")
        
        try await uiAutomationService.drag(
            from: CGPoint(x: fromX, y: fromY),
            to: CGPoint(x: toX, y: toY),
            duration: Int(duration * 1000), // Convert to milliseconds
            steps: 30,
            modifiers: modifierString.isEmpty ? nil : modifierString
        )
        
        return StepExecutionResult(
            output: ["dragged": true, "from": ["x": fromX, "y": fromY], "to": ["x": toX, "y": toY]],
            sessionId: sessionId
        )
    }
    
    private func executeHotkeyCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        guard let key = step.params?["key"]?.value as? String else {
            throw ValidationError(
                code: .invalidInput,
                userMessage: "Missing required parameter 'key' for command 'hotkey'",
                context: ["command": "hotkey", "parameter": "key"]
            )
        }
        
        let modifiers = parseModifiers(from: step.params)
        
        let keyCombo = modifiers.map { $0.rawValue }.joined(separator: ",") + (modifiers.isEmpty ? "" : ",") + key
        
        try await uiAutomationService.hotkey(keys: keyCombo, holdDuration: 0)
        
        return StepExecutionResult(
            output: ["hotkey": key, "modifiers": modifiers.map { $0.rawValue }],
            sessionId: sessionId
        )
    }
    
    private func executeSleepCommand(_ step: ScriptStep) async throws -> StepExecutionResult {
        let duration = step.params?["duration"]?.value as? Double ?? 1.0
        
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        
        return StepExecutionResult(
            output: ["slept": duration],
            sessionId: nil
        )
    }
    
    private func executeWindowCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        let action = step.params?["action"]?.value as? String ?? "focus"
        let app = step.params?["app"]?.value as? String
        let title = step.params?["title"]?.value as? String
        let index = step.params?["index"]?.value as? Int
        
        // Find the window
        let windows: [ServiceWindowInfo]
        if let appName = app {
            windows = try await windowManagementService.listWindows(target: .application(appName))
        } else {
            // Get all windows from all applications
            let apps = try await applicationService.listApplications()
            var allWindows: [ServiceWindowInfo] = []
            for app in apps {
                let appWindows = try await windowManagementService.listWindows(target: .application(app.name))
                allWindows.append(contentsOf: appWindows)
            }
            windows = allWindows
        }
        
        let targetWindow: ServiceWindowInfo?
        if let windowTitle = title {
            targetWindow = windows.first { $0.title.contains(windowTitle) }
        } else if let windowIndex = index, windowIndex < windows.count {
            targetWindow = windows[windowIndex]
        } else {
            targetWindow = windows.first
        }
        
        guard let window = targetWindow else {
            throw NotFoundError(
                code: .windowNotFound,
                userMessage: "No window found matching the specified criteria",
                context: ["app": app ?? "any", "title": title ?? "any", "index": String(index ?? -1)]
            )
        }
        
        // Perform the action
        switch action.lowercased() {
        case "close":
            try await windowManagementService.closeWindow(target: .windowId(window.windowID))
        case "minimize":
            try await windowManagementService.minimizeWindow(target: .windowId(window.windowID))
        case "maximize":
            try await windowManagementService.maximizeWindow(target: .windowId(window.windowID))
        case "focus":
            try await windowManagementService.focusWindow(target: .windowId(window.windowID))
        case "move":
            if let x = step.params?["x"]?.value as? Double,
               let y = step.params?["y"]?.value as? Double {
                try await windowManagementService.moveWindow(target: .windowId(window.windowID), to: CGPoint(x: x, y: y))
            }
        case "resize":
            if let width = step.params?["width"]?.value as? Double,
               let height = step.params?["height"]?.value as? Double {
                try await windowManagementService.resizeWindow(target: .windowId(window.windowID), to: CGSize(width: width, height: height))
            }
        default:
            throw ValidationError(
                code: .invalidInput,
                userMessage: "Invalid action '\(action)' for window command",
                context: ["command": "window", "parameter": "action", "value": action]
            )
        }
        
        return StepExecutionResult(
            output: ["window": window.title, "action": action],
            sessionId: sessionId
        )
    }
    
    private func executeMenuCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        guard let menuPath = step.params?["path"]?.value as? String else {
            throw ValidationError(
                code: .invalidInput,
                userMessage: "Missing required parameter 'path' for command 'menu'",
                context: ["command": "menu", "parameter": "path"]
            )
        }
        
        let app = step.params?["app"]?.value as? String
        
        let appName: String
        if let providedApp = app {
            appName = providedApp
        } else {
            // Use frontmost app
            let frontApp = try await applicationService.getFrontmostApplication()
            appName = frontApp.name
        }
        
        try await menuService.clickMenuItem(app: appName, itemPath: menuPath)
        
        return StepExecutionResult(
            output: ["menu_clicked": menuPath, "app": appName],
            sessionId: sessionId
        )
    }
    
    private func executeDockCommand(_ step: ScriptStep) async throws -> StepExecutionResult {
        let action = step.params?["action"]?.value as? String ?? "list"
        
        switch action.lowercased() {
        case "list":
            let items = try await dockService.listDockItems(includeAll: false)
            return StepExecutionResult(
                output: ["dock_items": items.map { ["title": $0.title, "type": $0.itemType.rawValue, "index": $0.index] }],
                sessionId: nil
            )
            
        case "click":
            guard let itemName = step.params?["item"]?.value as? String else {
                throw ValidationError(
                code: .invalidInput,
                userMessage: "Missing required parameter 'item' for dock command",
                context: ["command": "dock", "parameter": "item", "action": action]
            )
            }
            try await dockService.launchFromDock(appName: itemName)
            return StepExecutionResult(
                output: ["clicked": itemName],
                sessionId: nil
            )
            
        case "add":
            guard let path = step.params?["path"]?.value as? String else {
                throw ValidationError(
                code: .invalidInput,
                userMessage: "Missing required parameter 'path' for dock add command",
                context: ["command": "dock", "parameter": "path", "action": "add"]
            )
            }
            // Dock service doesn't support adding items directly
            throw OperationError(
                code: .interactionFailed,
                userMessage: "Adding items to Dock is not supported",
                context: ["action": "dock_add", "reason": "unsupported_operation"]
            )
            return StepExecutionResult(
                output: ["added": path],
                sessionId: nil
            )
            
        case "remove":
            guard let itemName = step.params?["item"]?.value as? String else {
                throw ValidationError(
                code: .invalidInput,
                userMessage: "Missing required parameter 'item' for dock command",
                context: ["command": "dock", "parameter": "item", "action": action]
            )
            }
            // Dock service doesn't support removing items directly
            throw OperationError(
                code: .interactionFailed,
                userMessage: "Removing items from Dock is not supported",
                context: ["action": "dock_remove", "reason": "unsupported_operation"]
            )
            return StepExecutionResult(
                output: ["removed": itemName],
                sessionId: nil
            )
            
        default:
            throw ValidationError(
                code: .invalidInput,
                userMessage: "Invalid action '\(action)' for dock command",
                context: ["command": "dock", "parameter": "action", "value": action]
            )
        }
    }
    
    private func executeAppCommand(_ step: ScriptStep) async throws -> StepExecutionResult {
        let action = step.params?["action"]?.value as? String ?? "launch"
        guard let appName = step.params?["name"]?.value as? String else {
            throw ValidationError(
                code: .invalidInput,
                userMessage: "Missing required parameter 'name' for command 'app'",
                context: ["command": "app", "parameter": "name"]
            )
        }
        
        switch action.lowercased() {
        case "launch":
            _ = try await applicationService.launchApplication(identifier: appName)
            return StepExecutionResult(
                output: ["launched": appName],
                sessionId: nil
            )
            
        case "quit":
            _ = try await applicationService.quitApplication(identifier: appName, force: false)
            return StepExecutionResult(
                output: ["quit": appName],
                sessionId: nil
            )
            
        case "hide":
            try await applicationService.hideApplication(identifier: appName)
            return StepExecutionResult(
                output: ["hidden": appName],
                sessionId: nil
            )
            
        case "show":
            try await applicationService.unhideApplication(identifier: appName)
            return StepExecutionResult(
                output: ["shown": appName],
                sessionId: nil
            )
            
        case "focus":
            try await applicationService.activateApplication(identifier: appName)
            return StepExecutionResult(
                output: ["focused": appName],
                sessionId: nil
            )
            
        default:
            throw ValidationError(
                code: .invalidInput,
                userMessage: "Invalid action '\(action)' for app command",
                context: ["command": "app", "parameter": "action", "value": action]
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseModifiers(from params: [String: AnyCodable]?) -> [ModifierKey] {
        var modifiers: [ModifierKey] = []
        
        if params?["cmd"]?.value as? Bool == true || params?["command"]?.value as? Bool == true {
            modifiers.append(.command)
        }
        if params?["shift"]?.value as? Bool == true {
            modifiers.append(.shift)
        }
        if params?["option"]?.value as? Bool == true || params?["alt"]?.value as? Bool == true {
            modifiers.append(.option)
        }
        if params?["control"]?.value as? Bool == true || params?["ctrl"]?.value as? Bool == true {
            modifiers.append(.control)
        }
        if params?["fn"]?.value as? Bool == true || params?["function"]?.value as? Bool == true {
            modifiers.append(.function)
        }
        
        return modifiers
    }
    
    // Removed findBestMatch - now handled by UIAutomationService
}

