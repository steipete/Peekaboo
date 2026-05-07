import Foundation
import MCP
import PeekabooAutomation
import TachikomaMCP

@MainActor
extension AppToolActions {
    func handleList(request: AppToolRequest) async throws -> ToolResponse {
        let appsOutput = try await self.service.listApplications()
        let apps = appsOutput.data.applications
        let executionTime = self.executionTime(since: request.startTime)

        let summary = apps
            .sorted { $0.isActive && !$1.isActive }
            .map { app in
                let prefix = app.isActive ? AgentDisplayTokens.Status.success : AgentDisplayTokens.Status.info
                return "\(prefix) \(app.name) (PID: \(app.processIdentifier))"
            }
            .joined(separator: "\n")
        let countLine = "\(AgentDisplayTokens.Status.info) Found \(apps.count) running applications "
            + "in \(self.executionTimeString(from: executionTime))"

        let baseMeta: [String: Value] = [
            "apps": .array(
                apps.map { app in
                    .object([
                        "name": .string(app.name),
                        "bundle_id": app.bundleIdentifier != nil ? .string(app.bundleIdentifier!) : .null,
                        "process_id": .double(Double(app.processIdentifier)),
                        "is_active": .bool(app.isActive),
                        "is_hidden": .bool(app.isHidden),
                    ])
                }),
            "execution_time": .double(executionTime),
        ]
        let summaryMeta = self.makeSummary(for: nil, action: "List Applications", notes: "Found \(apps.count) apps")
        return ToolResponse(
            content: [
                .text(text: summary, annotations: nil, _meta: nil),
                .text(text: countLine, annotations: nil, _meta: nil),
            ],
            meta: ToolEventSummary.merge(summary: summaryMeta, into: .object(baseMeta)))
    }
}
