import Foundation
import Testing
@testable import PeekabooCLI

@Suite("Window Command Basic Tests", .serialized, .tags(.safe))
struct WindowCommandBasicTests {
    @Test("Window command exists")
    func windowCommandExists() {
        // Verify WindowCommand type exists and has proper configuration
        let config = WindowCommand.commandDescription
        #expect(config.commandName == "window")
        #expect(config.abstract.contains("Manipulate application windows"))
    }

    @Test("Window command has expected subcommands")
    func windowSubcommands() {
        let subcommands = WindowCommand.commandDescription.subcommands

        // We expect 8 subcommands
        #expect(subcommands.count == 8)

        // Verify subcommand names by checking configuration
        let subcommandNames = Set(["close", "minimize", "maximize", "move", "resize", "set-bounds", "focus", "list"])

        // Each subcommand should have one of these names
        for subcommand in subcommands {
            let config = subcommand.commandDescription
            #expect(
                subcommandNames.contains(config.commandName ?? ""),
                "Unexpected subcommand: \(config.commandName ?? "")"
            )
        }
    }
}
