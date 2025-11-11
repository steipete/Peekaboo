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
        case .argument(let definition):
            arguments.append(definition)
        case .option(let definition):
            options.append(definition)
        case .flag(let definition):
            flags.append(definition)
        case .group(let signature):
            optionGroups.append(signature)
        }
    }

    public static func describe<T>(_ command: T) -> CommandSignature {
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
    func withStandardRuntimeFlags() -> CommandSignature {
        var copy = self
        let verboseFlag = FlagDefinition(
            label: "verbose",
            names: [.short("v"), .long("verbose")],
            help: "Enable verbose logging"
        )
        let jsonFlag = FlagDefinition(
            label: "jsonOutput",
            names: [.long("json-output"), .long("jsonOutput")],
            help: "Emit machine-readable JSON output"
        )
        copy.flags.append(contentsOf: [verboseFlag, jsonFlag])
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
public protocol CommanderParsable: Sendable {
    init()
}
