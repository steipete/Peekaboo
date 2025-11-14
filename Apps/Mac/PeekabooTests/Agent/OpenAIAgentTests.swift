import Foundation
import PeekabooCore
import Testing
@testable import Peekaboo

@Suite("PeekabooAgentService Tests", .tags(.ai, .unit), .disabled("Uses full PeekabooServices which may hang"))
@MainActor
struct PeekabooAgentServiceTests {
    var agentService: PeekabooAgentService!
    var settings: PeekabooSettings!
    var sessionStore: SessionStore!
    var agent: PeekabooAgent!

    mutating func setup() {
        let services = PeekabooServices()
        do {
            self.agentService = try PeekabooAgentService(services: services)
        } catch {
            Issue.record("Failed to initialize PeekabooAgentService: \\(error)")
            self.agentService = nil
        }
        self.settings = PeekabooSettings()
        self.settings.connectServices(services)
        self.sessionStore = SessionStore()
        self.agent = PeekabooAgent(
            settings: self.settings,
            sessionStore: self.sessionStore,
            services: services)
    }

    @Test("Agent service initializes correctly")
    mutating func agentServiceInitialization() {
        self.setup()
        #expect(self.agentService != nil)
    }

    @Test("Agent creates a valid set of tools")
    mutating func agentCreatesTools() {
        self.setup()
        let tools = self.agentService.createAgentTools()
        #expect(!tools.isEmpty)

        // Check for a few expected tools
        #expect(tools.contains { $0.name == "see" })
        #expect(tools.contains { $0.name == "click" })
        #expect(tools.contains { $0.name == "type" })
    }

    @Test("Task execution requires a valid API key")
    mutating func taskExecutionRequiresAPIKey() async {
        self.setup()
        self.settings.openAIAPIKey = ""

        await #expect(throws: AgentError.serviceUnavailable) {
            try await agent.executeTask("What time is it?")
        }
    }

    @Test("Dry run mode returns successfully without execution")
    mutating func dryRunMode() async throws {
        self.setup()
        self.settings.openAIAPIKey = "sk-test-key" // Needs a dummy key

        _ = try await self.agent.executeTask("Test task")

        // Dry run should create a session and a user message, but not execute
        let sessions = await sessionStore.sessions
        #expect(sessions.count == 1)
        #expect(sessions.first?.messages.count == 1)
        #expect(sessions.first?.messages.first?.role == .user)
    }
}
