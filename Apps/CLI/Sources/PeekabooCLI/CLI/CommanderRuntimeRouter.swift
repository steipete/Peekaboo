import Commander

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

    private static func isHelpToken(_ token: String) -> Bool {
        token == "--help" || token == "-h"
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
        self.printCommandHelp(descriptor)
    }

    private static func printRootHelp(descriptors: [CommanderCommandDescriptor]) {
        print("Peekaboo CLI Commands:\n")
        for descriptor in descriptors.sorted(by: { $0.metadata.name < $1.metadata.name }) {
            let abstract = descriptor.metadata.abstract.isEmpty ? "No description provided." : descriptor.metadata
                .abstract
            print("  \(descriptor.metadata.name)\t\(abstract)")
        }
        print("\nUse `peekaboo help <command>` or `peekaboo <command> --help` for detailed options.")
    }

    private static func printCommandHelp(_ descriptor: CommanderCommandDescriptor) {
        let helpText = CommandHelpRenderer.renderHelp(for: descriptor.type)
        print(helpText)
        guard !descriptor.subcommands.isEmpty else { return }
        print("\nSubcommands:")
        for child in descriptor.subcommands.sorted(by: { $0.metadata.name < $1.metadata.name }) {
            let abstract = child.metadata.abstract.isEmpty ? "No description provided." : child.metadata.abstract
            print("  \(child.metadata.name)\t\(abstract)")
        }
        if let defaultName = descriptor.metadata.defaultSubcommandName {
            print("\nDefault subcommand: \(defaultName)")
        }
    }
}
