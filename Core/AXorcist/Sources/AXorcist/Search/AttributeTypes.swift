// AttributeTypes.swift - Core types for attribute handling

import Foundation

// ElementDetails struct for AXpector
public struct ElementDetails {
    // MARK: Lifecycle

    public init() {
        self.isIgnored = false
        self.isClickable = false
    }

    // MARK: Public

    public var title: String?
    public var role: String?
    public var roleDescription: String?
    public var value: Any?
    public var help: Any?
    public var isIgnored: Bool
    public var actions: [String]?
    public var isClickable: Bool
    public var computedName: String?
}

// Enum to specify the source of an attribute
public enum AttributeSource: String, Codable {
    case direct // Directly from AXUIElement
    case computed // Computed by AXorcist (e.g., path, name heuristic)
    case prefetched // From element's stored attributes dictionary
}

// Struct to hold attribute data along with its source
public struct AttributeData: Codable {
    public let value: AnyCodable
    public let source: AttributeSource
}
