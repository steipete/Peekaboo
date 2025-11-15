import PeekabooAgentRuntime
import PeekabooCore
import Testing

@Suite("Tool event summary formatting")
struct ToolEventSummaryTests {
    @Test("Shell commands render with working directory")
    func shellSummaryUsesWorkingDirectory() {
        let summary = ToolEventSummary(
            command: "ls -la",
            workingDirectory: "/tmp")

        #expect(summary.shortDescription(toolName: "shell") == "Run `ls -la` in /tmp")
    }

    @Test("Click actions include target app and role")
    func clickSummaryShowsElement() {
        let summary = ToolEventSummary(
            targetApp: "Google Chrome",
            elementRole: "Button",
            elementLabel: "Sign In with Email")

        #expect(summary.shortDescription(toolName: "click") == "Google Chrome · Sign In with Email (Button)")
    }

    @Test("Sleep summaries use wait duration and reason")
    func sleepSummaryIncludesDuration() {
        let summary = ToolEventSummary(
            waitDurationMs: 2100,
            waitReason: "waiting for UI state")

        #expect(summary.shortDescription(toolName: "sleep") == "Wait 2.1s (waiting for UI state)")
    }

    @Test("Screen captures include app and window")
    func seeSummaryDescribesCaptureContext() {
        let summary = ToolEventSummary(
            captureApp: "Google Chrome",
            captureWindow: "Grindr – Dashboard")

        #expect(summary.shortDescription(toolName: "see") == "Captured Google Chrome · Grindr – Dashboard")
    }
}
