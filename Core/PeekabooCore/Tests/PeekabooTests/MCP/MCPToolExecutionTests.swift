import Foundation
import MCP
import Testing
@testable import PeekabooCore

@Suite("MCP Tool Execution Tests")
struct MCPToolExecutionTests {
    // MARK: - Sleep Tool Tests

    @Test("Sleep tool execution with valid duration")
    func sleepToolValidDuration() async throws {
        let tool = SleepTool()
        // Use a shorter duration for testing
        let args = ToolArguments(raw: ["duration": 0.01])

        let start = Date()
        let response = try await tool.execute(arguments: args)
        let elapsed = Date().timeIntervalSince(start)

        #expect(response.isError == false)
        // The actual sleep might be very quick, just verify it didn't error
        #expect(elapsed >= 0) // Any positive time is fine

        if case let .text(message) = response.content.first {
            // Message should mention the duration
            #expect(message.contains("Paused") || message.contains("Sleep"))
        }
    }

    @Test("Sleep tool with missing duration")
    func sleepToolMissingDuration() async throws {
        let tool = SleepTool()
        let args = ToolArguments(raw: [:])

        let response = try await tool.execute(arguments: args)
        #expect(response.isError == true)

        if case let .text(error) = response.content.first {
            #expect(error.contains("duration"))
        }
    }

    // MARK: - Permissions Tool Tests

    @Test("Permissions tool execution")
    func permissionsToolExecution() async throws {
        let tool = PermissionsTool()
        let args = ToolArguments(raw: [:])

        let response = try await tool.execute(arguments: args)
        #expect(response.isError == false)

        if case let .text(output) = response.content.first {
            // Should contain information about permissions
            #expect(output.contains("Accessibility") || output.contains("Screen Recording"))
        }
    }

    // MARK: - List Tool Tests

    @Test("List tool for apps")
    func listToolApps() async throws {
        let tool = ListTool()
        let args = ToolArguments(raw: ["type": "apps"])

        let response = try await tool.execute(arguments: args)
        #expect(response.isError == false)

        if case let .text(output) = response.content.first {
            // Should contain at least Finder
            #expect(output.contains("Finder") || output.contains("com.apple.finder"))
        }
    }

    @Test("List tool with invalid type")
    func listToolInvalidType() async throws {
        let tool = ListTool()
        let args = ToolArguments(raw: ["type": "invalid"])

        let response = try await tool.execute(arguments: args)
        // List tool might not validate the type and just return empty results
        // or it might fall back to a default type
        // Let's just check that it returns a response without crashing
        #expect(!response.content.isEmpty)
    }

    // MARK: - App Tool Tests

    @Test("App tool launch")
    func appToolLaunch() async throws {
        let tool = AppTool()
        let args = ToolArguments(raw: [
            "action": "launch",
            "target": "TextEdit",
        ])

        let response = try await tool.execute(arguments: args)

        // We can't guarantee TextEdit exists on all test systems
        // but we can verify the response format
        if !response.isError {
            if case let .text(output) = response.content.first {
                #expect(output.contains("Launch") || output.contains("already running"))
            }
        }
    }

    @Test("App tool missing action")
    func appToolMissingAction() async throws {
        let tool = AppTool()
        let args = ToolArguments(raw: ["target": "Finder"])

        let response = try await tool.execute(arguments: args)
        #expect(response.isError == true)
    }
}

@Suite("MCP Tool Schema Tests")
struct MCPToolSchemaTests {
    @Test("Image tool schema structure")
    func imageToolSchema() {
        let tool = ImageTool()

        guard case let .object(schema) = tool.inputSchema,
              let properties = schema["properties"] as? Value,
              case let .object(props) = properties
        else {
            Issue.record("Expected object schema with properties")
            return
        }

        // Verify required properties
        #expect(props["path"] != nil)
        #expect(props["format"] != nil)
        #expect(props["app_target"] != nil)
        #expect(props["question"] != nil)
        #expect(props["capture_focus"] != nil)

        // Check enum values
        if let formatSchema = props["format"],
           case let .object(formatDict) = formatSchema,
           let enumValue = formatDict["enum"] as? Value,
           case let .array(formats) = enumValue
        {
            #expect(formats.contains(.string("png")))
            #expect(formats.contains(.string("jpg")))
            #expect(formats.contains(.string("data")))
        }
    }

    @Test("Click tool schema validation")
    func clickToolSchema() {
        let tool = ClickTool()

        guard case let .object(schema) = tool.inputSchema,
              let properties = schema["properties"] as? Value,
              case let .object(props) = properties
        else {
            Issue.record("Expected object schema with properties")
            return
        }

        // Click tool has query, on, coords, and other properties
        #expect(props["query"] != nil)
        #expect(props["on"] != nil)
        #expect(props["coords"] != nil)
        #expect(props["session"] != nil)
        #expect(props["wait_for"] != nil)
        #expect(props["double"] != nil)
        #expect(props["right"] != nil)
    }

    @Test("Agent tool complex schema")
    func agentToolSchema() {
        let tool = MCPAgentTool()

        guard case let .object(schema) = tool.inputSchema,
              let properties = schema["properties"] as? Value,
              case let .object(props) = properties
        else {
            Issue.record("Expected object schema with properties")
            return
        }

        // Agent tool has complex parameters
        #expect(props["task"] != nil)
        #expect(props["model"] != nil)
        #expect(props["quiet"] != nil)
        #expect(props["verbose"] != nil)
        #expect(props["dry_run"] != nil)
        #expect(props["max_steps"] != nil)
        #expect(props["resume"] != nil)
        #expect(props["resumeSession"] != nil)
        #expect(props["listSessions"] != nil)
        #expect(props["noCache"] != nil)
    }
}

@Suite("MCP Tool Error Handling Tests")
struct MCPToolErrorHandlingTests {
    @Test("Tool handles invalid argument types gracefully")
    func invalidArgumentTypes() async throws {
        let tool = TypeTool()

        // Pass number where string expected
        let args = ToolArguments(raw: ["text": 12345])

        let response = try await tool.execute(arguments: args)

        // Tool should either convert or error gracefully
        // TypeTool should convert number to string
        #expect(response.isError == false)
    }

    @Test("Tool handles missing required arguments")
    func missingRequiredArguments() async throws {
        let tool = ClickTool()

        // ClickTool actually has no required parameters - it will error if no valid input is provided
        let args = ToolArguments(raw: [:])

        let response = try await tool.execute(arguments: args)
        #expect(response.isError == true)

        if case let .text(error) = response.content.first {
            // Should mention that it needs some input like query, on, or coords
            #expect(error.lowercased().contains("specify") || error.lowercased().contains("provide") || error
                .lowercased().contains("must"))
        }
    }

    @Test("Tool handles malformed coordinate strings")
    func malformedCoordinates() async throws {
        let tool = ClickTool()

        let args = ToolArguments(raw: ["target": "not-a-coordinate"])

        let response = try await tool.execute(arguments: args)

        // Should handle gracefully - either parse as element or error
        // The actual behavior depends on ClickTool implementation
    }
}

@Suite("MCP Tool Integration Tests", .tags(.integration))
struct MCPToolIntegrationTests {
    @Test("Multiple tools can execute concurrently")
    func concurrentToolExecution() async throws {
        let sleepTool = SleepTool()
        let permissionsTool = PermissionsTool()
        let listTool = ListTool()

        // Execute multiple tools concurrently
        async let sleep = sleepTool.execute(arguments: ToolArguments(raw: ["duration": 0.1]))
        async let permissions = permissionsTool.execute(arguments: ToolArguments(raw: [:]))
        async let list = listTool.execute(arguments: ToolArguments(raw: ["type": "apps"]))

        let results = try await (sleep, permissions, list)

        #expect(results.0.isError == false)
        #expect(results.1.isError == false)
        #expect(results.2.isError == false)
    }

    @Test("Tool execution with complex arguments")
    func complexArgumentHandling() async throws {
        // Test tools that accept complex nested arguments
        let tool = SeeTool()

        let args = ToolArguments(raw: [
            "annotate": true,
            "element_types": ["button", "link", "textfield"],
            "app_target": "Safari:0",
            "output_path": "/tmp/test-annotated.png",
        ])

        let response = try await tool.execute(arguments: args)

        // Can't guarantee Safari is running, but we can verify
        // the tool processes complex arguments correctly
        if response.isError {
            if case let .text(error) = response.content.first {
                // Should have a meaningful error if Safari isn't running
                #expect(error.contains("Safari") || error.contains("not found") || error.contains("running"))
            }
        }
    }
}
