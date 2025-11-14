import PeekabooCore
import PeekabooFoundation
import Testing

@Suite("MCP Tool Context")
struct MCPToolContextTests {
    @Test
    func exposesPeekabooServicesByDefault() async {
        let context = MCPToolContext.shared
        #expect(context.automation !== nil)
        #expect(context.menu !== nil)
    }

    @Test
    @MainActor
    func contextUsesInjectedServices() async {
        let injectedServices = await MainActor.run { PeekabooServices() }
        let context = await MainActor.run { MCPToolContext(services: injectedServices) }

        #expect(ObjectIdentifier(context.menu as AnyObject) ==
            ObjectIdentifier(injectedServices.menu as AnyObject))
        #expect(ObjectIdentifier(context.automation as AnyObject) ==
            ObjectIdentifier(injectedServices.automation as AnyObject))
    }

    @Test
    func taskLocalOverrideRestoresSharedValue() async throws {
        let baselineContext = MCPToolContext.shared
        let overrideContext = try await MainActor.run {
            MCPToolContext(services: PeekabooServices())
        }

        try await MCPToolContext.withContext(overrideContext) {
            let inside = MCPToolContext.shared
            #expect(ObjectIdentifier(inside.automation as AnyObject) ==
                ObjectIdentifier(overrideContext.automation as AnyObject))
        }

        let after = MCPToolContext.shared
        #expect(ObjectIdentifier(after.automation as AnyObject) ==
            ObjectIdentifier(baselineContext.automation as AnyObject))
    }
}
