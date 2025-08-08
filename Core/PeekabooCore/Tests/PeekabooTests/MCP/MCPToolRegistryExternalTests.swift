import Testing
import Foundation
import MCP
import TachikomaMCP
@testable import PeekabooCore

/// Tests for MCPToolRegistry external tool functionality
@Suite("MCP Tool Registry External Tests")
@MainActor
struct MCPToolRegistryExternalTests {
    
    @Test("Tool registry initialization")
    func testRegistryInitialization() async {
        let registry = MCPToolRegistry()
        
        let counts = registry.getToolCounts()
        #expect(counts.native == 0)
        #expect(counts.external == 0)
        #expect(counts.total == 0)
    }
    
    @Test("Register native tools")
    func testRegisterNativeTools() async {
        let registry = MCPToolRegistry()
        
        let tool1 = MockMCPTool(name: "tool1", description: "First tool")
        let tool2 = MockMCPTool(name: "tool2", description: "Second tool")
        
        registry.register(tool1)
        registry.register([tool2])
        
        let counts = registry.getToolCounts()
        #expect(counts.native == 2)
        #expect(counts.external == 0)
        #expect(counts.total == 2)
        
        #expect(registry.hasToolNamed("tool1") == true)
        #expect(registry.hasToolNamed("tool2") == true)
        #expect(registry.hasToolNamed("nonexistent") == false)
        
        let retrievedTool = registry.tool(named: "tool1")
        #expect(retrievedTool?.name == "tool1")
    }
    
    @Test("Set client manager")
    func testSetClientManager() async {
        let registry = MCPToolRegistry()
        let clientManager = TachikomaMCPClientManager.shared
        
        registry.setClientManager(clientManager)
        
        // No direct way to test this, but it should not crash
        // The real test is in registerExternalTools
    }
    
    @Test("Register external tools from empty client manager")
    func testRegisterExternalToolsEmpty() async {
        let registry = MCPToolRegistry()
        let clientManager = TachikomaMCPClientManager.shared
        
        await registry.registerExternalTools(from: clientManager)
        
        let counts = registry.getToolCounts()
        #expect(counts.external == 0)
        
        let categorized = await registry.getToolsBySource()
        #expect(categorized.external.isEmpty)
        #expect(categorized.externalCount == 0)
    }
    
    @Test("Get tools by source with mixed tools")
    func testGetToolsBySource() async {
        let registry = MCPToolRegistry()
        
        // Register native tools
        let nativeTool1 = MockMCPTool(name: "native1", description: "Native tool 1")
        let nativeTool2 = MockMCPTool(name: "native2", description: "Native tool 2")
        registry.register([nativeTool1, nativeTool2])
        
        let categorized = await registry.getToolsBySource()
        
        #expect(categorized.native.count == 2)
        #expect(categorized.external.isEmpty)
        #expect(categorized.totalCount == 2)
        #expect(categorized.externalCount == 0)
        
        // Check native tool names
        let nativeNames = categorized.native.map { $0.name }.sorted()
        #expect(nativeNames == ["native1", "native2"])
    }
    
    @Test("Get tool with prefix - native tools")
    func testGetToolWithPrefixNative() async {
        let registry = MCPToolRegistry()
        
        let nativeTool = MockMCPTool(name: "test_tool", description: "Test tool")
        registry.register(nativeTool)
        
        // Should find native tool by exact name
        let foundTool = registry.getToolWithPrefix(name: "test_tool")
        #expect(foundTool?.name == "test_tool")
        
        // Should not find non-existent tool
        let notFound = registry.getToolWithPrefix(name: "nonexistent")
        #expect(notFound == nil)
    }
    
    @Test("Get all tools combined")
    func testGetAllToolsCombined() async {
        let registry = MCPToolRegistry()
        
        let tool1 = MockMCPTool(name: "tool1", description: "Tool 1")
        let tool2 = MockMCPTool(name: "tool2", description: "Tool 2")
        
        registry.register([tool1, tool2])
        
        let allTools = registry.getAllTools()
        #expect(allTools.count == 2)
        
        let toolNames = allTools.map { $0.name }.sorted()
        #expect(toolNames == ["tool1", "tool2"])
        
        // Test native/external separation
        let nativeTools = registry.getNativeTools()
        let externalTools = registry.getExternalTools()
        
        #expect(nativeTools.count == 2)
        #expect(externalTools.count == 0)
    }
    
    @Test("Tool combined lookup")
    func testToolCombinedLookup() async {
        let registry = MCPToolRegistry()
        
        let nativeTool = MockMCPTool(name: "native_tool", description: "Native tool")
        registry.register(nativeTool)
        
        // Test combined lookup for native tool
        let foundNative = registry.toolCombined(named: "native_tool")
        #expect(foundNative?.name == "native_tool")
        
        // Test combined lookup for non-existent tool
        let notFound = registry.toolCombined(named: "nonexistent")
        #expect(notFound == nil)
    }
    
    @Test("Has any tool named")
    func testHasAnyToolNamed() async {
        let registry = MCPToolRegistry()
        
        let nativeTool = MockMCPTool(name: "test_tool", description: "Test tool")
        registry.register(nativeTool)
        
        #expect(registry.hasAnyToolNamed("test_tool") == true)
        #expect(registry.hasAnyToolNamed("nonexistent") == false)
    }
    
    @Test("All tool infos for MCP")
    func testAllToolInfos() async {
        let registry = MCPToolRegistry()
        
        let tool1 = MockMCPTool(name: "tool1", description: "First tool")
        let tool2 = MockMCPTool(name: "tool2", description: "Second tool")
        
        registry.register([tool1, tool2])
        
        let toolInfos = registry.allToolInfos()
        #expect(toolInfos.count == 2)
        
        let infoNames = toolInfos.map { $0.name }.sorted()
        #expect(infoNames == ["tool1", "tool2"])
        
        // Check that descriptions are preserved
        let tool1Info = toolInfos.first { $0.name == "tool1" }
        #expect(tool1Info?.description == "First tool")
    }
    
    @Test("Has external tool")
    func testHasExternalTool() async {
        let registry = MCPToolRegistry()
        
        // With no external tools registered
        #expect(registry.hasExternalTool("any_tool") == false)
        
        // This would require actual external tools to be registered
        // which would need a mock client manager with tools
    }
    
    @Test("Unregister tools")
    func testUnregisterTools() async {
        let registry = MCPToolRegistry()
        
        let tool1 = MockMCPTool(name: "tool1", description: "Tool 1")
        let tool2 = MockMCPTool(name: "tool2", description: "Tool 2")
        
        registry.register([tool1, tool2])
        #expect(registry.getToolCounts().native == 2)
        
        // Unregister one tool
        registry.unregister("tool1")
        #expect(registry.getToolCounts().native == 1)
        #expect(registry.hasToolNamed("tool1") == false)
        #expect(registry.hasToolNamed("tool2") == true)
        
        // Unregister all tools
        registry.unregisterAll()
        #expect(registry.getToolCounts().native == 0)
        #expect(registry.hasToolNamed("tool2") == false)
    }
    
    @Test("Refresh external tools without client manager")
    func testRefreshExternalToolsWithoutClientManager() async {
        let registry = MCPToolRegistry()
        
        await #expect(throws: MCPError.self) {
            try await registry.refreshExternalTools()
        }
    }
    
    @Test("Refresh external tools with client manager")
    func testRefreshExternalToolsWithClientManager() async throws {
        let registry = MCPToolRegistry()
        let clientManager = TachikomaMCPClientManager.shared
        
        registry.setClientManager(clientManager)
        
        // Should not throw with client manager set
        try await registry.refreshExternalTools()
        
        // Since client manager has no servers, external count should be 0
        #expect(registry.getToolCounts().external == 0)
    }
}

/// Tests for MCPToolRegistry with mock external tools
@Suite("MCP Tool Registry with Mock External Tools")
@MainActor
struct MCPToolRegistryMockExternalTests {
    
    @Test("Register mixed native and external tools")
    func testMixedToolRegistration() async {
        let registry = MCPToolRegistry()
        
        // Register native tools
        let nativeTool = MockMCPTool(name: "native_tool", description: "Native tool")
        registry.register(nativeTool)
        
        // Simulate external tools by directly adding them
        // (In real usage, this would be done through registerExternalTools)
        let clientManager = TachikomaMCPClientManager.shared
        let _ = ExternalMCPTool(
            serverName: "test-server",
            originalTool: Tool(
                name: "external_tool",
                description: "External tool",
                inputSchema: .object([:])
            ),
            clientManager: clientManager
        )
        
        // We can't directly test external tool registration without a proper client manager
        // but we can test the structure
        let counts = registry.getToolCounts()
        #expect(counts.native == 1)
        #expect(counts.total >= 1)
        
        let categorized = await registry.getToolsBySource()
        #expect(categorized.native.count == 1)
        #expect(categorized.native[0].name == "native_tool")
    }
    
    @Test("Tool lookup precedence")
    func testToolLookupPrecedence() async {
        let registry = MCPToolRegistry()
        
        // Register a native tool
        let nativeTool = MockMCPTool(name: "shared_name", description: "Native tool")
        registry.register(nativeTool)
        
        // Test that native tool is found first
        let foundTool = registry.toolCombined(named: "shared_name")
        #expect(foundTool?.name == "shared_name")
        #expect(foundTool?.description == "Native tool")
        
        // Test prefix search for native tool
        let prefixTool = registry.getToolWithPrefix(name: "shared_name")
        #expect(prefixTool?.name == "shared_name")
    }
}

// MARK: - Mock Classes

/// Mock MCP tool for testing
private struct MockMCPTool: MCPTool {
    let name: String
    let description: String
    let inputSchema: MCP.Value = .object([:])
    
    func execute(arguments: ToolArguments) async throws -> ToolResponse {
        return ToolResponse.text("Mock response for \(name)")
    }
}