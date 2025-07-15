import Foundation

// MARK: - Scannable Protocol

protocol Scannable {
    init?(_ scanner: Scanner)
}

// MARK: - Scannable Conformance

extension Int: Scannable {
    init?(_ scanner: Scanner) {
        if let value: Int = scanner.scanInteger() { self = value } else { return nil }
    }
}

extension UInt: Scannable {
    init?(_ scanner: Scanner) {
        if let value: UInt = scanner.scanUnsignedInteger() { self = value } else { return nil }
    }
}

extension Float: Scannable {
    init?(_ scanner: Scanner) {
        // Using the custom scanDouble and casting
        if let value = scanner.scanDouble() { self = Float(value) } else { return nil }
    }
}

extension Double: Scannable {
    init?(_ scanner: Scanner) {
        if let value = scanner.scanDouble() { self = value } else { return nil }
    }
}

extension Bool: Scannable {
    init?(_ scanner: Scanner) {
        scanner.scanWhitespaces()
        if let value: Bool = scanner
            .scan(dictionary: ["true": true, "false": false], options: [.caseInsensitive]) { self = value }
        else { return nil }
    }
}
