// Models.swift - Contains core data models and type aliases

import ApplicationServices // Added for AXUIElementGetTypeID
import Foundation

/// Type alias for a dictionary of accessibility element attributes.
/// Keys are attribute names (e.g., "AXTitle", "AXValue") and values are wrapped in AnyCodable.
public typealias ElementAttributes = [String: AnyCodable]

/// Wrapper that makes accessibility attribute values Codable and Sendable.
///
/// AXValueWrapper handles:
/// - Converting AXUIElement references to structured Element data
/// - Sanitizing arrays and dictionaries recursively
/// - Preserving type information for various accessibility values
/// - Thread-safe serialization of complex attribute values
public struct AXValueWrapper: Codable, Sendable, Equatable {
    // MARK: Lifecycle

    @MainActor // Added @MainActor to allow calling element.briefDescription
    public init(value: Any?) {
        let typeOfOriginalValue = String(describing: type(of: value))
        axDebugLog("AXVW.init: OrigType='\(typeOfOriginalValue)', Val=\(String(describing: value).prefix(100))")

        if let unwrappedValue = value {
            let typeOfUnwrappedValue = String(describing: type(of: unwrappedValue))
            axDebugLog("AXVW.init: UnwrappedType='\(typeOfUnwrappedValue)'")

            if let array = unwrappedValue as? [Any?] {
                axDebugLog("AXVW.init: Detected Array. Count: \(array.count)")
                // Sanitize each item and wrap the resulting array of sanitized items in AnyCodable
                self.anyValue = AnyCodable(array.map { AXValueWrapper.recursivelySanitize($0) })
            } else if let dict = unwrappedValue as? [String: Any?] {
                axDebugLog("AXVW.init: Detected Dictionary. Count: \(dict.count)")
                self.anyValue = AnyCodable(dict.mapValues { AXValueWrapper.recursivelySanitize($0) })
            } else {
                // Handle single, non-collection items
                self.anyValue = AnyCodable(AXValueWrapper.recursivelySanitize(unwrappedValue))
            }
        } else { // value was nil (absence of value)
            axDebugLog("AXVW.init: Original value was nil.")
            self.anyValue = nil // The AXValueWrapper's own anyValue property is nil
        }
    }

    // MARK: Public

    public var anyValue: AnyCodable? // This can be nil if the attribute itself had no value or was absent

    // MARK: Private

    // Static helper to sanitize individual items, called recursively by init for collections
    @MainActor
    private static func recursivelySanitize(_ item: Any?) -> Any { // Returns Any (basic types or () for nil)
        guard let anItem = item else { return () } // Convert nil to AnyCodable's nil marker
        let cfItem = anItem as CFTypeRef
        if CFGetTypeID(cfItem) == CFNullGetTypeID() { return () } // NSNull to AnyCodable's nil
        if CFGetTypeID(cfItem) == AXUIElementGetTypeID() { return "<AXUIElement_RS>" }
        if let element = anItem as? Element { return "<Element_RS: \(element.briefDescription(option: .raw))>" }

        // If it's a collection, recurse. This handles nested collections.
        // Note: This recursive call inside a static func might lead to issues if not careful with types.
        // However, we are returning basic types or placeholders from the checks above.
        if let array = anItem as? [Any?] {
            return array.map { recursivelySanitize($0) }
        }
        if let dict = anItem as? [String: Any?] {
            return dict.mapValues { recursivelySanitize($0) }
        }

        // For basic, already encodable types, return as is.
        // This assumes String, Int, Double, Bool are passed through.
        return anItem
    }

    // If AnyCodable has trouble with certain AX types (like AXUIElementRef),
    // custom Encodable/Decodable logic might be needed here or in AnyCodable itself.
    // For instance, AXUIElementRef might be encoded as a placeholder string or an empty dict.
}

public struct AXElement: Codable, HandlerDataRepresentable {
    // MARK: Lifecycle

    public init(attributes: ElementAttributes?, path: [String]? = nil) {
        self.attributes = attributes
        self.path = path
    }

    // MARK: Public

    public var attributes: ElementAttributes?
    public var path: [String]?
}

// MARK: - Search Log Entry Model (for stderr JSON logging)

public struct SearchLogEntry: Codable {
    // MARK: Lifecycle

    // Public initializer
    public init(
        depth: Int,
        elementRole: String?,
        elementTitle: String?,
        elementIdentifier: String?,
        maxDepth: Int,
        criteria: [String: String]?,
        status: String,
        isMatch: Bool?
    ) {
        self.depth = depth
        self.elementRole = elementRole
        self.elementTitle = elementTitle
        self.elementIdentifier = elementIdentifier
        self.maxDepth = maxDepth
        self.criteria = criteria
        self.status = status
        self.isMatch = isMatch
    }

    // MARK: Public

    public let depth: Int
    public let elementRole: String?
    public let elementTitle: String?
    public let elementIdentifier: String?
    public let maxDepth: Int
    public let criteria: [String: String]?
    public let status: String // status (e.g., "vis", "found", "noMatch", "maxD")
    public let isMatch: Bool? // isMatch (true, false, or nil if not applicable for this status)

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
        case depth = "d"
        case elementRole = "eR"
        case elementTitle = "eT"
        case elementIdentifier = "eI"
        case maxDepth = "mD"
        case criteria = "c"
        case status = "s"
        case isMatch = "iM"
    }
}
