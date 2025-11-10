import Foundation

// Assuming AXAttributeNames is available globally or via import from AXorcist.Core
// For now, direct use, assuming it's part of the same target.

/// Represents a single, structured component in a navigation path hint, designed for JSON decoding.
public struct JSONPathHintComponent: Codable, Sendable {
    // MARK: Lifecycle

    public init(attribute: String, value: String, depth: Int? = nil, matchType: MatchType? = nil) {
        self.attribute = attribute
        self.value = value
        self.depth = depth
        self.matchType = matchType
    }

    // If you need custom Codable implementation because of the new optional field
    // and want to maintain existing JSON compatibility (if matchType is often absent):
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attribute = try container.decode(String.self, forKey: .attribute)
        value = try container.decode(String.self, forKey: .value)
        depth = try container.decodeIfPresent(Int.self, forKey: .depth)
        matchType = try container.decodeIfPresent(MatchType.self, forKey: .matchType)
    }

    // MARK: Public

    public enum MatchType: String, Codable, Sendable {
        case exact
        case contains
        case regex
        case containsAny
        case prefix
        case suffix
    }

    /// The type of attribute to match (e.g., "ROLE", "TITLE", "DOM", "DOMCLASS"). Case-insensitive.
    public let attribute: String
    /// The expected value for the attribute.
    public let value: String
    /// Optional: The search depth for this specific step. Defaults if omitted.
    public let depth: Int?
    public let matchType: MatchType?

    /// The actual accessibility attribute name derived from the 'attribute' string.
    public var axAttributeName: String? {
        // This map should be kept in sync with any similar maps (e.g., in old/deleted RichPathHintParser)
        // Keys are uppercased for case-insensitive matching.
        let attributeTypeMap: [String: String] = [
            "ROLE": AXAttributeNames.kAXRoleAttribute,
            "SUBROLE": AXAttributeNames.kAXSubroleAttribute,
            "TITLE": AXAttributeNames.kAXTitleAttribute,
            "ID": AXAttributeNames.kAXIdentifierAttribute,
            "IDENTIFIER": AXAttributeNames.kAXIdentifierAttribute,
            "DOM": AXAttributeNames.kAXDOMClassListAttribute, // Standard for DOM class list
            "DOMCLASS": AXAttributeNames.kAXDOMClassListAttribute, // Alias for DOM
            "DOMID": AXAttributeNames.kAXDOMIdentifierAttribute,
            "VALUE": AXAttributeNames.kAXValueAttribute,
            "HELP": AXAttributeNames.kAXHelpAttribute,
            "DESCRIPTION": AXAttributeNames.kAXDescriptionAttribute,
            "PLACEHOLDER": AXAttributeNames.kAXPlaceholderValueAttribute,
            // Add other common attributes as needed
        ]
        return attributeTypeMap[attribute.uppercased()]
    }

    /// Converts this component to a simple criteria dictionary for use with existing matching logic.
    public var simpleCriteria: [String: String]? {
        guard let resolvedAttributeName = axAttributeName else {
            // Log a warning here if this component is used, as it means an invalid attribute type was provided.
            // GlobalAXLogger.shared.log(...) or axWarningLog(...) - Requires importing/access
            // For now, just return nil. The calling code should handle this.
            print("WARNING: JSONPathHintComponent has unrecognized attribute type: \(attribute)")
            return nil
        }
        return [resolvedAttributeName: value]
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(attribute, forKey: .attribute)
        try container.encode(value, forKey: .value)
        try container.encodeIfPresent(depth, forKey: .depth)
        try container.encodeIfPresent(matchType, forKey: .matchType)
    }

    /// Returns a string representation suitable for logging
    public func descriptionForLog() -> String {
        "\(axAttributeName ?? attribute):\(value)"
    }

    // MARK: Internal

    // Default depth if not specified in JSON
    static let defaultDepthForSegment = 3

    // MARK: Private

    // For Sendable conformance, all stored properties must be Sendable.
    // String and Int? are Sendable.

    private enum CodingKeys: String, CodingKey {
        case attribute
        case value
        case depth
        case matchType
    }
}
