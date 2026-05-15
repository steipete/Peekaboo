import PeekabooAutomationKit
import TachikomaMCP

struct InspectUIRequest {
    let appTarget: String?
    let snapshotId: String?

    init(arguments: ToolArguments) {
        self.appTarget = arguments.getString("app_target")
        self.snapshotId = arguments.getString("snapshot")
    }
}

@MainActor
struct InspectUISummaryBuilder {
    let snapshot: UISnapshot
    let result: ElementDetectionResult
    let target: ObservationTargetArgument

    func build() async -> String {
        var lines = self.headerLines()
        await lines.append(contentsOf: self.metadataLines())
        lines.append("Elements found: \(self.result.elements.all.count)")
        if self.result.metadata.method.contains("cached") {
            lines.append("(Result from cached accessibility tree)")
        }
        lines.append("")
        lines.append(contentsOf: self.elementSection())
        lines.append("")
        lines.append("Use element IDs with click, type, and other interaction commands.")
        lines.append("If text looks incomplete, use `see` for a screenshot-based observation.")
        return lines.joined(separator: "\n")
    }

    private func headerLines() -> [String] {
        [
            "🔍 UI Text Inspection",
            "Snapshot ID: \(self.snapshot.id)",
        ]
    }

    private func metadataLines() async -> [String] {
        var lines: [String] = []
        if let appName = self.result.metadata.windowContext?.applicationName {
            lines.append("Application: \(appName)")
        }
        if let windowTitle = self.result.metadata.windowContext?.windowTitle {
            lines.append("Window: \(windowTitle)")
        }
        return lines
    }

    private func elementSection() -> [String] {
        let elements = self.result.elements.all
        guard !elements.isEmpty else {
            return ["No accessible UI elements found. Try `see` for screenshot-based detection."]
        }

        let elementsByRole = Dictionary(grouping: elements, by: { $0.type.rawValue })
        var lines = ["UI Elements:"]
        for (role, roleElements) in elementsByRole.sorted(by: { $0.key < $1.key }) {
            lines.append("")
            lines.append(self.roleHeader(role: role, elements: roleElements))
            lines.append(contentsOf: roleElements.map(self.describeElement))
        }
        return lines
    }

    private func roleHeader(role: String, elements: [DetectedElement]) -> String {
        let actionableCount = elements.count(where: { $0.isEnabled })
        return "\(role) (\(elements.count) found, \(actionableCount) actionable):"
    }

    private func describeElement(_ element: DetectedElement) -> String {
        var parts = ["  \(element.id)"]
        if let label = element.label, !label.isEmpty {
            parts.append("\"\(label)\"")
        }
        let sizeText = "size \(Int(element.bounds.width))×\(Int(element.bounds.height))"
        parts.append("at (\(Int(element.bounds.origin.x)), \(Int(element.bounds.origin.y))) \(sizeText)")
        if let value = element.value, !value.isEmpty {
            parts.append("value: \"\(value)\"")
        }
        if let desc = element.attributes["description"], !desc.isEmpty {
            parts.append("desc: \"\(desc)\"")
        }
        if let help = element.attributes["help"], !help.isEmpty {
            parts.append("help: \"\(help)\"")
        }
        if let shortcut = element.attributes["keyboardShortcut"], !shortcut.isEmpty {
            parts.append("shortcut: \(shortcut)")
        }
        if let identifier = element.attributes["identifier"], !identifier.isEmpty {
            parts.append("identifier: \(identifier)")
        }
        if !element.isEnabled {
            parts.append("[not actionable]")
        }
        return parts.joined(separator: " - ")
    }
}
