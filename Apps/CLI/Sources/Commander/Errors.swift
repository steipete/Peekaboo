import Foundation

public enum CommanderError: Error, CustomStringConvertible, Sendable, Equatable {
    case unknownOption(String)
    case missingValue(option: String)
    case unexpectedArgument(String)
    case invalidValue(option: String, value: String)

    public var description: String {
        switch self {
        case .unknownOption(let name):
            return "Unknown option \(name)"
        case .missingValue(let option):
            return "Missing value for option \(option)"
        case .unexpectedArgument(let value):
            return "Unexpected argument: \(value)"
        case .invalidValue(let option, let value):
            return "Invalid value '\(value)' for option \(option)"
        }
    }
}
