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
        if let alias = try Self.resolveAgentPermissionAlias(arguments: trimmedArgs, originalArgv: argv) {
            return alias
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
            let tokens = Array(arguments.dropFirst())
            if self.handleAgentPermissionHelp(tokens: tokens) {
                return true
            }
            let path = self.resolveHelpPath(from: tokens, descriptors: descriptors)
            try self.printHelp(for: path, descriptors: descriptors)
            return true
        }

        if let index = arguments.firstIndex(where: { self.isHelpToken($0) }) {
            let tokens = Array(arguments.prefix(index))
            if self.handleAgentPermissionHelp(tokens: tokens) {
                return true
            }
            let path = self.resolveHelpPath(from: tokens, descriptors: descriptors)
            try self.printHelp(for: path, descriptors: descriptors)
            return true
        }

        return false
    }

    private static func handleAgentPermissionHelp(tokens: [String]) -> Bool {
        guard tokens.count >= 2,
              tokens[0].caseInsensitiveCompare("agent") == .orderedSame,
              tokens[1].caseInsensitiveCompare("permission") == .orderedSame else {
            return false
        }

        let rootDescriptor = CommanderRegistryBuilder.buildDescriptor(for: PermissionCommand.self)
        let permissionPath = ["permission"] + tokens.dropFirst(2)
        guard let descriptor = self.findDescriptor(in: [rootDescriptor], matching: permissionPath) else {
            return false
        }
        self.printCommandHelp(descriptor, path: ["agent"] + permissionPath)
        return true
    }

    private static func resolveAgentPermissionAlias(
        arguments: [String],
        originalArgv: [String]
    ) throws -> CommanderResolvedCommand? {
        guard arguments.count >= 2,
              arguments[0].caseInsensitiveCompare("agent") == .orderedSame,
              arguments[1].caseInsensitiveCompare("permission") == .orderedSame else {
            return nil
        }

        let rootDescriptor = CommanderRegistryBuilder.buildDescriptor(for: PermissionCommand.self)
        let executable = originalArgv.first ?? "peekaboo"
        let aliasArgv = [executable, "permission"] + arguments.dropFirst(2)
        let program = Program(descriptors: [rootDescriptor.metadata])
        let invocation = try program.resolve(argv: Array(aliasArgv))
        guard let descriptor = self.findDescriptor(in: [rootDescriptor], matching: invocation.path) else {
            throw CommanderProgramError.unknownCommand(invocation.path.joined(separator: ":"))
        }
        return CommanderResolvedCommand(
            metadata: descriptor.metadata,
            type: descriptor.type,
            parsedValues: invocation.parsedValues
        )
    }

    private static func resolveHelpPath(
        from tokens: [String],
        descriptors: [CommanderCommandDescriptor]
    ) -> [String] {
        guard !tokens.isEmpty else { return [] }

        for length in stride(from: tokens.count, through: 1, by: -1) {
            let candidate = Array(tokens.prefix(length))
            if self.findDescriptor(in: descriptors, matching: candidate) != nil {
                return candidate
            }
        }

        // Preserve previous behavior for unknown paths: let printHelp throw with the original tokens.
        return tokens
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
        if !descriptor.metadata.subcommands.isEmpty {
            throw CommanderProgramError.missingSubcommand(command: token)
        }
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
