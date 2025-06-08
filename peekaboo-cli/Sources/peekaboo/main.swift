import ArgumentParser
import Foundation

struct PeekabooCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "peekaboo",
        abstract: "A cross-platform utility for screen capture, application listing, and window management",
        version: Version.current,
        subcommands: [ImageCommand.self, ListCommand.self],
        defaultSubcommand: ImageCommand.self
    )
}

// Entry point
PeekabooCommand.main()
