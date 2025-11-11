import Commander
import PeekabooFoundation

@MainActor
enum CommanderPilot {
    static func tryRun(arguments: [String]) async -> Bool {
        guard ProcessInfo.processInfo.environment["PEEKABOO_USE_COMMANDER"] == "1" else {
            return false
        }

        do {
            let resolved = try CommanderRuntimeRouter.resolve(argv: arguments)
            if try await runLearnCommandIfSupported(resolved: resolved) {
                return true
            }
            Logger.shared.debug("Commander pilot unsupported for command \(resolved.metadata.name)", category: "Commander")
        } catch {
            Logger.shared.debug("Commander pilot failed: \(error.localizedDescription)", category: "Commander")
        }
        return false
    }

    private static func runLearnCommandIfSupported(resolved: CommanderResolvedCommand) async throws -> Bool {
        guard resolved.metadata.name == "learn" else { return false }
        guard resolved.parsedValues.positional.isEmpty,
              resolved.parsedValues.options.isEmpty,
              resolved.parsedValues.flags.isEmpty else {
            Logger.shared.debug("Commander pilot: learn currently supports no arguments", category: "Commander")
            return false
        }
        var command = CommanderBinder.instantiateCommand(ofType: LearnCommand.self, parsedValues: resolved.parsedValues)
        let runtime = CommandRuntime(options: CommandRuntimeOptions())
        try await command.run(using: runtime)
        return true
    }
}
