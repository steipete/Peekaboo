import Commander
import Testing
@testable import PeekabooCLI

@Suite("Commander Binder Command Binding (App + Config)")
struct CommanderBinderCommandBindingAppConfigTests {
    @Test("App launch binding")
        func bindAppLaunch() throws {
            let parsed = ParsedValues(
                positional: ["Visual Studio Code"],
                options: [
                    "bundleId": ["com.microsoft.VSCode"]
                ],
                flags: ["waitUntilReady"]
            )
            let command = try CommanderCLIBinder.instantiateCommand(
                ofType: AppCommand.LaunchSubcommand.self,
                parsedValues: parsed
            )
            #expect(command.app == "Visual Studio Code")
            #expect(command.bundleId == "com.microsoft.VSCode")
            #expect(command.waitUntilReady == true)
        }

        @Test("App quit binding")
        func bindAppQuit() throws {
            let parsed = ParsedValues(
                positional: [],
                options: [
                    "app": ["Safari"],
                    "pid": ["123"],
                    "except": ["Finder,Terminal"]
                ],
                flags: ["all", "force"]
            )
            let command = try CommanderCLIBinder.instantiateCommand(
                ofType: AppCommand.QuitSubcommand.self,
                parsedValues: parsed
            )
            #expect(command.app == "Safari")
            #expect(command.pid == 123)
            #expect(command.all == true)
            #expect(command.except == "Finder,Terminal")
            #expect(command.force == true)
        }

        @Test("App switch binding")
        func bindAppSwitch() throws {
            let parsed = ParsedValues(
                positional: [],
                options: ["to": ["Slack"]],
                flags: ["cycle"]
            )
            let command = try CommanderCLIBinder.instantiateCommand(
                ofType: AppCommand.SwitchSubcommand.self,
                parsedValues: parsed
            )
            #expect(command.to == "Slack")
            #expect(command.cycle == true)
        }

        @Test("App list binding")
        func bindAppList() throws {
            let parsed = ParsedValues(
                positional: [],
                options: [:],
                flags: ["includeHidden", "includeBackground"]
            )
            let command = try CommanderCLIBinder.instantiateCommand(
                ofType: AppCommand.ListSubcommand.self,
                parsedValues: parsed
            )
            #expect(command.includeHidden == true)
            #expect(command.includeBackground == true)
        }

        @Test("App relaunch binding")
        func bindAppRelaunch() throws {
            let parsed = ParsedValues(
                positional: ["Safari"],
                options: [
                    "pid": ["456"],
                    "wait": ["3.5"]
                ],
                flags: ["force", "waitUntilReady"]
            )
            let command = try CommanderCLIBinder.instantiateCommand(
                ofType: AppCommand.RelaunchSubcommand.self,
                parsedValues: parsed
            )
            #expect(command.app == "Safari")
            #expect(command.pid == 456)
            #expect(command.wait == 3.5)
            #expect(command.force == true)
            #expect(command.waitUntilReady == true)
        }

        @Test("Config init binding")
        func bindConfigInit() throws {
            let parsed = ParsedValues(positional: [], options: [:], flags: ["force"])
            let command = try CommanderCLIBinder.instantiateCommand(
                ofType: ConfigCommand.InitCommand.self,
                parsedValues: parsed
            )
            #expect(command.force == true)
        }

        @Test("Config show binding")
        func bindConfigShow() throws {
            let parsed = ParsedValues(positional: [], options: [:], flags: ["effective"])
            let command = try CommanderCLIBinder.instantiateCommand(
                ofType: ConfigCommand.ShowCommand.self,
                parsedValues: parsed
            )
            #expect(command.effective == true)
        }

        @Test("Config set credential binding")
        func bindConfigSetCredential() throws {
            let parsed = ParsedValues(positional: ["OPENAI_API_KEY", "sk-123"], options: [:], flags: [])
            let command = try CommanderCLIBinder.instantiateCommand(
                ofType: ConfigCommand.SetCredentialCommand.self,
                parsedValues: parsed
            )
            #expect(command.key == "OPENAI_API_KEY")
            #expect(command.value == "sk-123")
        }

        @Test("Config add provider binding")
        func bindConfigAddProvider() throws {
            let parsed = ParsedValues(
                positional: ["openrouter"],
                options: [
                    "type": ["openai"],
                    "name": ["OpenRouter"],
                    "baseUrl": ["https://openrouter.ai"],
                    "apiKey": ["{env:OPENROUTER_API_KEY}"],
                    "description": ["Multi-provider"],
                    "headers": ["x-demo:yes"]
                ],
                flags: ["force"]
            )
            let command = try CommanderCLIBinder.instantiateCommand(
                ofType: ConfigCommand.AddProviderCommand.self,
                parsedValues: parsed
            )
            #expect(command.providerId == "openrouter")
            #expect(command.type == "openai")
            #expect(command.name == "OpenRouter")
            #expect(command.baseUrl == "https://openrouter.ai")
            #expect(command.apiKey == "{env:OPENROUTER_API_KEY}")
            #expect(command.description == "Multi-provider")
            #expect(command.headers == "x-demo:yes")
            #expect(command.force == true)
        }

        @Test("Config remove provider binding")
        func bindConfigRemoveProvider() throws {
            let parsed = ParsedValues(positional: ["openrouter"], options: [:], flags: ["force"])
            let command = try CommanderCLIBinder.instantiateCommand(
                ofType: ConfigCommand.RemoveProviderCommand.self,
                parsedValues: parsed
            )
            #expect(command.providerId == "openrouter")
            #expect(command.force == true)
        }

        @Test("Config models provider binding")
        func bindConfigModelsProvider() throws {
            let parsed = ParsedValues(positional: ["openrouter"], options: [:], flags: ["discover"])
            let command = try CommanderCLIBinder.instantiateCommand(
                ofType: ConfigCommand.ModelsProviderCommand.self,
                parsedValues: parsed
            )
            #expect(command.providerId == "openrouter")
            #expect(command.discover == true)
        }

        @Test("Space list binding")
        func bindSpaceList() throws {
            let parsed = ParsedValues(positional: [], options: [:], flags: ["detailed"])
            let command = try CommanderCLIBinder.instantiateCommand(ofType: ListSubcommand.self, parsedValues: parsed)
            #expect(command.detailed == true)
        }

        @Test("Space switch binding")
        func bindSpaceSwitch() throws {
            let parsed = ParsedValues(positional: [], options: ["to": ["3"]], flags: [])
            let command = try CommanderCLIBinder.instantiateCommand(ofType: SwitchSubcommand.self, parsedValues: parsed)
            #expect(command.to == 3)
        }

        @Test("Space move-window binding")
        func bindSpaceMoveWindow() throws {
            let parsed = ParsedValues(
                positional: [],
                options: [
                    "app": ["Safari"],
                    "pid": ["123"],
                    "windowTitle": ["Inbox"],
                    "windowIndex": ["456"],
                    "to": ["2"]
                ],
                flags: ["toCurrent", "follow"]
            )
            let command = try CommanderCLIBinder.instantiateCommand(
                ofType: MoveWindowSubcommand.self,
                parsedValues: parsed
            )
            #expect(command.app == "Safari")
            #expect(command.pid == 123)
            #expect(command.windowTitle == "Inbox")
            #expect(command.windowIndex == 456)
            #expect(command.to == 2)
            #expect(command.toCurrent == true)
            #expect(command.follow == true)
        }

        @Test("Agent command binding")
        func bindAgentCommand() throws {
            let parsed = ParsedValues(
                positional: ["Open Notes and write summary"],
                options: [
                    "maxSteps": ["7"],
                    "model": ["gpt-5"],
                    "resumeSession": ["sess-42"],
                    "audioFile": ["/tmp/input.wav"]
                ],
                flags: [
                    "debugTerminal",
                    "quiet",
                    "dryRun",
                    "resume",
                    "listSessions",
                    "noCache",
                    "audio",
                    "realtime",
                    "simple",
                    "noColor"
                ]
            )
            let command = try CommanderCLIBinder.instantiateCommand(ofType: AgentCommand.self, parsedValues: parsed)
            #expect(command.task == "Open Notes and write summary")
            #expect(command.debugTerminal == true)
            #expect(command.quiet == true)
            #expect(command.dryRun == true)
            #expect(command.maxSteps == 7)
            #expect(command.model == "gpt-5")
            #expect(command.resume == true)
            #expect(command.resumeSession == "sess-42")
            #expect(command.listSessions == true)
            #expect(command.noCache == true)
            #expect(command.audio == true)
            #expect(command.audioFile == "/tmp/input.wav")
            #expect(command.realtime == true)
            #expect(command.simple == true)
            #expect(command.noColor == true)
        }


    }
}
