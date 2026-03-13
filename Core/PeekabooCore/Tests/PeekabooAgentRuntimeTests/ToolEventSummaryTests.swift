import PeekabooAgentRuntime
import PeekabooCore
import Testing

struct ToolEventSummaryTests {
    @Test
    func `Shell commands render with working directory`() {
        let summary = ToolEventSummary(
            command: "ls -la",
            workingDirectory: "/tmp")

        #expect(summary.shortDescription(toolName: "shell") == "Run `ls -la` in /tmp")
    }

    @Test
    func `Click actions include target app and role`() {
        let summary = ToolEventSummary(
            targetApp: "Google Chrome",
            elementRole: "Button",
            elementLabel: "Sign In with Email")

        #expect(summary.shortDescription(toolName: "click") == "Google Chrome · Sign In with Email (Button)")
    }

    @Test
    func `Sleep summaries use wait duration and reason`() {
        let summary = ToolEventSummary(
            waitDurationMs: 2100,
            waitReason: "waiting for UI state")

        #expect(summary.shortDescription(toolName: "sleep") == "Wait 2.1s (waiting for UI state)")
    }

    @Test
    func `Screen captures include app and window`() {
        let summary = ToolEventSummary(
            captureApp: "Google Chrome",
            captureWindow: "Grindr – Dashboard")

        #expect(summary.shortDescription(toolName: "see") == "Captured Google Chrome · Grindr – Dashboard")
    }
}
