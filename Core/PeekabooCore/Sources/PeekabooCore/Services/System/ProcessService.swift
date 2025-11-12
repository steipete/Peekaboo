import AppKit
import AXorcist
import Foundation
import PeekabooFoundation

/// Implementation of ProcessServiceProtocol for executing Peekaboo scripts
@available(macOS 14.0, *)
@MainActor
public final class ProcessService: ProcessServiceProtocol {
    private let applicationService: any ApplicationServiceProtocol
    private let screenCaptureService: any ScreenCaptureServiceProtocol
    private let sessionManager: any SessionManagerProtocol
    private let uiAutomationService: any UIAutomationServiceProtocol
    private let windowManagementService: any WindowManagementServiceProtocol
    private let menuService: any MenuServiceProtocol
    private let dockService: any DockServiceProtocol

    public init(
        applicationService: any ApplicationServiceProtocol,
        screenCaptureService: any ScreenCaptureServiceProtocol,
        sessionManager: any SessionManagerProtocol,
        uiAutomationService: any UIAutomationServiceProtocol,
        windowManagementService: any WindowManagementServiceProtocol,
        menuService: any MenuServiceProtocol,
        dockService: any DockServiceProtocol)
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
            let decoder = JSONCoding.makeDecoder()
            return try decoder.decode(PeekabooScript.self, from: data)
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
}

@MainActor
public extension ProcessService {
    func executeStep(
        _ step: ScriptStep,
        sessionId: String?) async throws -> StepExecutionResult
    {
        let normalizedStep = self.normalizeStepParameters(step)

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
}

@MainActor
private extension ProcessService {

    // MARK: - Command Implementations

    private func executeSeeCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        let params = self.screenshotParameters(from: step)
        let captureResult = try await self.captureScreenshot(using: params)
        let screenshotPath = try self.saveScreenshot(
            captureResult,
            to: params.path)
        let resolvedSessionId = try await self.storeScreenshot(
            captureResult: captureResult,
            path: screenshotPath,
            existingSessionId: sessionId)

        try await self.annotateIfNeeded(
            shouldAnnotate: params.annotate ?? true,
            captureResult: captureResult,
            sessionId: resolvedSessionId)

        return StepExecutionResult(
            output: .data([
                "session_id": .success(resolvedSessionId),
                "screenshot_path": .success(screenshotPath),
            ]),
            sessionId: resolvedSessionId)
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
        guard try await sessionManager.getDetectionResult(sessionId: effectiveSessionId) != nil else {
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

        let scrollDirection: PeekabooFoundation.ScrollDirection = switch scrollParams.direction.lowercased() {
        case "up": .up
        case "down": .down
        case "left": .left
        case "right": .right
        default: .down
        }

        let request = ScrollRequest(
            direction: scrollDirection,
            amount: amount,
            target: scrollParams.target,
            smooth: smooth,
            delay: delay,
            sessionId: sessionId)
        try await self.uiAutomationService.scroll(request)

        return StepExecutionResult(
            output: .data([
                "scrolled": .success(scrollParams.direction),
                "amount": .success(String(amount)),
                "smooth": .success(String(smooth)),
            ]),
            sessionId: sessionId)
    }

    private func executeSwipeCommand(_ step: ScriptStep, sessionId: String?) async throws -> StepExecutionResult {
        guard case let .swipe(swipeParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for swipe command")
        }

        let distance = swipeParams.distance ?? 100.0
        let duration = swipeParams.duration ?? 0.5
        let swipeDirection = self.swipeDirection(from: swipeParams.direction)
        let points = self.swipeEndpoints(
            params: swipeParams,
            direction: swipeDirection,
            distance: distance)

        try await self.uiAutomationService.swipe(
            from: points.start,
            to: points.end,
            duration: Int(duration * 1000),
            steps: 30)

        return StepExecutionResult(
            output: .data([
                "swiped": .success(swipeParams.direction),
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
        let context = try self.windowCommandContext(from: step)
        let windows = try await self.fetchWindows(for: context.app)
        let window = try self.selectWindow(
            from: windows,
            title: context.title,
            index: context.index)

        try await self.performWindowAction(
            context.action,
            window: window,
            resizeParams: context.resizeParams)

        return StepExecutionResult(
            output: .data([
                "window": .success(window.title),
                "action": .success(context.action),
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
        guard case let .generic(dict) = step.params else {
            return step
        }

        guard let typedParams = self.typedParameters(for: step.command.lowercased(), dict: dict) else {
            return step
        }

        return ScriptStep(
            stepId: step.stepId,
            comment: step.comment,
            command: step.command,
            params: typedParams)
    }

    func typedParameters(for command: String, dict: [String: String]) -> ProcessCommandParameters? {
        switch command {
        case "see":
            return .screenshot(self.typedScreenshotParameters(from: dict))
        case "click":
            return .click(self.typedClickParameters(from: dict))
        case "type":
            return self.typedTypeParameters(from: dict)
        case "scroll":
            return .scroll(self.typedScrollParameters(from: dict))
        case "hotkey":
            return self.typedHotkeyParameters(from: dict)
        case "menu":
            return self.typedMenuParameters(from: dict)
        case "window":
            return .focusWindow(self.typedWindowParameters(from: dict))
        case "app":
            return self.typedAppParameters(from: dict)
        case "swipe":
            return .swipe(self.typedSwipeParameters(from: dict))
        case "drag":
            return self.typedDragParameters(from: dict)
        case "sleep":
            return .sleep(self.typedSleepParameters(from: dict))
        case "dock":
            return .dock(self.typedDockParameters(from: dict))
        default:
            return nil
        }
    }

    func typedScreenshotParameters(from dict: [String: String]) -> ProcessCommandParameters.ScreenshotParameters {
        ProcessCommandParameters.ScreenshotParameters(
            path: dict["path"] ?? "screenshot.png",
            app: dict["app"],
            window: dict["window"],
            display: dict["display"].flatMap { Int($0) },
            mode: dict["mode"],
            annotate: dict["annotate"].flatMap { Bool($0) })
    }

    func typedClickParameters(from dict: [String: String]) -> ProcessCommandParameters.ClickParameters {
        ProcessCommandParameters.ClickParameters(
            x: dict["x"].flatMap { Double($0) },
            y: dict["y"].flatMap { Double($0) },
            label: dict["query"] ?? dict["label"],
            app: dict["app"],
            button: dict["button"] ??
                (dict["right-click"] == "true" ? "right" :
                    dict["double-click"] == "true" ? "double" : "left"),
            modifiers: nil)
    }

    func typedTypeParameters(from dict: [String: String]) -> ProcessCommandParameters? {
        guard let text = dict["text"] else { return nil }
        return .type(ProcessCommandParameters.TypeParameters(
            text: text,
            app: dict["app"],
            field: dict["field"],
            clearFirst: dict["clear-first"].flatMap { Bool($0) },
            pressEnter: dict["press-enter"].flatMap { Bool($0) }))
    }

    func typedScrollParameters(from dict: [String: String]) -> ProcessCommandParameters.ScrollParameters {
        ProcessCommandParameters.ScrollParameters(
            direction: dict["direction"] ?? "down",
            amount: dict["amount"].flatMap { Int($0) },
            app: dict["app"],
            target: dict["on"] ?? dict["target"])
    }

    func typedHotkeyParameters(from dict: [String: String]) -> ProcessCommandParameters? {
        guard let key = dict["key"] else { return nil }
        var modifiers: [String] = []
        if dict["cmd"] == "true" || dict["command"] == "true" { modifiers.append("command") }
        if dict["shift"] == "true" { modifiers.append("shift") }
        if dict["control"] == "true" || dict["ctrl"] == "true" { modifiers.append("control") }
        if dict["option"] == "true" || dict["alt"] == "true" { modifiers.append("option") }
        if dict["fn"] == "true" || dict["function"] == "true" { modifiers.append("function") }

        return .hotkey(ProcessCommandParameters.HotkeyParameters(
            key: key,
            modifiers: modifiers,
            app: dict["app"]))
    }

    func typedMenuParameters(from dict: [String: String]) -> ProcessCommandParameters? {
        guard let path = dict["path"] ?? dict["menu"] else { return nil }
        let menuItems = path.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
        return .menuClick(ProcessCommandParameters.MenuClickParameters(
            menuPath: menuItems,
            app: dict["app"]))
    }

    func typedWindowParameters(from dict: [String: String]) -> ProcessCommandParameters.FocusWindowParameters {
        ProcessCommandParameters.FocusWindowParameters(
            app: dict["app"],
            title: dict["title"],
            index: dict["index"].flatMap { Int($0) })
    }

    func typedAppParameters(from dict: [String: String]) -> ProcessCommandParameters? {
        guard let appName = dict["name"] else { return nil }
        return .launchApp(ProcessCommandParameters.LaunchAppParameters(
            appName: appName,
            action: dict["action"],
            waitForLaunch: dict["wait"].flatMap { Bool($0) },
            bringToFront: dict["focus"].flatMap { Bool($0) },
            force: dict["force"].flatMap { Bool($0) }))
    }

    func typedSwipeParameters(from dict: [String: String]) -> ProcessCommandParameters.SwipeParameters {
        ProcessCommandParameters.SwipeParameters(
            direction: dict["direction"] ?? "right",
            distance: dict["distance"].flatMap { Double($0) },
            duration: dict["duration"].flatMap { Double($0) },
            fromX: dict["from-x"].flatMap { Double($0) },
            fromY: dict["from-y"].flatMap { Double($0) })
    }

    func typedDragParameters(from dict: [String: String]) -> ProcessCommandParameters? {
        guard let fromX = dict["from-x"].flatMap(Double.init),
              let fromY = dict["from-y"].flatMap(Double.init),
              let toX = dict["to-x"].flatMap(Double.init),
              let toY = dict["to-y"].flatMap(Double.init)
        else {
            return nil
        }

        var modifiers: [String] = []
        if dict["cmd"] == "true" || dict["command"] == "true" { modifiers.append("command") }
        if dict["shift"] == "true" { modifiers.append("shift") }
        if dict["control"] == "true" || dict["ctrl"] == "true" { modifiers.append("control") }
        if dict["option"] == "true" || dict["alt"] == "true" { modifiers.append("option") }
        if dict["fn"] == "true" || dict["function"] == "true" { modifiers.append("function") }

        return .drag(ProcessCommandParameters.DragParameters(
            fromX: fromX,
            fromY: fromY,
            toX: toX,
            toY: toY,
            duration: dict["duration"].flatMap { Double($0) },
            modifiers: modifiers.isEmpty ? nil : modifiers))
    }

    func typedSleepParameters(from dict: [String: String]) -> ProcessCommandParameters.SleepParameters {
        let duration = dict["duration"].flatMap { Double($0) } ?? 1.0
        return ProcessCommandParameters.SleepParameters(duration: duration)
    }

    func typedDockParameters(from dict: [String: String]) -> ProcessCommandParameters.DockParameters {
        ProcessCommandParameters.DockParameters(
            action: dict["action"] ?? "list",
            item: dict["item"],
            path: dict["path"])
    }

    func screenshotParameters(from step: ScriptStep) -> ProcessCommandParameters.ScreenshotParameters {
        if case let .screenshot(params) = step.params {
            return params
        }
        return ProcessCommandParameters.ScreenshotParameters(path: "screenshot.png")
    }

    func captureScreenshot(using params: ProcessCommandParameters.ScreenshotParameters) async throws -> CaptureResult {
        let mode = params.mode ?? "window"
        switch mode {
        case "fullscreen":
            return try await self.screenCaptureService.captureScreen(displayIndex: nil)
        case "frontmost":
            return try await self.screenCaptureService.captureFrontmost()
        case "window":
            if let appName = params.app {
                let windowIndex = params.window.flatMap(Int.init)
                return try await self.screenCaptureService.captureWindow(
                    appIdentifier: appName,
                    windowIndex: windowIndex)
            }
            return try await self.screenCaptureService.captureFrontmost()
        default:
            return try await self.screenCaptureService.captureFrontmost()
        }
    }

    func saveScreenshot(
        _ captureResult: CaptureResult,
        to outputPath: String) throws -> String
    {
        guard !outputPath.isEmpty else {
            return captureResult.savedPath ?? ""
        }
        try captureResult.imageData.write(to: URL(fileURLWithPath: outputPath))
        return outputPath
    }

    func storeScreenshot(
        captureResult: CaptureResult,
        path: String,
        existingSessionId: String?) async throws -> String
    {
        let sessionIdentifier: String
        if let existingSessionId {
            sessionIdentifier = existingSessionId
        } else {
            sessionIdentifier = try await self.sessionManager.createSession()
        }
        try await self.persistScreenshot(
            captureResult: captureResult,
            path: path,
            sessionId: sessionIdentifier)
        return sessionIdentifier
    }

    func persistScreenshot(
        captureResult: CaptureResult,
        path: String,
        sessionId: String) async throws
    {
        let appInfo = captureResult.metadata.applicationInfo
        let windowInfo = captureResult.metadata.windowInfo
        try await self.sessionManager.storeScreenshot(
            sessionId: sessionId,
            screenshotPath: path,
            applicationName: appInfo?.name,
            windowTitle: windowInfo?.title,
            windowBounds: windowInfo?.bounds)
    }

    func annotateIfNeeded(
        shouldAnnotate: Bool,
        captureResult: CaptureResult,
        sessionId: String) async throws
    {
        guard shouldAnnotate else { return }
        let detectionResult = try await uiAutomationService.detectElements(
            in: captureResult.imageData,
            sessionId: sessionId,
            windowContext: nil)
        try await self.sessionManager.storeDetectionResult(
            sessionId: sessionId,
            result: detectionResult)
    }

    func swipeDirection(from rawValue: String) -> SwipeDirection {
        switch rawValue.lowercased() {
        case "up": return .up
        case "down": return .down
        case "left": return .left
        case "right": return .right
        default: return .right
        }
    }

    func swipeEndpoints(
        params: ProcessCommandParameters.SwipeParameters,
        direction: SwipeDirection,
        distance: Double) -> (start: CGPoint, end: CGPoint)
    {
        if let x = params.fromX, let y = params.fromY {
            let start = CGPoint(x: x, y: y)
            return (start, self.offsetPoint(start, direction: direction, distance: distance))
        }

        let screenBounds = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let center = CGPoint(x: screenBounds.midX, y: screenBounds.midY)
        let endPoint = self.offsetPoint(center, direction: direction, distance: distance)
        return (center, endPoint)
    }

    func offsetPoint(_ point: CGPoint, direction: SwipeDirection, distance: Double) -> CGPoint {
        switch direction {
        case .up:
            return CGPoint(x: point.x, y: point.y - distance)
        case .down:
            return CGPoint(x: point.x, y: point.y + distance)
        case .left:
            return CGPoint(x: point.x - distance, y: point.y)
        case .right:
            return CGPoint(x: point.x + distance, y: point.y)
        }
    }

    struct WindowCommandContext {
        let action: String
        let app: String?
        let title: String?
        let index: Int?
        let resizeParams: ProcessCommandParameters.ResizeWindowParameters?
    }

    func windowCommandContext(from step: ScriptStep) throws -> WindowCommandContext {
        if case let .focusWindow(params) = step.params {
            return WindowCommandContext(
                action: "focus",
                app: params.app,
                title: params.title,
                index: params.index,
                resizeParams: nil)
        } else if case let .resizeWindow(params) = step.params {
            let action: String
            if params.maximize == true {
                action = "maximize"
            } else if params.minimize == true {
                action = "minimize"
            } else if params.x != nil || params.y != nil {
                action = "move"
            } else {
                action = "resize"
            }

            return WindowCommandContext(
                action: action,
                app: params.app,
                title: nil,
                index: nil,
                resizeParams: params)
        }

        throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for window command")
    }

    func fetchWindows(for app: String?) async throws -> [ServiceWindowInfo] {
        if let appName = app {
            return try await self.windowManagementService.listWindows(target: .application(appName))
        }

        let appsOutput = try await applicationService.listApplications()
        var allWindows: [ServiceWindowInfo] = []
        for app in appsOutput.data.applications {
            let appWindows = try await windowManagementService.listWindows(target: .application(app.name))
            allWindows.append(contentsOf: appWindows)
        }
        return allWindows
    }

    func selectWindow(
        from windows: [ServiceWindowInfo],
        title: String?,
        index: Int?) throws -> ServiceWindowInfo
    {
        if let windowTitle = title,
           let match = windows.first(where: { $0.title.contains(windowTitle) })
        {
            return match
        }

        if let windowIndex = index,
           windows.indices.contains(windowIndex)
        {
            return windows[windowIndex]
        }

        if let first = windows.first {
            return first
        }

        throw PeekabooError.windowNotFound()
    }

    func performWindowAction(
        _ action: String,
        window: ServiceWindowInfo,
        resizeParams: ProcessCommandParameters.ResizeWindowParameters?) async throws
    {
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
            guard let params = resizeParams, let x = params.x, let y = params.y else {
                throw PeekabooError.invalidInput(field: "params", reason: "Move action requires x and y coordinates")
            }
            try await self.windowManagementService.moveWindow(
                target: .windowId(window.windowID),
                to: CGPoint(x: x, y: y))
        case "resize":
            guard let params = resizeParams, let width = params.width, let height = params.height else {
                throw PeekabooError.invalidInput(
                    field: "params",
                    reason: "Resize action requires width and height values")
            }
            try await self.windowManagementService.resizeWindow(
                target: .windowId(window.windowID),
                to: CGSize(width: width, height: height))
        default:
            throw PeekabooError.invalidInput(field: "action", reason: "Invalid action '\(action)' for window command")
        }
    }
}
