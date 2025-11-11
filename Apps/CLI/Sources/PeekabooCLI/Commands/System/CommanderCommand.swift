import Commander
import Foundation
import PeekabooFoundation

@MainActor

struct CommanderCommand: ParsableCommand {
    @Flag(names: [.long, .customShort("v", allowingJoined: false)], help: "Enable verbose logging for diagnostics")
    var verbose = false

    @Flag(name: .long, help: "Emit machine-readable JSON output")
    var json = false

    static var commandDescription: CommandDescription {
        CommandDescription(
            commandName: "commander",
            abstract: "Commander diagnostics (experimental)",
            discussion: "Inspect the upcoming Commander parser state."
        )
    }

    @MainActor
    mutating func run() async throws {
        let summaries = CommanderRegistryBuilder.buildCommandSummaries()
        let outputStruct = CommanderDiagnostics(commands: summaries)
        let runtimeOptions = CommandRuntimeOptions(verbose: verbose, jsonOutput: json)
        let runtime = CommandRuntime(options: runtimeOptions)
        CommanderDiagnosticsReporter(runtime: runtime).report(outputStruct)
    }
}

struct CommanderDiagnostics: Codable {
    let commands: [CommanderCommandSummary]
}

@MainActor
struct CommanderDiagnosticsReporter {
    let runtime: CommandRuntime

    func report(_ diagnostics: CommanderDiagnostics) {
        if self.runtime.configuration.jsonOutput, let jsonData = try? JSONEncoder.pretty.encode(diagnostics),
           let jsonString = String(
               data: jsonData,
               encoding: .utf8
           ) {
            print(jsonString)
        } else {
            for command in diagnostics.commands {
                self.runtime.logger.info("\(command.name): \(command.abstract)")
                for option in command.options {
                    let help = option.help ?? "No description provided"
                    self.runtime.logger.verbose(
                        "Option: \(option.names.joined(separator: ", ")) -- \(help)",
                        category: "Commander"
                    )
                }
            }
        }
    }
}

extension JSONEncoder {
    fileprivate static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension CommanderCommand: CommanderBindableCommand {
    mutating func applyCommanderValues(_ values: CommanderBindableValues) throws {
        self.verbose = values.flag("verbose")
        self.json = values.flag("json")
    }
}
