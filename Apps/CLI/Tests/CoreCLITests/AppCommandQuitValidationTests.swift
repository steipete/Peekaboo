import Commander
import PeekabooCore
import Testing
@testable import PeekabooCLI

@MainActor
struct AppCommandQuitValidationTests {
    private func makeRuntime() -> CommandRuntime {
        CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: true, logLevel: nil),
            services: PeekabooServices()
        )
    }

    @Test
    func `Rejects --all combined with --app`() async {
        var command = AppCommand.QuitSubcommand()
        command.all = true
        command.app = "Finder"

        let exitCode = await #expect(throws: ExitCode.self) {
            try await command.run(using: self.makeRuntime())
        }
        #expect(exitCode == .failure)
    }

    @Test
    func `Rejects --except without --all`() async {
        var command = AppCommand.QuitSubcommand()
        command.except = "Finder"

        let exitCode = await #expect(throws: ExitCode.self) {
            try await command.run(using: self.makeRuntime())
        }
        #expect(exitCode == .failure)
    }

    @Test
    func `Rejects missing target when not using --all`() async {
        var command = AppCommand.QuitSubcommand()

        let exitCode = await #expect(throws: ExitCode.self) {
            try await command.run(using: self.makeRuntime())
        }
        #expect(exitCode == .failure)
    }
}
