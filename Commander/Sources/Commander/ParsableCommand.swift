import Foundation

public struct CommandDescription: Sendable {
    public var commandName: String?
    public var abstract: String
    public var discussion: String?
    public var version: String?
    public var subcommands: [any ParsableCommand.Type]
    public var defaultSubcommand: (any ParsableCommand.Type)?

    public init(
        commandName: String? = nil,
        abstract: String = "",
        discussion: String? = nil,
        version: String? = nil,
        subcommands: [any ParsableCommand.Type] = [],
        defaultSubcommand: (any ParsableCommand.Type)? = nil)
    {
        self.commandName = commandName
        self.abstract = abstract
        self.discussion = discussion
        self.version = version
        self.subcommands = subcommands
        self.defaultSubcommand = defaultSubcommand
    }
}

@MainActor
public enum MainActorCommandDescription {
    public nonisolated static func describe(_ build: () -> CommandDescription) -> CommandDescription {
        build()
    }
}

@MainActor
public protocol ParsableCommand: Sendable {
    init()
    static var commandDescription: CommandDescription { get }
    mutating func run() async throws
}

public extension ParsableCommand {
    static var commandDescription: CommandDescription {
        CommandDescription()
    }

    mutating func run() async throws {}
}

public struct ValidationError: Error, LocalizedError, CustomStringConvertible, Sendable {
    private let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { self.message }
    public var description: String { self.message }
}

public struct ExitCode: Error, Equatable, CustomStringConvertible, Sendable {
    public let rawValue: Int32

    public init(_ rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let success = ExitCode(0)
    public static let failure = ExitCode(1)

    public var description: String { "ExitCode(\(self.rawValue))" }
}
