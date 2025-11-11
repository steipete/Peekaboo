import Commander
import Foundation

@MainActor
struct CommandHelpRenderer {
    static func renderHelp(for type: (some ParsableCommand).Type) -> String {
        if let descriptor = CommanderRegistryBuilder.descriptor(for: type) {
            return self.renderHelp(
                abstract: descriptor.abstract,
                discussion: descriptor.discussion,
                signature: descriptor.signature
            )
        }

        let fallbackSignature = CommandSignature.describe(type.init())
            .flattened()
            .withStandardRuntimeFlags()
        return self.renderHelp(
            abstract: type.commandDescription.abstract,
            discussion: type.commandDescription.discussion,
            signature: fallbackSignature
        )
    }

    private static func renderHelp(
        abstract: String,
        discussion: String?,
        signature: CommandSignature
    ) -> String {
        var sections: [String] = []

        if !abstract.isEmpty {
            sections.append(abstract)
        }
        if let discussion, !discussion.isEmpty {
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
