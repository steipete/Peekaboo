// MatchingTypes.swift - Types for element matching and locating

import Foundation

// Represents a single criterion for element matching
public struct Criterion: Codable, Sendable {
    // MARK: Lifecycle

    public init(attribute: String, value: String, matchType: JSONPathHintComponent.MatchType? = nil) {
        self.attribute = attribute
        self.value = value
        self.matchType = matchType
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attribute = try container.decode(String.self, forKey: .attribute)
        value = try container.decode(String.self, forKey: .value)
        matchType = try container.decodeIfPresent(JSONPathHintComponent.MatchType.self, forKey: .matchType)
    }

    // MARK: Public

    public let attribute: String
    public let value: String
    public let matchType: JSONPathHintComponent.MatchType?

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(attribute, forKey: .attribute)
        try container.encode(value, forKey: .value)
        try container.encodeIfPresent(matchType, forKey: .matchType)
    }

    // MARK: Internal

    // With `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`,
    // we can simply rely on automatic snake-case → camel-case conversion.
    // Using a custom raw value here would *break* that feature because the
    // strategy is applied **after** the raw value is resolved, resulting in
    // the decoder searching for a non-existent key ("matchType").
    // Therefore we keep the raw key identical to the Swift property name.
    enum CodingKeys: String, CodingKey {
        case attribute, value, matchType
    }
}

/// Represents a step in a hierarchical path, defined by a set of criteria.
public struct PathStep: Codable, Sendable {
    // MARK: Lifecycle

    // Default initializer
    public init(criteria: [Criterion],
                matchType: JSONPathHintComponent.MatchType? = .exact,
                matchAllCriteria: Bool? = true,
                maxDepthForStep: Int? = nil)
    { // Added maxDepthForStep
        self.criteria = criteria
        self.matchType = matchType
        self.matchAllCriteria = matchAllCriteria
        self.maxDepthForStep = maxDepthForStep // Initialize
    }

    // MARK: Public

    public let criteria: [Criterion]
    public let matchType: JSONPathHintComponent.MatchType? // How to evaluate criteria (e.g., exact, contains)
    public let matchAllCriteria: Bool? // Whether all criteria must match (AND) or any (OR)
    public let maxDepthForStep: Int? // Maximum depth to search for this specific step

    /// Returns a string representation suitable for logging
    public func descriptionForLog() -> String {
        let critDesc = criteria.map { criterion -> String in
            "\(criterion.attribute):\(criterion.value)(\((criterion.matchType ?? .exact).rawValue))"
        }.joined(separator: ", ")

        let depthStringPart = if let depth = maxDepthForStep {
            ", Depth: \(depth)"
        } else {
            ""
        }

        let matchTypeStringPart = (matchType ?? .exact).rawValue
        let matchAllStringPart = "\(matchAllCriteria ?? true)"

        return "[Criteria: (\(critDesc)), MatchType: \(matchTypeStringPart), MatchAll: \(matchAllStringPart)\(depthStringPart)]"
    }

    // MARK: Internal

    // CodingKeys to map JSON keys to Swift properties
    enum CodingKeys: String, CodingKey {
        case criteria
        case matchType
        case matchAllCriteria
        case maxDepthForStep = "max_depth_for_step" // Map JSON's snake_case to Swift's camelCase
    }
}

// Locator for finding elements
public struct Locator: Codable, Sendable {
    // MARK: Lifecycle

    public init(
        matchAll: Bool? = true, // Default to true for criteria
        criteria: [Criterion] = [],
        rootElementPathHint: [JSONPathHintComponent]? = nil, // Changed from [PathStep]?
        descendantCriteria: [String: String]? = nil,
        requireAction: String? = nil,
        computedNameContains: String? = nil,
        debugPathSearch: Bool? = false
    ) {
        self.matchAll = matchAll
        self.criteria = criteria
        self.rootElementPathHint = rootElementPathHint
        self.descendantCriteria = descendantCriteria
        self.requireAction = requireAction
        self.computedNameContains = computedNameContains
        self.debugPathSearch = debugPathSearch
    }

    // MARK: Public

    public var matchAll: Bool? // For the top-level criteria, if path_from_root is not used or fails early.
    public var criteria: [Criterion]
    public var rootElementPathHint: [JSONPathHintComponent]? // Changed from [PathStep]?
    public var descendantCriteria: [String: String]? // This seems to be an older/alternative way? Consider phasing out
    // or clarifying.
    public var requireAction: String?
    public var computedNameContains: String?
    public var debugPathSearch: Bool?

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
        case matchAll
        case criteria
        case rootElementPathHint = "path_from_root" // Map to JSON key "path_from_root"
        case descendantCriteria
        case requireAction
        case computedNameContains
        case debugPathSearch
    }
}
