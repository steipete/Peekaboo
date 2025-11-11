import Commander

/// Describes a CLI command in terms Commander can understand without yet replacing
/// the existing ArgumentParser runtime.
struct CommanderCommandDescriptor: Sendable {
    let name: String
    let category: CommandRegistryEntry.Category
    let type: any ParsableCommand.Type
    let abstract: String
    let discussion: String?
    let signature: CommandSignature
}

@MainActor
enum CommanderRegistryBuilder {
    static func buildDescriptors() -> [CommanderCommandDescriptor] {
        CommandRegistry.entries.map { entry in
            let configuration = entry.type.configuration
            let commandInstance = entry.type.init()
            let signature = CommandSignature.describe(commandInstance)
            return CommanderCommandDescriptor(
                name: configuration.commandName ?? String(describing: entry.type),
                category: entry.category,
                type: entry.type,
                abstract: configuration.abstract,
                discussion: configuration.discussion,
                signature: signature
            )
        }
    }
}
