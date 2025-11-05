import ArgumentParser
import Foundation

// MARK: - Verbose Protocol

/// Protocol for commands that support verbose logging
protocol VerboseCommand {
    var verbose: Bool { get }
}

extension VerboseCommand {
    /// Configure logger for verbose mode if enabled
    func configureVerboseLogging() {
        Logger.shared.setVerboseMode(verbose)
        if verbose {
            Logger.shared.verbose("Verbose logging enabled")
        }
    }
}
