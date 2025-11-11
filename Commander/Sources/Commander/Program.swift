import Foundation

public struct CommandDescriptor: Sendable {
    public let name: String
    public let abstract: String
    public let discussion: String?
    public let signature: CommandSignature
    public let subcommands: [CommandDescriptor]
    public let defaultSubcommandName: String?

    public init(
        name: String,
        abstract: String,
        discussion: String?,
        signature: CommandSignature,
        subcommands: [CommandDescriptor] = [],
        defaultSubcommandName: String? = nil)
    {
        self.name = name
        self.abstract = abstract
        self.discussion = discussion
        self.signature = signature
        self.subcommands = subcommands
        self.defaultSubcommandName = defaultSubcommandName
    }
}

public struct CommandInvocation: Sendable {
    public let descriptor: CommandDescriptor
    public let parsedValues: ParsedValues
    public let path: [String]
}

public enum CommanderProgramError: Error, CustomStringConvertible, Sendable, Equatable {
    case missingCommand
    case unknownCommand(String)
    case missingSubcommand(command: String)
    case unknownSubcommand(command: String, name: String)
    case parsingError(CommanderError)

    public var description: String {
        switch self {
        case .missingCommand:
            "No command specified"
        case let .unknownCommand(name):
            "Unknown command '\(name)'"
        case let .missingSubcommand(command):
            "Command '\(command)' requires a subcommand"
        case let .unknownSubcommand(command, name):
            "Unknown subcommand '\(name)' for command '\(command)'"
        case let .parsingError(error):
            error.description
        }
    }
}

public struct Program: Sendable {
    private let descriptorLookup: [String: CommandDescriptor]

    public init(descriptors: [CommandDescriptor]) {
        self.descriptorLookup = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.name, $0) })
    }

    public func resolve(argv: [String]) throws -> CommandInvocation {
        var args = argv
        if !args.isEmpty, args[0].hasSuffix("peekaboo") {
            args.removeFirst()
        }
        guard let commandName = args.first else {
            throw CommanderProgramError.missingCommand
        }
        guard var descriptor = descriptorLookup[commandName] else {
            throw CommanderProgramError.unknownCommand(commandName)
        }
        args.removeFirst()
        var remainingArguments = args
        var commandPath = [commandName]
        descriptor = try self.resolveDescriptor(descriptor, arguments: &remainingArguments, path: &commandPath)
        let parser = CommandParser(signature: descriptor.signature)
        do {
            let parsed = try parser.parse(arguments: remainingArguments)
            return CommandInvocation(descriptor: descriptor, parsedValues: parsed, path: commandPath)
        } catch let error as CommanderError {
            throw CommanderProgramError.parsingError(error)
        }
    }

    private func resolveDescriptor(
        _ descriptor: CommandDescriptor,
        arguments: inout [String],
        path: inout [String]) throws -> CommandDescriptor
    {
        guard !descriptor.subcommands.isEmpty else {
            return descriptor
        }

        if arguments.isEmpty {
            if let defaultChild = lookupDefaultSubcommand(for: descriptor) {
                path.append(defaultChild.name)
                return try self.resolveDescriptor(defaultChild, arguments: &arguments, path: &path)
            }
            throw CommanderProgramError.missingSubcommand(command: descriptor.name)
        }

        let nextToken = arguments[0]
        if nextToken.isCommanderOptionToken {
            if let defaultChild = lookupDefaultSubcommand(for: descriptor) {
                path.append(defaultChild.name)
                return try self.resolveDescriptor(defaultChild, arguments: &arguments, path: &path)
            }
            throw CommanderProgramError.missingSubcommand(command: descriptor.name)
        }

        guard let match = descriptor.subcommands.first(where: { $0.name == nextToken }) else {
            throw CommanderProgramError.unknownSubcommand(command: descriptor.name, name: nextToken)
        }
        arguments.removeFirst()
        path.append(match.name)
        return try self.resolveDescriptor(match, arguments: &arguments, path: &path)
    }

    private func lookupDefaultSubcommand(for descriptor: CommandDescriptor) -> CommandDescriptor? {
        guard let name = descriptor.defaultSubcommandName else { return nil }
        return descriptor.subcommands.first(where: { $0.name == name })
    }
}

extension String {
    fileprivate var isCommanderOptionToken: Bool {
        guard let first = self.first else { return false }
        return first == "-"
    }
}
