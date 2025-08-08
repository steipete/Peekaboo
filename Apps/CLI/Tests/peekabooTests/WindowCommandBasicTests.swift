import Foundation
import Testing
@testable import peekaboo

@Suite("Window Command Basic Tests", .serialized)
struct WindowCommandBasicTests {
    @Test("Window command exists")
    func windowCommandExists() {
        // Verify WindowCommand type exists and has proper configuration
        let config = WindowCommand.configuration
        #expect(config.commandName == "window")
        #expect(config.abstract.contains("Manipulate application windows"))
    }

    @Test("Window command has expected subcommands")
    func windowSubcommands() {
        let subcommands = WindowCommand.configuration.subcommands

        // We expect 8 subcommands
        #expect(subcommands.count == 8)

        // Verify subcommand names by checking configuration
        let subcommandNames = Set(["close", "minimize", "maximize", "move", "resize", "set-bounds", "focus", "list"])

        // Each subcommand should have one of these names
        for subcommand in subcommands {
            let config = subcommand.configuration
            #expect(
                subcommandNames.contains(config.commandName ?? ""),
                "Unexpected subcommand: \(config.commandName ?? "")"
            )
        }
    }
}
