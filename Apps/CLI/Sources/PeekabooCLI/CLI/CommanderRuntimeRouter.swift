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
}
