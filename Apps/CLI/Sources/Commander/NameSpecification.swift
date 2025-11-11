import Foundation

/// Represents a specific flag/option name (short or long).
public enum CommanderName: Equatable, Sendable {
    case short(Character)
    case long(String)
}

/// Mimics ArgumentParser's name specification convenience API.
public enum NameSpecification: Sendable {
    case automatic
    case short(Character)
    case long(String)
    case shortAndLong
    case customShort(Character, allowingJoined: Bool)
    case customLong(String)

    func resolve(defaultLabel: String) -> [CommanderName] {
        switch self {
        case .automatic:
            return [.long(Self.normalize(defaultLabel))]
        case .short(let char):
            return [.short(char)]
        case .long(let name):
            return [.long(name)]
        case .shortAndLong:
            return [.short(Self.firstCharacter(in: defaultLabel)), .long(Self.normalize(defaultLabel))]
        case .customShort(let char, _):
            return [.short(char)]
        case .customLong(let name):
            return [.long(name)]
        }
    }

    private static func normalize(_ label: String) -> String {
        label.replacingOccurrences(of: "_", with: "-")
    }

    private static func firstCharacter(in label: String) -> Character {
        label.first ?? "x"
    }
}
