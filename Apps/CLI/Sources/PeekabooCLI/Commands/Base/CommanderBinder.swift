import Commander
import Foundation

@MainActor
enum CommanderCLIBinder {
    static func instantiateCommand<T>(ofType type: T.Type, parsedValues: ParsedValues) -> T where T: ParsableCommand {
        var command = type.init()
        // TODO: Map Commander parsed values directly into option/flag properties per command.
        _ = parsedValues
        return command
    }

    static func makeRuntimeOptions(from parsedValues: ParsedValues) -> CommandRuntimeOptions {
        var options = CommandRuntimeOptions()
        options.verbose = parsedValues.flags.contains("verbose")
        options.jsonOutput = parsedValues.flags.contains("jsonOutput")
        return options
    }
}
