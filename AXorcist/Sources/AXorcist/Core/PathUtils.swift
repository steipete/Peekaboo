import Foundation

public enum PathUtils {
    // Mapping of common attribute shortcuts to their full AX attribute names
    public static let attributeKeyMappings: [String: String] = [
        "role": AXAttributeNames.kAXRoleAttribute,
        "subrole": AXAttributeNames.kAXSubroleAttribute,
        "title": AXAttributeNames.kAXTitleAttribute,
        "value": AXAttributeNames.kAXValueAttribute,
        "identifier": AXAttributeNames.kAXIdentifierAttribute,
        "id": AXAttributeNames.kAXIdentifierAttribute,
        "domid": AXAttributeNames.kAXDOMIdentifierAttribute,
        "domclass": AXAttributeNames.kAXDOMClassListAttribute,
        "help": AXAttributeNames.kAXHelpAttribute,
        "description": AXAttributeNames.kAXDescriptionAttribute,
        "placeholder": AXAttributeNames.kAXPlaceholderValueAttribute,
        "enabled": AXAttributeNames.kAXEnabledAttribute,
        "focused": AXAttributeNames.kAXFocusedAttribute,
    ]

    public static func parsePathComponent(_ pathComponent: String) -> (attributeName: String, expectedValue: String) {
        let trimmedPathComponentString = pathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmedPathComponentString.split(separator: ":", maxSplits: 1)

        guard parts.count == 2 else {
            // AXorcist's navigateToElement should handle this, e.g. by logging a CRITICAL_NAV_PARSE_FAILURE_MARKER
            // and returning nil from navigateToElement if attributeName is empty.
            return (attributeName: "", expectedValue: "")
        }
        return (attributeName: String(parts[0]), expectedValue: String(parts[1]))
    }

    public static func parseRichPathComponent(_ pathComponent: String) -> [String: String] {
        var criteria: [String: String] = [:]
        let trimmedPathComponent = pathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        // Split by comma, but be careful about commas inside quoted values if we encounter them later
        // For now, assuming commas are reliable delimiters between key:value pairs
        let pairs = trimmedPathComponent.split(separator: ",")

        for pair in pairs {
            let keyValue = pair.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":", maxSplits: 1)
            if keyValue.count == 2 {
                let key = String(keyValue[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                var value = String(keyValue[1]).trimmingCharacters(in: .whitespacesAndNewlines)

                // Remove surrounding quotes from value if present (e.g., Title: "XYZ" or Title: 'XYZ')
                if value.count >= 2 {
                    if value.hasPrefix("\""), value.hasSuffix("\"") {
                        value = String(value.dropFirst().dropLast())
                    } else if value.hasPrefix("'"), value.hasSuffix("'") {
                        value = String(value.dropFirst().dropLast())
                    }
                }
                criteria[key] = value
            }
        }
        return criteria
    }
}
