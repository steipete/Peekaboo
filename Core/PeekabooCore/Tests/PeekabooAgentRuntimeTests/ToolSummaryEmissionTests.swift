import Foundation
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
        guard let description = summary.shortDescription(toolName: tool.name) else {
            Issue.record("Shell summary missing short description")
            return
        }
        #expect(description.hasPrefix("Run `echo summary-test`"))
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
          let json = convertToJSONObject(summaryValue) as? [String: Any]
    else {
        return nil
    }
    return ToolEventSummary(json: json)
}

private func convertToJSONObject(_ value: Value) -> Any? {
    switch value {
    case .null:
        return NSNull()
    case let .string(string):
        return string
    case let .int(int):
        return int
    case let .double(double):
        return double
    case let .bool(bool):
        return bool
    case let .array(array):
        return array.compactMap { convertToJSONObject($0) }
    case let .object(dict):
        return dict.reduce(into: [String: Any]()) { result, entry in
            if let converted = convertToJSONObject(entry.value) {
                result[entry.key] = converted
            }
        }
    case let .data(mimeType, data):
        return [
            "type": "data",
            "mimeType": mimeType ?? "application/octet-stream",
            "base64": data.base64EncodedString(),
        ]
    }
}
