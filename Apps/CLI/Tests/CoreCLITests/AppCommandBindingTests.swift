import Commander
import Testing
@testable import PeekabooCLI

@Suite("App command binding")
struct AppCommandBindingTests {
    @Test
    func `hide accepts positional app`() throws {
        let parsed = ParsedValues(positional: ["Preview"], options: [:], flags: [])
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: AppCommand.HideSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.app == "Preview")
    }

    @Test
    func `unhide accepts positional app`() throws {
        let parsed = ParsedValues(positional: ["Preview"], options: [:], flags: ["activate"])
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: AppCommand.UnhideSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.app == "Preview")
        #expect(command.activate == true)
    }
}
