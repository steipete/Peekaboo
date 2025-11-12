import ApplicationServices // For AXUIElement, AXNotification (if used directly)
import CoreGraphics // For CGRect, CGPoint, CGSize
import Foundation

// Consider if AXNotification needs to be accessible here, or if its rawValue is sufficient.
// If AXorcist/Models/DataModels.swift defines AXNotification, that might be a better import.

// Recursively sanitize value into JSON-encodable form
func sanitizeValue(_ val: Any) -> Any {
    if let specialValue = sanitizeSpecialValue(val) {
        return specialValue
    }
    if let dict = val as? [String: Any] {
        return dict.reduce(into: [String: Any]()) { result, pair in
            result[pair.key] = sanitizeValue(pair.value)
        }
    }
    if let array = val as? [Any] {
        return array.map { sanitizeValue($0) }
    }
    if isPrimitiveJSONValue(val) {
        return val
    }
    return String(describing: val)
}

private func sanitizeSpecialValue(_ value: Any) -> Any? {
    switch value {
    case let notif as AXNotification:
        return notif.rawValue
    case is AXUIElement:
        return "<AXUIElement>"
    case let element as Element:
        return String(describing: element)
    case let attributed as NSAttributedString:
        return attributed.string
    case let rect as CGRect:
        return [
            "x": rect.origin.x,
            "y": rect.origin.y,
            "width": rect.size.width,
            "height": rect.size.height
        ]
    case let point as CGPoint:
        return ["x": point.x, "y": point.y]
    case let size as CGSize:
        return ["width": size.width, "height": size.height]
    default:
        return nil
    }
}

private func isPrimitiveJSONValue(_ value: Any) -> Bool {
    value is String || value is Int || value is Double || value is Bool || value is NSNull
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
