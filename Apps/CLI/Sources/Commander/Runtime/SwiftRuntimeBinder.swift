import Foundation

/// Utility that describes how to hydrate Commander-parsed values into Swift
/// command instances. As we migrate commands we will gradually implement
/// per-field binding here.
public enum SwiftRuntimeBinder {
    public static func applyRuntimeFlags(flags: RuntimeFlags) -> CommandRuntimeOptions {
        var options = CommandRuntimeOptions()
        options.verbose = flags.verbose
        options.jsonOutput = flags.jsonOutput
        return options
    }
}
