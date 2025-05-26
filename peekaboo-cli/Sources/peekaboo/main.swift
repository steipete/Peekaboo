import ArgumentParser
import Foundation

struct PeekabooCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "peekaboo",
        abstract: "A macOS utility for screen capture, application listing, and window management",
        version: "1.0.0-beta.9",
        subcommands: [ImageCommand.self, ListCommand.self],
        defaultSubcommand: ImageCommand.self
    )
}

// Entry point
PeekabooCommand.main()
