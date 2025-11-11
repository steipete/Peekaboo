import Commander
@preconcurrency import ArgumentParser

@MainActor
enum CommanderRegistryBuilder {
    static func buildDescriptors() -> [CommandDescriptor] {
        CommandRegistry.entries.map { entry in
            let configuration = entry.type.configuration
            let commandInstance = entry.type.init()
            let signature = CommandSignature.describe(commandInstance)
            return CommandDescriptor(
                name: configuration.commandName ?? String(describing: entry.type),
                abstract: configuration.abstract,
                discussion: configuration.discussion,
                signature: signature
            )
        }
    }
}
