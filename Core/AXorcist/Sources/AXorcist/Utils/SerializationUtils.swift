import ApplicationServices // For AXUIElement, AXNotification (if used directly)
import CoreGraphics // For CGRect, CGPoint, CGSize
import Foundation

// Consider if AXNotification needs to be accessible here, or if its rawValue is sufficient.
// If AXorcist/Models/DataModels.swift defines AXNotification, that might be a better import.

// Recursively sanitize value into JSON-encodable form
func sanitizeValue(_ val: Any) -> Any {
    switch val {
    case let notif as AXNotification: // Assuming AXNotification is accessible
        return notif.rawValue
    case is AXUIElement:
        return "<AXUIElement>" // Placeholder for opaque AXUIElementRef
    case let elem as Element: // Assuming Element is accessible
        return String(describing: elem) // Or a more specific brief description if safe
    case let attrStr as NSAttributedString:
        return attrStr.string
    case let rect as CGRect:
        return ["x": rect.origin.x, "y": rect.origin.y, "width": rect.size.width, "height": rect.size.height]
    case let point as CGPoint:
        return ["x": point.x, "y": point.y]
    case let size as CGSize:
        return ["width": size.width, "height": size.height]
    case let dict as [String: Any]:
        var newDict: [String: Any] = [:]
        for (key, value) in dict {
            newDict[key] = sanitizeValue(value)
        }
        return newDict
    case let arr as [Any]:
        return arr.map { sanitizeValue($0) }
    // Consider adding cases for other common non-JSON-friendly types like URL, Date etc.
    // For Date, you might convert to ISO8601 string or epoch timestamp.
    default:
        // If it's a simple value type (Int, Double, Bool, String), it's already fine.
        // For anything else, converting to String is a safe fallback.
        // However, be mindful that this might not be the desired representation.
        if val is String || val is Int || val is Double || val is Bool || val is NSNull {
            return val
        }
        // Fallback for unknown complex types
        return String(describing: val)
    }
}

// Ensure all nested values are JSON-serialisable (NSString/NSNumber/NSNull/Array/Dict)
// This function is crucial for preparing the payload for JSONSerialization.
func makeJSONCompatible(_ value: Any) -> Any {
    switch value {
    case let str as String:
        return str // Already a JSON primitive
    case let num as NSNumber: // Handles Int, Double, Bool bridged from Objective-C
        return num // Already a JSON primitive (or convertible)
    case is NSNull:
        return value // Already a JSON primitive
    case let dict as [String: Any]:
        var newDict = [String: Any]()
        for (key, value) in dict {
            newDict[key] = makeJSONCompatible(value)
        }
        return newDict // Recurse for dictionary values
    case let arr as [Any]:
        return arr.map { makeJSONCompatible($0) } // Recurse for array elements
    default:
        // If it's not one of the above, it's likely not directly JSON serializable.
        // Convert to a string representation as a fallback.
        // This ensures that JSONSerialization.data(withJSONObject:) doesn't throw an error
        // due to an invalid top-level or nested type.
        return String(describing: value)
    }
}
