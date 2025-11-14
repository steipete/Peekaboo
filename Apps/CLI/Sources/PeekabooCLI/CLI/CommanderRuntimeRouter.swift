import Commander
import Foundation

struct CommanderResolvedCommand {
    let metadata: CommandDescriptor
    let type: any ParsableCommand.Type
    let parsedValues: ParsedValues
}

@MainActor
enum CommanderRuntimeRouter {
    static func resolve(argv: [String]) throws -> CommanderResolvedCommand {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let trimmedArgs = Self.trimmedArguments(from: argv)
        if trimmedArgs.isEmpty {
            self.printRootHelp(descriptors: descriptors)
            throw ExitCode.success
        }
        if Self.handleVersionRequest(arguments: trimmedArgs) {
            throw ExitCode.success
        }
        if try Self.handleBareInvocation(arguments: trimmedArgs, descriptors: descriptors) {
            throw ExitCode.success
        }
        if try Self.handleHelpRequest(arguments: trimmedArgs, descriptors: descriptors) {
            throw ExitCode.success
        }
        let program = Program(descriptors: descriptors.map(\.metadata))
        let invocation = try program.resolve(argv: argv)
        guard let descriptor = Self.findDescriptor(in: descriptors, matching: invocation.path) else {
            throw CommanderProgramError.unknownCommand(invocation.path.joined(separator: ":"))
        }
        return CommanderResolvedCommand(
            metadata: descriptor.metadata,
            type: descriptor.type,
            parsedValues: invocation.parsedValues
        )
    }

    private static func findDescriptor(
        in descriptors: [CommanderCommandDescriptor],
        matching path: [String]
    ) -> CommanderCommandDescriptor? {
        guard let head = path.first else { return nil }
        guard let match = descriptors.first(where: { $0.metadata.name == head }) else {
            return nil
        }
        guard path.count > 1 else {
            return match
        }
        let remainder = Array(path.dropFirst())
        return self.findDescriptor(in: match.subcommands, matching: remainder)
    }

    private static func trimmedArguments(from argv: [String]) -> [String] {
        guard !argv.isEmpty else { return [] }
        var args = argv
        if args[0].hasSuffix("peekaboo") {
            args.removeFirst()
        }
        return args
    }

    private static func handleHelpRequest(
        arguments: [String],
        descriptors: [CommanderCommandDescriptor]
    ) throws -> Bool {
        guard !arguments.isEmpty else { return false }

        if arguments[0].caseInsensitiveCompare("help") == .orderedSame {
            let path = Array(arguments.dropFirst())
            try self.printHelp(for: path, descriptors: descriptors)
            return true
        }

        if let index = arguments.firstIndex(where: { self.isHelpToken($0) }) {
            let path = Array(arguments.prefix(index))
            try self.printHelp(for: path, descriptors: descriptors)
            return true
        }

        return false
    }

    private static func handleVersionRequest(arguments: [String]) -> Bool {
        guard let first = arguments.first else { return false }
        guard self.isVersionToken(first) else { return false }
        print(Version.fullVersion)
        return true
    }

    private static func handleBareInvocation(
        arguments: [String],
        descriptors: [CommanderCommandDescriptor]
    ) throws -> Bool {
        guard arguments.count == 1 else { return false }
        let token = arguments[0]
        guard let descriptor = descriptors.first(where: { $0.metadata.name == token }) else {
            return false
        }
        let description = descriptor.type.commandDescription
        guard description.showHelpOnEmptyInvocation else { return false }
        self.printCommandHelp(descriptor, path: [token])
        return true
    }

    private static func isHelpToken(_ token: String) -> Bool {
        token == "--help" || token == "-h"
    }

    private static func isVersionToken(_ token: String) -> Bool {
        token == "--version" || token == "-V"
    }

    private static func printHelp(
        for path: [String],
        descriptors: [CommanderCommandDescriptor]
    ) throws {
        if path.isEmpty {
            self.printRootHelp(descriptors: descriptors)
            return
        }
        guard let descriptor = self.findDescriptor(in: descriptors, matching: path) else {
            throw CommanderProgramError.unknownCommand(path.joined(separator: " "))
        }
        self.printCommandHelp(descriptor, path: path)
    }
    
    private static func printRootHelp(descriptors: [CommanderCommandDescriptor]) {
        let theme = self.makeHelpTheme()
        print(self.renderRootUsageCard(theme: theme))
        print("")

        let groupedByCategory = Dictionary(grouping: descriptors) { descriptor in
            Self.categoryLookup[ObjectIdentifier(descriptor.type)] ?? .core
        }

        for category in CommandRegistryEntry.Category.allCases {
            guard let commands = groupedByCategory[category], !commands.isEmpty else { continue }
            print(theme.heading(category.displayName))
        let rows = self.renderCommandList(for: commands, theme: theme)
        rows.forEach { print($0) }
            print("")
        }

        print(self.renderGlobalFlagsSection(theme: theme))
        print("")
        print(theme.dim("Use `peekaboo help <command>` or `peekaboo <command> --help` for detailed options."))
    }

    private static func printCommandHelp(_ descriptor: CommanderCommandDescriptor, path: [String]) {
        let theme = self.makeHelpTheme()
        let usageCard = self.renderUsageCard(for: descriptor, path: path, theme: theme)
        let helpText = CommandHelpRenderer.renderHelp(for: descriptor.type, theme: theme)
        print(usageCard)
        print("")
        print(helpText)
        print("")
        print(self.renderGlobalFlagsSection(theme: theme))
        guard !descriptor.subcommands.isEmpty else { return }
        print("\nSubcommands:")
        let subcommandRows = self.renderCommandList(for: descriptor.subcommands, theme: theme)
        subcommandRows.forEach { print($0) }
        if let defaultName = descriptor.metadata.defaultSubcommandName {
            print("\nDefault subcommand: \(theme.command(defaultName))")
        }
    }
}

// MARK: - Usage Card + Theming

private extension CommanderRuntimeRouter {
    private static let categoryLookup: [ObjectIdentifier: CommandRegistryEntry.Category] = {
        var lookup: [ObjectIdentifier: CommandRegistryEntry.Category] = [:]
        for entry in CommandRegistry.entries {
            lookup[ObjectIdentifier(entry.type)] = entry.category
        }
        return lookup
    }()

    private static func makeHelpTheme() -> HelpTheme {
        let capabilities = TerminalDetector.detectCapabilities()
        if let forcedMode = TerminalDetector.shouldForceOutputMode() {
            return HelpTheme(useColors: forcedMode.supportsColors)
        }
        return HelpTheme(useColors: capabilities.supportsColors)
    }

    private static func renderRootUsageCard(theme: HelpTheme) -> String {
        var lines: [String] = []
        lines.append(theme.heading("Usage"))
        lines.append("  \(theme.accent("polter peekaboo <command> [options]"))")
        lines.append("")
        lines.append(theme.heading("Tip"))
        lines.append("  Run via \(theme.accent("polter peekaboo")) to ensure fresh builds.")
        return lines.joined(separator: "\n")
    }

    private static func renderUsageCard(
        for descriptor: CommanderCommandDescriptor,
        path: [String],
        theme: HelpTheme
    ) -> String {
        let usageLine = self.buildUsageLine(path: path, signature: descriptor.metadata.signature)
        var lines: [String] = []
        lines.append(theme.heading("Usage"))
        lines.append("  \(theme.accent(usageLine))")

        let abstract = descriptor.metadata.abstract.trimmingCharacters(in: .whitespacesAndNewlines)
        if !abstract.isEmpty {
            lines.append("")
            lines.append(theme.heading("Summary"))
            lines.append("  \(abstract)")
        }

        lines.append("")
        lines.append(theme.heading("Tip"))
        lines.append("  Run via \(theme.accent("polter peekaboo")) to ensure fresh builds.")
        return lines.joined(separator: "\n")
    }

    private static func globalFlagSummaries(theme: HelpTheme) -> [String] {
        [
            theme.bullet(label: "--json/-j", description: "Emit machine-readable JSON output"),
            theme.bullet(label: "--verbose/-v", description: "Enable verbose logging"),
            theme.bullet(
                label: "--log-level <level>",
                description: "trace | verbose | debug | info | warning | error | critical"
            )
        ]
    }

    private static func renderGlobalFlagsSection(theme: HelpTheme) -> String {
        var lines: [String] = []
        lines.append(theme.heading("Global Runtime Flags"))
        for entry in self.globalFlagSummaries(theme: theme) {
            lines.append("  \(entry)")
        }
        return lines.joined(separator: "\n")
    }

    private static func renderCommandList(
        for commands: [CommanderCommandDescriptor],
        theme: HelpTheme,
        indent: String = "  "
    ) -> [String] {
        let sorted = commands.sorted { $0.metadata.name < $1.metadata.name }
        let maxNameLength = sorted.map { $0.metadata.name.count }.max() ?? 0
        let columnWidth = min(max(maxNameLength, 8), 24)
        return sorted.map { descriptor in
            let name = descriptor.metadata.name
            let summary = descriptor.metadata.abstract.isEmpty ? "No description provided." : descriptor.metadata.abstract
            let paddedName: String
            if name.count >= columnWidth {
                paddedName = name
            } else {
                paddedName = name + String(repeating: " ", count: columnWidth - name.count)
            }
            let displayName = theme.command(paddedName)
            return "\(indent)\(displayName)  \(summary)"
        }
    }

    private static func buildUsageLine(path: [String], signature: CommandSignature) -> String {
        var tokens = ["polter", "peekaboo"]
        let commandPath = path.isEmpty ? ["<command>"] : path
        tokens.append(contentsOf: commandPath)

        for argument in signature.arguments {
            let placeholder = self.argumentPlaceholder(for: argument)
            tokens.append(argument.isOptional ? "[\(placeholder)]" : "<\(placeholder)>")
        }

        if !signature.options.isEmpty || !signature.flags.isEmpty {
            tokens.append("[options]")
        }

        return tokens.joined(separator: " ")
    }

    private static func argumentPlaceholder(for argument: ArgumentDefinition) -> String {
        let lowered = argument.label.replacingOccurrences(of: "_", with: "-")
        return Self.kebabCased(lowered)
    }

    private static func kebabCased(_ value: String) -> String {
        guard !value.isEmpty else { return value }
        var scalars: [Character] = []
        for character in value {
            if character.isUppercase {
                if !scalars.isEmpty && scalars.last != "-" {
                    scalars.append("-")
                }
                scalars.append(contentsOf: character.lowercased())
            } else if character == " " || character == "-" {
                if scalars.last != "-" { scalars.append("-") }
            } else {
                scalars.append(character)
            }
        }
        return String(scalars)
    }
}

struct HelpTheme {
    let useColors: Bool

    func heading(_ text: String) -> String {
        guard self.useColors else { return text }
        return "\(TerminalColor.bold)\(TerminalColor.cyan)\(text)\(TerminalColor.reset)"
    }

    func accent(_ text: String) -> String {
        guard self.useColors else { return text }
        return "\(TerminalColor.magenta)\(text)\(TerminalColor.reset)"
    }

    func command(_ text: String) -> String {
        guard self.useColors else { return text }
        return "\(TerminalColor.bold)\(text)\(TerminalColor.reset)"
    }

    func dim(_ text: String) -> String {
        guard self.useColors else { return text }
        return "\(TerminalColor.gray)\(text)\(TerminalColor.reset)"
    }

    func bullet(label: String, description: String) -> String {
        let prefix = self.useColors ? "\(TerminalColor.gray)•\(TerminalColor.reset)" : "-"
        let labelText = self.useColors ? "\(TerminalColor.bold)\(label)\(TerminalColor.reset)" : label
        return "\(prefix) \(labelText) \(description)"
    }
}

private extension CommandRegistryEntry.Category {
    var displayName: String {
        switch self {
        case .core:
            "Core Commands"
        case .interaction:
            "Interaction"
        case .system:
            "System"
        case .vision:
            "Vision"
        case .ai:
            "AI"
        case .mcp:
            "MCP"
        }
    }
}
