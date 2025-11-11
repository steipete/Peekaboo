import Commander
import Foundation

@MainActor
enum CommanderCLIBinder {
    static func instantiateCommand<T>(ofType type: T.Type, parsedValues: ParsedValues) -> T where T: ParsableCommand {
        var command = type.init()
        if var hasOptions = command as? (any HasRuntimeOptions & ParsableCommand) {
            let flags = CommanderBinder.runtimeFlags(from: parsedValues)
            SwiftRuntimeBinder.applyRuntimeFlags(to: &hasOptions, flags: flags)
            if let rebound = hasOptions as? T {
                command = rebound
            }
        }
        return command
    }

    static func makeRuntimeOptions(from parsedValues: ParsedValues) -> CommandRuntimeOptions {
        var options = CommandRuntimeOptions()
        let flags = CommanderBinder.runtimeFlags(from: parsedValues)
        options.verbose = flags.verbose
        options.jsonOutput = flags.jsonOutput
        return options
    }
}
