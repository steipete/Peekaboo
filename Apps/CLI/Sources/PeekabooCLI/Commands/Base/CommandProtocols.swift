@preconcurrency import ArgumentParser
import Foundation

// MARK: - Concurrency Helpers

/// Marker protocol that bridges `ParsableArguments` into our MainActor-isolated world.
@preconcurrency
@MainActor
protocol MainActorParsableArguments: ParsableArguments {}

/// Marker protocol that bridges `AsyncParsableCommand` into our MainActor-isolated world.
@preconcurrency
@MainActor
protocol MainActorAsyncParsableCommand: AsyncParsableCommand {}

/// Marker protocol that bridges `ParsableCommand` into our MainActor-isolated world.
@preconcurrency
@MainActor
protocol MainActorParsableCommand: ParsableCommand {}

// MARK: - Runtime Command Protocol

/// Protocol for commands that accept runtime context injection.
/// Commands conforming to this protocol receive a `CommandRuntime` instance
/// containing logger, services, and configuration instead of accessing singletons.
@MainActor
protocol AsyncRuntimeCommand: MainActorAsyncParsableCommand {
    /// Run the command with injected runtime context.
    mutating func run(using runtime: CommandRuntime) async throws
}

extension AsyncRuntimeCommand {
    /// Default run() implementation that creates a CommandRuntime from options.
    /// Commands must define `runtimeOptions: CommandRuntimeOptions` to use this.
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
