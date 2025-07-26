import Foundation

// CustomCharacterSet struct from Scanner
public struct CustomCharacterSet {
    // MARK: Lifecycle

    public init(characters: Set<Character>) {
        self.characters = characters
    }

    public init(charactersInString: String) {
        self.characters = Set(Array(charactersInString))
    }

    // MARK: Public

    // Add some common character sets that might be useful, similar to Foundation.CharacterSet
    public static var whitespacesAndNewlines: CustomCharacterSet {
        CustomCharacterSet(charactersInString: " \t\n\r")
    }

    public static var decimalDigits: CustomCharacterSet {
        CustomCharacterSet(charactersInString: "0123456789")
    }

    public static func punctuationAndSymbols() -> CustomCharacterSet { // Example
        // This would need a more comprehensive list based on actual needs
        CustomCharacterSet(charactersInString: ".,:;?!()[]{}-_=+") // Simplified set
    }

    public static func characters(in string: String) -> CustomCharacterSet {
        CustomCharacterSet(charactersInString: string)
    }

    public func contains(_ character: Character) -> Bool {
        self.characters.contains(character)
    }

    public mutating func add(_ characters: Set<Character>) {
        self.characters.formUnion(characters)
    }

    public func adding(_ characters: Set<Character>) -> CustomCharacterSet {
        CustomCharacterSet(characters: self.characters.union(characters))
    }

    public mutating func remove(_ characters: Set<Character>) {
        self.characters.subtract(characters)
    }

    public func removing(_ characters: Set<Character>) -> CustomCharacterSet {
        CustomCharacterSet(characters: self.characters.subtracting(characters))
    }

    // MARK: Private

    private var characters: Set<Character>
}
