import Foundation
import MCP
import os.log
import PeekabooAutomation
import PeekabooFoundation
import TachikomaMCP

/// MCP tool for typing text
public struct TypeTool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "TypeTool")
    private let context: MCPToolContext

    public let name = "type"

    public var description: String {
        """
        Types text into UI elements or at current focus.
        Supports special keys ({return}, {tab}, etc.) plus human typing (--wpm) or fixed-delay (--delay) pacing.
        Can target specific elements or type at current keyboard focus.
        Peekaboo MCP 3.0.0-beta3 using openai/gpt-5.1
        and anthropic/claude-sonnet-4.5
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "text": SchemaBuilder.string(
                    description: "The text to type. If not specified, can use special key flags instead."),
                "on": SchemaBuilder.string(
                    description: "Optional. Element ID to type into (from see command). " +
                        "If not specified, types at current focus."),
                "snapshot": SchemaBuilder.string(
                    description: "Optional. Snapshot ID from see command. Uses latest snapshot if not specified."),
                "delay": SchemaBuilder.number(
                    description: "Optional. Delay between keystrokes in milliseconds (linear profile). Default: 5.",
                    default: 5),
                "profile": SchemaBuilder.string(
                    description: "Optional. Typing profile: human (default) or linear."),
                "wpm": SchemaBuilder.number(
                    description: "Optional. Human typing speed (80-220 WPM). Overrides delay when set."),
                "clear": SchemaBuilder.boolean(
                    description: "Optional. Clear the field before typing (Cmd+A, Delete).",
                    default: false),
                "press_return": SchemaBuilder.boolean(
                    description: "Optional. Press return/enter after typing.",
                    default: false),
                "tab": SchemaBuilder.number(
                    description: "Optional. Press tab N times."),
                "escape": SchemaBuilder.boolean(
                    description: "Optional. Press escape key.",
                    default: false),
                "delete": SchemaBuilder.boolean(
                    description: "Optional. Press delete/backspace key.",
                    default: false),
            ],
            required: [])
    }

    public init(context: MCPToolContext = .shared) {
        self.context = context
    }

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        do {
            let request = try self.parseRequest(arguments: arguments)
            return try await self.performType(request: request)
        } catch let error as TypeToolValidationError {
            return ToolResponse.error(error.message)
        } catch {
            self.logger.error("Type execution failed: \(error)")
            return ToolResponse.error("Failed to type text: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func getSnapshot(id: String?) async -> UISnapshot? {
        await UISnapshotManager.shared.getSnapshot(id: id)
    }

    private func parseRequest(arguments: ToolArguments) throws -> TypeRequest {
        let profile = try self.parseProfile(arguments.getString("profile"))
        let request = TypeRequest(
            text: arguments.getString("text"),
            elementId: arguments.getString("on"),
            snapshotId: arguments.getString("snapshot"),
            delay: Int(arguments.getNumber("delay") ?? 5),
            profile: profile,
            wordsPerMinute: arguments.getNumber("wpm").map { Int($0) },
            clearField: arguments.getBool("clear") ?? false,
            pressReturn: arguments.getBool("press_return") ?? false,
            tabCount: arguments.getNumber("tab").map { Int($0) },
            pressEscape: arguments.getBool("escape") ?? false,
            pressDelete: arguments.getBool("delete") ?? false)

        guard request.hasActions else {
            throw TypeToolValidationError("Must specify text to type or special key actions")
        }

        if let wpm = request.wordsPerMinute, !(80...220).contains(wpm) {
            throw TypeToolValidationError("wpm must be between 80 and 220")
        }

        if request.wordsPerMinute != nil, request.profile != .human {
            throw TypeToolValidationError("wpm is only supported with the human profile")
        }

        return request
    }

    private func parseProfile(_ raw: String?) throws -> TypingProfile {
        guard let raw else { return .human }
        guard let profile = TypingProfile(rawValue: raw.lowercased()) else {
            throw TypeToolValidationError("profile must be 'human' or 'linear'")
        }
        return profile
    }

    @MainActor
    private func performType(request: TypeRequest) async throws -> ToolResponse {
        let automation = self.context.automation
        let startTime = Date()

        let targetContext = try await self.resolveTargetContext(for: request)

        try await self.focusIfNeeded(targetContext: targetContext, request: request, automation: automation)
        let actions = try self.buildActions(for: request)
        let typeResult = try await automation.typeActions(
            actions,
            cadence: request.cadence,
            snapshotId: request.snapshotId)

        let executionTime = Date().timeIntervalSince(startTime)
        let message = self.buildSummary(
            request: request,
            executionTime: executionTime,
            result: typeResult)
        let baseMeta: Value = .object([
            "execution_time": .double(executionTime),
            "characters_typed": .double(Double(typeResult.totalCharacters)),
        ])
        let summary = self.buildEventSummary(
            request: request,
            result: typeResult,
            targetContext: targetContext)
        let mergedMeta = ToolEventSummary.merge(summary: summary, into: baseMeta)

        return ToolResponse(
            content: [.text(message)],
            meta: mergedMeta)
    }

    @MainActor
    private func focusIfNeeded(
        targetContext: TargetElementContext?,
        request: TypeRequest,
        automation: any UIAutomationServiceProtocol) async throws
    {
        guard let context = targetContext else { return }

        let element = context.element
        let clickLocation = CGPoint(x: element.frame.midX, y: element.frame.midY)
        try await automation.click(
            target: .coordinates(clickLocation),
            clickType: .single,
            snapshotId: request.snapshotId)
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    @MainActor
    private func resolveTargetContext(for request: TypeRequest) async throws -> TargetElementContext? {
        guard let elementId = request.elementId else { return nil }
        guard let snapshot = await self.getSnapshot(id: request.snapshotId) else {
            throw TypeToolValidationError("No active snapshot. Run 'see' command first to capture UI state.")
        }

        guard let element = await snapshot.getElement(byId: elementId) else {
            throw TypeToolValidationError(
                "Element '\(elementId)' not found in current snapshot. Run 'see' command to update UI state.")
        }

        return TargetElementContext(snapshot: snapshot, element: element)
    }

    private func buildEventSummary(
        request: TypeRequest,
        result: TypeResult,
        targetContext: TargetElementContext?) -> ToolEventSummary
    {
        let truncatedInput = self.truncatedText(request.text)
        return ToolEventSummary(
            targetApp: targetContext?.snapshot.applicationName,
            windowTitle: targetContext?.snapshot.windowTitle,
            elementRole: targetContext?.element.summaryRole,
            elementLabel: targetContext?.element.summaryLabel,
            elementValue: truncatedInput,
            actionDescription: self.describeAction(for: request),
            notes: truncatedInput)
    }

    private func truncatedText(_ text: String?, limit: Int = 80) -> String? {
        guard let text, !text.isEmpty else { return nil }
        if text.count <= limit {
            return text
        }
        let endIndex = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<endIndex]) + "…"
    }

    private func describeAction(for request: TypeRequest) -> String {
        if let text = request.text, !text.isEmpty {
            return "Typed"
        }
        var actions: [String] = []
        if let tabs = request.tabCount, tabs > 0 { actions.append("Tab×\(tabs)") }
        if request.pressReturn { actions.append("Return") }
        if request.pressEscape { actions.append("Escape") }
        if request.pressDelete { actions.append("Delete") }
        if request.clearField { actions.append("Clear Field") }
        return actions.isEmpty ? "Type" : actions.joined(separator: ", ")
    }

    private func buildActions(for request: TypeRequest) throws -> [TypeAction] {
        var actions: [TypeAction] = []

        if request.clearField {
            actions.append(.clear)
        }

        if let text = request.text, !text.isEmpty {
            actions.append(.text(text))
        }

        if let tabCount = request.tabCount, tabCount > 0 {
            actions.append(contentsOf: Array(repeating: .key(.tab), count: tabCount))
        }

        if request.pressEscape {
            actions.append(.key(.escape))
        }

        if request.pressDelete {
            actions.append(.key(.delete))
        }

        if request.pressReturn {
            actions.append(.key(.return))
        }

        guard !actions.isEmpty else {
            throw TypeToolValidationError("Specify text or key actions to run the type tool")
        }

        return actions
    }

    private func buildSummary(
        request: TypeRequest,
        executionTime: TimeInterval,
        result: TypeResult) -> String
    {
        var actions: [String] = []

        if request.clearField {
            actions.append("Cleared field")
        }

        if let text = request.text {
            let displayText = text.count > 50 ? String(text.prefix(50)) + "..." : text
            actions.append("Typed: \"\(displayText)\"")
        }

        if let tabCount = request.tabCount {
            actions.append("Pressed Tab \(tabCount) time\(tabCount == 1 ? "" : "s")")
        }

        if request.pressEscape {
            actions.append("Pressed Escape")
        }

        if request.pressDelete {
            actions.append("Pressed Delete")
        }

        if request.pressReturn {
            actions.append("Pressed Return")
        }

        if let wpm = request.wordsPerMinute {
            actions.append("Human cadence: \(wpm) WPM")
        } else {
            actions.append("Fixed delay: \(request.delay)ms")
        }

        actions.append("Profile: \(request.profile.rawValue)")
        if let wpm = request.wordsPerMinute ?? (request.profile == .human ? TypeRequest.defaultHumanWPM : nil) {
            if request.profile == .human {
                actions.append("WPM: \(wpm)")
            }
        } else {
            actions.append("Delay: \(request.delay)ms")
        }
        actions.append("Chars: \(result.totalCharacters)")
        let specialKeys = max(result.keyPresses - result.totalCharacters, 0)
        actions.append("Special keys: \(specialKeys)")

        let duration = String(format: "%.2f", executionTime) + "s"
        let summary = actions.isEmpty ? "Performed no actions" : actions.joined(separator: ", ")
        return "\(AgentDisplayTokens.Status.success) \(summary) in \(duration)"
    }
}

private struct TypeRequest {
    let text: String?
    let elementId: String?
    let snapshotId: String?
    let delay: Int
    let profile: TypingProfile
    let wordsPerMinute: Int?
    let clearField: Bool
    let pressReturn: Bool
    let tabCount: Int?
    let pressEscape: Bool
    let pressDelete: Bool

    static let defaultHumanWPM = 140

    var hasActions: Bool {
        self.text != nil ||
            self.tabCount != nil ||
            self.pressEscape ||
            self.pressDelete ||
            self.pressReturn ||
            self.clearField
    }

    var cadence: TypingCadence {
        switch self.profile {
        case .human:
            let wpm = self.wordsPerMinute ?? Self.defaultHumanWPM
            return .human(wordsPerMinute: wpm)
        case .linear:
            return .fixed(milliseconds: self.delay)
        }
    }
}

private struct TypeToolValidationError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

private struct TargetElementContext {
    let snapshot: UISnapshot
    let element: UIElement
}
