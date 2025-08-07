import AppKit
import AXorcist
import Foundation

/// Implementation of ProcessServiceProtocol for executing Peekaboo scripts
@available(macOS 14.0, *)
@MainActor
public final class ProcessService: ProcessServiceProtocol {
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
        dockService: DockServiceProtocol)
    {
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
            throw PeekabooError.fileIOError("Script file not found: \(path)")
        }

        return try await performOperation({
            let data = try Data(contentsOf: url)
            return try JSONCoding.decoder.decode(PeekabooScript.self, from: data)
        }, errorContext: "Failed to load script from \(path)")
    }

    public func executeScript(
        _ script: PeekabooScript,
        failFast: Bool,
        verbose: Bool) async throws -> [StepResult]
    {
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
                    output: executionResult.output,
                    error: nil,
                    executionTime: Date().timeIntervalSince(stepStartTime))

                results.append(result)

            } catch {
                let result = StepResult(
                    stepId: step.stepId,
                    stepNumber: stepNumber,
                    command: step.command,
                    success: false,
                    output: nil,
                    error: error.localizedDescription,
                    executionTime: Date().timeIntervalSince(stepStartTime))

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
        sessionId: String?) async throws -> StepExecutionResult
    {
        // Normalize parameters from generic to typed if needed
        let normalizedStep = self.normalizeStepParameters(step)

        // Map command to appropriate service method
        switch normalizedStep.command.lowercased() {
        case "see":
            return try await self.executeSeeCommand(normalizedStep, sessionId: sessionId)

        case "click":
            return try await self.executeClickCommand(normalizedStep, sessionId: sessionId)

        case "type":
            return try await self.executeTypeCommand(normalizedStep, sessionId: sessionId)

        case "scroll":
            return try await self.executeScrollCommand(normalizedStep, sessionId: sessionId)

        case "swipe":
            return try await self.executeSwipeCommand(normalizedStep, sessionId: sessionId)

        case "drag":
            return try await self.executeDragCommand(normalizedStep, sessionId: sessionId)

        case "hotkey":
            return try await self.executeHotkeyCommand(normalizedStep, sessionId: sessionId)

        case "sleep":
            return try await self.executeSleepCommand(normalizedStep)

        case "window":
            return try await self.executeWindowCommand(normalizedStep, sessionId: sessionId)

        case "menu":
            return try await self.executeMenuCommand(normalizedStep, sessionId: sessionId)

        case "dock":
            return try await self.executeDockCommand(normalizedStep)

        case "app":
            return try await self.executeAppCommand(normalizedStep)

        default:
            throw PeekabooError.invalidInput(field: "command", reason: "Unknown command: \(step.command)")
        }
    }

    // MARK: - Command Implementations

    private func executeSeeCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        // Extract screenshot parameters - should already be normalized
        let screenshotParams: ProcessCommandParameters.ScreenshotParameters = if case let .screenshot(params) = step
            .params
        {
            params
        } else {
            // Use default if no params provided
            ProcessCommandParameters.ScreenshotParameters(path: "screenshot.png")
        }

        // Use mode and annotate from parameters, with defaults
        let mode = screenshotParams.mode ?? "window"
        let annotate = screenshotParams.annotate ?? true

        // Capture screenshot based on mode
        let captureResult: CaptureResult
        switch mode {
        case "fullscreen":
            captureResult = try await self.screenCaptureService.captureScreen(displayIndex: nil)
        case "frontmost":
            captureResult = try await self.screenCaptureService.captureFrontmost()
        case "window":
            if let appName = screenshotParams.app {
                let windowIndex = screenshotParams.window.flatMap { title in
                    // Try to parse as index
                    Int(title)
                }
                captureResult = try await self.screenCaptureService.captureWindow(
                    appIdentifier: appName,
                    windowIndex: windowIndex)
            } else {
                captureResult = try await self.screenCaptureService.captureFrontmost()
            }
        default:
            captureResult = try await self.screenCaptureService.captureFrontmost()
        }

        // Save to output path if specified
        let screenshotPath: String
        let outputPath = screenshotParams.path
        if !outputPath.isEmpty {
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
               let windowInfo = captureResult.metadata.windowInfo
            {
                try await self.sessionManager.storeScreenshot(
                    sessionId: existingSessionId,
                    screenshotPath: screenshotPath,
                    applicationName: appInfo.name,
                    windowTitle: windowInfo.title,
                    windowBounds: windowInfo.bounds)
            } else {
                try await self.sessionManager.storeScreenshot(
                    sessionId: existingSessionId,
                    screenshotPath: screenshotPath,
                    applicationName: nil,
                    windowTitle: nil,
                    windowBounds: nil)
            }
        } else {
            // Create new session
            newSessionId = try await self.sessionManager.createSession()
            // Store screenshot in new session
            if let appInfo = captureResult.metadata.applicationInfo,
               let windowInfo = captureResult.metadata.windowInfo
            {
                try await self.sessionManager.storeScreenshot(
                    sessionId: newSessionId,
                    screenshotPath: screenshotPath,
                    applicationName: appInfo.name,
                    windowTitle: windowInfo.title,
                    windowBounds: windowInfo.bounds)
            } else {
                try await self.sessionManager.storeScreenshot(
                    sessionId: newSessionId,
                    screenshotPath: screenshotPath,
                    applicationName: nil,
                    windowTitle: nil,
                    windowBounds: nil)
            }
        }

        // Build UI map if annotate is true
        if annotate {
            let detectionResult = try await uiAutomationService.detectElements(
                in: captureResult.imageData,
                sessionId: newSessionId,
                windowContext: nil)

            // Store detection result in session
            try await self.sessionManager.storeDetectionResult(
                sessionId: newSessionId,
                result: detectionResult)
        }

        return StepExecutionResult(
            output: .data([
                "session_id": .success(newSessionId),
                "screenshot_path": .success(screenshotPath),
            ]),
            sessionId: newSessionId)
    }

    private func executeClickCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        // Extract click parameters - should already be normalized
        guard case let .click(clickParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for click command")
        }

        guard let effectiveSessionId = sessionId else {
            throw PeekabooError.invalidInput(field: "session", reason: "Session ID is required for click command")
        }

        // Determine click type
        let rightClick = clickParams.button == "right"
        let doubleClick = clickParams.button == "double"

        // Get session detection result
        guard let _ = try await sessionManager.getDetectionResult(sessionId: effectiveSessionId) else {
            throw PeekabooError.sessionNotFound(effectiveSessionId)
        }

        // Determine click target
        let clickTarget: ClickTarget
        if let x = clickParams.x, let y = clickParams.y {
            clickTarget = .coordinates(CGPoint(x: x, y: y))
        } else if let label = clickParams.label {
            clickTarget = .query(label)
        } else {
            throw PeekabooError.invalidInput(
                field: "target",
                reason: "Either coordinates (x,y) or label is required for click command")
        }

        // Perform click
        let clickType: ClickType = doubleClick ? .double : (rightClick ? .right : .single)
        try await uiAutomationService.click(
            target: clickTarget,
            clickType: clickType,
            sessionId: effectiveSessionId)

        return StepExecutionResult(
            output: .success("Clicked successfully"),
            sessionId: effectiveSessionId)
    }

    private func executeTypeCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        // Extract type parameters - should already be normalized
        guard case let .type(typeParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for type command")
        }

        let clearFirst = typeParams.clearFirst ?? false
        let pressEnter = typeParams.pressEnter ?? false

        // Type the text
        try await self.uiAutomationService.type(
            text: typeParams.text,
            target: typeParams.field,
            clearExisting: clearFirst,
            typingDelay: 50,
            sessionId: sessionId)

        // Press Enter if requested
        if pressEnter {
            // Use typeActions to press Enter key
            _ = try await self.uiAutomationService.typeActions(
                [.key(.return)],
                typingDelay: 50,
                sessionId: sessionId)
        }

        return StepExecutionResult(
            output: .data([
                "typed": .success(typeParams.text),
                "cleared": .success(String(clearFirst)),
                "enter_pressed": .success(String(pressEnter)),
            ]),
            sessionId: sessionId)
    }

    private func executeScrollCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        // Extract scroll parameters - should already be normalized
        guard case let .scroll(scrollParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for scroll command")
        }

        let amount = scrollParams.amount ?? 5
        let smooth = false // Not in ScrollParameters, using default
        let delay = 100 // Not in ScrollParameters, using default

        let scrollDirection: ScrollDirection = switch scrollParams.direction.lowercased() {
        case "up": .up
        case "down": .down
        case "left": .left
        case "right": .right
        default: .down
        }

        try await self.uiAutomationService.scroll(
            direction: scrollDirection,
            amount: amount,
            target: scrollParams.target,
            smooth: smooth,
            delay: delay,
            sessionId: sessionId)

        return StepExecutionResult(
            output: .data([
                "scrolled": .success(scrollParams.direction),
                "amount": .success(String(amount)),
                "smooth": .success(String(smooth)),
            ]),
            sessionId: sessionId)
    }

    private func executeSwipeCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        // Extract swipe parameters - should already be normalized
        guard case let .swipe(swipeParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for swipe command")
        }

        let direction = swipeParams.direction
        let distance = swipeParams.distance ?? 100.0
        let duration = swipeParams.duration ?? 0.5

        let swipeDirection: SwipeDirection = switch direction.lowercased() {
        case "up": .up
        case "down": .down
        case "left": .left
        case "right": .right
        default: .right
        }

        // If coordinates are specified, use them as the starting point
        var startPoint: CGPoint?
        if let x = swipeParams.fromX,
           let y = swipeParams.fromY
        {
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

        try await self.uiAutomationService.swipe(
            from: startPoint ?? CGPoint.zero,
            to: endPoint,
            duration: Int(duration * 1000), // Convert to milliseconds
            steps: 30)

        return StepExecutionResult(
            output: .data([
                "swiped": .success(direction),
                "distance": .success(String(distance)),
                "duration": .success(String(duration)),
            ]),
            sessionId: sessionId)
    }

    private func executeDragCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        // Extract drag parameters - should already be normalized
        guard case let .drag(dragParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for drag command")
        }

        let duration = dragParams.duration ?? 1.0
        let modifiers = self.parseModifiers(from: dragParams.modifiers)

        let modifierString = modifiers.map(\.rawValue).joined(separator: ",")

        try await self.uiAutomationService.drag(
            from: CGPoint(x: dragParams.fromX, y: dragParams.fromY),
            to: CGPoint(x: dragParams.toX, y: dragParams.toY),
            duration: Int(duration * 1000), // Convert to milliseconds
            steps: 30,
            modifiers: modifierString.isEmpty ? nil : modifierString)

        return StepExecutionResult(
            output: .data([
                "dragged": .success("true"),
                "from_x": .success(String(dragParams.fromX)),
                "from_y": .success(String(dragParams.fromY)),
                "to_x": .success(String(dragParams.toX)),
                "to_y": .success(String(dragParams.toY)),
            ]),
            sessionId: sessionId)
    }

    private func executeHotkeyCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        // Extract hotkey parameters - should already be normalized
        guard case let .hotkey(hotkeyParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for hotkey command")
        }

        let modifiers = hotkeyParams.modifiers.compactMap { mod -> ModifierKey? in
            switch mod.lowercased() {
            case "command", "cmd": return .command
            case "shift": return .shift
            case "control", "ctrl": return .control
            case "option", "alt": return .option
            case "function", "fn": return .function
            default: return nil
            }
        }

        let keyCombo = modifiers.map(\.rawValue).joined(separator: ",") + (modifiers.isEmpty ? "" : ",") + hotkeyParams
            .key

        try await self.uiAutomationService.hotkey(keys: keyCombo, holdDuration: 0)

        return StepExecutionResult(
            output: .data([
                "hotkey": .success(hotkeyParams.key),
                "modifiers": .success(modifiers.map(\.rawValue).joined(separator: ",")),
            ]),
            sessionId: sessionId)
    }

    private func executeSleepCommand(_ step: ScriptStep) async throws -> StepExecutionResult {
        // Extract sleep parameters - should already be normalized
        guard case let .sleep(sleepParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for sleep command")
        }

        try await Task.sleep(nanoseconds: UInt64(sleepParams.duration * 1_000_000_000))

        return StepExecutionResult(
            output: .success("Slept for \(sleepParams.duration) seconds"),
            sessionId: nil)
    }

    private func executeWindowCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        // Extract window parameters
        let action: String
        let app: String?
        let title: String?
        let index: Int?
        let resizeParams: ProcessCommandParameters.ResizeWindowParameters?

        if case let .focusWindow(params) = step.params {
            action = "focus"
            app = params.app
            title = params.title
            index = params.index
            resizeParams = nil
        } else if case let .resizeWindow(params) = step.params {
            action = params.maximize == true ? "maximize" : params.minimize == true ? "minimize" : "resize"
            app = params.app
            title = nil
            index = nil
            resizeParams = params
        } else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for window command")
        }

        // Find the window
        let windows: [ServiceWindowInfo]
        if let appName = app {
            windows = try await self.windowManagementService.listWindows(target: .application(appName))
        } else {
            // Get all windows from all applications
            let appsOutput = try await applicationService.listApplications()
            var allWindows: [ServiceWindowInfo] = []
            for app in appsOutput.data.applications {
                let appWindows = try await windowManagementService.listWindows(target: .application(app.name))
                allWindows.append(contentsOf: appWindows)
            }
            windows = allWindows
        }

        let targetWindow: ServiceWindowInfo? = if let windowTitle = title {
            windows.first { $0.title.contains(windowTitle) }
        } else if let windowIndex = index, windowIndex < windows.count {
            windows[windowIndex]
        } else {
            windows.first
        }

        guard let window = targetWindow else {
            throw PeekabooError.windowNotFound()
        }

        // Perform the action
        switch action.lowercased() {
        case "close":
            try await self.windowManagementService.closeWindow(target: .windowId(window.windowID))
        case "minimize":
            try await self.windowManagementService.minimizeWindow(target: .windowId(window.windowID))
        case "maximize":
            try await self.windowManagementService.maximizeWindow(target: .windowId(window.windowID))
        case "focus":
            try await self.windowManagementService.focusWindow(target: .windowId(window.windowID))
        case "move":
            if let params = resizeParams, let x = params.x, let y = params.y {
                try await self.windowManagementService.moveWindow(
                    target: .windowId(window.windowID),
                    to: CGPoint(x: x, y: y))
            }
        case "resize":
            if let params = resizeParams, let width = params.width, let height = params.height {
                try await self.windowManagementService.resizeWindow(
                    target: .windowId(window.windowID),
                    to: CGSize(width: width, height: height))
            }
        default:
            throw PeekabooError.invalidInput(field: "action", reason: "Invalid action '\(action)' for window command")
        }

        return StepExecutionResult(
            output: .data([
                "window": .success(window.title),
                "action": .success(action),
            ]),
            sessionId: sessionId)
    }

    private func executeMenuCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        // Extract menu parameters - should already be normalized
        guard case let .menuClick(menuParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for menu command")
        }

        let menuPath = menuParams.menuPath.joined(separator: " > ")
        let app = menuParams.app

        let appName: String
        if let providedApp = app {
            appName = providedApp
        } else {
            // Use frontmost app
            let frontApp = try await applicationService.getFrontmostApplication()
            appName = frontApp.name
        }

        try await self.menuService.clickMenuItem(app: appName, itemPath: menuPath)

        return StepExecutionResult(
            output: .success("Clicked menu: \(menuPath) in \(appName)"),
            sessionId: sessionId)
    }

    private func executeDockCommand(_ step: ScriptStep) async throws -> StepExecutionResult {
        // Extract dock parameters - should already be normalized
        guard case let .dock(dockParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for dock command")
        }

        switch dockParams.action.lowercased() {
        case "list":
            let items = try await dockService.listDockItems(includeAll: false)
            return StepExecutionResult(
                output: .list(items.map { "\($0.title) (\($0.itemType.rawValue))" }),
                sessionId: nil)

        case "click":
            guard let itemName = dockParams.item else {
                throw PeekabooError.invalidInput(
                    field: "item",
                    reason: "Missing required parameter for dock click command")
            }
            try await self.dockService.launchFromDock(appName: itemName)
            return StepExecutionResult(
                output: .success("Clicked dock item: \(itemName)"),
                sessionId: nil)

        case "add":
            guard let path = dockParams.path else {
                throw PeekabooError.invalidInput(
                    field: "path",
                    reason: "Missing required parameter for dock add command")
            }
            try await self.dockService.addToDock(path: path, persistent: true)
            return StepExecutionResult(
                output: .success("Added to Dock: \(path)"),
                sessionId: nil)

        case "remove":
            guard let item = dockParams.item else {
                throw PeekabooError.invalidInput(
                    field: "item",
                    reason: "Missing required parameter for dock remove command")
            }
            try await self.dockService.removeFromDock(appName: item)
            return StepExecutionResult(
                output: .success("Removed from Dock: \(item)"),
                sessionId: nil)

        default:
            throw PeekabooError.invalidInput(
                field: "action",
                reason: "Invalid action '\(dockParams.action)' for dock command")
        }
    }

    private func executeAppCommand(_ step: ScriptStep) async throws -> StepExecutionResult {
        // Extract app parameters - should already be normalized
        guard case let .launchApp(appParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for app command")
        }

        let appName = appParams.appName
        // Use action from parameters, default to launch
        let action = appParams.action ?? "launch"

        switch action.lowercased() {
        case "launch":
            _ = try await self.applicationService.launchApplication(identifier: appName)
            return StepExecutionResult(
                output: .success("Launched application: \(appName)"),
                sessionId: nil)

        case "quit":
            _ = try await self.applicationService.quitApplication(identifier: appName, force: appParams.force ?? false)
            return StepExecutionResult(
                output: .success("Quit application: \(appName)"),
                sessionId: nil)

        case "hide":
            try await self.applicationService.hideApplication(identifier: appName)
            return StepExecutionResult(
                output: .success("Hidden application: \(appName)"),
                sessionId: nil)

        case "show":
            try await self.applicationService.unhideApplication(identifier: appName)
            return StepExecutionResult(
                output: .success("Shown application: \(appName)"),
                sessionId: nil)

        case "focus":
            try await self.applicationService.activateApplication(identifier: appName)
            return StepExecutionResult(
                output: .success("Focused application: \(appName)"),
                sessionId: nil)

        default:
            throw PeekabooError.invalidInput(field: "action", reason: "Invalid action '\(action)' for app command")
        }
    }

    // MARK: - Helper Methods

    private func parseModifiers(from modifierStrings: [String]?) -> [ModifierKey] {
        guard let modifierStrings else { return [] }

        var modifiers: [ModifierKey] = []

        for modifier in modifierStrings {
            switch modifier.lowercased() {
            case "cmd", "command":
                modifiers.append(.command)
            case "shift":
                modifiers.append(.shift)
            case "option", "alt":
                modifiers.append(.option)
            case "control", "ctrl":
                modifiers.append(.control)
            case "fn", "function":
                modifiers.append(.function)
            default:
                break
            }
        }

        return modifiers
    }

    // Removed findBestMatch - now handled by UIAutomationService

    /// Normalize generic parameters to typed parameters based on command
    private func normalizeStepParameters(_ step: ScriptStep) -> ScriptStep {
        // If already typed or nil, return as-is
        guard case let .generic(dict) = step.params else {
            return step
        }

        // Convert generic dictionary to typed parameters based on command
        let typedParams: ProcessCommandParameters?

        switch step.command.lowercased() {
        case "see":
            typedParams = .screenshot(ProcessCommandParameters.ScreenshotParameters(
                path: dict["path"] ?? "screenshot.png",
                app: dict["app"],
                window: dict["window"],
                display: dict["display"].flatMap { Int($0) },
                mode: dict["mode"],
                annotate: dict["annotate"].flatMap { Bool($0) }))

        case "click":
            typedParams = .click(ProcessCommandParameters.ClickParameters(
                x: dict["x"].flatMap { Double($0) },
                y: dict["y"].flatMap { Double($0) },
                label: dict["query"] ?? dict["label"],
                app: dict["app"],
                button: dict["button"] ??
                    (dict["right-click"] == "true" ? "right" : dict["double-click"] == "true" ? "double" : "left"),
                modifiers: nil))

        case "type":
            if let text = dict["text"] {
                typedParams = .type(ProcessCommandParameters.TypeParameters(
                    text: text,
                    app: dict["app"],
                    field: dict["field"],
                    clearFirst: dict["clear-first"].flatMap { Bool($0) },
                    pressEnter: dict["press-enter"].flatMap { Bool($0) }))
            } else {
                typedParams = step.params // Keep generic if text is missing
            }

        case "scroll":
            typedParams = .scroll(ProcessCommandParameters.ScrollParameters(
                direction: dict["direction"] ?? "down",
                amount: dict["amount"].flatMap { Int($0) },
                app: dict["app"],
                target: dict["on"] ?? dict["target"]))

        case "hotkey":
            if let key = dict["key"] {
                var modifiers: [String] = []
                if dict["cmd"] == "true" || dict["command"] == "true" { modifiers.append("command") }
                if dict["shift"] == "true" { modifiers.append("shift") }
                if dict["control"] == "true" || dict["ctrl"] == "true" { modifiers.append("control") }
                if dict["option"] == "true" || dict["alt"] == "true" { modifiers.append("option") }
                if dict["fn"] == "true" || dict["function"] == "true" { modifiers.append("function") }

                typedParams = .hotkey(ProcessCommandParameters.HotkeyParameters(
                    key: key,
                    modifiers: modifiers,
                    app: dict["app"]))
            } else {
                typedParams = step.params // Keep generic if key is missing
            }

        case "menu":
            if let path = dict["path"] {
                let menuPath = path.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
                typedParams = .menuClick(ProcessCommandParameters.MenuClickParameters(
                    menuPath: menuPath,
                    app: dict["app"]))
            } else {
                typedParams = step.params // Keep generic if path is missing
            }

        case "window":
            typedParams = .focusWindow(ProcessCommandParameters.FocusWindowParameters(
                app: dict["app"],
                title: dict["title"],
                index: dict["index"].flatMap { Int($0) }))

        case "app":
            if let appName = dict["name"] {
                typedParams = .launchApp(ProcessCommandParameters.LaunchAppParameters(
                    appName: appName,
                    action: dict["action"],
                    waitForLaunch: dict["wait"].flatMap { Bool($0) },
                    bringToFront: dict["focus"].flatMap { Bool($0) },
                    force: dict["force"].flatMap { Bool($0) }))
            } else {
                typedParams = step.params // Keep generic if name is missing
            }

        case "swipe":
            typedParams = .swipe(ProcessCommandParameters.SwipeParameters(
                direction: dict["direction"] ?? "right",
                distance: dict["distance"].flatMap { Double($0) },
                duration: dict["duration"].flatMap { Double($0) },
                fromX: dict["from-x"].flatMap { Double($0) },
                fromY: dict["from-y"].flatMap { Double($0) }))

        case "drag":
            if let fromX = dict["from-x"].flatMap({ Double($0) }),
               let fromY = dict["from-y"].flatMap({ Double($0) }),
               let toX = dict["to-x"].flatMap({ Double($0) }),
               let toY = dict["to-y"].flatMap({ Double($0) })
            {
                var modifiers: [String] = []
                if dict["cmd"] == "true" || dict["command"] == "true" { modifiers.append("command") }
                if dict["shift"] == "true" { modifiers.append("shift") }
                if dict["control"] == "true" || dict["ctrl"] == "true" { modifiers.append("control") }
                if dict["option"] == "true" || dict["alt"] == "true" { modifiers.append("option") }
                if dict["fn"] == "true" || dict["function"] == "true" { modifiers.append("function") }

                typedParams = .drag(ProcessCommandParameters.DragParameters(
                    fromX: fromX,
                    fromY: fromY,
                    toX: toX,
                    toY: toY,
                    duration: dict["duration"].flatMap { Double($0) },
                    modifiers: modifiers.isEmpty ? nil : modifiers))
            } else {
                typedParams = step.params // Keep generic if coordinates are missing
            }

        case "sleep":
            let duration = dict["duration"].flatMap { Double($0) } ?? 1.0
            typedParams = .sleep(ProcessCommandParameters.SleepParameters(duration: duration))

        case "dock":
            typedParams = .dock(ProcessCommandParameters.DockParameters(
                action: dict["action"] ?? "list",
                item: dict["item"],
                path: dict["path"]))

        default:
            // For unrecognized commands, keep generic
            typedParams = step.params
        }

        // Return new step with typed parameters
        return ScriptStep(
            stepId: step.stepId,
            comment: step.comment,
            command: step.command,
            params: typedParams)
    }
}
