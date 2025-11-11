import Commander
import Foundation

/// Temporary binder that exists while we build out Commander-based execution.
/// Currently this instantiates the command type and interprets Commander parsing
/// results for shared option groups like `CommandRuntimeOptions`.
@MainActor
enum CommanderCLIBinder {
    static func instantiateCommand<T>(ofType type: T.Type, parsedValues: ParsedValues) -> T where T: ParsableCommand {
        var command = type.init()
        // TODO: Map Commander parsed values directly into option/flag properties.
        _ = parsedValues
        return command
    }

    static func makeRuntimeOptions(from parsedValues: ParsedValues) -> CommandRuntimeOptions {
        var options = CommandRuntimeOptions()
        if parsedValues.flags.contains("verbose") {
            options.verbose = true
        }
        if parsedValues.flags.contains("jsonOutput") {
            options.jsonOutput = true
        }
        return options
    }
}
