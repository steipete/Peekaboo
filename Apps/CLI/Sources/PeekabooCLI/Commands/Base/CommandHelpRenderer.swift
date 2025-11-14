import Commander
import Foundation

@MainActor
struct CommandHelpRenderer {
    static func renderHelp(for type: (some ParsableCommand).Type) -> String {
        let description = type.commandDescription
        if let descriptor = CommanderRegistryBuilder.descriptor(for: type) {
            return self.renderHelp(
                abstract: description.abstract,
                discussion: description.discussion,
                signature: descriptor.signature,
                usageExamples: description.usageExamples
            )
        }

        let fallbackSignature = CommandSignature.describe(type.init())
            .flattened()
            .withStandardRuntimeFlags()
        return self.renderHelp(
            abstract: description.abstract,
            discussion: description.discussion,
            signature: fallbackSignature,
            usageExamples: description.usageExamples
        )
    }

    private static func renderHelp(
        abstract: String,
        discussion: String?,
        signature: CommandSignature,
        usageExamples: [CommandUsageExample]
    ) -> String {
        var sections: [String] = []

        if let descriptionSection = self.renderDescription(abstract: abstract, discussion: discussion) {
            sections.append(descriptionSection)
        }

        if let argumentsSection = self.renderArguments(signature.arguments) {
            sections.append(argumentsSection)
        }

        if let optionsSection = self.renderOptions(signature.options) {
            sections.append(optionsSection)
        }

        if let flagsSection = self.renderFlags(signature.flags) {
            sections.append(flagsSection)
        }

        if let examplesSection = self.renderExamples(usageExamples) {
            sections.append(examplesSection)
        }

        return sections.joined(separator: "\n\n")
    }

    private static func renderDescription(abstract: String, discussion: String?) -> String? {
        var body: [String] = []
        if !abstract.isEmpty {
            body.append(abstract)
        }
        if let discussion, !discussion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body.append(discussion)
        }
        guard !body.isEmpty else { return nil }
        return self.makeSection(title: "DESCRIPTION", lines: body)
    }

    private static func renderArguments(_ arguments: [ArgumentDefinition]) -> String? {
        guard !arguments.isEmpty else { return nil }
        let rows = arguments.map { argument -> (String, String?) in
            let label = argument.isOptional ? "[\(argument.label)]" : "<\(argument.label)>"
            return (label, argument.help)
        }
        return self.makeSection(title: "ARGUMENTS", lines: self.renderKeyValueRows(rows))
    }

    private static func renderOptions(_ options: [OptionDefinition]) -> String? {
        guard !options.isEmpty else { return nil }
        let rows = options.map { option -> (String, String?) in
            let names = option.names
                .filter { !$0.isAlias }
                .map(\.cliSpelling)
                .joined(separator: ", ")
            let valuePlaceholder = " <\(option.label)>"
            return (names + valuePlaceholder, option.help)
        }
        return self.makeSection(title: "OPTIONS", lines: self.renderKeyValueRows(rows))
    }

    private static func renderFlags(_ flags: [FlagDefinition]) -> String? {
        guard !flags.isEmpty else { return nil }
        let rows = flags.map { flag -> (String, String?) in
            let names = flag.names
                .filter { !$0.isAlias }
                .map(\.cliSpelling)
                .joined(separator: ", ")
            return (names, flag.help)
        }
        return self.makeSection(title: "FLAGS", lines: self.renderKeyValueRows(rows))
    }

    private static func renderExamples(_ examples: [CommandUsageExample]) -> String? {
        guard !examples.isEmpty else { return nil }
        let rows = examples.map { ("$ \($0.command)", $0.description) }
        return self.makeSection(title: "USAGE EXAMPLES", lines: self.renderKeyValueRows(rows))
    }

    private static func makeSection(title: String, lines: [String]) -> String {
        ([title] + lines.map { "  \($0)" }).joined(separator: "\n")
    }

    private static func renderKeyValueRows(_ rows: [(String, String?)]) -> [String] {
        guard !rows.isEmpty else { return [] }
        let padding = min(max(rows.map { $0.0.count }.max() ?? 0, 12), 32)
        return rows.map { key, value in
            guard let value, !value.isEmpty else {
                return key
            }
            let paddedKey: String
            if key.count >= padding {
                paddedKey = key
            } else {
                paddedKey = key + String(repeating: " ", count: padding - key.count)
            }
            return "\(paddedKey)  \(value)"
        }
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
        case let .short(value), let .aliasShort(value):
            "-\(value)"
        case let .long(value), let .aliasLong(value):
            "--\(value)"
        }
    }
}
