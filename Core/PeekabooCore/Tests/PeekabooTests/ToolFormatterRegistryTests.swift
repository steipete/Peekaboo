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

    @Test
    func `formats pointer movement tool summaries`() {
        let registry = ToolFormatterRegistry()

        #expect(
            registry.formatter(for: .drag).formatResultSummary(result: [
                "from": ["description": "element A"],
                "to": ["x": 300.0, "y": 400.0],
                "profile": "human",
                "distance": 123.4,
                "duration": 500.0,
                "steps": 20.0,
            ]) ==
                "→ Dragged from element A to (300, 400) [human profile, 123.4px, 500ms, 20 steps]")

        #expect(
            registry.formatter(for: .swipe).formatResultSummary(result: [
                "direction": "left",
                "from": ["x": 400.0, "y": 200.0],
                "to": ["x": 200.0, "y": 200.0],
                "profile": "linear",
                "distance": 200.0,
                "duration": 500.0,
                "steps": 10.0,
            ]) ==
                "→ Swiped left from (400, 200) to (200, 200) [linear profile, 200.0px, 500ms, 10 steps]")

        #expect(
            registry.formatter(for: .move).formatResultSummary(result: [
                "target_description": "center of screen",
                "smooth": false,
            ]) ==
                "→ Moved cursor to center of screen [instant]")
    }
}
