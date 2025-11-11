import Commander
import Foundation

@MainActor
struct CommandHelpRenderer {
    static func renderHelp<T: ParsableCommand>(for type: T.Type) -> String {
        let config = T.configuration
        let instance = type.init()
        let signature = CommandSignature.describe(instance)
            .flattened()
            .withStandardRuntimeFlags()

        var sections: [String] = []
        if !config.abstract.isEmpty {
            sections.append(config.abstract)
        }
        if let discussion = config.discussion, !discussion.isEmpty {
            sections.append(discussion)
        }

        let argumentText = signature.arguments.map { "<\($0.label)>" }
        if !argumentText.isEmpty {
            sections.append("Arguments: " + argumentText.joined(separator: " "))
        }

        let optionNames = signature.options.flatMap { option in
            option.names.map(\.cliSpelling)
        }
        if !optionNames.isEmpty {
            sections.append("Options: " + optionNames.joined(separator: " "))
        }

        let flagNames = signature.flags.flatMap { flag in
            flag.names.map(\.cliSpelling)
        }
        if !flagNames.isEmpty {
            sections.append("Flags: " + flagNames.joined(separator: " "))
        }

        return sections.joined(separator: "\n")
    }
}

extension ParsableCommand {
    static func helpMessage() -> String {
        MainActor.assumeIsolated {
            CommandHelpRenderer.renderHelp(for: Self.self)
        }
    }
}

extension CommanderName {
    fileprivate var cliSpelling: String {
        switch self {
        case let .short(value):
            "-\(value)"
        case let .long(value):
            "--\(value)"
        }
    }
}
