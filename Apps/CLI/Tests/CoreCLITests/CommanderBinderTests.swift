import Commander
import PeekabooAutomation
import PeekabooBridge
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
    func `Runtime options map input strategy option and force local mode`() throws {
        let parsed = ParsedValues(positional: [], options: ["inputStrategy": ["actionFirst"]], flags: [])
        let options = try CommanderCLIBinder.makeRuntimeOptions(from: parsed)
        #expect(options.inputStrategy?.rawValue == "actionFirst")
        #expect(options.preferRemote == false)
    }

    @Test
    func `Input strategy environment overrides force local runtime`() {
        #expect(CommandRuntime.hasInputStrategyEnvironmentOverride(environment: [
            "PEEKABOO_INPUT_STRATEGY": "synthOnly",
        ]))
        #expect(CommandRuntime.hasInputStrategyEnvironmentOverride(environment: [
            "PEEKABOO_CLICK_INPUT_STRATEGY": " actionFirst ",
        ]))
        #expect(!CommandRuntime.hasInputStrategyEnvironmentOverride(environment: [
            "PEEKABOO_INPUT_STRATEGY": " ",
            "OTHER": "synthOnly",
        ]))
        #expect(!CommandRuntime.hasInputStrategyEnvironmentOverride(environment: [
            "PEEKABOO_INPUT_STRATEGY": "action-first",
        ]))
    }

    @Test
    func `Input strategy config overrides force local runtime`() {
        #expect(CommandRuntime.hasInputStrategyConfigOverride(input: Configuration.InputConfig(click: .synthOnly)))
        #expect(CommandRuntime.hasInputStrategyConfigOverride(input: Configuration.InputConfig(
            perApp: [
                "com.example.Editor": Configuration.AppInputConfig(scroll: .actionFirst),
            ]
        )))
        #expect(!CommandRuntime.hasInputStrategyConfigOverride(input: nil))
        #expect(!CommandRuntime.hasInputStrategyConfigOverride(input: Configuration.InputConfig()))
        #expect(!CommandRuntime.hasInputStrategyConfigOverride(input: Configuration.InputConfig(
            perApp: [
                "com.example.Empty": Configuration.AppInputConfig(),
            ]
        )))
    }

    @Test
    func `Element actions require bridge protocol and operation support`() {
        let current = PeekabooBridgeHandshakeResponse(
            negotiatedVersion: .init(major: 1, minor: 3),
            hostKind: .gui,
            build: nil,
            supportedOperations: [.setValue, .performAction]
        )
        let oldProtocol = PeekabooBridgeHandshakeResponse(
            negotiatedVersion: .init(major: 1, minor: 2),
            hostKind: .gui,
            build: nil,
            supportedOperations: [.setValue, .performAction]
        )
        let missingOperation = PeekabooBridgeHandshakeResponse(
            negotiatedVersion: .init(major: 1, minor: 3),
            hostKind: .gui,
            build: nil,
            supportedOperations: [.setValue]
        )

        #expect(CommandRuntime.supportsElementActions(for: current))
        #expect(!CommandRuntime.supportsElementActions(for: oldProtocol))
        #expect(!CommandRuntime.supportsElementActions(for: missingOperation))
    }

    @Test
    func `Element action commands require bridge element action support`() throws {
        let setValueOptions = try CommanderCLIBinder.makeRuntimeOptions(
            from: ParsedValues(positional: [], options: [:], flags: []),
            commandType: SetValueCommand.self
        )
        let performActionOptions = try CommanderCLIBinder.makeRuntimeOptions(
            from: ParsedValues(positional: [], options: [:], flags: []),
            commandType: PerformActionCommand.self
        )
        let seeOptions = try CommanderCLIBinder.makeRuntimeOptions(
            from: ParsedValues(positional: [], options: [:], flags: []),
            commandType: SeeCommand.self
        )

        #expect(setValueOptions.requiresElementActions)
        #expect(performActionOptions.requiresElementActions)
        #expect(!seeOptions.requiresElementActions)
    }

    @Test
    func `Remote requirements skip bridges missing required element action support`() {
        let current = PeekabooBridgeHandshakeResponse(
            negotiatedVersion: .init(major: 1, minor: 3),
            hostKind: .gui,
            build: nil,
            supportedOperations: [.captureScreen, .setValue, .performAction]
        )
        let oldProtocol = PeekabooBridgeHandshakeResponse(
            negotiatedVersion: .init(major: 1, minor: 2),
            hostKind: .gui,
            build: nil,
            supportedOperations: [.captureScreen, .setValue, .performAction]
        )
        var ordinaryOptions = CommandRuntimeOptions()
        var elementActionOptions = CommandRuntimeOptions()
        elementActionOptions.requiresElementActions = true

        #expect(CommandRuntime.supportsRemoteRequirements(for: current, options: elementActionOptions))
        #expect(CommandRuntime.supportsRemoteRequirements(for: oldProtocol, options: ordinaryOptions))
        #expect(!CommandRuntime.supportsRemoteRequirements(for: oldProtocol, options: elementActionOptions))

        ordinaryOptions.requiresElementActions = false
        #expect(CommandRuntime.supportsRemoteRequirements(for: oldProtocol, options: ordinaryOptions))
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
    func `Runtime options validate input strategy`() {
        let parsed = ParsedValues(positional: [], options: ["inputStrategy": ["nope"]], flags: [])
        #expect(throws: CommanderBindingError.invalidArgument(
            label: "input-strategy",
            value: "nope",
            reason: "expected one of actionFirst, synthFirst, actionOnly, synthOnly"
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
    func `Local inventory runtimes default to local host mode`() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        let commandTypes: [any ParsableCommand.Type] = [
            ToolsCommand.self,
        ]

        for commandType in commandTypes {
            let options = try CommanderCLIBinder.makeRuntimeOptions(from: parsed, commandType: commandType)
            #expect(options.preferRemote == false)
        }
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
