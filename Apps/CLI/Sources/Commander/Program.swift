import Foundation

public struct CommandDescriptor: Sendable {
    public let name: String
    public let abstract: String
    public let discussion: String?
    public let signature: CommandSignature

    public init(name: String, abstract: String, discussion: String?, signature: CommandSignature) {
        self.name = name
        self.abstract = abstract
        self.discussion = discussion
        self.signature = signature
    }
}

public struct CommandInvocation: Sendable {
    public let descriptor: CommandDescriptor
    public let parsedValues: ParsedValues
}

public enum CommanderProgramError: Error, CustomStringConvertible, Sendable {
    case missingCommand
    case unknownCommand(String)
    case parsingError(CommanderError)

    public var description: String {
        switch self {
        case .missingCommand:
            return "No command specified"
        case .unknownCommand(let name):
            return "Unknown command '\(name)'"
        case .parsingError(let error):
            return error.description
        }
    }
}

public struct Program: Sendable {
    private let descriptors: [String: CommandDescriptor]

    public init(descriptors: [CommandDescriptor]) {
        self.descriptors = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.name, $0) })
    }

    public func resolve(argv: [String]) throws -> CommandInvocation {
        var args = argv
        if !args.isEmpty, args[0].hasSuffix("peekaboo") {
            args.removeFirst()
        }
        guard let commandName = args.first else {
            throw CommanderProgramError.missingCommand
        }
        guard let descriptor = descriptors[commandName] else {
            throw CommanderProgramError.unknownCommand(commandName)
        }
        let parser = CommandParser(signature: descriptor.signature)
        do {
            let parsed = try parser.parse(arguments: Array(args.dropFirst()))
            return CommandInvocation(descriptor: descriptor, parsedValues: parsed)
        } catch let error as CommanderError {
            throw CommanderProgramError.parsingError(error)
        }
    }
}
