@preconcurrency import ArgumentParser
import Foundation

// MARK: - Runtime Command Protocol

/// Protocol for commands that accept runtime context injection.
/// Commands conforming to this protocol receive a `CommandRuntime` instance
/// containing logger, services, and configuration instead of accessing singletons.
protocol AsyncRuntimeCommand: AsyncParsableCommand {
    /// Run the command with injected runtime context.
    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws
}

extension AsyncRuntimeCommand {
    /// Default run() implementation that creates a CommandRuntime from options.
    /// Commands must define `runtimeOptions: CommandRuntimeOptions` to use this.
    @MainActor
    mutating func run() async throws {
        // Access runtimeOptions via reflection to create runtime
        let mirror = Mirror(reflecting: self)
        guard let options = mirror.children.first(where: { $0.label == "runtimeOptions" })?.value as? CommandRuntimeOptions else {
            fatalError("AsyncRuntimeCommand requires @OptionGroup var runtimeOptions: CommandRuntimeOptions")
        }

        let runtime = CommandRuntime(options: options)
        try await self.run(using: runtime)
    }
}

/// Main-actor-only commands that still use the shared runtime plumbing.
@MainActor
protocol MainActorRuntimeCommand: AsyncRuntimeCommand {
    @MainActor
    mutating func runMainActor(using runtime: CommandRuntime) async throws
}

extension MainActorRuntimeCommand {
    @MainActor
    mutating func run(using runtime: CommandRuntime) async throws {
        try await self.runMainActor(using: runtime)
    }
}
