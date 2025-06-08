import ArgumentParser
import Foundation

@available(macOS 10.15, *)
struct PeekabooCommand: ParsableCommand, AsyncRunnable {
    static let configuration = CommandConfiguration(
        commandName: "peekaboo",
        abstract: "A macOS utility for screen capture, application listing, and window management",
        version: Version.current,
        subcommands: [ImageCommand.self, ListCommand.self],
        defaultSubcommand: ImageCommand.self
    )
    
    func runAsync() async throws {
        // Root command doesn't do anything, subcommands handle everything
    }
}

// Entry point
PeekabooCommand.main()