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
    case longName(String)
    case shortAndLong
    case customShort(Character, allowingJoined: Bool)
    case customLong(String)

    public static var long: NameSpecification { .automatic }

    public static func long(_ value: String) -> NameSpecification {
        .longName(value)
    }

    func resolve(defaultLabel: String) -> [CommanderName] {
        switch self {
        case .automatic:
            [.long(Self.normalize(defaultLabel))]
        case let .short(char):
            [.short(char)]
        case let .longName(name):
            [.long(name)]
        case .shortAndLong:
            [.short(Self.firstCharacter(in: defaultLabel)), .long(Self.normalize(defaultLabel))]
        case let .customShort(char, _):
            [.short(char)]
        case let .customLong(name):
            [.long(name)]
        }
    }

    private static func normalize(_ label: String) -> String {
        guard !label.isEmpty else { return label }

        let scalars = Array(label.unicodeScalars)
        let uppercase = CharacterSet.uppercaseLetters
        let lowercase = CharacterSet.lowercaseLetters
        let digits = CharacterSet.decimalDigits
        let separators = CharacterSet(charactersIn: "-_ ")

        var output = ""

        func appendHyphenIfNeeded() {
            if output.last != "-", !output.isEmpty {
                output.append("-")
            }
        }

        for index in scalars.indices {
            let scalar = scalars[index]

            if separators.contains(scalar) {
                appendHyphenIfNeeded()
                continue
            }

            let isUpper = uppercase.contains(scalar)
            let isDigit = digits.contains(scalar)

            if isUpper {
                if index > 0 {
                    let previous = scalars[index - 1]
                    let prevIsLowerOrDigit = lowercase.contains(previous) || digits.contains(previous)
                    if prevIsLowerOrDigit {
                        appendHyphenIfNeeded()
                    } else if uppercase.contains(previous), index + 1 < scalars.count {
                        let next = scalars[index + 1]
                        if lowercase.contains(next) {
                            appendHyphenIfNeeded()
                        }
                    }
                }
                output.append(contentsOf: String(scalar).lowercased())
            } else if isDigit {
                output.append(Character(scalar))
            } else {
                output.append(contentsOf: String(scalar).lowercased())
            }
        }

        return output.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func firstCharacter(in label: String) -> Character {
        label.first ?? "x"
    }
}
