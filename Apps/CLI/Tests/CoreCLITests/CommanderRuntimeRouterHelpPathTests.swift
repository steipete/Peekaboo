import Commander
import Testing
@testable import PeekabooCLI

@MainActor
struct CommanderRuntimeRouterHelpPathTests {
    @Test
    func `help resolves longest matching command prefix`() {
        let exitCode = #expect(throws: ExitCode.self) {
            _ = try CommanderRuntimeRouter.resolve(argv: ["peekaboo", "help", "list", "apps", "extra-token"])
        }
        #expect(exitCode == .success)
    }

    @Test
    func `help ignores option-like trailing tokens`() {
        let exitCode = #expect(throws: ExitCode.self) {
            _ = try CommanderRuntimeRouter.resolve(argv: ["peekaboo", "help", "app", "quit", "--pid", "123"])
        }
        #expect(exitCode == .success)
    }
}
