import Foundation
import Testing
@testable import PeekabooCLI

@Suite("Agent Command Basic Tests", .tags(.safe))
struct AgentCommandBasicTests {
    @Test("Agent command exists and has correct configuration")
    func agentCommandExists() {
        // Verify the command configuration
        let config = AgentCommand.commandDescription
        #expect(config.commandName == "agent")
        #expect(config.abstract == "Execute complex automation tasks using the Peekaboo agent")
    }
}
