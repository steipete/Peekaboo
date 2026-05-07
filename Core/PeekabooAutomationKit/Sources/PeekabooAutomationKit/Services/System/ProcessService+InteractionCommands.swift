import AppKit
import Foundation
import PeekabooFoundation

@MainActor
extension ProcessService {
    func executeClickCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
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

    func executeTypeCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
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

    func executeScrollCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
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

    func executeSwipeCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
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

    func executeDragCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
        // Extract drag parameters - should already be normalized
        guard case let .drag(dragParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for drag command")
        }

        let duration = dragParams.duration ?? 1.0
        let modifiers = self.parseModifiers(from: dragParams.modifiers)

        let modifierString = modifiers.map(\.rawValue).joined(separator: ",")

        try await self.uiAutomationService.drag(
            DragOperationRequest(
                from: CGPoint(x: dragParams.fromX, y: dragParams.fromY),
                to: CGPoint(x: dragParams.toX, y: dragParams.toY),
                duration: Int(duration * 1000), // Convert to milliseconds
                steps: 30,
                modifiers: modifierString.isEmpty ? nil : modifierString,
                profile: .linear))

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

    func executeHotkeyCommand(_ step: ScriptStep, snapshotId: String?) async throws -> StepExecutionResult {
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

    func executeSleepCommand(_ step: ScriptStep) async throws -> StepExecutionResult {
        // Extract sleep parameters - should already be normalized
        guard case let .sleep(sleepParams) = step.params else {
            throw PeekabooError.invalidInput(field: "params", reason: "Invalid parameters for sleep command")
        }

        try await Task.sleep(nanoseconds: UInt64(sleepParams.duration * 1_000_000_000))

        return StepExecutionResult(
            output: .success("Slept for \(sleepParams.duration) seconds"),
            snapshotId: nil)
    }

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
}
