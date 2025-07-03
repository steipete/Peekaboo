import ArgumentParser
import Foundation

@main
@available(macOS 14.0, *)
struct PeekabooCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "peekaboo",
        abstract: "A macOS utility for screen capture, application listing, window management, and AI analysis",
        version: Version.current,
        subcommands: [ImageCommand.self, ListCommand.self, AnalyzeCommand.self],
        defaultSubcommand: ImageCommand.self
    )

    func run() async throws {
        // Root command doesn't do anything, subcommands handle everything
    }
}
