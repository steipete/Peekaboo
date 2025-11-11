import Foundation

@propertyWrapper
public struct Option<Value: ExpressibleFromArgument & Sendable>: CommanderMetadata, Sendable {
    public var wrappedValue: Value?
    private let nameSpecification: NameSpecification
    private let help: String?
    private let parsing: OptionParsingStrategy

    public init(
        wrappedValue: Value? = nil,
        name: NameSpecification = .automatic,
        help: String? = nil,
        parsing: OptionParsingStrategy = .singleValue)
    {
        self.wrappedValue = wrappedValue
        self.nameSpecification = name
        self.help = help
        self.parsing = parsing
    }

    public func register(label: String, signature: inout CommandSignature) {
        let definition = OptionDefinition(
            label: label,
            names: nameSpecification.resolve(defaultLabel: label),
            help: help,
            parsing: parsing
        )
        signature.append(.option(definition))
    }
}

@propertyWrapper
public struct Argument<Value: ExpressibleFromArgument & Sendable>: CommanderMetadata, Sendable {
    public var wrappedValue: Value
    private let help: String?

    public init(wrappedValue: Value, help: String? = nil) {
        self.wrappedValue = wrappedValue
        self.help = help
    }

    public func register(label: String, signature: inout CommandSignature) {
        let definition = ArgumentDefinition(
            label: label,
            help: help,
            isOptional: Value.self is OptionalProtocol.Type
        )
        signature.append(.argument(definition))
    }
}

@propertyWrapper
public struct Flag: CommanderMetadata, Sendable {
    public var wrappedValue: Bool
    private let nameSpecification: NameSpecification
    private let help: String?

    public init(wrappedValue: Bool = false, name: NameSpecification = .automatic, help: String? = nil) {
        self.wrappedValue = wrappedValue
        self.nameSpecification = name
        self.help = help
    }

    public func register(label: String, signature: inout CommandSignature) {
        let definition = FlagDefinition(
            label: label,
            names: nameSpecification.resolve(defaultLabel: label),
            help: help
        )
        signature.append(.flag(definition))
    }
}

@propertyWrapper
public struct OptionGroup<Group: CommanderParsable>: CommanderOptionGroup, Sendable {
    public var wrappedValue: Group

    public init() {
        self.wrappedValue = Group()
    }

    public init(wrappedValue: Group) {
        self.wrappedValue = wrappedValue
    }

    public func register(label: String, signature: inout CommandSignature) {
        let groupSignature = CommandSignature.describe(wrappedValue)
        signature.append(.group(groupSignature))
    }
}

// MARK: - Optional detection

private protocol OptionalProtocol {}
extension Optional: OptionalProtocol {}
