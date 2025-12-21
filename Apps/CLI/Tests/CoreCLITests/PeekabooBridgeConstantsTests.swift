import PeekabooBridge
import Testing

@Suite("Peekaboo Bridge Constants")
struct PeekabooBridgeConstantsTests {
    @Test("Claude socket path uses Application Support/Claude")
    func claudeSocketPathUsesClaudeApplicationSupportDirectory() {
        #expect(PeekabooBridgeConstants.claudeSocketPath.hasSuffix("/Claude/bridge.sock"))
    }
}

