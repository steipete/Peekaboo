import Foundation

// MARK: - Command Signature & Definitions

public struct CommandSignature: Sendable {
    public private(set) var arguments: [ArgumentDefinition]
    public private(set) var options: [OptionDefinition]
    public private(set) var flags: [FlagDefinition]
    public private(set) var optionGroups: [CommandSignature]

    public init(
        arguments: [ArgumentDefinition] = [],
        options: [OptionDefinition] = [],
        flags: [FlagDefinition] = [],
        optionGroups: [CommandSignature] = [])
    {
        self.arguments = arguments
        self.options = options
        self.flags = flags
        self.optionGroups = optionGroups
    }

    mutating func append(_ component: CommandComponent) {
        switch component {
        case let .argument(definition):
            self.arguments.append(definition)
        case let .option(definition):
            self.options.append(definition)
        case let .flag(definition):
            self.flags.append(definition)
        case let .group(signature):
            self.optionGroups.append(signature)
        }
    }

    public static func describe(_ command: some Any) -> CommandSignature {
        var signature = CommandSignature()
        Self.inspect(value: command, into: &signature)
        return signature
    }

    private static func inspect(value: Any, into signature: inout CommandSignature) {
        let mirror = Mirror(reflecting: value)
        for child in mirror.children {
            guard let label = child.label else { continue }
            if let registrable = child.value as? CommanderMetadata {
                registrable.register(label: label, signature: &signature)
            } else if let optionGroup = child.value as? CommanderOptionGroup {
                optionGroup.register(label: label, signature: &signature)
            }
        }
    }
}

extension CommandSignature {
    public func flattened() -> CommandSignature {
        var combined = CommandSignature(
            arguments: self.arguments,
            options: self.options,
            flags: self.flags)
        for group in self.optionGroups {
            let flattenedGroup = group.flattened()
            combined.arguments.append(contentsOf: flattenedGroup.arguments)
            combined.options.append(contentsOf: flattenedGroup.options)
            combined.flags.append(contentsOf: flattenedGroup.flags)
        }
        return combined
    }

    public func withStandardRuntimeFlags() -> CommandSignature {
        var copy = self
        let verboseFlag = FlagDefinition(
            label: "verbose",
            names: [.short("v"), .long("verbose")],
            help: "Enable verbose logging")
        let jsonFlag = FlagDefinition(
            label: "jsonOutput",
            names: [.long("json-output"), .long("jsonOutput")],
            help: "Emit machine-readable JSON output")
        let logLevelOption = OptionDefinition(
            label: "logLevel",
            names: [.long("log-level"), .long("logLevel")],
            help: "Set log level (trace|verbose|debug|info|warning|error|critical)",
            parsing: .singleValue
        )
        copy.flags.append(contentsOf: [verboseFlag, jsonFlag])
        copy.options.append(logLevelOption)
        return copy
    }
}

public enum CommandComponent: Sendable {
    case argument(ArgumentDefinition)
    case option(OptionDefinition)
    case flag(FlagDefinition)
    case group(CommandSignature)
}

public struct OptionDefinition: Sendable, Equatable {
    public let label: String
    public let names: [CommanderName]
    public let help: String?
    public let parsing: OptionParsingStrategy
}

public struct ArgumentDefinition: Sendable, Equatable {
    public let label: String
    public let help: String?
    public let isOptional: Bool
}

public struct FlagDefinition: Sendable, Equatable {
    public let label: String
    public let names: [CommanderName]
    public let help: String?
}

extension OptionDefinition {
    public static func make(
        label: String,
        names: [CommanderName],
        help: String? = nil,
        parsing: OptionParsingStrategy = .singleValue) -> OptionDefinition
    {
        OptionDefinition(label: label, names: names, help: help, parsing: parsing)
    }
}

extension FlagDefinition {
    public static func make(
        label: String,
        names: [CommanderName],
        help: String? = nil) -> FlagDefinition
    {
        FlagDefinition(label: label, names: names, help: help)
    }
}

extension ArgumentDefinition {
    public static func make(
        label: String,
        help: String? = nil,
        isOptional: Bool = false) -> ArgumentDefinition
    {
        ArgumentDefinition(label: label, help: help, isOptional: isOptional)
    }
}

public enum OptionParsingStrategy: Sendable, Equatable {
    case singleValue
    case upToNextOption
    case remaining
}

// MARK: - Commander Metadata Protocols

protocol CommanderMetadata {
    func register(label: String, signature: inout CommandSignature)
}

protocol CommanderOptionGroup {
    func register(label: String, signature: inout CommandSignature)
}

/// Marker protocol adopted by option-group structs to allow Commander to
/// instantiate nested groups automatically.
public protocol CommanderParsable {
    init()
}
