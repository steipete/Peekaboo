import PeekabooBridge
import Testing

struct PeekabooBridgeConstantsTests {
    @Test
    func `Claude socket path uses Application Support/Claude`() {
        #expect(PeekabooBridgeConstants.claudeSocketPath.hasSuffix("/Claude/bridge.sock"))
    }
}
