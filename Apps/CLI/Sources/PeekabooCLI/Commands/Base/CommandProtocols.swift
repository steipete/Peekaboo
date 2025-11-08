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

// MARK: - Verbose Protocol

/// Protocol for commands that support verbose logging
protocol VerboseCommand {
    var verbose: Bool { get }
}

extension VerboseCommand {
    /// Configure logger for verbose mode if enabled
    func configureVerboseLogging() {
        // Configure logger for verbose mode if enabled
        Logger.shared.setVerboseMode(verbose)
        if verbose {
            Logger.shared.verbose("Verbose logging enabled")
        }
    }
}
