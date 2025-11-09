//
//  CommandRegistry.swift
//  PeekabooCLI
//

@preconcurrency import ArgumentParser

struct CommandRegistryEntry {
    enum Category: String, Codable, CaseIterable {
        case core
        case interaction
        case system
        case vision
        case ai
        case mcp
    }

    let type: ParsableCommand.Type
    let category: Category
}

struct CommandDefinition: Codable {
    let name: String
    let typeName: String
    let category: CommandRegistryEntry.Category
    let abstract: String
    let discussion: String?
    let version: String?
    let subcommandCount: Int
}

enum CommandRegistry {
    static let entries: [CommandRegistryEntry] = [
        .init(type: ImageCommand.self, category: .core),
        .init(type: ListCommand.self, category: .core),
        .init(type: ToolsCommand.self, category: .core),
        .init(type: ConfigCommand.self, category: .core),
        .init(type: PermissionsCommand.self, category: .core),
        .init(type: LearnCommand.self, category: .core),
        .init(type: SeeCommand.self, category: .vision),
        .init(type: ClickCommand.self, category: .interaction),
        .init(type: TypeCommand.self, category: .interaction),
        .init(type: PressCommand.self, category: .interaction),
        .init(type: ScrollCommand.self, category: .interaction),
        .init(type: HotkeyCommand.self, category: .interaction),
        .init(type: SwipeCommand.self, category: .interaction),
        .init(type: DragCommand.self, category: .interaction),
        .init(type: MoveCommand.self, category: .interaction),
        .init(type: RunCommand.self, category: .core),
        .init(type: SleepCommand.self, category: .core),
        .init(type: CleanCommand.self, category: .core),
        .init(type: WindowCommand.self, category: .system),
        .init(type: MenuCommand.self, category: .system),
        .init(type: MenuBarCommand.self, category: .system),
        .init(type: AppCommand.self, category: .system),
        .init(type: DockCommand.self, category: .system),
        .init(type: DialogCommand.self, category: .system),
        .init(type: SpaceCommand.self, category: .system),
        .init(type: AgentCommand.self, category: .ai),
        .init(type: MCPCommand.self, category: .mcp),
    ]

    static var rootCommandTypes: [ParsableCommand.Type] {
        self.entries.map(\.type)
    }

    static func definitions() -> [CommandDefinition] {
        entries.map { entry in
            let configuration = entry.type.configuration
            return CommandDefinition(
                name: configuration.commandName ?? String(describing: entry.type),
                typeName: String(reflecting: entry.type),
                category: entry.category,
                abstract: configuration.abstract ?? "",
                discussion: configuration.discussion,
                version: configuration.version,
                subcommandCount: configuration.subcommands.count
            )
        }
    }
}
