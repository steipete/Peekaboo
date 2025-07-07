import Foundation

// String extension from Scanner
extension String {
    subscript (offset: Int) -> Character {
        return self[index(startIndex, offsetBy: offset)]
    }
    func range(from range: NSRange) -> Range<String.Index>? {
        return Range(range, in: self)
    }
    func range(from range: Range<String.Index>) -> NSRange {
        return NSRange(range, in: self)
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
        case .some(let value): return "\(value)"
        case .none: return "nil"
        }
    }
}

extension String {
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count > length {
            return String(self.prefix(length - trailing.count)) + trailing
        } else {
            return self
        }
    }

    private static let MAX_LOG_ABBREV_LENGTH = 50

    func truncatedToMaxLogAbbrev() -> String {
        if self.count > Self.MAX_LOG_ABBREV_LENGTH {
            return String(self.prefix(Self.MAX_LOG_ABBREV_LENGTH - 3)) + "..."
        } else {
            return self
        }
    }
}
