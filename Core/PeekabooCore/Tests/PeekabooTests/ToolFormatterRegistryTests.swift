import Testing
@testable import PeekabooAgentRuntime

@Suite("Tool formatter registry")
struct ToolFormatterRegistryTests {
    @Test
    func `routes dock tools to dock formatter`() {
        let registry = ToolFormatterRegistry()

        #expect(registry.formatter(for: .listDock).formatResultSummary(result: ["count": 3]) == "→ 3 items")
        #expect(
            registry.formatter(for: .dockLaunch).formatResultSummary(result: ["app": "Preview"]) ==
                "→ launched Preview from dock")
    }

    @Test
    func `routes system tools to system formatter`() {
        let registry = ToolFormatterRegistry()

        #expect(
            registry.formatter(for: .copyToClipboard).formatResultSummary(result: ["text": "hello"]) ==
                "→ Copied to clipboard \"hello\"")
        #expect(registry.formatter(for: .shell).formatResultSummary(result: ["exitCode": 0, "command": "pwd"]) ==
            "→ Success \"pwd\"")
    }
}
