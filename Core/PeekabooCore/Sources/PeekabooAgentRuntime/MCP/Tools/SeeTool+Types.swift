import PeekabooAutomationKit
import TachikomaMCP

struct SeeRequest {
    let appTarget: String?
    let path: String?
    let snapshotId: String?
    let annotate: Bool

    init(arguments: ToolArguments) {
        self.appTarget = arguments.getString("app_target")
        self.path = arguments.getString("path")
        self.snapshotId = arguments.getString("snapshot")
        self.annotate = arguments.getBool("annotate") ?? false
    }
}

struct ScreenshotOutput {
    let screenshotPath: String
    let annotatedPath: String?
    let annotate: Bool
}

@MainActor
struct SeeSummaryBuilder {
    let snapshot: UISnapshot
    let elements: [UIElement]
    let screenshotPath: String

    func build() async -> String {
        var lines = self.headerLines()
        await lines.append(contentsOf: self.metadataLines())
        lines.append("Screenshot: \(self.screenshotPath)")
        lines.append("Elements found: \(self.elements.count)")
        lines.append("")
        lines.append(contentsOf: self.elementSection())
        lines.append("")
        lines.append("Use element IDs (B1, T1, etc.) with click, type, and other interaction commands.")
        return lines.joined(separator: "\n")
    }

    private func headerLines() -> [String] {
        [
            "📸 UI State Captured",
            "Snapshot ID: \(self.snapshot.id)",
        ]
    }

    private func metadataLines() async -> [String] {
        guard let metadata = await self.snapshot.screenshotMetadata else { return [] }
        var lines: [String] = []
        if let appInfo = metadata.applicationInfo {
            lines.append("Application: \(appInfo.name)")
        }
        if let windowInfo = metadata.windowInfo {
            lines.append("Window: \(windowInfo.title)")
        }
        return lines
    }

    private func elementSection() -> [String] {
        let elementsByRole = Dictionary(grouping: self.elements, by: { $0.role })
        var lines = ["UI Elements:"]
        for (role, roleElements) in elementsByRole.sorted(by: { $0.key < $1.key }) {
            lines.append("")
            lines.append(self.roleHeader(role: role, elements: roleElements))
            lines.append(contentsOf: roleElements.map(self.describeElement))
        }
        return lines
    }

    private func roleHeader(role: String, elements: [UIElement]) -> String {
        let actionableCount = elements.count(where: { $0.isActionable })
        return "\(role) (\(elements.count) found, \(actionableCount) actionable):"
    }

    private func describeElement(_ element: UIElement) -> String {
        SeeElementTextFormatter.describe(element)
    }
}
