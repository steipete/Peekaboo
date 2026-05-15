import Foundation
import MCP
import os.log
import PeekabooAutomation
import PeekabooAutomationKit
import PeekabooFoundation
import TachikomaMCP

/// MCP tool for inspecting UI text and control state via the accessibility tree without capturing a screenshot.
public struct InspectUITool: MCPTool {
    private let logger = os.Logger(subsystem: "boo.peekaboo.mcp", category: "InspectUITool")
    private let context: MCPToolContext

    public let name = "inspect_ui"

    public var description: String {
        """
        Inspects the accessibility tree of the active UI and returns visible text, labels,
        buttons, text fields, and control state. No screenshot is captured.

        Use this when you only need to read UI text or discover interactive elements and do not
        need a visual screenshot. For visual layout or when AX text is incomplete, use `see`.
        """
    }

    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "app_target": SchemaBuilder.string(
                    description: """
                    Optional. Specifies the inspection target (same as see/image tools).
                    Omit or use an empty string for all screens.
                    Use 'frontmost' for the current foreground application.
                    Use 'AppName' (e.g., 'Safari') for a specific application.
                    Use 'PID:PROCESS_ID' to target a specific process.
                    """),
                "snapshot": SchemaBuilder.string(
                    description: """
                    Optional. Snapshot ID for UI automation tracking. A new snapshot is created when absent.
                    """),
            ],
            required: [])
    }

    public init(context: MCPToolContext = .shared) {
        self.context = context
    }

    @MainActor
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        let request = InspectUIRequest(arguments: arguments)

        do {
            let snapshot = try await self.getOrCreateSnapshot(snapshotId: request.snapshotId)
            let target = try ObservationTargetArgument.parse(request.appTarget)
            let windowContext = self.makeWindowContext(for: target)

            let result = try await self.context.automation.inspectAccessibilityTree(
                windowContext: windowContext)

            await snapshot.setUIElements(self.convertElements(result.elements.all))

            let summaryText = await self.buildSummary(
                snapshot: snapshot,
                result: result,
                target: target)

            let metadata: Value = .object([
                "snapshot_id": .string(snapshot.id),
                "element_count": .double(Double(result.elements.all.count)),
                "actionable_count": .double(Double(result.elements.all.count(where: { $0.isEnabled }))),
                "used_cache": .bool(result.metadata.method.contains("cached")),
            ])

            var summary = ToolEventSummary(
                targetApp: result.metadata.windowContext?.applicationName,
                windowTitle: result.metadata.windowContext?.windowTitle,
                actionDescription: "Inspect UI",
                notes: String(describing: target))
            summary.captureApp = result.metadata.windowContext?.applicationName
            summary.captureWindow = result.metadata.windowContext?.windowTitle

            let mergedMeta = ToolEventSummary.merge(summary: summary, into: metadata)

            return ToolResponse(
                content: [.text(text: summaryText, annotations: nil, _meta: nil)],
                meta: mergedMeta)
        } catch {
            self.logger.error("Inspect UI tool execution failed: \(error.localizedDescription)")
            return ToolResponse.error("Failed to inspect UI: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func getOrCreateSnapshot(snapshotId: String?) async throws -> UISnapshot {
        if let snapshotId {
            if let existingSnapshot = await UISnapshotManager.shared.getSnapshot(id: snapshotId) {
                return existingSnapshot
            }
        }
        return await UISnapshotManager.shared.createSnapshot()
    }

    private func makeWindowContext(for target: ObservationTargetArgument) -> WindowContext {
        WindowContext(
            applicationName: target.focusIdentifier,
            shouldFocusWebContent: true)
    }

    private func convertElements(_ detected: [DetectedElement]) -> [UIElement] {
        detected.map { element in
            UIElement(
                id: element.id,
                elementId: element.id,
                role: element.type.rawValue,
                title: element.label,
                label: element.label,
                value: element.value,
                description: element.attributes["description"],
                help: element.attributes["help"],
                roleDescription: element.attributes["roleDescription"],
                identifier: element.attributes["identifier"],
                frame: element.bounds,
                isActionable: element.isEnabled,
                parentId: nil,
                children: [],
                keyboardShortcut: element.attributes["keyboardShortcut"])
        }
    }

    @MainActor
    private func buildSummary(
        snapshot: UISnapshot,
        result: ElementDetectionResult,
        target: ObservationTargetArgument) async -> String
    {
        await InspectUISummaryBuilder(
            snapshot: snapshot,
            result: result,
            target: target)
            .build()
    }
}
