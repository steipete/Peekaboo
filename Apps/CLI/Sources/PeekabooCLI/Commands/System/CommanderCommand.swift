import Commander
import Foundation
import PeekabooFoundation

struct CommanderCommand: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "commander",
            abstract: "Commander diagnostics (experimental)",
            discussion: "Inspect the upcoming Commander parser state."
        )
    }

    @MainActor
    mutating func run() async throws {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payload = descriptors.map { CommanderDescriptorSummary(descriptor: $0) }
        let data = try encoder.encode(payload)
        if let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    }
}

struct CommanderDescriptorSummary: Codable {
    let name: String
    let abstract: String
    let positionalArguments: [String]
    let options: [CommanderOptionSummary]
    let flags: [CommanderFlagSummary]

    init(descriptor: CommanderCommandDescriptor) {
        self.name = descriptor.metadata.name
        self.abstract = descriptor.metadata.abstract
        self.positionalArguments = descriptor.metadata.signature.arguments.map { $0.label }
        self.options = descriptor.metadata.signature.options.map { option in
            CommanderOptionSummary(
                names: option.names.map { $0.displayName },
                help: option.help ?? "",
                parsing: option.parsing.description
            )
        }
        self.flags = descriptor.metadata.signature.flags.map { flag in
            CommanderFlagSummary(names: flag.names.map { $0.displayName }, help: flag.help ?? "")
        }
    }
}

struct CommanderOptionSummary: Codable {
    let names: [String]
    let help: String
    let parsing: String
}

struct CommanderFlagSummary: Codable {
    let names: [String]
    let help: String
}

private extension CommanderName {
    var displayName: String {
        switch self {
        case .short(let value):
            return "-\(value)"
        case .long(let value):
            return "--\(value)"
        }
    }
}

private extension OptionParsingStrategy {
    var description: String {
        switch self {
        case .singleValue: return "singleValue"
        case .upToNextOption: return "upToNextOption"
        case .remaining: return "remaining"
        }
    }
}
