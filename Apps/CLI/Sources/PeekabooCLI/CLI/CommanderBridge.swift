import Commander
@preconcurrency import ArgumentParser

struct CommanderCommandDescriptor {
    let metadata: CommandDescriptor
    let type: any ParsableCommand.Type
}

@MainActor
enum CommanderRegistryBuilder {
    static func buildDescriptors() -> [CommanderCommandDescriptor] {
        CommandRegistry.entries.map { entry in
            let configuration = entry.type.configuration
            let commandInstance = entry.type.init()
            let signature = CommandSignature.describe(commandInstance)
            let metadata = CommandDescriptor(
                name: configuration.commandName ?? String(describing: entry.type),
                abstract: configuration.abstract,
                discussion: configuration.discussion,
                signature: signature
            )
            return CommanderCommandDescriptor(metadata: metadata, type: entry.type)
        }
    }
}
