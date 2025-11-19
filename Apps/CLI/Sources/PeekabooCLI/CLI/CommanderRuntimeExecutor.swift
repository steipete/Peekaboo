import Commander
import Foundation

/// Commands that can specify a preferred capture engine.
protocol CaptureEngineConfigurable {
    var captureEngine: String? { get }
}

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
            if let capturePreference = (command as? CaptureEngineConfigurable)?.captureEngine,
               !capturePreference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Respect explicit engine choice; also allow disabling CG globally.
                setenv("PEEKABOO_CAPTURE_ENGINE", capturePreference, 1)
            }
            let runtimeOptions = try CommanderCLIBinder.makeRuntimeOptions(from: resolved.parsedValues)
            let runtime = CommandRuntime.makeDefault(options: runtimeOptions)
            try await runtimeCommand.run(using: runtime)
            return
        }

        var plainCommand = command
        try await plainCommand.run()
    }
}
