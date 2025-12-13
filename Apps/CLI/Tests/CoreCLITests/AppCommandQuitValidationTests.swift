import Commander
import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite("AppCommand quit validation")
@MainActor
struct AppCommandQuitValidationTests {
    private func makeRuntime() -> CommandRuntime {
        CommandRuntime(
            configuration: .init(verbose: false, jsonOutput: true, logLevel: nil),
            services: PeekabooServices()
        )
    }

    @Test("Rejects --all combined with --app")
    func rejectAllWithApp() async {
        var command = AppCommand.QuitSubcommand()
        command.all = true
        command.app = "Finder"

        let exitCode = await #expect(throws: ExitCode.self) {
            try await command.run(using: self.makeRuntime())
        }
        #expect(exitCode == .failure)
    }

    @Test("Rejects --except without --all")
    func rejectExceptWithoutAll() async {
        var command = AppCommand.QuitSubcommand()
        command.except = "Finder"

        let exitCode = await #expect(throws: ExitCode.self) {
            try await command.run(using: self.makeRuntime())
        }
        #expect(exitCode == .failure)
    }

    @Test("Rejects missing target when not using --all")
    func rejectMissingTarget() async {
        var command = AppCommand.QuitSubcommand()

        let exitCode = await #expect(throws: ExitCode.self) {
            try await command.run(using: self.makeRuntime())
        }
        #expect(exitCode == .failure)
    }
}
