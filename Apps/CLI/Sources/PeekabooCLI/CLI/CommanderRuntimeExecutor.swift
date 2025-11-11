import Commander
import Foundation

@MainActor
enum CommanderRuntimeExecutor {
    static func resolveAndRun(arguments: [String]) async throws {
        let resolved = try CommanderRuntimeRouter.resolve(argv: arguments)
        try await self.run(resolved: resolved)
    }

    static func run(resolved: CommanderResolvedCommand) async throws {
        let command = try CommanderCLIBinder.instantiateCommand(
            type: resolved.type,
            parsedValues: resolved.parsedValues
        )

        if var runtimeCommand = command as? any AsyncRuntimeCommand {
            let runtimeOptions = CommanderCLIBinder.makeRuntimeOptions(from: resolved.parsedValues)
            let runtime = CommandRuntime(options: runtimeOptions)
            try await runtimeCommand.run(using: runtime)
            return
        }

        var plainCommand = command
        try await plainCommand.run()
    }
}
