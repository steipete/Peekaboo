import ArgumentParser
import Foundation

@main
@available(macOS 10.15, *)
struct PeekabooCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "peekaboo",
        abstract: "A macOS utility for screen capture, application listing, and window management",
        version: Version.current,
        subcommands: [ImageCommand.self, ListCommand.self],
        defaultSubcommand: ImageCommand.self
    )

    func run() async throws {
        // Root command doesn't do anything, subcommands handle everything
    }
}
