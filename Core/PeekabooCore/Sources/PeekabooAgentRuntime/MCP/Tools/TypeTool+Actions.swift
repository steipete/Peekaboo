import Foundation
import PeekabooAutomation
import PeekabooFoundation

extension TypeTool {
    func buildEventSummary(
        request: TypeRequest,
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

    func buildActions(for request: TypeRequest) throws -> [TypeAction] {
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

    func buildSummary(
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
}
