import Commander
import CoreGraphics
import Darwin
import Foundation
import PeekabooCore

/// Shared entry point used by the executable target.
@MainActor
public func runPeekabooCLI() async {
    let status = await executePeekabooCLI(arguments: CommandLine.arguments)
    Darwin.exit(status)
}

/// Internal helper that runs the CLI and returns an exit code (used by tests).
@MainActor
func executePeekabooCLI(arguments: [String]) async -> Int32 {
    #if DEBUG
    checkBuildStaleness()
    #endif

    // Initialize CoreGraphics silently to prevent CGS_REQUIRE_INIT error
    _ = CGMainDisplayID()

    // Load configuration at startup
    _ = ConfigurationManager.shared.loadConfiguration()

    do {
        try await CommanderRuntimeExecutor.resolveAndRun(arguments: arguments)
        return EXIT_SUCCESS
    } catch let exit as ExitCode {
        return exit.rawValue
    } catch let programError as CommanderProgramError {
        printCommanderError(programError)
        return EXIT_FAILURE
    } catch {
        fputs("Error: \(error.localizedDescription)\n", stderr)
        return EXIT_FAILURE
    }
}

private func printCommanderError(_ error: CommanderProgramError) {
    switch error {
    case let .parsingError(parsing):
        fputs("Error: \(parsing.description)\n", stderr)
    case let .unknownCommand(name):
        fputs("Error: Unknown command '\(name)'\n", stderr)
    case let .unknownSubcommand(command, name):
        fputs("Error: Unknown subcommand '\(name)' for command '\(command)'\n", stderr)
    case .missingCommand:
        fputs("Error: No command specified\n", stderr)
    case let .missingSubcommand(command):
        fputs("Error: Command '\(command)' requires a subcommand\n", stderr)
    }
}
