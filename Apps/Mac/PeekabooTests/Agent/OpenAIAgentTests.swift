import Foundation
import Testing
import PeekabooCore
@testable import Peekaboo

@Suite("PeekabooAgentService Tests", .tags(.ai, .unit), .disabled("Uses PeekabooServices.shared which may hang"))
@MainActor
struct PeekabooAgentServiceTests {
    var agentService: PeekabooAgentService!
    var settings: PeekabooSettings!
    var sessionStore: SessionStore!
    var agent: PeekabooAgent!

    mutating func setup() {
        let services = PeekabooServices.shared
        agentService = try! PeekabooAgentService(services: services)
        settings = PeekabooSettings()
        sessionStore = SessionStore()
        agent = PeekabooAgent(settings: settings, sessionStore: sessionStore)
    }

    @Test("Agent service initializes correctly")
    mutating func agentServiceInitialization() {
        setup()
        #expect(agentService != nil)
    }

    @Test("Agent creates a valid set of tools")
    mutating func agentCreatesTools() {
        setup()
        let tools = agentService.createAgentTools()
        #expect(!tools.isEmpty)

        // Check for a few expected tools
        #expect(tools.contains { $0.name == "see" })
        #expect(tools.contains { $0.name == "click" })
        #expect(tools.contains { $0.name == "type" })
    }

    @Test("Task execution requires a valid API key")
    mutating func taskExecutionRequiresAPIKey() async {
        setup()
        settings.openAIAPIKey = ""
        
        await #expect(throws: AgentError.serviceUnavailable) {
            try await agent.executeTask("What time is it?")
        }
    }

    @Test("Dry run mode returns successfully without execution")
    mutating func dryRunMode() async throws {
        setup()
        settings.openAIAPIKey = "sk-test-key" // Needs a dummy key
        
        _ = try await agent.executeTask("Test task")

        // Dry run should create a session and a user message, but not execute
        let sessions = await sessionStore.sessions
        #expect(sessions.count == 1)
        #expect(sessions.first?.messages.count == 1)
        #expect(sessions.first?.messages.first?.role == .user)
    }
}
