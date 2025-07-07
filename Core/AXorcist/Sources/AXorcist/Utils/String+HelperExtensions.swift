import Foundation

// String extension from Scanner
extension String {
    subscript(offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }

    func range(from range: NSRange) -> Range<String.Index>? {
        Range(range, in: self)
    }

    func range(from range: Range<String.Index>) -> NSRange {
        NSRange(range, in: self)
    }

    var firstLine: String? {
        var line: String?
        self.enumerateLines {
            line = $0
            $1 = true
        }
        return line
    }
}

extension Optional {
    var orNilString: String {
        switch self {
        case let .some(value): "\(value)"
        case .none: "nil"
        }
    }
}

extension String {
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count > length {
            String(self.prefix(length - trailing.count)) + trailing
        } else {
            self
        }
    }

    private static let maxLogAbbrevLength = 50

    func truncatedToMaxLogAbbrev() -> String {
        if self.count > Self.maxLogAbbrevLength {
            String(self.prefix(Self.maxLogAbbrevLength - 3)) + "..."
        } else {
            self
        }
    }
}
