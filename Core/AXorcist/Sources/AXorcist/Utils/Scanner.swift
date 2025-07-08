// Scanner.swift - Custom scanner implementation (Scanner)

import Foundation

/// A lightweight string scanning utility for parsing text.
///
/// `Scanner` provides efficient character-by-character scanning of strings with
/// support for character sets, string literals, and pattern matching. It maintains
/// a current position and allows for forward scanning operations.
///
/// ## Overview
///
/// The scanner:
/// - Maintains a current position in the string
/// - Supports scanning based on character sets
/// - Can scan for specific strings or patterns
/// - Provides utilities for identifier parsing
/// - Allows peeking at upcoming characters without advancing
///
/// This is an internal utility class used by AXorcist for parsing various string formats.
///
/// ## Topics
///
/// ### Creating a Scanner
///
/// - ``init(string:)``
///
/// ### Scanner State
///
/// - ``string``
/// - ``location``
/// - ``isAtEnd``
/// - ``remainingString``
///
/// ### Character Set Scanning
///
/// - ``scanUpToCharacters(in:)``
/// - ``scanCharacters(from:)``
///
/// ### String Scanning
///
/// - ``scanString(_:)``
/// - ``scanUpToString(_:)``
///
/// ### Character Sets
///
/// - ``identifierFirstCharSet``
/// - ``identifierFollowingCharSet``
class Scanner {
    // MARK: Lifecycle

    init(string: String) {
        self.string = string
    }

    // MARK: Internal

    static var identifierFirstCharSet: CustomCharacterSet {
        CustomCharacterSet(charactersInString: characterSets.lowercaseLetters + characterSets.uppercaseLetters + "_")
    }

    static var identifierFollowingCharSet: CustomCharacterSet {
        CustomCharacterSet(charactersInString: characterSets.lowercaseLetters + characterSets
            .uppercaseLetters + characterSets.digits + "_")
    }

    // MARK: - Properties and Initialization

    let string: String
    var location: Int = 0

    var isAtEnd: Bool {
        self.location >= self.string.count
    }

    // Helper to get the remaining string
    var remainingString: String {
        if isAtEnd { return "" }
        let startIndex = string.index(string.startIndex, offsetBy: location)
        return String(string[startIndex...])
    }

    // MARK: - Character Set Scanning

    // A more conventional scanUpTo (scans until a character in the set is found)
    @discardableResult func scanUpToCharacters(in charSet: CustomCharacterSet) -> String? {
        let initialLocation = self.location
        var scannedCharacters = String()

        while self.location < self.string.count {
            let currentChar = self.string[self.location]
            if charSet.contains(currentChar) { break }
            scannedCharacters.append(currentChar)
            self.location += 1
        }

        return scannedCharacters.isEmpty && self.location == initialLocation ? nil : scannedCharacters
    }

    // Scans characters that ARE in the provided set (like original Scanner's scanUpTo/scan(characterSet:))
    @discardableResult func scanCharacters(in charSet: CustomCharacterSet) -> String? {
        let initialLocation = self.location
        var characters = String()

        while self.location < self.string.count, charSet.contains(self.string[self.location]) {
            characters.append(self.string[self.location])
            self.location += 1
        }

        if characters.isEmpty {
            self.location = initialLocation // Revert if nothing was scanned
            return nil
        }
        return characters
    }

    @discardableResult func scan(characterSet: CustomCharacterSet) -> Character? {
        guard self.location < self.string.count else { return nil }
        let character = self.string[self.location]
        guard characterSet.contains(character) else { return nil }
        self.location += 1
        return character
    }

    @discardableResult func scan(characterSet: CustomCharacterSet) -> String? {
        var characters = String()
        while let character: Character = self.scan(characterSet: characterSet) {
            characters.append(character)
        }
        return characters.isEmpty ? nil : characters
    }

    // MARK: - Specific Character and String Scanning

    @discardableResult func scan(character: Character, options: NSString.CompareOptions = []) -> Character? {
        guard self.location < self.string.count else { return nil }
        let characterString = String(character)
        if characterString
            .compare(String(self.string[self.location]), options: options, range: nil, locale: nil) == .orderedSame
        {
            self.location += 1
            return character
        }
        return nil
    }

    @discardableResult func scan(string: String, options: NSString.CompareOptions = []) -> String? {
        let savepoint = self.location
        var characters = String()

        for character in string {
            if let charScanned = self.scan(character: character, options: options) {
                characters.append(charScanned)
            } else {
                self.location = savepoint // Revert on failure
                return nil
            }
        }

        // If we scanned the whole string, it's a match.
        return characters.count == string.count ? characters : { self.location = savepoint; return nil }()
    }

    func scan(token: String, options: NSString.CompareOptions = []) -> String? {
        self.scanWhitespaces()
        return self.scan(string: token, options: options)
    }

    func scan(strings: [String], options: NSString.CompareOptions = []) -> String? {
        for stringEntry in strings {
            if let scannedString = self.scan(string: stringEntry, options: options) {
                return scannedString
            }
        }
        return nil
    }

    func scan(tokens: [String], options: NSString.CompareOptions = []) -> String? {
        self.scanWhitespaces()
        return self.scan(strings: tokens, options: options)
    }

    // MARK: - Integer Scanning

    func scanSign() -> Int? {
        self.scan(dictionary: ["+": 1, "-": -1])
    }

    func scanUnsignedInteger<T: UnsignedInteger>() -> T? {
        self.scanWhitespaces()
        guard let digitString = self.scanDigits() else { return nil }
        return integerValue(from: digitString)
    }

    func scanInteger<T: SignedInteger>() -> T? {
        let savepoint = self.location
        self.scanWhitespaces()

        // Parse sign if present
        let sign = self.scanSign() ?? 1

        // Parse digits
        guard let digitString = self.scanDigits() else {
            // If we found a sign but no digits, revert and return nil
            if sign != 1 {
                self.location = savepoint
            }
            return nil
        }

        // Calculate final value with sign applied
        return T(sign) * integerValue(from: digitString)
    }

    // MARK: - Floating Point Scanning

    // Attempt to parse Double with a compact implementation
    func scanDouble() -> Double? {
        scanWhitespaces()
        let initialLocation = self.location

        // Parse sign
        let sign: Double = (scan(character: "-") != nil) ? -1.0 : { _ = scan(character: "+"); return 1.0 }()

        // Buffer to build the numeric string
        var numberStr = ""
        var hasDigits = false

        // Parse integer part
        if let digits = scanCharacters(in: .decimalDigits) {
            numberStr += digits
            hasDigits = true
        }

        // Parse fractional part
        let dotLocation = location
        if scan(character: ".") != nil {
            if let fractionDigits = scanCharacters(in: .decimalDigits) {
                numberStr += "."
                numberStr += fractionDigits
                hasDigits = true
            } else {
                // Revert dot scan if not followed by digits
                location = dotLocation
            }
        }

        // If no digits found in either integer or fractional part, revert and return nil
        if !hasDigits {
            location = initialLocation
            return nil
        }

        // Parse exponent
        var exponent = 0
        let expLocation = location
        if scan(character: "e", options: .caseInsensitive) != nil {
            let expSign: Double = (scan(character: "-") != nil) ? -1.0 : { _ = scan(character: "+"); return 1.0 }()

            if let expDigits = scanCharacters(in: .decimalDigits), let expValue = Int(expDigits) {
                exponent = Int(expSign) * expValue
            } else {
                // Revert exponent scan if not followed by valid digits
                location = expLocation
            }
        }

        // Convert to final double value
        if var value = Double(numberStr) {
            value *= sign
            if exponent != 0 {
                value *= pow(10.0, Double(exponent))
            }
            return value
        }

        // If conversion fails, revert everything
        location = initialLocation
        return nil
    }

    func scanHexadecimalInteger<T: UnsignedInteger>() -> T? {
        let initialLoc = location
        let hexCharSet = CustomCharacterSet(charactersInString: Self.characterSets.hexDigits)

        var value: T = 0
        var digitCount = 0

        while let char: Character = scan(characterSet: hexCharSet),
              let digit = Self.hexValues[char]
        {
            value = value * 16 + T(digit)
            digitCount += 1
        }

        if digitCount == 0 {
            location = initialLoc // Revert if nothing was scanned
            return nil
        }

        return value
    }

    func scanIdentifier() -> String? {
        scanWhitespaces()
        let savepoint = location

        // Scan first character (must be letter or underscore)
        guard let firstChar: Character = scan(characterSet: Self.identifierFirstCharSet) else {
            location = savepoint
            return nil
        }

        // Begin with the first character
        var identifier = String(firstChar)

        // Scan remaining characters (can include digits)
        while let nextChar: Character = scan(characterSet: Self.identifierFollowingCharSet) {
            identifier.append(nextChar)
        }

        return identifier
    }

    // MARK: - Whitespace Scanning

    func scanWhitespaces() {
        _ = self.scanCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Dictionary-based Scanning

    func scan<T>(dictionary: [String: T], options: NSString.CompareOptions = []) -> T? {
        for (key, value) in dictionary where self.scan(string: key, options: options) != nil {
            // Original Scanner asserts string == key, which is true if scan(string:) returns non-nil.
            return value
        }
        return nil
    }

    // MARK: Private

    // Mapping hex characters to their integer values
    private static let hexValues: [Character: Int] = [
        "0": 0, "1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9,
        "a": 10, "b": 11, "c": 12, "d": 13, "e": 14, "f": 15,
        "A": 10, "B": 11, "C": 12, "D": 13, "E": 14, "F": 15,
    ]

    // MARK: - Identifier Scanning

    // Character sets for identifier scanning
    private static let characterSets = (
        lowercaseLetters: "abcdefghijklmnopqrstuvwxyz",
        uppercaseLetters: "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
        digits: "0123456789",
        hexDigits: "0123456789abcdefABCDEF"
    )

    // Private helper that scans and returns a string of digits
    private func scanDigits() -> String? {
        self.scanCharacters(in: .decimalDigits)
    }

    // Calculate integer value from digit string with given base
    private func integerValue<T: BinaryInteger>(from digitString: String, base: T = 10) -> T {
        digitString.reduce(T(0)) { result, char in
            result * base + T(Int(String(char))!)
        }
    }

    // Helper function for power calculation with FloatingPoint types
    private func scannerPower<T: FloatingPoint>(base: T, exponent: Int) -> T {
        if exponent == 0 { return T(1) }
        if exponent < 0 { return T(1) / scannerPower(base: base, exponent: -exponent) }
        var result = T(1)
        for _ in 0 ..< exponent {
            result *= base
        }
        return result
    }
}
