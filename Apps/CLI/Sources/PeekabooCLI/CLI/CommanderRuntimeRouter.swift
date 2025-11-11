import Commander
@preconcurrency import ArgumentParser

struct CommanderResolvedCommand {
    let metadata: CommandDescriptor
    let type: any ParsableCommand.Type
    let parsedValues: ParsedValues
}

@MainActor
enum CommanderRuntimeRouter {
    static func resolve(argv: [String]) throws -> CommanderResolvedCommand {
        let descriptors = CommanderRegistryBuilder.buildDescriptors()
        let program = Program(descriptors: descriptors.map { $0.metadata })
        let invocation = try program.resolve(argv: argv)
        guard let descriptor = descriptors.first(where: { $0.metadata.name == invocation.descriptor.name }) else {
            throw CommanderProgramError.unknownCommand(invocation.descriptor.name)
        }
        return CommanderResolvedCommand(
            metadata: invocation.descriptor,
            type: descriptor.type,
            parsedValues: invocation.parsedValues
        )
    }
}
