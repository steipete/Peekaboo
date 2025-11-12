import Foundation

/// Errors emitted by ``CommandParser`` when raw arguments cannot be bound to a
/// ``CommandSignature``.
public enum CommanderError: Error, CustomStringConvertible, Sendable, Equatable {
    case unknownOption(String)
    case missingValue(option: String)
    case unexpectedArgument(String)
    case invalidValue(option: String, value: String)

    public var description: String {
        switch self {
        case let .unknownOption(name):
            "Unknown option \(name)"
        case let .missingValue(option):
            "Missing value for option \(option)"
        case let .unexpectedArgument(value):
            "Unexpected argument: \(value)"
        case let .invalidValue(option, value):
            "Invalid value '\(value)' for option \(option)"
        }
    }
}
