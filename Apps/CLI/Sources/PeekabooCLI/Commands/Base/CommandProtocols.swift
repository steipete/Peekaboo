@preconcurrency import ArgumentParser
import Dispatch
import Foundation

// MARK: - Runtime Command Protocol

/// Protocol for commands that accept runtime context injection.
/// Commands conforming to this protocol receive a `CommandRuntime` instance
/// containing logger, services, and configuration instead of accessing singletons.
@MainActor
protocol AsyncRuntimeCommand: ParsableCommand {
    /// Run the command with injected runtime context.
    mutating func run(using runtime: CommandRuntime) async throws
}

extension AsyncRuntimeCommand {
    /// Default synchronous run() implementation that builds the runtime context
    /// and executes the async implementation on the main actor.
    mutating func run() throws {
        let mirror = Mirror(reflecting: self)
        guard let options = mirror.children.first(where: { $0.label == "runtimeOptions" })?.value as? CommandRuntimeOptions else {
            fatalError("AsyncRuntimeCommand requires @OptionGroup var runtimeOptions: CommandRuntimeOptions")
        }
        let runtime = CommandRuntime(options: options)

        var commandCopy = self
        let semaphore = DispatchSemaphore(value: 0)
        var thrownError: Error?

        Task { @MainActor in
            do {
                try await commandCopy.run(using: runtime)
            } catch {
                thrownError = error
            }
            semaphore.signal()
        }

        semaphore.wait()
        self = commandCopy
        if let error = thrownError {
            throw error
        }
    }
}
