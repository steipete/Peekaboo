import Foundation
import os
import Testing
@testable import Peekaboo

// Mock tool executor for testing
final class MockToolExecutor: ToolExecutor {
    private let _executedTools = OSAllocatedUnfairLock(initialState: [(name: String, arguments: String)]())
    private let _toolResults = OSAllocatedUnfairLock(initialState: [String: String]())

    var executedTools: [(name: String, arguments: String)] {
        self._executedTools.withLock { $0 }
    }

    var toolResults: [String: String] {
        get { self._toolResults.withLock { $0 } }
        set { self._toolResults.withLock { $0 = newValue } }
    }

    func executeTool(name: String, arguments: String) async -> String {
        self._executedTools.withLock { $0.append((name: name, arguments: arguments)) }
        return self._toolResults.withLock { $0[name] } ?? "Mock result for \(name)"
    }

    func availableTools() -> [Tool] {
        [
            Tool(
                function: ToolFunction(
                    name: "test_tool",
                    description: "A test tool",
                    parameters: FunctionParameters(
                        properties: ["param": Property(type: "string", description: "A parameter")],
                        required: ["param"]))),
        ]
    }

    func systemPrompt() -> String {
        "Test system prompt"
    }
}

@Suite("OpenAIAgent Tests", .tags(.ai, .unit))
struct OpenAIAgentTests {
    @Test("Agent initialization")
    func agentInit() async {
        let executor = MockToolExecutor()
        _ = OpenAIAgent(
            apiKey: "test-key",
            model: "gpt-4o",
            toolExecutor: executor)

        // Agent should be created successfully
        // The agent is non-optional, so it's always created
    }

    @Test("Dry run mode skips API calls")
    func dryRunMode() async throws {
        let executor = MockToolExecutor()
        let agent = OpenAIAgent(
            apiKey: "test-key",
            model: "gpt-4o",
            toolExecutor: executor)

        let result = try await agent.executeTask("Test task", dryRun: true)

        #expect(result.success == true)
        #expect(result.output.contains("DRY RUN"))
        #expect(executor.executedTools.isEmpty) // No tools should be executed in dry run
    }

    @Test("Tool executor integration")
    func toolExecutorIntegration() async {
        let executor = MockToolExecutor()
        executor.toolResults["test_tool"] = "Custom test result"

        _ = OpenAIAgent(
            apiKey: "test-key",
            model: "gpt-4o",
            toolExecutor: executor)

        // Get available tools
        let tools = executor.availableTools()
        #expect(tools.count == 1)
        #expect(tools[0].function.name == "test_tool")

        // Execute tool
        let result = await executor.executeTool(
            name: "test_tool",
            arguments: "{\"param\": \"value\"}")
        #expect(result == "Custom test result")
        #expect(executor.executedTools.count == 1)
    }
}

@Suite("PeekabooToolExecutor Tests", .tags(.ai, .integration))
struct PeekabooToolExecutorTests {
    let executor = PeekabooToolExecutor()

    @Test("All expected tools are available")
    func testAvailableTools() {
        let tools = self.executor.availableTools()
        let toolNames = Set(tools.map(\.function.name))

        let expectedTools: Set<String> = [
            "screenshot",
            "click",
            "type_text",
            "key",
            "scroll",
            "drag",
            "app",
            "window",
            "list_windows",
            "list_apps",
            "wait",
            "see",
            "analyze",
            "speak",
            "ask",
        ]

        #expect(toolNames == expectedTools)
    }

    @Test("Tool definitions are valid")
    func toolDefinitions() {
        let tools = self.executor.availableTools()

        for tool in tools {
            // Each tool should have required fields
            #expect(!tool.function.name.isEmpty)
            #expect(!tool.function.description.isEmpty)
            #expect(tool.function.parameters.type == "object")
            #expect(!tool.function.parameters.properties.isEmpty)
        }
    }

    @Test("System prompt contains necessary information")
    func testSystemPrompt() {
        let prompt = self.executor.systemPrompt()

        #expect(!prompt.isEmpty)
        #expect(prompt.contains("macOS"))
        #expect(prompt.contains("automation"))
    }

    @Test("Tool execution format")
    func toolExecutionFormat() async {
        // Test that tool executor properly formats commands
        let testCases: [(String, String, String)] = [
            ("screenshot", "{\"application\": \"Safari\"}", "image --app"),
            ("click", "{\"x\": 100, \"y\": 200}", "click"),
            ("list_apps", "{}", "list apps"),
            ("list_windows", "{\"application\": \"Finder\"}", "list windows"),
        ]

        for (toolName, _, _) in testCases {
            // Note: We can't actually execute without the CLI, but we can verify
            // the executor handles the tool names correctly
            let tools = self.executor.availableTools()
            let tool = tools.first { $0.function.name == toolName }
            #expect(tool != nil)
        }
    }
}
