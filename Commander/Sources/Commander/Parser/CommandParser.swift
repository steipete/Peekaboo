import Foundation

public struct ParsedValues: Sendable, Equatable {
    public var positional: [String]
    public var options: [String: [String]]
    public var flags: Set<String>

    public init(positional: [String], options: [String: [String]], flags: Set<String>) {
        self.positional = positional
        self.options = options
        self.flags = flags
    }
}

public struct CommandParser {
    let signature: CommandSignature

    public init(signature: CommandSignature) {
        self.signature = signature
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    public func parse(arguments: [String]) throws -> ParsedValues {
        let tokens = CommandLineTokenizer.tokenize(arguments)
        var positional: [String] = []
        var options: [String: [String]] = [:]
        var flags = Set<String>()

        let optionLookup = Self.buildOptionLookup(self.signature.options)
        let flagLookup = Self.buildFlagLookup(self.signature.flags)
        let remainingOption = self.signature.options.first(where: { $0.parsing == .remaining })

        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            index += 1
            switch token {
            case let .option(name):
                if let definition = optionLookup[name] {
                    var consumed: [String] = []
                    switch definition.parsing {
                    case .singleValue:
                        guard index < tokens.count else {
                            throw CommanderError.missingValue(option: name)
                        }
                        if case let .argument(value) = tokens[index] {
                            consumed.append(value)
                            index += 1
                        } else {
                            throw CommanderError.missingValue(option: name)
                        }
                    case .upToNextOption:
                        parsingLoop: while index < tokens.count {
                            switch tokens[index] {
                            case let .argument(value):
                                consumed.append(value)
                                index += 1
                            case .terminator:
                                break parsingLoop
                            case .option, .flag:
                                break parsingLoop
                            }
                        }
                    case .remaining:
                        while index < tokens.count {
                            if case let .argument(value) = tokens[index] {
                                consumed.append(value)
                            }
                            index += 1
                        }
                    }
                    options[definition.label, default: []].append(contentsOf: consumed)
                } else if let flagLabel = flagLookup[name] {
                    flags.insert(flagLabel)
                } else {
                    throw CommanderError.unknownOption("--" + name)
                }
            case let .flag(name):
                guard let flagLabel = flagLookup[name] else {
                    throw CommanderError.unknownOption("-" + name)
                }
                flags.insert(flagLabel)
            case let .argument(value):
                positional.append(value)
            case .terminator:
                if let remainingOption {
                    var tail: [String] = []
                    while index < tokens.count {
                        if case let .argument(value) = tokens[index] {
                            tail.append(value)
                        }
                        index += 1
                    }
                    if !tail.isEmpty {
                        options[remainingOption.label, default: []].append(contentsOf: tail)
                    }
                } else {
                    while index < tokens.count {
                        if case let .argument(value) = tokens[index] {
                            positional.append(value)
                        }
                        index += 1
                    }
                }
            }
        }

        return ParsedValues(positional: positional, options: options, flags: flags)
    }

    // swiftlint:enable cyclomatic_complexity function_body_length

    private static func buildOptionLookup(_ definitions: [OptionDefinition]) -> [String: OptionDefinition] {
        var lookup: [String: OptionDefinition] = [:]
        for definition in definitions {
            for name in definition.names {
                switch name {
                case let .long(longName):
                    lookup[longName] = definition
                case let .short(shortName):
                    lookup[String(shortName)] = definition
                }
            }
        }
        return lookup
    }

    private static func buildFlagLookup(_ definitions: [FlagDefinition]) -> [String: String] {
        var lookup: [String: String] = [:]
        for definition in definitions {
            for name in definition.names {
                switch name {
                case let .long(longName):
                    lookup[longName] = definition.label
                case let .short(shortName):
                    lookup[String(shortName)] = definition.label
                }
            }
        }
        return lookup
    }
}
