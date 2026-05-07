import Commander
import Testing
@testable import PeekabooCLI

struct CommanderBinderTests {
    @Test
    func `Runtime options map verbose flag`() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: ["verbose"])
        let options = try CommanderCLIBinder.makeRuntimeOptions(from: parsed)
        #expect(options.verbose == true)
        #expect(options.jsonOutput == false)
    }

    @Test
    func `Runtime options map json flag`() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: ["jsonOutput"])
        let options = try CommanderCLIBinder.makeRuntimeOptions(from: parsed)
        #expect(options.verbose == false)
        #expect(options.jsonOutput == true)
    }

    @Test
    func `Runtime options map log level option`() throws {
        let parsed = ParsedValues(positional: [], options: ["logLevel": ["error"]], flags: [])
        let options = try CommanderCLIBinder.makeRuntimeOptions(from: parsed)
        #expect(options.logLevel == .error)
    }

    @Test
    func `Runtime options validate log level`() {
        let parsed = ParsedValues(positional: [], options: ["logLevel": ["nope"]], flags: [])
        #expect(throws: CommanderBindingError.invalidArgument(
            label: "logLevel",
            value: "nope",
            reason: "Unable to parse LogLevel"
        )) {
            _ = try CommanderCLIBinder.makeRuntimeOptions(from: parsed)
        }
    }

    @Test
    func `Agent runtime defaults to local host mode`() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        let options = try CommanderCLIBinder.makeRuntimeOptions(from: parsed, commandType: AgentCommand.self)
        #expect(options.preferRemote == false)
    }

    @Test
    func `Non-agent runtime keeps remote host mode by default`() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        let options = try CommanderCLIBinder.makeRuntimeOptions(from: parsed, commandType: SleepCommand.self)
        #expect(options.preferRemote == true)
    }

    @Test
    func `Image runtime defaults to local host mode`() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        let options = try CommanderCLIBinder.makeRuntimeOptions(from: parsed, commandType: ImageCommand.self)
        #expect(options.preferRemote == false)
    }

    @Test
    func `See runtime defaults to local host mode`() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        let options = try CommanderCLIBinder.makeRuntimeOptions(from: parsed, commandType: SeeCommand.self)
        #expect(options.preferRemote == false)
    }

    @Test
    func `Tools runtime defaults to local host mode`() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        let options = try CommanderCLIBinder.makeRuntimeOptions(from: parsed, commandType: ToolsCommand.self)
        #expect(options.preferRemote == false)
    }

    @Test
    func `List inventory runtimes default to local host mode`() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        let commandTypes: [any ParsableCommand.Type] = [
            ListCommand.AppsSubcommand.self,
            ListCommand.WindowsSubcommand.self,
            ListCommand.MenuBarSubcommand.self,
            ListCommand.ScreensSubcommand.self,
        ]

        for commandType in commandTypes {
            let options = try CommanderCLIBinder.makeRuntimeOptions(from: parsed, commandType: commandType)
            #expect(options.preferRemote == false)
        }
    }

    @Test
    func `Permission inventory keeps remote host mode by default`() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        let options = try CommanderCLIBinder.makeRuntimeOptions(
            from: parsed,
            commandType: ListCommand.PermissionsSubcommand.self
        )
        #expect(options.preferRemote == true)
    }

    @Test
    func `Image runtime honors explicit bridge socket`() throws {
        let parsed = ParsedValues(
            positional: [],
            options: ["bridge-socket": ["/tmp/peekaboo.sock"]],
            flags: []
        )
        let options = try CommanderCLIBinder.makeRuntimeOptions(from: parsed, commandType: ImageCommand.self)
        #expect(options.preferRemote == true)
        #expect(options.bridgeSocketPath == "/tmp/peekaboo.sock")
    }

    @Test
    func `See runtime honors explicit bridge socket`() throws {
        let parsed = ParsedValues(
            positional: [],
            options: ["bridge-socket": ["/tmp/peekaboo.sock"]],
            flags: []
        )
        let options = try CommanderCLIBinder.makeRuntimeOptions(from: parsed, commandType: SeeCommand.self)
        #expect(options.preferRemote == true)
        #expect(options.bridgeSocketPath == "/tmp/peekaboo.sock")
    }
}
