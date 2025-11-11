import Commander
import PeekabooFoundation

enum CommanderPreview {
    @MainActor
    static func attempt(arguments: [String]) {
        do {
            let resolved = try CommanderRuntimeRouter.resolve(argv: arguments)
            Logger.shared.verbose(
                "Commander preview: \(resolved.metadata.name)",
                category: "Commander",
                metadata: [
                    "positional": resolved.parsedValues.positional.count,
                    "options": resolved.parsedValues.options.count,
                    "flags": resolved.parsedValues.flags.count
                ])
        } catch CommanderProgramError.missingCommand {
            // No command provided; ignore.
        } catch CommanderProgramError.unknownCommand {
            // Commander prototype can’t parse this yet—silently continue.
        } catch CommanderProgramError.parsingError {
            Logger.shared.debug("Commander parsing error (ignored)", category: "Commander")
        } catch {
            Logger.shared.debug("Commander preview failed: \(error.localizedDescription)", category: "Commander")
        }
    }
}
