import Foundation
import Testing
@testable import PeekabooCLI

@Suite(.tags(.safe))
struct AgentCommandBasicTests {
    @Test
    func `Agent command exists and has correct configuration`() {
        // Verify the command configuration
        let config = AgentCommand.commandDescription
        #expect(config.commandName == "agent")
        #expect(config.abstract == "Execute complex automation tasks using the Peekaboo agent")
    }
}
