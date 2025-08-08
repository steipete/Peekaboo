import Foundation
import Testing
@testable import peekaboo

@Suite("Agent Command Basic Tests")
struct AgentCommandBasicTests {
    @Test("Agent command exists and has correct configuration")
    func agentCommandExists() {
        // Verify the command configuration
        let config = AgentCommand.configuration
        #expect(config.commandName == "agent")
        #expect(config.abstract == "Execute complex automation tasks using AI agent")
    }
}
