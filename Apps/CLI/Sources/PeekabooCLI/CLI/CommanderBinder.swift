import Commander
@preconcurrency import ArgumentParser

/// Temporary binder that exists while we build out Commander-based execution.
/// Currently this only instantiates the command type so we can progressively
/// add property hydration without touching ArgumentParser behavior.
@MainActor
enum CommanderBinder {
    static func instantiateCommand<T>(ofType type: T.Type, parsedValues: ParsedValues) -> T where T: ParsableCommand {
        var command = type.init()
        // TODO: Map `parsedValues` into property wrappers once Commander becomes authoritative.
        _ = parsedValues
        return command
    }
}
