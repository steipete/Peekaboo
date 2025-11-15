import MCP
import PeekabooAgentRuntime
import PeekabooAutomation
import TachikomaMCP
import Testing

@Suite("Tool summary emission")
struct ToolSummaryEmissionTests {
    @Test("Shell tool attaches command metadata")
    func shellToolEmitsSummary() async throws {
        let tool = ShellTool()
        let response = try await tool.execute(arguments: ToolArguments(raw: ["command": "echo summary-test"]))

        guard let summary = extractSummary(from: response.meta) else {
            Issue.record("ShellTool response missing summary metadata")
            return
        }

        #expect(summary.command == "echo summary-test")
        #expect(summary.shortDescription(toolName: tool.name) == "Run `echo summary-test`")
    }

    @Test("Sleep tool stores wait duration")
    func sleepToolEmitsSummary() async throws {
        let tool = SleepTool()
        let response = try await tool.execute(arguments: ToolArguments(raw: ["duration": 5]))

        guard let summary = extractSummary(from: response.meta) else {
            Issue.record("SleepTool response missing summary metadata")
            return
        }

        #expect(summary.actionDescription == "Sleep")
        #expect((summary.waitDurationMs ?? 0) >= 0)
    }
}

private func extractSummary(from meta: Value?) -> ToolEventSummary? {
    guard case let .object(metaDict) = meta,
          let summaryValue = metaDict["summary"],
          let json = summaryValue.toJSON() as? [String: Any]
    else {
        return nil
    }
    return ToolEventSummary(json: json)
}
