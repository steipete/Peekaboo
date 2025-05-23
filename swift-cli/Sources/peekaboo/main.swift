import Foundation
import ArgumentParser

struct PeekabooCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "peekaboo",
        abstract: "A macOS utility for screen capture, application listing, and window management",
        version: "1.1.1",
        subcommands: [ImageCommand.self, ListCommand.self],
        defaultSubcommand: ImageCommand.self
    )
}

// Entry point
PeekabooCommand.main() 