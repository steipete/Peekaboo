import AppKit
import AXorcist
import Foundation
import PeekabooFoundation
import UniformTypeIdentifiers

/// Implementation of ProcessServiceProtocol for executing Peekaboo scripts
@available(macOS 14.0, *)
@MainActor
public final class ProcessService: ProcessServiceProtocol {
    private let applicationService: any ApplicationServiceProtocol
    private let screenCaptureService: any ScreenCaptureServiceProtocol
    private let snapshotManager: any SnapshotManagerProtocol
    private let uiAutomationService: any UIAutomationServiceProtocol
    private let windowManagementService: any WindowManagementServiceProtocol
    private let menuService: any MenuServiceProtocol
    private let dockService: any DockServiceProtocol
    private let clipboardService: any ClipboardServiceProtocol

    public init(
        applicationService: any ApplicationServiceProtocol,
        screenCaptureService: any ScreenCaptureServiceProtocol,
        snapshotManager: any SnapshotManagerProtocol,
        uiAutomationService: any UIAutomationServiceProtocol,
        windowManagementService: any WindowManagementServiceProtocol,
        menuService: any MenuServiceProtocol,
        dockService: any DockServiceProtocol,
        clipboardService: any ClipboardServiceProtocol)
    {
        self.applicationService = applicationService
        self.screenCaptureService = screenCaptureService
        self.snapshotManager = snapshotManager
        self.uiAutomationService = uiAutomationService
        self.windowManagementService = windowManagementService
        self.menuService = menuService
        self.dockService = dockService
        self.clipboardService = clipboardService
    }

    public convenience init(
        feedbackClient: any AutomationFeedbackClient = NoopAutomationFeedbackClient())
    {
        let snapshotManager = SnapshotManager()
        let loggingService = LoggingService()
        let applicationService = ApplicationService(feedbackClient: feedbackClient)
        let windowManagementService = WindowManagementService(
            applicationService: applicationService,
            feedbackClient: feedbackClient)
        let menuService = MenuService(feedbackClient: feedbackClient)
        let dockService = DockService(feedbackClient: feedbackClient)
        let clipboardService = ClipboardService()
        let uiAutomationService = UIAutomationService(
            snapshotManager: snapshotManager,
            loggingService: loggingService,
            feedbackClient: feedbackClient)

        let baseCaptureDeps = ScreenCaptureService.Dependencies.live()
        let captureDeps = ScreenCaptureService.Dependencies(
            feedbackClient: feedbackClient,
            permissionEvaluator: baseCaptureDeps.permissionEvaluator,
            fallbackRunner: baseCaptureDeps.fallbackRunner,
            applicationResolver: baseCaptureDeps.applicationResolver,
            makeModernOperator: baseCaptureDeps.makeModernOperator,
            makeLegacyOperator: baseCaptureDeps.makeLegacyOperator)
        let screenCaptureService = ScreenCaptureService(
            loggingService: loggingService,
            dependencies: captureDeps)

        self.init(
            applicationService: applicationService,
            screenCaptureService: screenCaptureService,
            snapshotManager: snapshotManager,
            uiAutomationService: uiAutomationService,
            windowManagementService: windowManagementService,
            menuService: menuService,
            dockService: dockService,
            clipboardService: clipboardService)
    }

    public func loadScript(from path: String) async throws -> PeekabooScript {
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PeekabooError.fileIOError("Script file not found: \(path)")
        }

        return try await performOperation({
            let data = try Data(contentsOf: url)
            let decoder = JSONCoding.makeDecoder()
            do {
                return try decoder.decode(PeekabooScript.self, from: data)
            } catch let decodingError as DecodingError {
                throw PeekabooError.invalidInput(Self.describeScriptDecodingError(decodingError, path: path))
            }
        }, errorContext: "Failed to load script from \(path)")
    }

    private nonisolated static func describeScriptDecodingError(_ error: DecodingError, path: String) -> String {
        let hint = "Tip: Peekaboo script params use Swift enum coding " +
            "(e.g. `{\"params\":{\"generic\":{\"_0\":{...}}}}`)."

        func formatContext(_ context: DecodingError.Context) -> String {
            let codingPath = context.codingPath.map(\.stringValue).joined(separator: ".")
            if codingPath.isEmpty {
                return context.debugDescription
            }
            return "\(context.debugDescription) (at \(codingPath))"
        }

        let details: String
        switch error {
        case let .typeMismatch(_, context):
            details = formatContext(context)
        case let .valueNotFound(_, context):
            details = formatContext(context)
        case let .keyNotFound(key, context):
            let base = formatContext(context)
            let codingPath = (context.codingPath + [key]).map(\.stringValue).joined(separator: ".")
            details = "\(base) (missing key \(codingPath))"
        case let .dataCorrupted(context):
            details = formatContext(context)
        @unknown default:
            details = String(describing: error)
        }

        return [
            "Invalid script JSON in \(path).",
            details,
            hint,
        ].joined(separator: " ")
    }

    public func executeScript(
        _ script: PeekabooScript,
        failFast: Bool,
        verbose: Bool) async throws -> [StepResult]
    {
        var results: [StepResult] = []
        var currentSnapshotId: String?

        for (index, step) in script.steps.indexed() {
            let stepNumber = index + 1
            let stepStartTime = Date()

            do {
                // Execute the step
                let executionResult = try await executeStep(step, snapshotId: currentSnapshotId)

                // Update snapshot ID if a new one was created
                if let newSnapshotId = executionResult.snapshotId {
                    currentSnapshotId = newSnapshotId
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
extension ProcessService {
    public func executeStep(
        _ step: ScriptStep,
        snapshotId: String?) async throws -> StepExecutionResult
    {
        let normalizedStep = self.normalizeStepParameters(step)

        switch normalizedStep.command.lowercased() {
        case "see":
            return try await self.executeSeeCommand(normalizedStep, snapshotId: snapshotId)
        case "click":
            return try await self.executeClickCommand(normalizedStep, snapshotId: snapshotId)
        case "type":
            return try await self.executeTypeCommand(normalizedStep, snapshotId: snapshotId)
        case "scroll":
            return try await self.executeScrollCommand(normalizedStep, snapshotId: snapshotId)
        case "swipe":
            return try await self.executeSwipeCommand(normalizedStep, snapshotId: snapshotId)
        case "drag":
            return try await self.executeDragCommand(normalizedStep, snapshotId: snapshotId)
        case "hotkey":
            return try await self.executeHotkeyCommand(normalizedStep, snapshotId: snapshotId)
        case "sleep":
            return try await self.executeSleepCommand(normalizedStep)
        case "window":
            return try await self.executeWindowCommand(normalizedStep, snapshotId: snapshotId)
        case "menu":
            return try await self.executeMenuCommand(normalizedStep, snapshotId: snapshotId)
        case "dock":
            return try await self.executeDockCommand(normalizedStep)
        case "app":
            return try await self.executeAppCommand(normalizedStep)
        case "clipboard":
            return try await self.executeClipboardCommand(normalizedStep)
        default:
            throw PeekabooError.invalidInput(field: "command", reason: "Unknown command: \(step.command)")
        }
    }
}

@MainActor
extension ProcessService {
    // MARK: - Command Implementations

    private func executeSeeCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
        let params = self.screenshotParameters(from: step)
        let captureResult = try await self.captureScreenshot(using: params)
        let screenshotPath = try self.saveScreenshot(
            captureResult,
            to: params.path)
        let resolvedSnapshotId = try await self.storeScreenshot(
            captureResult: captureResult,
            path: screenshotPath,
            existingSnapshotId: snapshotId)

        try await self.annotateIfNeeded(
            shouldAnnotate: params.annotate ?? true,
            captureResult: captureResult,
            snapshotId: resolvedSnapshotId)

        return StepExecutionResult(
            output: .data([
                "snapshot_id": .success(resolvedSnapshotId),
                "screenshot_path": .success(screenshotPath),
            ]),
            snapshotId: resolvedSnapshotId)
    }

    private func executeClickCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
        // Extract click parameters - should already be normalized
        guard case let .click(clickParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for click command")
        }

        guard let effectiveSnapshotId = snapshotId else {
            throw PeekabooError.invalidInput(field: "snapshot", reason: "Snapshot ID is required for click command")
        }

        // Determine click type
        let rightClick = clickParams.button == "right"
        let doubleClick = clickParams.button == "double"

        // Get snapshot detection result
        guard try await self.snapshotManager.getDetectionResult(snapshotId: effectiveSnapshotId) != nil else {
            throw PeekabooError.snapshotNotFound(effectiveSnapshotId)
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
            snapshotId: effectiveSnapshotId)

        return StepExecutionResult(
            output: .success("Clicked successfully"),
            snapshotId: effectiveSnapshotId)
    }

    private func executeTypeCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
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
            snapshotId: snapshotId)

        // Press Enter if requested
        if pressEnter {
            // Use typeActions to press Enter key
            _ = try await self.uiAutomationService.typeActions(
                [.key(.return)],
                cadence: .fixed(milliseconds: 50),
                snapshotId: snapshotId)
        }

        return StepExecutionResult(
            output: .data([
                "typed": .success(typeParams.text),
                "cleared": .success(String(clearFirst)),
                "enter_pressed": .success(String(pressEnter)),
            ]),
            snapshotId: snapshotId)
    }

    private func executeScrollCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
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
            snapshotId: snapshotId)
        try await self.uiAutomationService.scroll(request)

        return StepExecutionResult(
            output: .data([
                "scrolled": .success(scrollParams.direction),
                "amount": .success(String(amount)),
                "smooth": .success(String(smooth)),
            ]),
            snapshotId: snapshotId)
    }

    private func executeSwipeCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
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
            steps: 30,
            profile: .linear)

        return StepExecutionResult(
            output: .data([
                "swiped": .success(swipeParams.direction),
                "distance": .success(String(distance)),
                "duration": .success(String(duration)),
            ]),
            snapshotId: snapshotId)
    }

    private func executeDragCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
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
            modifiers: modifierString.isEmpty ? nil : modifierString,
            profile: .linear)

        return StepExecutionResult(
            output: .data([
                "dragged": .success("true"),
                "from_x": .success(String(dragParams.fromX)),
                "from_y": .success(String(dragParams.fromY)),
                "to_x": .success(String(dragParams.toX)),
                "to_y": .success(String(dragParams.toY)),
            ]),
            snapshotId: snapshotId)
    }

    private func executeHotkeyCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
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
            snapshotId: snapshotId)
    }

    private func executeSleepCommand(_ step: ScriptStep) async throws -> StepExecutionResult {
        // Extract sleep parameters - should already be normalized
        guard case let .sleep(sleepParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for sleep command")
        }

        try await Task.sleep(nanoseconds: UInt64(sleepParams.duration * 1_000_000_000))

        return StepExecutionResult(
            output: .success("Slept for \(sleepParams.duration) seconds"),
            snapshotId: nil)
    }

    private func executeWindowCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
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
            snapshotId: snapshotId)
    }

    private func executeMenuCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
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
            snapshotId: snapshotId)
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
                snapshotId: nil)

        case "click":
            guard let itemName = dockParams.item else {
                throw PeekabooError.invalidInput(
                    field: "item",
                    reason: "Missing required parameter for dock click command")
            }
            try await self.dockService.launchFromDock(appName: itemName)
            return StepExecutionResult(
                output: .success("Clicked dock item: \(itemName)"),
                snapshotId: nil)

        case "add":
            guard let path = dockParams.path else {
                throw PeekabooError.invalidInput(
                    field: "path",
                    reason: "Missing required parameter for dock add command")
            }
            try await self.dockService.addToDock(path: path, persistent: true)
            return StepExecutionResult(
                output: .success("Added to Dock: \(path)"),
                snapshotId: nil)

        case "remove":
            guard let item = dockParams.item else {
                throw PeekabooError.invalidInput(
                    field: "item",
                    reason: "Missing required parameter for dock remove command")
            }
            try await self.dockService.removeFromDock(appName: item)
            return StepExecutionResult(
                output: .success("Removed from Dock: \(item)"),
                snapshotId: nil)

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
                snapshotId: nil)

        case "quit":
            _ = try await self.applicationService.quitApplication(identifier: appName, force: appParams.force ?? false)
            return StepExecutionResult(
                output: .success("Quit application: \(appName)"),
                snapshotId: nil)

        case "hide":
            try await self.applicationService.hideApplication(identifier: appName)
            return StepExecutionResult(
                output: .success("Hidden application: \(appName)"),
                snapshotId: nil)

        case "show":
            try await self.applicationService.unhideApplication(identifier: appName)
            return StepExecutionResult(
                output: .success("Shown application: \(appName)"),
                snapshotId: nil)

        case "focus":
            try await self.applicationService.activateApplication(identifier: appName)
            return StepExecutionResult(
                output: .success("Focused application: \(appName)"),
                snapshotId: nil)

        default:
            throw PeekabooError.invalidInput(field: "action", reason: "Invalid action '\(action)' for app command")
        }
    }

    private func executeClipboardCommand(_ step: ScriptStep) async throws -> StepExecutionResult {
        guard case let .clipboard(clipboardParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for clipboard command")
        }

        let action = clipboardParams.action.lowercased()
        let slot = clipboardParams.slot ?? "0"

        switch action {
        case "clear":
            self.clipboardService.clear()
            return StepExecutionResult(output: .success("Cleared clipboard."), snapshotId: nil)

        case "save":
            try self.clipboardService.save(slot: slot)
            return StepExecutionResult(output: .success("Saved clipboard to slot \"\(slot)\"."), snapshotId: nil)

        case "restore":
            let result = try self.clipboardService.restore(slot: slot)
            return StepExecutionResult(
                output: .data([
                    "slot": .success(slot),
                    "uti": .success(result.utiIdentifier),
                    "bytes": .success("\(result.data.count)"),
                    "textPreview": .success(result.textPreview),
                ]),
                snapshotId: nil)

        case "get":
            let preferUTI: UTType? = clipboardParams.prefer.flatMap { UTType($0) }
            guard let result = try self.clipboardService.get(prefer: preferUTI) else {
                return StepExecutionResult(output: .success("Clipboard is empty."), snapshotId: nil)
            }

            if let outputPath = clipboardParams.output {
                try result.data.write(to: URL(fileURLWithPath: outputPath))
                return StepExecutionResult(
                    output: .data([
                        "output": .success(outputPath),
                        "uti": .success(result.utiIdentifier),
                        "bytes": .success("\(result.data.count)"),
                        "textPreview": .success(result.textPreview),
                    ]),
                    snapshotId: nil)
            }

            return StepExecutionResult(
                output: .data([
                    "uti": .success(result.utiIdentifier),
                    "bytes": .success("\(result.data.count)"),
                    "textPreview": .success(result.textPreview),
                ]),
                snapshotId: nil)

        case "set", "load":
            let allowLarge = clipboardParams.allowLarge ?? false
            let alsoText = clipboardParams.alsoText

            if let text = clipboardParams.text {
                guard let data = text.data(using: .utf8) else {
                    throw ClipboardServiceError.writeFailed("Unable to encode text as UTF-8.")
                }
                let request = ClipboardWriteRequest(
                    representations: ClipboardWriteRequest.textRepresentations(from: data),
                    alsoText: alsoText,
                    allowLarge: allowLarge)
                let result = try self.clipboardService.set(request)
                return StepExecutionResult(
                    output: .data([
                        "uti": .success(result.utiIdentifier),
                        "bytes": .success("\(result.data.count)"),
                        "textPreview": .success(result.textPreview),
                    ]),
                    snapshotId: nil)
            }

            if let filePath = clipboardParams.filePath {
                let url = URL(fileURLWithPath: filePath)
                let data = try Data(contentsOf: url)
                let uti = clipboardParams.uti
                    ?? UTType(filenameExtension: url.pathExtension)?.identifier
                    ?? UTType.data.identifier
                let request = ClipboardWriteRequest(
                    representations: [ClipboardRepresentation(utiIdentifier: uti, data: data)],
                    alsoText: alsoText,
                    allowLarge: allowLarge)
                let result = try self.clipboardService.set(request)
                return StepExecutionResult(
                    output: .data([
                        "filePath": .success(filePath),
                        "uti": .success(result.utiIdentifier),
                        "bytes": .success("\(result.data.count)"),
                        "textPreview": .success(result.textPreview),
                    ]),
                    snapshotId: nil)
            }

            if let dataBase64 = clipboardParams.dataBase64, let uti = clipboardParams.uti {
                guard let data = Data(base64Encoded: dataBase64) else {
                    throw ClipboardServiceError.writeFailed("Invalid base64 payload.")
                }
                let request = ClipboardWriteRequest(
                    representations: [ClipboardRepresentation(utiIdentifier: uti, data: data)],
                    alsoText: alsoText,
                    allowLarge: allowLarge)
                let result = try self.clipboardService.set(request)
                return StepExecutionResult(
                    output: .data([
                        "uti": .success(result.utiIdentifier),
                        "bytes": .success("\(result.data.count)"),
                        "textPreview": .success(result.textPreview),
                    ]),
                    snapshotId: nil)
            }

            throw ClipboardServiceError.writeFailed(
                "Provide text, file-path/image-path, or data-base64+uti to set the clipboard.")

        default:
            throw PeekabooError.invalidInput(field: "action", reason: "Unknown clipboard action: \(action)")
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

    private func typedParameters(for command: String, dict: [String: String]) -> ProcessCommandParameters? {
        switch command {
        case "see":
            .screenshot(self.typedScreenshotParameters(from: dict))
        case "click":
            .click(self.typedClickParameters(from: dict))
        case "type":
            self.typedTypeParameters(from: dict)
        case "scroll":
            .scroll(self.typedScrollParameters(from: dict))
        case "hotkey":
            self.typedHotkeyParameters(from: dict)
        case "menu":
            self.typedMenuParameters(from: dict)
        case "window":
            .focusWindow(self.typedWindowParameters(from: dict))
        case "app":
            self.typedAppParameters(from: dict)
        case "swipe":
            .swipe(self.typedSwipeParameters(from: dict))
        case "drag":
            self.typedDragParameters(from: dict)
        case "sleep":
            .sleep(self.typedSleepParameters(from: dict))
        case "dock":
            .dock(self.typedDockParameters(from: dict))
        case "clipboard":
            self.typedClipboardParameters(from: dict)
        default:
            nil
        }
    }

    private func typedScreenshotParameters(from dict: [String: String]) -> ProcessCommandParameters
    .ScreenshotParameters {
        ProcessCommandParameters.ScreenshotParameters(
            path: dict["path"] ?? "screenshot.png",
            app: dict["app"],
            window: dict["window"],
            display: dict["display"].flatMap { Int($0) },
            mode: dict["mode"],
            annotate: dict["annotate"].flatMap { Bool($0) })
    }

    private func typedClickParameters(from dict: [String: String]) -> ProcessCommandParameters.ClickParameters {
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

    private func typedTypeParameters(from dict: [String: String]) -> ProcessCommandParameters? {
        guard let text = dict["text"] else { return nil }
        return .type(ProcessCommandParameters.TypeParameters(
            text: text,
            app: dict["app"],
            field: dict["field"],
            clearFirst: dict["clear-first"].flatMap { Bool($0) },
            pressEnter: dict["press-enter"].flatMap { Bool($0) }))
    }

    private func typedScrollParameters(from dict: [String: String]) -> ProcessCommandParameters.ScrollParameters {
        ProcessCommandParameters.ScrollParameters(
            direction: dict["direction"] ?? "down",
            amount: dict["amount"].flatMap { Int($0) },
            app: dict["app"],
            target: dict["on"] ?? dict["target"])
    }

    private func typedHotkeyParameters(from dict: [String: String]) -> ProcessCommandParameters? {
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

    private func typedMenuParameters(from dict: [String: String]) -> ProcessCommandParameters? {
        guard let path = dict["path"] ?? dict["menu"] else { return nil }
        let menuItems = path.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
        return .menuClick(ProcessCommandParameters.MenuClickParameters(
            menuPath: menuItems,
            app: dict["app"]))
    }

    private func typedWindowParameters(from dict: [String: String]) -> ProcessCommandParameters.FocusWindowParameters {
        ProcessCommandParameters.FocusWindowParameters(
            app: dict["app"],
            title: dict["title"],
            index: dict["index"].flatMap { Int($0) })
    }

    private func typedAppParameters(from dict: [String: String]) -> ProcessCommandParameters? {
        guard let appName = dict["name"] else { return nil }
        return .launchApp(ProcessCommandParameters.LaunchAppParameters(
            appName: appName,
            action: dict["action"],
            waitForLaunch: dict["wait"].flatMap { Bool($0) },
            bringToFront: dict["focus"].flatMap { Bool($0) },
            force: dict["force"].flatMap { Bool($0) }))
    }

    private func typedSwipeParameters(from dict: [String: String]) -> ProcessCommandParameters.SwipeParameters {
        ProcessCommandParameters.SwipeParameters(
            direction: dict["direction"] ?? "right",
            distance: dict["distance"].flatMap { Double($0) },
            duration: dict["duration"].flatMap { Double($0) },
            fromX: dict["from-x"].flatMap { Double($0) },
            fromY: dict["from-y"].flatMap { Double($0) })
    }

    private func typedDragParameters(from dict: [String: String]) -> ProcessCommandParameters? {
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

    private func typedSleepParameters(from dict: [String: String]) -> ProcessCommandParameters.SleepParameters {
        let duration = dict["duration"].flatMap { Double($0) } ?? 1.0
        return ProcessCommandParameters.SleepParameters(duration: duration)
    }

    private func typedDockParameters(from dict: [String: String]) -> ProcessCommandParameters.DockParameters {
        ProcessCommandParameters.DockParameters(
            action: dict["action"] ?? "list",
            item: dict["item"],
            path: dict["path"])
    }

    private func typedClipboardParameters(from dict: [String: String]) -> ProcessCommandParameters? {
        guard let action = dict["action"] else { return nil }

        return .clipboard(ProcessCommandParameters.ClipboardParameters(
            action: action,
            text: dict["text"],
            filePath: dict["file-path"] ?? dict["filePath"] ?? dict["image-path"] ?? dict["imagePath"],
            dataBase64: dict["data-base64"] ?? dict["dataBase64"],
            uti: dict["uti"],
            prefer: dict["prefer"],
            output: dict["output"],
            slot: dict["slot"],
            alsoText: dict["also-text"] ?? dict["alsoText"],
            allowLarge: dict["allow-large"].flatMap { Bool($0) } ?? dict["allowLarge"].flatMap { Bool($0) }))
    }

    private func screenshotParameters(from step: ScriptStep) -> ProcessCommandParameters.ScreenshotParameters {
        if case let .screenshot(params) = step.params {
            return params
        }
        return ProcessCommandParameters.ScreenshotParameters(path: "screenshot.png")
    }

    private func captureScreenshot(using params: ProcessCommandParameters
        .ScreenshotParameters) async throws -> CaptureResult
    {
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

    private func saveScreenshot(
        _ captureResult: CaptureResult,
        to outputPath: String) throws -> String
    {
        guard !outputPath.isEmpty else {
            return captureResult.savedPath ?? ""
        }
        try captureResult.imageData.write(to: URL(fileURLWithPath: outputPath))
        return outputPath
    }

    private func storeScreenshot(
        captureResult: CaptureResult,
        path: String,
        existingSnapshotId: String?) async throws -> String
    {
        let snapshotIdentifier: String = if let existingSnapshotId {
            existingSnapshotId
        } else {
            try await self.snapshotManager.createSnapshot()
        }
        try await self.persistScreenshot(
            captureResult: captureResult,
            path: path,
            snapshotId: snapshotIdentifier)
        return snapshotIdentifier
    }

    private func persistScreenshot(
        captureResult: CaptureResult,
        path: String,
        snapshotId: String) async throws
    {
        let appInfo = captureResult.metadata.applicationInfo
        let windowInfo = captureResult.metadata.windowInfo
        try await self.snapshotManager.storeScreenshot(
            snapshotId: snapshotId,
            screenshotPath: path,
            applicationBundleId: appInfo?.bundleIdentifier,
            applicationProcessId: appInfo.map { Int32($0.processIdentifier) },
            applicationName: appInfo?.name,
            windowTitle: windowInfo?.title,
            windowBounds: windowInfo?.bounds)
    }

    private func annotateIfNeeded(
        shouldAnnotate: Bool,
        captureResult: CaptureResult,
        snapshotId: String) async throws
    {
        guard shouldAnnotate else { return }
        let detectionResult = try await uiAutomationService.detectElements(
            in: captureResult.imageData,
            snapshotId: snapshotId,
            windowContext: nil)
        try await self.snapshotManager.storeDetectionResult(
            snapshotId: snapshotId,
            result: detectionResult)
    }

    private func swipeDirection(from rawValue: String) -> SwipeDirection {
        switch rawValue.lowercased() {
        case "up": .up
        case "down": .down
        case "left": .left
        case "right": .right
        default: .right
        }
    }

    private func swipeEndpoints(
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

    private func offsetPoint(_ point: CGPoint, direction: SwipeDirection, distance: Double) -> CGPoint {
        switch direction {
        case .up:
            CGPoint(x: point.x, y: point.y - distance)
        case .down:
            CGPoint(x: point.x, y: point.y + distance)
        case .left:
            CGPoint(x: point.x - distance, y: point.y)
        case .right:
            CGPoint(x: point.x + distance, y: point.y)
        }
    }

    fileprivate struct WindowCommandContext {
        let action: String
        let app: String?
        let title: String?
        let index: Int?
        let resizeParams: ProcessCommandParameters.ResizeWindowParameters?
    }

    private func windowCommandContext(from step: ScriptStep) throws -> WindowCommandContext {
        if case let .focusWindow(params) = step.params {
            return WindowCommandContext(
                action: "focus",
                app: params.app,
                title: params.title,
                index: params.index,
                resizeParams: nil)
        } else if case let .resizeWindow(params) = step.params {
            let action = if params.maximize == true {
                "maximize"
            } else if params.minimize == true {
                "minimize"
            } else if params.x != nil || params.y != nil {
                "move"
            } else {
                "resize"
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

    private func fetchWindows(for app: String?) async throws -> [ServiceWindowInfo] {
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

    private func selectWindow(
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

    private func performWindowAction(
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
