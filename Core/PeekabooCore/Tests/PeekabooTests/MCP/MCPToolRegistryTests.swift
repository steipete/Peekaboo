import Foundation
import MCP
import TachikomaMCP
import Testing
@testable import PeekabooCore

@Suite("MCPToolRegistry Tests")
struct MCPToolRegistryTests {
    @Test("Registry initialization")
    func registryInitialization() async {
        let registry = await MCPToolRegistry()
        let tools = await registry.allTools()

        // Registry should start empty
        #expect(tools.isEmpty)
    }

    @Test("Register single tool")
    func registerSingleTool() async {
        let registry = await MCPToolRegistry()
        let mockTool = MockTool(
            name: "test-tool",
            description: "A test tool",
            inputSchema: .object([:]))

        await registry.register(mockTool)

        let tools = await registry.allTools()
        #expect(tools.count == 1)

        let registeredTool = await registry.tool(named: "test-tool")
        #expect(registeredTool != nil)
        #expect(registeredTool?.name == "test-tool")
    }

    @Test("Register multiple tools")
    func registerMultipleTools() async {
        let registry = await MCPToolRegistry()
        let tools = [
            MockTool(name: "tool1", description: "Tool 1", inputSchema: .object([:])),
            MockTool(name: "tool2", description: "Tool 2", inputSchema: .object([:])),
            MockTool(name: "tool3", description: "Tool 3", inputSchema: .object([:])),
        ]

        await registry.register(tools)

        let allTools = await registry.allTools()
        #expect(allTools.count == 3)

        // Verify each tool can be retrieved
        for tool in tools {
            let retrieved = await registry.tool(named: tool.name)
            #expect(retrieved != nil)
            #expect(retrieved?.name == tool.name)
        }
    }

    @Test("Tool overwriting")
    func toolOverwriting() async {
        let registry = await MCPToolRegistry()

        let tool1 = MockTool(
            name: "duplicate",
            description: "Original tool",
            inputSchema: .object([:]))

        let tool2 = MockTool(
            name: "duplicate",
            description: "Replacement tool",
            inputSchema: .object(["newField": .string("test")]))

        await registry.register(tool1)
        await registry.register(tool2)

        let tools = await registry.allTools()
        #expect(tools.count == 1)

        let retrieved = await registry.tool(named: "duplicate")
        #expect(retrieved?.description == "Replacement tool")
    }

    @Test("Tool not found")
    func toolNotFound() async {
        let registry = await MCPToolRegistry()

        let tool = await registry.tool(named: "nonexistent")
        #expect(tool == nil)
    }

    @Test("Tool info conversion")
    func toolInfoConversion() async {
        let registry = await MCPToolRegistry()

        let mockTool = MockTool(
            name: "info-test",
            description: "Tool for testing info conversion",
            inputSchema: SchemaBuilder.object(
                properties: [
                    "param1": SchemaBuilder.string(description: "First parameter"),
                    "param2": SchemaBuilder.number(description: "Second parameter"),
                ],
                required: ["param1"]))

        await registry.register(mockTool)

        let toolInfos = await registry.toolInfos()
        #expect(toolInfos.count == 1)

        let info = toolInfos.first!
        #expect(info.name == "info-test")
        #expect(info.description == "Tool for testing info conversion")

        // Verify schema is properly converted
        guard case let .object(schemaDict) = info.inputSchema else {
            Issue.record("Expected object schema")
            return
        }

        if case let .string(type)? = schemaDict["type"] {
            #expect(type == "object")
        } else {
            Issue.record("Expected schema type string")
        }
        #expect(schemaDict["properties"] != nil)
        #expect(schemaDict["required"] != nil)
    }

    @Test("Registry thread safety")
    func registryThreadSafety() async {
        let registry = await MCPToolRegistry()

        // Concurrently register many tools
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let tool = MockTool(
                        name: "concurrent-\(i)",
                        description: "Concurrent tool \(i)",
                        inputSchema: .object([:]))
                    await registry.register(tool)
                }
            }
        }

        let tools = await registry.allTools()
        #expect(tools.count == 100)

        // Verify all tools were registered correctly
        for i in 0..<100 {
            let tool = await registry.tool(named: "concurrent-\(i)")
            #expect(tool != nil)
        }
    }

    @Test("Empty registry tool infos")
    func emptyRegistryToolInfos() async {
        let registry = await MCPToolRegistry()
        let infos = await registry.toolInfos()

        #expect(infos.isEmpty)
    }
}

@Suite("MCPToolRegistry Integration Tests", .tags(.integration))
struct MCPToolRegistryIntegrationTests {
    @Test("Register all Peekaboo tools")
    func registerAllPeekabooTools() async {
        let registry = await MCPToolRegistry()

        // Register the actual Peekaboo tools
        await registry.register([
            ImageTool(),
            AnalyzeTool(),
            ListTool(),
            PermissionsTool(),
            SleepTool(),
            SeeTool(),
            ClickTool(),
            TypeTool(),
            ScrollTool(),
            HotkeyTool(),
            SwipeTool(),
            DragTool(),
            MoveTool(),
            AppTool(),
            WindowTool(),
            MenuTool(),
            MCPAgentTool(),
            DockTool(),
            DialogTool(),
            SpaceTool(),
        ])

        let tools = await registry.allTools()
        #expect(tools.count == 20)

        // Verify some key tools are present
        let imageToolExists = await registry.tool(named: "image") != nil
        let clickToolExists = await registry.tool(named: "click") != nil
        let agentToolExists = await registry.tool(named: "agent") != nil

        #expect(imageToolExists)
        #expect(clickToolExists)
        #expect(agentToolExists)
    }

    @Test("Tool info schema validation")
    func toolInfoSchemaValidation() async {
        let registry = await MCPToolRegistry()

        // Register a complex tool with full schema
        let complexTool = MockTool(
            name: "complex",
            description: "A complex tool with many parameters",
            inputSchema: SchemaBuilder.object(
                properties: [
                    "requiredString": SchemaBuilder.string(description: "A required string"),
                    "optionalNumber": SchemaBuilder.number(description: "An optional number"),
                    "enumValue": SchemaBuilder.string(
                        description: "Choice value",
                        enum: ["option1", "option2", "option3"],
                        default: "option1"),
                    "flagValue": SchemaBuilder.boolean(description: "A boolean flag"),
                    "nestedObject": SchemaBuilder.object(
                        properties: [
                            "innerField": SchemaBuilder.string(description: "Inner field"),
                        ],
                        required: ["innerField"]),
                ],
                required: ["requiredString"],
                description: "Complex tool schema"))

        await registry.register(complexTool)

        let infos = await registry.toolInfos()
        #expect(infos.count == 1)

        let info = infos.first!

        // Validate the schema structure is preserved
        guard case let .object(schema) = info.inputSchema,
              let properties = schema["properties"],
              case let .object(props) = properties
        else {
            Issue.record("Expected object schema with properties")
            return
        }

        #expect(props.count == 5)
        #expect(props["requiredString"] != nil)
        #expect(props["optionalNumber"] != nil)
        #expect(props["enumValue"] != nil)
        #expect(props["flagValue"] != nil)
        #expect(props["nestedObject"] != nil)

        // Check required array
        if let required = schema["required"],
           case let .array(requiredArray) = required
        {
            #expect(requiredArray.count == 1)
            #expect(requiredArray.contains(.string("requiredString")))
        }
    }
}
