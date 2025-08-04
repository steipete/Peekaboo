import Testing
import Foundation
import Tachikoma
@testable import PeekabooCore

/// Tests for PeekabooToolBridge functionality
@Suite("Peekaboo Tool Bridge Tests")
struct PeekabooToolBridgeTests {
    
    @Test("Bridge initialization with services and tools")
    func testBridgeInitialization() async throws {
        let services = try PeekabooServices.createForTesting()
        let agentService = try PeekabooAgentService(services: services)
        
        // Get native tools from agent service
        let nativeTools = agentService.createPeekabooTools()
        #expect(!nativeTools.isEmpty, "Should have native tools")
        
        // Create bridge and convert
        let bridge = PeekabooToolBridge(services: services, nativeTools: nativeTools)
        let simpleTools = bridge.createSimpleTools()
        
        #expect(!simpleTools.isEmpty, "Should have converted simple tools")
        #expect(simpleTools.count == nativeTools.count, "Should convert all tools")
        
        // Verify tool names match
        let nativeNames = Set(nativeTools.map { $0.name })
        let simpleNames = Set(simpleTools.map { $0.name })
        #expect(nativeNames == simpleNames, "Tool names should match")
    }
    
    @Test("Parameter conversion from Peekaboo to Tachikoma")
    func testParameterConversion() async throws {
        let services = try PeekabooServices.createForTesting()
        let agentService = try PeekabooAgentService(services: services)
        
        // Get native tools and find shell tool
        let nativeTools = agentService.createPeekabooTools()
        let shellTool = nativeTools.first { $0.name == "shell" }
        #expect(shellTool != nil, "Should have shell tool")
        
        // Create bridge and convert
        let bridge = PeekabooToolBridge(services: services, nativeTools: nativeTools)
        let simpleTools = bridge.createSimpleTools()
        
        // Find converted shell tool
        let convertedShellTool = simpleTools.first { $0.name == "shell" }
        #expect(convertedShellTool != nil, "Should have converted shell tool")
        
        if let convertedTool = convertedShellTool {
            #expect(convertedTool.description.contains("shell"), "Shell tool should have appropriate description")
            #expect(!convertedTool.parameters.properties.isEmpty, "Shell tool should have parameters")
        }
    }
    
    @Test("Tool execution through bridge")
    func testToolExecution() async throws {
        let services = try PeekabooServices.createForTesting()
        let agentService = try PeekabooAgentService(services: services)
        
        // Get tools and create bridge
        let nativeTools = agentService.createPeekabooTools()
        let bridge = PeekabooToolBridge(services: services, nativeTools: nativeTools)
        let simpleTools = bridge.createSimpleTools()
        
        // Find a simple tool we can test (shell tool)
        let shellTool = simpleTools.first { $0.name == "shell" }
        
        guard let tool = shellTool else {
            Issue.record("Shell tool not found in converted tools")
            return
        }
        
        // Create test arguments for shell command
        let testArgs = Tachikoma.ToolArguments([
            "command": .string("echo 'bridge test'")
        ])
        
        // Execute the tool through the bridge
        let result = try await tool.execute(testArgs)
        
        // Verify execution worked (should return some result)
        #expect(result != .null, "Tool execution should return a result")
    }
    
    @Test("Bridge maintains tool execution capability")
    func testBridgeIntegration() async throws {
        let services = try PeekabooServices.createForTesting()
        let agentService = try PeekabooAgentService(services: services)
        
        // Test the bridged simple tools method
        let bridgedTools = agentService.createBridgedSimpleTools()
        
        #expect(!bridgedTools.isEmpty, "Should have bridged tools")
        
        // Verify we have core tools
        let toolNames = bridgedTools.map { $0.name }
        #expect(toolNames.contains("shell"), "Should have shell tool")
        #expect(toolNames.contains("see"), "Should have see tool")
        #expect(toolNames.contains("click"), "Should have click tool")
        
        // Verify no duplicates
        let uniqueNames = Set(toolNames)
        #expect(uniqueNames.count == toolNames.count, "Should have no duplicate tool names")
    }
    
    @Test("Parameter type conversion accuracy")
    func testParameterTypeConversion() async throws {
        let services = try PeekabooServices.createForTesting()
        
        // Create a test tool with various parameter types
        let testTool = Tool<PeekabooServices>(
            name: "test_tool",
            description: "Tool with various parameter types",
            parameters: ToolParameters(
                properties: [
                    "stringParam": ToolParameterProperty(type: .string, description: "String parameter"),
                    "intParam": ToolParameterProperty(type: .integer, description: "Integer parameter"),
                    "boolParam": ToolParameterProperty(type: .boolean, description: "Boolean parameter"),
                    "arrayParam": ToolParameterProperty(type: .array, description: "Array parameter")
                ],
                required: ["stringParam"]
            ),
            execute: { input, services in
                return .string("test result")
            }
        )
        
        // Create bridge and convert just this tool
        let bridge = PeekabooToolBridge(services: services, nativeTools: [testTool])
        let simpleTools = bridge.createSimpleTools()
        
        #expect(simpleTools.count == 1, "Should convert one tool")
        
        let convertedTool = simpleTools[0]
        #expect(convertedTool.name == "test_tool", "Should preserve tool name")
        
        // Check parameters were converted correctly
        let parameters = convertedTool.parameters
        
        // Verify different parameter types are converted correctly
        if let stringParam = parameters.properties["stringParam"] {
            #expect(stringParam.type == .string)
        }
        
        if let intParam = parameters.properties["intParam"] {
            #expect(intParam.type == .integer)
        }
        
        if let boolParam = parameters.properties["boolParam"] {
            #expect(boolParam.type == .boolean)
        }
        
        if let arrayParam = parameters.properties["arrayParam"] {
            #expect(arrayParam.type == .array)
        }
    }
}