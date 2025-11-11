import Commander
import Testing
@testable import PeekabooCLI

@Suite("Commander Binder")
struct CommanderBinderTests {
    @Test("Runtime options map verbose flag")
    func runtimeOptionVerbose() {
        let parsed = ParsedValues(positional: [], options: [:], flags: ["verbose"])
        let options = CommanderBinder.makeRuntimeOptions(from: parsed)
        #expect(options.verbose == true)
        #expect(options.jsonOutput == false)
    }

    @Test("Runtime options map json flag")
    func runtimeOptionJson() {
        let parsed = ParsedValues(positional: [], options: [:], flags: ["jsonOutput"])
        let options = CommanderBinder.makeRuntimeOptions(from: parsed)
        #expect(options.verbose == false)
        #expect(options.jsonOutput == true)
    }
}
