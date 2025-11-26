import Commander
import Testing
@testable import PeekabooCLI

@Suite("Commander Binder Command Binding (Menu + Dock)")
struct CommanderBinderMenuDockTests {
    @Test("Scroll command binding")
    func bindScrollCommand() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "direction": ["down"],
                "amount": ["7"],
                "on": ["B4"],
                "session": ["sess-5"],
                "delay": ["5"],
                "app": ["Mail"]
            ],
            flags: ["smooth", "spaceSwitch"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: ScrollCommand.self,
            parsedValues: parsed
        )
        #expect(command.direction == "down")
        #expect(command.amount == 7)
        #expect(command.on == "B4")
        #expect(command.session == "sess-5")
        #expect(command.delay == 5)
        #expect(command.app == "Mail")
        #expect(command.smooth == true)
        #expect(command.focusOptions.spaceSwitch == true)
    }

    @Test("Menu click binding")
    func bindMenuClick() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "app": ["Safari"],
                "item": ["File"],
                "path": ["File>New Window"]
            ],
            flags: ["spaceSwitch"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: MenuCommand.ClickSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.app == "Safari")
        #expect(command.item == "File")
        #expect(command.path == "File>New Window")
        #expect(command.focusOptions.spaceSwitch == true)
    }

    @Test("Menu click requires app")
    func bindMenuClickMissingApp() {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        #expect(throws: CommanderBindingError.missingArgument(label: "app")) {
            _ = try CommanderCLIBinder.instantiateCommand(
                ofType: MenuCommand.ClickSubcommand.self,
                parsedValues: parsed
            )
        }
    }

    @Test("Menu click-extra binding")
    func bindMenuClickExtra() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "title": ["Wi-Fi"],
                "item": ["Turn Wi-Fi Off"]
            ],
            flags: []
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: MenuCommand.ClickExtraSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.title == "Wi-Fi")
        #expect(command.item == "Turn Wi-Fi Off")
    }

    @Test("Menu list binding")
    func bindMenuList() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "app": ["Safari"]
            ],
            flags: ["includeDisabled", "noAutoFocus"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: MenuCommand.ListSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.app == "Safari")
        #expect(command.includeDisabled == true)
    }

    @Test("Menu list requires app")
    func bindMenuListMissingApp() {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        #expect(throws: CommanderBindingError.missingArgument(label: "app")) {
            _ = try CommanderCLIBinder.instantiateCommand(
                ofType: MenuCommand.ListSubcommand.self,
                parsedValues: parsed
            )
        }
    }

    @Test("Menu list-all binding")
    func bindMenuListAll() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [:],
            flags: ["includeDisabled", "includeFrames"]
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: MenuCommand.ListAllSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.includeDisabled == true)
        #expect(command.includeFrames == true)
    }

    @Test("Dock launch binding")
    func bindDockLaunch() throws {
        let parsed = ParsedValues(positional: ["Safari"], options: [:], flags: [])
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: DockCommand.LaunchSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.app == "Safari")
    }

    @Test("Dock right-click binding")
    func bindDockRightClick() throws {
        let parsed = ParsedValues(
            positional: [],
            options: [
                "app": ["Finder"],
                "select": ["New Window"]
            ],
            flags: []
        )
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: DockCommand.RightClickSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.app == "Finder")
        #expect(command.select == "New Window")
    }

    @Test("Dock right-click requires app")
    func bindDockRightClickMissingApp() {
        let parsed = ParsedValues(positional: [], options: [:], flags: [])
        #expect(throws: CommanderBindingError.missingArgument(label: "app")) {
            _ = try CommanderCLIBinder.instantiateCommand(
                ofType: DockCommand.RightClickSubcommand.self,
                parsedValues: parsed
            )
        }
    }

    @Test("Dock list binding")
    func bindDockList() throws {
        let parsed = ParsedValues(positional: [], options: [:], flags: ["includeAll"])
        let command = try CommanderCLIBinder.instantiateCommand(
            ofType: DockCommand.ListSubcommand.self,
            parsedValues: parsed
        )
        #expect(command.includeAll == true)
    }
}
