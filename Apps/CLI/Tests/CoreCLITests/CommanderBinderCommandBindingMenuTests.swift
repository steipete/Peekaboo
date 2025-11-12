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
}
