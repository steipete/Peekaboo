import Foundation

@propertyWrapper
public struct Option<Value: ExpressibleFromArgument>: CommanderMetadata {
    private var storage: Value?
    private let nameSpecifications: [NameSpecification]
    private let help: String?
    private let parsing: OptionParsingStrategy

    public var wrappedValue: Value {
        get {
            if let storage {
                return storage
            }
            if Value.self is OptionalProtocol.Type {
                return (Optional<Any>.none as! Value)
            }
            fatalError("Commander option '\(Value.self)' accessed before being bound")
        }
        set {
            storage = newValue
        }
    }

    public init(
        wrappedValue: Value,
        name: NameSpecification = .automatic,
        help: String? = nil,
        parsing: OptionParsingStrategy = .singleValue)
    {
        self.storage = wrappedValue
        self.nameSpecifications = [name]
        self.help = help
        self.parsing = parsing
    }

    public init(
        name: NameSpecification = .automatic,
        help: String? = nil,
        parsing: OptionParsingStrategy = .singleValue)
    {
        self.storage = nil
        self.nameSpecifications = [name]
        self.help = help
        self.parsing = parsing
    }

    public init(
        names: [NameSpecification],
        help: String? = nil,
        parsing: OptionParsingStrategy = .singleValue)
    {
        self.storage = nil
        self.nameSpecifications = names
        self.help = help
        self.parsing = parsing
    }

    public func register(label: String, signature: inout CommandSignature) {
        let resolvedLabel = Self.sanitize(label)
        let resolvedNames = nameSpecifications.flatMap { $0.resolve(defaultLabel: resolvedLabel) }
        let definition = OptionDefinition(
            label: resolvedLabel,
            names: resolvedNames,
            help: help,
            parsing: parsing
        )
        signature.append(.option(definition))
    }

    private static func sanitize(_ label: String) -> String {
        label.hasPrefix("_") ? String(label.dropFirst()) : label
    }
}

extension Option: Sendable where Value: Sendable {}

@propertyWrapper
public struct Argument<Value: ExpressibleFromArgument>: CommanderMetadata {
    private var storage: Value?
    private let help: String?

    public var wrappedValue: Value {
        get {
            guard let storage else {
                fatalError("Commander argument '\(Value.self)' accessed before being bound")
            }
            return storage
        }
        set {
            storage = newValue
        }
    }

    public init(wrappedValue: Value, help: String? = nil) {
        self.storage = wrappedValue
        self.help = help
    }

    public init(help: String? = nil) {
        self.storage = nil
        self.help = help
    }

    public init() {
        self.init(help: nil)
    }

    public func register(label: String, signature: inout CommandSignature) {
        let resolvedLabel = Self.sanitize(label)
        let definition = ArgumentDefinition(
            label: resolvedLabel,
            help: help,
            isOptional: Value.self is OptionalProtocol.Type
        )
        signature.append(.argument(definition))
    }

    private static func sanitize(_ label: String) -> String {
        label.hasPrefix("_") ? String(label.dropFirst()) : label
    }
}

extension Argument: Sendable where Value: Sendable {}

@propertyWrapper
public struct Flag: CommanderMetadata, Sendable {
    public var wrappedValue: Bool
    private let nameSpecifications: [NameSpecification]
    private let help: String?

    public init(wrappedValue: Bool = false, name: NameSpecification = .automatic, help: String? = nil) {
        self.wrappedValue = wrappedValue
        self.nameSpecifications = [name]
        self.help = help
    }

    public init(wrappedValue: Bool = false, names: [NameSpecification], help: String? = nil) {
        self.wrappedValue = wrappedValue
        self.nameSpecifications = names
        self.help = help
    }

    public func register(label: String, signature: inout CommandSignature) {
        let resolvedLabel = Self.sanitize(label)
        let definition = FlagDefinition(
            label: resolvedLabel,
            names: nameSpecifications.flatMap { $0.resolve(defaultLabel: resolvedLabel) },
            help: help
        )
        signature.append(.flag(definition))
    }

    private static func sanitize(_ label: String) -> String {
        label.hasPrefix("_") ? String(label.dropFirst()) : label
    }
}

@propertyWrapper
public struct OptionGroup<Group: CommanderParsable>: CommanderOptionGroup {
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

extension OptionGroup: Sendable where Group: Sendable {}

// MARK: - Optional detection

private protocol OptionalProtocol {}
extension Optional: OptionalProtocol {}
