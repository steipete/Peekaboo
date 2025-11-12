// Models.swift - Contains core data models and type aliases

import ApplicationServices // Added for AXUIElementGetTypeID
import Foundation

/// Type alias for a dictionary of accessibility element attributes.
/// Keys are attribute names (e.g., "AXTitle", "AXValue") and values are strongly typed using AttributeValue.
public typealias ElementAttributes = [String: AttributeValue]

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
                // Sanitize each item and wrap the resulting array of sanitized items in AttributeValue
                let sanitizedArray = array.compactMap { item -> AttributeValue? in
                    AXValueWrapper.convertToAttributeValue(AXValueWrapper.recursivelySanitize(item))
                }
                self.anyValue = .array(sanitizedArray)
            } else if let dict = unwrappedValue as? [String: Any?] {
                axDebugLog("AXVW.init: Detected Dictionary. Count: \(dict.count)")
                let sanitizedDict = dict.compactMapValues { value -> AttributeValue? in
                    AXValueWrapper.convertToAttributeValue(AXValueWrapper.recursivelySanitize(value))
                }
                self.anyValue = .dictionary(sanitizedDict)
            } else {
                // Handle single, non-collection items
                let sanitized = AXValueWrapper.recursivelySanitize(unwrappedValue)
                self.anyValue = AXValueWrapper.convertToAttributeValue(sanitized)
            }
        } else { // value was nil (absence of value)
            axDebugLog("AXVW.init: Original value was nil.")
            self.anyValue = nil // The AXValueWrapper's own anyValue property is nil
        }
    }

    // MARK: Public

    public var anyValue: AttributeValue? // This can be nil if the attribute itself had no value or was absent

    // MARK: Private

    // Static helper to sanitize individual items, called recursively by init for collections
    @MainActor
    private static func recursivelySanitize(_ item: Any?) -> Any {
        return recursivelySanitizeWithDepth(item, depth: 0, visited: Set<ObjectIdentifier>())
    }

    // Convert sanitized Any value to AttributeValue
    private static func convertToAttributeValue(_ value: Any) -> AttributeValue? {
        switch value {
        case let string as String:
            return .string(string)
        case let bool as Bool:
            return .bool(bool)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let array as [Any]:
            let attributeArray = array.compactMap { convertToAttributeValue($0) }
            return .array(attributeArray)
        case let dict as [String: Any]:
            let attributeDict = dict.compactMapValues { convertToAttributeValue($0) }
            return .dictionary(attributeDict)
        case is ():
            return .null
        default:
            // Convert unknown types to string representation
            return .string(String(describing: value))
        }
    }

    @MainActor
    private static func recursivelySanitizeWithDepth(_ item: Any?, depth: Int, visited: Set<ObjectIdentifier>) -> Any {
        // Prevent infinite recursion with depth limit
        guard depth < 50 else { return "<max_depth_reached>" }

        guard let anItem = item else { return () } // Convert nil to null marker for AttributeValue

        // Check for circular references in collections
        var currentVisited = visited
        if type(of: anItem) is AnyClass {
            let object = anItem as AnyObject
            let id = ObjectIdentifier(object)
            if currentVisited.contains(id) {
                return "<circular_reference>"
            }
            currentVisited.insert(id)
        }

        let cfItem = anItem as CFTypeRef
        if CFGetTypeID(cfItem) == CFNullGetTypeID() { return () } // NSNull to null marker
        if CFGetTypeID(cfItem) == AXUIElementGetTypeID() { return "<AXUIElement_RS>" }
        if let element = anItem as? Element { return "<Element_RS: \(element.briefDescription(option: .raw))>" }

        // If it's a collection, recurse with cycle detection
        if let array = anItem as? [Any?] {
            return array.map { recursivelySanitizeWithDepth($0, depth: depth + 1, visited: currentVisited) }
        }
        if let dict = anItem as? [String: Any?] {
            return dict.mapValues { recursivelySanitizeWithDepth($0, depth: depth + 1, visited: currentVisited) }
        }

        // For basic, already encodable types, return as is.
        // This assumes String, Int, Double, Bool are passed through.
        return anItem
    }

    // If AttributeValue has trouble with certain AX types (like AXUIElementRef),
    // they are converted to string representations in the convertToAttributeValue method.
    // For instance, AXUIElementRef is converted to a placeholder string like "<AXUIElement_RS>".
}

public nonisolated struct AXElement: Codable, HandlerDataRepresentable {
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
