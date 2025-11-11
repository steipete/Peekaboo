import Foundation

/// Utility that reads Commander metadata and hydrates Swift command instances.
/// This will eventually power Commander-first execution.
public enum SwiftRuntimeBinder {
    public static func applyRuntimeFlags<T>(to command: inout T, flags: RuntimeFlags) where T: ParsableCommand & HasRuntimeOptions {
        command.runtimeOptions.verbose = flags.verbose
        command.runtimeOptions.jsonOutput = flags.jsonOutput
    }
}

public protocol HasRuntimeOptions {
    var runtimeOptions: CommandRuntimeOptions { get set }
}
