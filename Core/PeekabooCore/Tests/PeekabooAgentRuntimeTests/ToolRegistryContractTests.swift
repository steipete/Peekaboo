import PeekabooAgentRuntime
import PeekabooAutomation
import PeekabooCore
import Testing

@Suite("ToolRegistry contract")
@MainActor
struct ToolRegistryContractTests {
    @Test("Default services expose automation tools")
    func registryIncludesAutomationTools() async throws {
        let services = PeekabooServices()
        services.installAgentRuntimeDefaults()

        let tools = ToolRegistry.allTools(using: services)
        #expect(!tools.isEmpty)
    }

    @Test("installAgentRuntimeDefaults feeds MCP context")
    func installsMCPContext() async throws {
        let services = PeekabooServices()
        services.installAgentRuntimeDefaults()

        let context = MCPToolContext.shared
        #expect(ObjectIdentifier(context.automation as AnyObject) ==
            ObjectIdentifier(services.automation as AnyObject))
    }
}
