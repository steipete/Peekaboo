//
//  AgentChatUI.swift
//  PeekabooCLI
//

import Foundation
import PeekabooAgentRuntime
import Tachikoma
import TauTUI

// Minimal loader component to keep chat rendering responsive without pulling in full spinner logic.
@MainActor
private final class Loader: Component {
    private var message: String

    init(tui: TUI, message: String) {
        self.message = message
    }

    func setMessage(_ message: String) {
        self.message = message
    }

    func stop() {}

    func render(width: Int) -> [String] {
        ["\(self.message)"]
    }
}

// MARK: - Input

@MainActor
final class AgentChatInput: Component {
    private let editor = Editor()

    var onSubmit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onInterrupt: (() -> Void)?
    var onQueueWhileLocked: (() -> Void)?

    var isLocked: Bool = false {
        didSet {
            if !self.isLocked {
                self.editor.disableSubmit = false
            }
        }
    }

    init() {
        self.editor.onSubmit = { [weak self] value in
            self?.onSubmit?(value)
        }
    }

    func render(width: Int) -> [String] {
        self.editor.render(width: width)
    }

    func handle(input: TerminalInput) {
        switch input {
        case let .key(.character(char), modifiers):
            if modifiers.contains(.control) {
                let lower = String(char).lowercased()
                if lower == "c" || lower == "d" {
                    self.onInterrupt?()
                    return
                }
            }
        case .key(.escape, _):
            if self.isLocked {
                self.onCancel?()
                return
            }
        case .key(.end, _):
            if self.isLocked {
                self.onQueueWhileLocked?()
                return
            }
        default:
            break
        }

        self.editor.handle(input: input)
    }

    func clear() {
        self.editor.setText("")
    }

    func currentText() -> String {
        self.editor.getText()
    }
}

// MARK: - TauTUI Chat UI

@MainActor
final class AgentChatUI {
    var onCancelRequested: (() -> Void)?
    var onInterruptRequested: (() -> Void)?

    private let tui: TUI
    private let messages = Container()
    private let input = AgentChatInput()
    private let header: Text
    private let sessionLine: Text
    private let helpLines: [String]
    private let queueMode: QueueMode
    private let queueContainer = Container()
    private let queuePreview = Text(text: "", paddingX: 1, paddingY: 0)

    // Palette for consistent styling (ANSI colors)
    private let accentBlue = AnsiStyling.color(39)
    private let successGreen = AnsiStyling.color(82)
    private let failureRed = AnsiStyling.color(203)
    private let thinkingGray = AnsiStyling.color(246)

    private var promptContinuation: AsyncStream<String>.Continuation?
    private var loader: Loader?
    private var assistantBuffer = ""
    private var assistantComponent: MarkdownComponent?
    private var thinkingBlocks: [MarkdownComponent] = []
    private var sessionId: String?
    private var queuedPrompts: [String] = []
    private var isRunning = false

    init(modelDescription: String, sessionId: String?, queueMode: QueueMode, helpLines: [String]) {
        self.tui = TUI(terminal: ProcessTerminal())
        self.sessionId = sessionId
        self.helpLines = helpLines
        self.queueMode = queueMode
        let queueLabel = queueMode == .all ? "all" : "one-at-a-time"
        self.header = Text(
            text: "Interactive agent chat – model: \(modelDescription) • queue: \(queueLabel)",
            paddingX: 1,
            paddingY: 0
        )
        self.sessionLine = Text(
            text: AgentChatUI.sessionDescription(for: sessionId, queueMode: queueMode),
            paddingX: 1,
            paddingY: 0
        )

        self.input.onSubmit = { [weak self] value in
            self?.handleSubmit(value)
        }
        self.input.onCancel = { [weak self] in
            self?.onCancelRequested?()
        }
        self.input.onInterrupt = { [weak self] in
            self?.onInterruptRequested?()
        }
        self.input.onQueueWhileLocked = { [weak self] in
            self?.queueCurrentInput()
        }
    }

    func start() throws {
        self.tui.addChild(self.header)
        self.tui.addChild(self.sessionLine)
        self.tui.addChild(Spacer(lines: 1))
        self.tui.addChild(self.messages)
        self.tui.addChild(Spacer(lines: 1))
        self.tui.addChild(self.queueContainer)
        self.tui.addChild(self.input)
        self.tui.setFocus(self.input)

        try self.tui.start()
        self.showHelpMenu()
        self.tui.requestRender()
    }

    func stop() {
        self.tui.stop()
    }

    func promptStream(initialPrompt: String?) -> AsyncStream<String> {
        AsyncStream { continuation in
            self.promptContinuation = continuation
            if let seed = initialPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
               !seed.isEmpty {
                self.appendUserMessage(seed)
                continuation.yield(seed)
            }
        }
    }

    func finishPromptStream() {
        self.promptContinuation?.finish()
    }

    func beginRun(prompt: String) {
        self.setRunning(true)
        self.removeLoader()
        self.loader = Loader(tui: self.tui, message: "Running…")
        if let loader {
            self.messages.addChild(loader)
        }
        self.assistantBuffer = ""
        self.assistantComponent = nil
        self.thinkingBlocks.removeAll()
        self.requestRender()
    }

    func endRun(result: AgentExecutionResult, sessionId: String?) {
        self.loader?.stop()
        self.loader = nil
        if let sessionId {
            self.sessionId = sessionId
            self.sessionLine.text = AgentChatUI.sessionDescription(for: sessionId, queueMode: self.queueMode)
        }
        let summary = self.summaryLine(for: result)
        let summaryComponent = Text(text: summary, paddingX: 1, paddingY: 0)
        self.messages.addChild(summaryComponent)
        self.setRunning(false)
        self.processNextQueuedPromptIfNeeded()
        self.requestRender()
    }

    func showHelpMenu() {
        // Render each line separately so the bullets always appear on their own lines,
        // even when terminals collapse single newlines in a single Text component.
        for line in self.helpLines {
            let helpLine = Text(text: line, paddingX: 1, paddingY: 0)
            self.messages.addChild(helpLine)
        }
        self.requestRender()
    }

    func showCancelled() {
        self.setRunning(false)
        let cancelled = Text(text: "◼︎ Cancelled", paddingX: 1, paddingY: 0)
        self.messages.addChild(cancelled)
        self.requestRender()
    }

    func showError(_ message: String) {
        self.setRunning(false)
        let errorText = Text(text: "✗ \(message)", paddingX: 1, paddingY: 0)
        self.messages.addChild(errorText)
        self.requestRender()
    }

    func showToolStart(name: String, summary: String?, icon: String?, displayName: String?) {
        let label = displayName ?? name
        let detail = summary.flatMap { $0.isEmpty ? nil : $0 }
        let body = detail.map { "**\(label)** – \($0)" } ?? "**\(label)**"
        let content = ["⚒", icon, body].compactMap(\.self).joined(separator: " ")
        self.messages.addChild(self.colorLine(content, color: self.accentBlue))
        self.requestRender()
    }

    func showToolCompletion(name: String, success: Bool, summary: String?, icon: String?, displayName: String?) {
        let prefix = success ? "✓" : "✗"
        let color = success ? self.successGreen : self.failureRed
        let label = displayName ?? name
        let detail = summary.flatMap { $0.isEmpty ? nil : $0 }
        let body = detail.map { "**\(label)** – \($0)" } ?? "**\(label)**"
        let content = [prefix, icon, body].compactMap(\.self).joined(separator: " ")
        self.messages.addChild(self.colorLine(content, color: color))
        self.requestRender()
    }

    func showToolUpdate(name: String, summary: String?, icon: String?, displayName: String?) {
        let label = displayName ?? name
        let detail = summary.flatMap { $0.isEmpty ? nil : $0 }
        let body = detail.map { "**\(label)** – \($0)" } ?? "**\(label)**"
        let content = ["↻", icon, body].compactMap(\.self).joined(separator: " ")
        self.messages.addChild(self.colorLine(content, color: self.accentBlue))
        self.requestRender()
    }

    func updateThinking(_ content: String) {
        let component = MarkdownComponent(
            text: "*\(content)*",
            padding: .init(horizontal: 1, vertical: 0),
            defaultTextStyle: .init(color: self.thinkingGray)
        )
        self.thinkingBlocks.append(component)
        self.messages.addChild(component)
        self.requestRender()
    }

    func appendAssistant(_ content: String) {
        self.assistantBuffer.append(content)
        let formatted = "**Agent:** \(self.assistantBuffer)"
        if let assistantComponent {
            assistantComponent.text = formatted
        } else {
            let component = MarkdownComponent(text: formatted, padding: .init(horizontal: 1, vertical: 0))
            self.assistantComponent = component
            self.messages.addChild(component)
        }
        self.requestRender()
    }

    func finishStreaming() {
        self.requestRender()
    }

    func setRunning(_ running: Bool) {
        let wasRunning = self.isRunning
        self.isRunning = running
        self.input.isLocked = running
        if !running {
            self.removeLoader()
            if wasRunning {
                self.processNextQueuedPromptIfNeeded()
            }
        }
    }

    func markCancelling() {
        self.loader?.setMessage("Cancelling…")
        self.requestRender()
    }

    func requestRender() {
        self.tui.requestRender()
    }

    private func colorLine(_ text: String, color: @escaping AnsiStyling.Style) -> MarkdownComponent {
        MarkdownComponent(
            text: text,
            padding: .init(horizontal: 1, vertical: 0),
            defaultTextStyle: .init(color: color))
    }

    private func removeLoader() {
        guard let loader else { return }
        loader.stop()
        self.messages.removeChild(loader)
        self.loader = nil
        self.requestRender()
    }

    private func handleSubmit(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if self.isRunning {
            self.enqueueQueuedPrompt(trimmed)
            self.input.clear()
            return
        }

        self.dispatchPrompt(trimmed)
    }

    private func queueCurrentInput() {
        guard self.isRunning else { return }
        let trimmed = self.input.currentText().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        self.enqueueQueuedPrompt(trimmed)
        self.input.clear()
    }

    private func enqueueQueuedPrompt(_ prompt: String) {
        self.queuedPrompts.append(prompt)
        self.updateQueuePreview()
    }

    private func updateQueuePreview() {
        if self.queuedPrompts.isEmpty {
            self.queueContainer.clear()
            self.queuePreview.text = ""
            self.requestRender()
            return
        }

        self.queuePreview.text = self.queuePreviewLine()
        if self.queueContainer.children.isEmpty {
            self.queueContainer.addChild(self.queuePreview)
        }
        self.requestRender()
    }

    private func queuePreviewLine() -> String {
        let joined = self.queuedPrompts.joined(separator: "   ·   ")
        var summary = "Queued (\(self.queuedPrompts.count)): \(joined)"
        let limit = 96
        if summary.count > limit {
            let index = summary.index(summary.startIndex, offsetBy: max(0, limit - 1))
            summary = String(summary[..<index]) + "…"
        }
        return summary
    }

    private func processNextQueuedPromptIfNeeded() {
        guard !self.queuedPrompts.isEmpty else { return }
        let next = self.queuedPrompts.removeFirst()
        self.updateQueuePreview()
        self.dispatchPrompt(next)
    }

    func drainQueuedPrompts() -> [String] {
        let queued = self.queuedPrompts
        self.queuedPrompts.removeAll()
        self.updateQueuePreview()
        return queued
    }

    private func dispatchPrompt(_ text: String) {
        self.appendUserMessage(text)
        self.promptContinuation?.yield(text)
    }

    private func appendUserMessage(_ text: String) {
        let message = MarkdownComponent(text: "**You:** \(text)", padding: .init(horizontal: 1, vertical: 0))
        self.messages.addChild(message)
        self.requestRender()
    }

    private func summaryLine(for result: AgentExecutionResult) -> String {
        let duration = String(format: "%.1fs", result.metadata.executionTime)
        let tools = result.metadata.toolCallCount == 1 ? "1 tool" : "\(result.metadata.toolCallCount) tools"
        let sessionFragment = self.sessionId.map { String($0.prefix(8)) } ?? "new session"
        return "✓ Session \(sessionFragment) • \(duration) • \(tools)"
    }

    private static func sessionDescription(for sessionId: String?, queueMode: QueueMode) -> String {
        let base = sessionId.map { "Session: \($0)" } ?? "Session: new (will be created on first run)"
        let mode = queueMode == .all ? "queue: all" : "queue: one-at-a-time"
        return "\(base) • \(mode)"
    }
}

// MARK: - Event delegate

@MainActor
final class AgentChatEventDelegate: AgentEventDelegate {
    private weak var ui: AgentChatUI?
    private var lastToolArguments: [String: [String: Any]] = [:]

    init(ui: AgentChatUI) {
        self.ui = ui
    }

    func agentDidEmitEvent(_ event: AgentEvent) {
        guard let ui else { return }
        switch event {
        case .started:
            break
        case let .assistantMessage(content):
            ui.appendAssistant(content)
        case let .thinkingMessage(content):
            ui.updateThinking(content)
        case let .toolCallStarted(name, arguments):
            let args = self.parseArguments(arguments)
            self.lastToolArguments[name] = args
            let formatter = self.toolFormatter(for: name)
            let toolType = ToolType(rawValue: name)
            let summary = formatter?.formatStarting(arguments: args) ??
                name.replacingOccurrences(of: "_", with: " ")
            ui.showToolStart(
                name: name,
                summary: summary,
                icon: toolType?.icon,
                displayName: toolType?.displayName
            )
        case let .toolCallCompleted(name, result):
            let summary = self.toolResultSummary(name: name, result: result)
            let success = self.successFlag(from: result)
            let toolType = ToolType(rawValue: name)
            ui.showToolCompletion(
                name: name,
                success: success,
                summary: summary,
                icon: toolType?.icon,
                displayName: toolType?.displayName
            )
        case let .toolCallUpdated(name, arguments):
            let args = self.parseArguments(arguments)
            if let previous = self.lastToolArguments[name], self.dictionariesEqual(previous, args) {
                break // skip no-op updates
            }
            let formatter = self.toolFormatter(for: name)
            let toolType = ToolType(rawValue: name)
            let summary = self.diffSummary(for: name, newArgs: args)
                ?? formatter?.formatStarting(arguments: args)
                ?? name.replacingOccurrences(of: "_", with: " ")
            ui.showToolUpdate(
                name: name,
                summary: summary,
                icon: toolType?.icon,
                displayName: toolType?.displayName
            )
            self.lastToolArguments[name] = args
        case let .error(message):
            ui.showError(message)
        case .completed:
            ui.finishStreaming()
        case .queueDrained:
            break
        }
    }

    private func toolFormatter(for name: String) -> (any ToolFormatter)? {
        if let type = ToolType(rawValue: name) {
            return ToolFormatterRegistry.shared.formatter(for: type)
        }
        return nil
    }

    private func parseArguments(_ jsonString: String) -> [String: Any] {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    private func parseResult(_ jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    private func toolResultSummary(name: String, result: String) -> String? {
        guard let json = self.parseResult(result) else { return nil }
        if let summary = ToolEventSummary.from(resultJSON: json)?.shortDescription(toolName: name) {
            return summary
        }
        let formatter = self.toolFormatter(for: name)
        return formatter?.formatResultSummary(result: json)
    }

    private func successFlag(from result: String) -> Bool {
        guard let json = self.parseResult(result) else { return true }
        return (json["success"] as? Bool) ?? true
    }

    /// Minimal diff between previous and new args for the same tool name.
    private func diffSummary(for toolName: String, newArgs: [String: Any]) -> String? {
        guard let previous = self.lastToolArguments[toolName] else { return nil }

        var changes: [String] = []
        for (key, newValue) in newArgs {
            guard let prevValue = previous[key] else {
                changes.append("+\(key)")
                continue
            }
            if !self.valuesEqual(prevValue, newValue) {
                let rendered = self.renderValue(newValue)
                changes.append("\(key): \(rendered)")
            }
            if changes.count >= 3 { break }
        }

        if changes.isEmpty { return nil }
        return changes.joined(separator: ", ")
    }

    private func valuesEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        switch (lhs, rhs) {
        case let (l as String, r as String): return l == r
        case let (l as Int, r as Int): return l == r
        case let (l as Double, r as Double): return l == r
        case let (l as Bool, r as Bool): return l == r
        default: return false
        }
    }

    private func dictionariesEqual(_ lhs: [String: Any], _ rhs: [String: Any]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (key, lval) in lhs {
            guard let rval = rhs[key], self.valuesEqual(lval, rval) else { return false }
        }
        return true
    }

    private func renderValue(_ value: Any) -> String {
        switch value {
        case let str as String:
            let max = 32
            if str.count > max {
                let idx = str.index(str.startIndex, offsetBy: max)
                return String(str[..<idx]) + "…"
            }
            return str
        case let num as Int: return String(num)
        case let num as Double: return String(format: "%.3f", num)
        case let bool as Bool: return bool ? "true" : "false"
        default: return "…"
        }
    }
}
