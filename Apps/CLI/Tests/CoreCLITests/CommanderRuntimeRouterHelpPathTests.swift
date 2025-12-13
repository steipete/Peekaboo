import Commander
import Testing
@testable import PeekabooCLI

@Suite("CommanderRuntimeRouter help path resolution")
@MainActor
struct CommanderRuntimeRouterHelpPathTests {
    @Test("help resolves longest matching command prefix")
    func helpResolvesLongestPrefix() {
        let exitCode = #expect(throws: ExitCode.self) {
            _ = try CommanderRuntimeRouter.resolve(argv: ["peekaboo", "help", "list", "apps", "extra-token"])
        }
        #expect(exitCode == .success)
    }

    @Test("help ignores option-like trailing tokens")
    func helpResolvesWithTrailingOptions() {
        let exitCode = #expect(throws: ExitCode.self) {
            _ = try CommanderRuntimeRouter.resolve(argv: ["peekaboo", "help", "app", "quit", "--pid", "123"])
        }
        #expect(exitCode == .success)
    }
}
