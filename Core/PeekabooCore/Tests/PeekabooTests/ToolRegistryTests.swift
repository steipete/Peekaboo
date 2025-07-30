import Testing
import Foundation
@testable import PeekabooCore

@Suite("ToolRegistry Tests")
struct ToolRegistryTests {
    
    // MARK: - Tool Retrieval Tests
    
    @Test("Registry contains expected tools")
    func registryContainsExpectedTools() {
        let allTools = ToolRegistry.allTools
        
        // Verify registry is not empty
        #expect(!allTools.isEmpty)
        
        // Check for essential tools
        let toolNames = allTools.map { $0.name }
        #expect(toolNames.contains("see"))
        #expect(toolNames.contains("screenshot"))
        #expect(toolNames.contains("click"))
        #expect(toolNames.contains("type"))
        #expect(toolNames.contains("press"))
        #expect(toolNames.contains("scroll"))
        #expect(toolNames.contains("hotkey"))
        #expect(toolNames.contains("list_apps"))
        #expect(toolNames.contains("launch_app"))
        #expect(toolNames.contains("menu_click"))
        #expect(toolNames.contains("shell"))
    }
    
    @Test("Tool retrieval by name")
    func toolRetrievalByName() {
        // Test exact name match
        let clickTool = ToolRegistry.tool(named: "click")
        #expect(clickTool != nil)
        #expect(clickTool?.name == "click")
        
        // Test command name match (if different from tool name)
        let listAppsTool = ToolRegistry.tool(named: "list_apps")
        #expect(listAppsTool != nil)
        
        // Test non-existent tool
        let nonExistentTool = ToolRegistry.tool(named: "non_existent_tool")
        #expect(nonExistentTool == nil)
    }
    
    @Test("Tool retrieval by command name")
    func toolRetrievalByCommandName() {
        // Find a tool with a different command name
        let toolWithCommandName = ToolRegistry.allTools.first { $0.commandName != nil }
        
        if let tool = toolWithCommandName, let cmdName = tool.commandName {
            let retrievedTool = ToolRegistry.tool(named: cmdName)
            #expect(retrievedTool != nil)
            #expect(retrievedTool?.name == tool.name)
        }
    }
    
    // MARK: - Category Tests
    
    @Test("Tools organized by category")
    func toolsOrganizedByCategory() {
        let toolsByCategory = ToolRegistry.toolsByCategory()
        
        // Verify categories are populated
        #expect(!toolsByCategory.isEmpty)
        
        // Check expected categories
        #expect(toolsByCategory[.vision] != nil)
        #expect(toolsByCategory[.automation] != nil)
        #expect(toolsByCategory[.app] != nil)
        #expect(toolsByCategory[.menu] != nil)
        #expect(toolsByCategory[.system] != nil)
        
        // Verify tools are in correct categories
        if let visionTools = toolsByCategory[.vision] {
            let visionToolNames = visionTools.map { $0.name }
            #expect(visionToolNames.contains("see"))
            #expect(visionToolNames.contains("screenshot"))
        }
        
        if let automationTools = toolsByCategory[.automation] {
            let automationToolNames = automationTools.map { $0.name }
            #expect(automationToolNames.contains("click"))
            #expect(automationToolNames.contains("type"))
            #expect(automationToolNames.contains("press"))
        }
    }
    
    @Test("Category icons")
    func categoryIcons() {
        // Verify all categories have icons
        for category in ToolCategory.allCases {
            let icon = category.icon
            #expect(!icon.isEmpty)
        }
        
        // Check specific icons
        #expect(ToolCategory.vision.icon == "👁️")
        #expect(ToolCategory.automation.icon == "🤖")
        #expect(ToolCategory.window.icon == "🪟")
        #expect(ToolCategory.app.icon == "📱")
        #expect(ToolCategory.menu.icon == "📋")
        #expect(ToolCategory.system.icon == "⚙️")
        #expect(ToolCategory.element.icon == "🔍")
    }
    
    // MARK: - Parameter Tests
    
    @Test("Parameter retrieval")
    func parameterRetrieval() {
        // Get a tool with parameters
        guard let clickTool = ToolRegistry.tool(named: "click") else {
            Issue.record("Click tool not found")
            return
        }
        
        // Check for expected parameters
        let queryParam = ToolRegistry.parameter(named: "query", from: clickTool)
        #expect(queryParam != nil)
        #expect(queryParam?.type == .string)
        
        let onParam = ToolRegistry.parameter(named: "on", from: clickTool)
        #expect(onParam != nil)
        
        // Test non-existent parameter
        let nonExistentParam = ToolRegistry.parameter(named: "non_existent", from: clickTool)
        #expect(nonExistentParam == nil)
    }
    
    // MARK: - Tool Definition Tests
    
    @Test("Tool definition properties")
    func toolDefinitionProperties() {
        // Create a test tool definition
        let testTool = UnifiedToolDefinition(
            name: "test_tool",
            commandName: "test-cmd",
            abstract: "Test tool abstract",
            discussion: "Detailed test tool discussion",
            category: .system,
            parameters: [
                ParameterDefinition(
                    name: "input",
                    type: .string,
                    description: "Input parameter",
                    required: true
                ),
                ParameterDefinition(
                    name: "count",
                    type: .integer,
                    description: "Count parameter",
                    defaultValue: "1"
                )
            ],
            examples: ["test-cmd --input hello", "test-cmd --input world --count 5"],
            agentGuidance: "Special guidance for agents"
        )
        
        // Verify properties
        #expect(testTool.name == "test_tool")
        #expect(testTool.commandName == "test-cmd")
        #expect(testTool.abstract == "Test tool abstract")
        #expect(testTool.category == .system)
        #expect(testTool.parameters.count == 2)
        #expect(testTool.examples.count == 2)
        #expect(testTool.agentGuidance == "Special guidance for agents")
        
        // Test command configuration
        let config = testTool.commandConfiguration
        #expect(config.commandName == "test-cmd")
        #expect(config.abstract == "Test tool abstract")
        #expect(config.discussion == "Detailed test tool discussion")
        
        // Test agent description
        let agentDesc = testTool.agentDescription
        #expect(agentDesc.contains("Test tool abstract"))
        #expect(agentDesc.contains("Special guidance for agents"))
    }
    
    @Test("Tool definition without agent guidance")
    func toolDefinitionWithoutAgentGuidance() {
        let tool = UnifiedToolDefinition(
            name: "simple_tool",
            abstract: "Simple tool",
            discussion: "Simple tool discussion",
            category: .system
        )
        
        let agentDesc = tool.agentDescription
        #expect(agentDesc == "Simple tool")
    }
    
    // MARK: - Parameter Definition Tests
    
    @Test("Parameter types")
    func parameterTypes() {
        let params = [
            ParameterDefinition(name: "str", type: .string, description: "String param"),
            ParameterDefinition(name: "int", type: .integer, description: "Integer param"),
            ParameterDefinition(name: "bool", type: .boolean, description: "Boolean param"),
            ParameterDefinition(name: "enum", type: .enumeration, description: "Enum param", options: ["a", "b", "c"]),
            ParameterDefinition(name: "obj", type: .object, description: "Object param"),
            ParameterDefinition(name: "arr", type: .array, description: "Array param")
        ]
        
        #expect(params[0].type == .string)
        #expect(params[1].type == .integer)
        #expect(params[2].type == .boolean)
        #expect(params[3].type == .enumeration)
        #expect(params[4].type == .object)
        #expect(params[5].type == .array)
        
        // Check enum options
        #expect(params[3].options == ["a", "b", "c"])
    }
    
    @Test("CLI options")
    func cliOptions() {
        let param = ParameterDefinition(
            name: "verbose",
            type: .boolean,
            description: "Verbose output",
            cliOptions: CLIOptions(
                argumentType: .flag,
                shortName: "v",
                longName: "verbose"
            )
        )
        
        #expect(param.cliOptions?.argumentType == .flag)
        #expect(param.cliOptions?.shortName == "v")
        #expect(param.cliOptions?.longName == "verbose")
    }
    
    // MARK: - Agent Conversion Tests
    
    @Test("Tool to agent parameters conversion")
    func toolToAgentParameters() {
        let tool = UnifiedToolDefinition(
            name: "test_tool",
            abstract: "Test tool",
            discussion: "Test tool discussion",
            category: .system,
            parameters: [
                ParameterDefinition(
                    name: "input-text",
                    type: .string,
                    description: "Input text",
                    required: true
                ),
                ParameterDefinition(
                    name: "count",
                    type: .integer,
                    description: "Count",
                    defaultValue: "1"
                ),
                ParameterDefinition(
                    name: "enabled",
                    type: .boolean,
                    description: "Enabled flag"
                ),
                ParameterDefinition(
                    name: "mode",
                    type: .enumeration,
                    description: "Mode selection",
                    options: ["fast", "slow", "medium"]
                )
            ]
        )
        
        let agentParams = tool.toAgentParameters()
        
        // Verify parameter conversion (dashes should be converted to underscores)
        #expect(agentParams.type == "object")
        let properties = agentParams.properties
        let required = agentParams.required
        #expect(properties["input_text"] != nil)
        #expect(properties["count"] != nil)
        #expect(properties["enabled"] != nil)
        #expect(properties["mode"] != nil)
        
        // Check required parameters
        #expect(required.contains("input_text"))
        #expect(!required.contains("count")) // Not required
        
        // Verify parameter types
        if let inputTextParam = properties["input_text"] {
            #expect(inputTextParam.type == .string)
        } else {
            Issue.record("input_text parameter not found")
        }
        
        if let countParam = properties["count"] {
            #expect(countParam.type == .integer)
        } else {
            Issue.record("count parameter not found")
        }
        
        if let enabledParam = properties["enabled"] {
            #expect(enabledParam.type == .boolean)
        } else {
            Issue.record("enabled parameter not found")
        }
        
        if let modeParam = properties["mode"] {
            #expect(modeParam.type == .string) // Enumerations are string type with enumValues
            #expect(modeParam.enumValues == ["fast", "slow", "medium"])
        } else {
            Issue.record("mode parameter not found")
        }
    }
    
    // MARK: - Registry Integrity Tests
    
    @Test("All tools have valid categories")
    func allToolsHaveValidCategories() {
        let allTools = ToolRegistry.allTools
        let validCategories = Set(ToolCategory.allCases)
        
        for tool in allTools {
            #expect(validCategories.contains(tool.category))
        }
    }
    
    @Test("No duplicate tool names")
    func noDuplicateToolNames() {
        let allTools = ToolRegistry.allTools
        let toolNames = allTools.map { $0.name }
        let uniqueToolNames = Set(toolNames)
        
        #expect(toolNames.count == uniqueToolNames.count, "Found duplicate tool names")
    }
    
    @Test("All tools have abstracts and discussions")
    func allToolsHaveDescriptions() {
        let allTools = ToolRegistry.allTools
        
        for tool in allTools {
            #expect(!tool.abstract.isEmpty, "Tool \(tool.name) has empty abstract")
            #expect(!tool.discussion.isEmpty, "Tool \(tool.name) has empty discussion")
        }
    }
}