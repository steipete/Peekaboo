// ValueCasters.swift - Contains type casting helper functions for AX values

import ApplicationServices
import CoreGraphics // For CGPoint, CGSize
import Foundation

// Note: Assumes Element (for castToElementArray) is available.

@MainActor
func castValueToType<T>(_ value: Any, expectedType: T.Type, attr: String) -> T? {
    // Handle basic types
    if let result = castToBasicType(value, expectedType: expectedType, attr: attr) {
        return result
    }

    // Handle array types
    if let result = castToArrayType(value, expectedType: expectedType, attr: attr) {
        return result
    }

    // Handle geometry types
    if let result = castToGeometryType(value, expectedType: expectedType, attr: attr) {
        return result
    }

    // Handle special types
    if let result = castToSpecialType(value, expectedType: expectedType, attr: attr) {
        return result
    }
    // Direct cast fallback
    if let directCast = value as? T {
        return directCast
    }

    axDebugLog(
        "axValue: Fallback cast attempt for attribute '\(attr)' to type \(T.self) FAILED. " +
            "Unwrapped value was \(type(of: value)): \(value)",
        file: #file,
        function: #function,
        line: #line
    )
    return nil
}

@MainActor
func castToBasicType<T>(_ value: Any, expectedType: T.Type, attr: String) -> T? {
    switch expectedType {
    case is String.Type:
        castToString(value, attr: attr) as? T
    case is Bool.Type:
        castToBool(value, attr: attr) as? T
    case is Int.Type:
        castToInt(value, attr: attr) as? T
    case is Double.Type:
        castToDouble(value, attr: attr) as? T
    default:
        nil
    }
}

@MainActor
func castToString(_ value: Any, attr: String) -> String? {
    if let str = value as? String {
        return str
    } else if let attrStr = value as? NSAttributedString {
        return attrStr.string
    }
    axDebugLog(
        "axValue: Expected String for attribute '\(attr)', but got \(type(of: value)): \(value)",
        file: #file,
        function: #function,
        line: #line
    )
    return nil
}

@MainActor
func castToBool(_ value: Any, attr: String) -> Bool? {
    if let boolVal = value as? Bool {
        return boolVal
    } else if let numVal = value as? NSNumber {
        return numVal.boolValue
    }
    axDebugLog(
        "axValue: Expected Bool for attribute '\(attr)', but got \(type(of: value)): \(value)",
        file: #file,
        function: #function,
        line: #line
    )
    return nil
}

@MainActor
func castToInt(_ value: Any, attr: String) -> Int? {
    if let intVal = value as? Int {
        return intVal
    } else if let numVal = value as? NSNumber {
        return numVal.intValue
    }
    axDebugLog(
        "axValue: Expected Int for attribute '\(attr)', but got \(type(of: value)): \(value)",
        file: #file,
        function: #function,
        line: #line
    )
    return nil
}

@MainActor
func castToDouble(_ value: Any, attr: String) -> Double? {
    if let doubleVal = value as? Double {
        return doubleVal
    } else if let numVal = value as? NSNumber {
        return numVal.doubleValue
    }
    axDebugLog(
        "axValue: Expected Double for attribute '\(attr)', but got \(type(of: value)): \(value)",
        file: #file,
        function: #function,
        line: #line
    )
    return nil
}

@MainActor
func castToArrayType<T>(_ value: Any, expectedType: T.Type, attr: String) -> T? {
    switch expectedType {
    case is [AXUIElement].Type:
        castToAXUIElementArray(value, attr: attr) as? T
    case is [Element].Type:
        castToElementArray(value, attr: attr) as? T
    case is [String].Type:
        castToStringArray(value, attr: attr) as? T
    default:
        nil
    }
}

@MainActor
func castToAXUIElementArray(_ value: Any, attr: String) -> [AXUIElement]? {
    if let anyArray = value as? [Any?] {
        let result = anyArray.compactMap { item -> AXUIElement? in
            guard let cfItem = item else { return nil }
            if CFGetTypeID(cfItem as CFTypeRef) == AXUIElementGetTypeID() {
                return (cfItem as! AXUIElement)
            }
            return nil
        }
        return result
    }
    axDebugLog(
        "axValue: Expected [AXUIElement] for attribute '\(attr)', but got \(type(of: value)): \(value)",
        file: #file,
        function: #function,
        line: #line
    )
    return nil
}

@MainActor
func castToElementArray(_ value: Any, attr: String) -> [Element]? {
    if let anyArray = value as? [Any?] {
        let result = anyArray.compactMap { item -> Element? in
            guard let cfItem = item else { return nil }
            if CFGetTypeID(cfItem as CFTypeRef) == AXUIElementGetTypeID() {
                return Element(cfItem as! AXUIElement) // Assumes Element initializer is public/internal
            }
            return nil
        }
        return result
    }
    axDebugLog(
        "axValue: Expected [Element] for attribute '\(attr)', but got \(type(of: value)): \(value)",
        file: #file,
        function: #function,
        line: #line
    )
    return nil
}

@MainActor
func castToStringArray(_ value: Any, attr: String) -> [String]? {
    if let stringArray = value as? [Any?] {
        let result = stringArray.compactMap { $0 as? String }
        if result.count == stringArray.count {
            return result
        }
    }
    axDebugLog(
        "axValue: Expected [String] for attribute '\(attr)', but got \(type(of: value)): \(value)",
        file: #file,
        function: #function,
        line: #line
    )
    return nil
}

@MainActor
func castToGeometryType<T>(_ value: Any, expectedType: T.Type, attr: String) -> T? {
    switch expectedType {
    case is CGPoint.Type:
        castToCGPoint(value, attr: attr) as? T
    case is CGSize.Type:
        castToCGSize(value, attr: attr) as? T
    default:
        nil
    }
}

@MainActor
func castToCGPoint(_ value: Any, attr: String) -> CGPoint? {
    if let pointVal = value as? CGPoint {
        return pointVal
    }
    axDebugLog(
        "axValue: Expected CGPoint for attribute '\(attr)', but got \(type(of: value)): \(value)",
        file: #file,
        function: #function,
        line: #line
    )
    return nil
}

@MainActor
func castToCGSize(_ value: Any, attr: String) -> CGSize? {
    if let sizeVal = value as? CGSize {
        return sizeVal
    }
    axDebugLog(
        "axValue: Expected CGSize for attribute '\(attr)', but got \(type(of: value)): \(value)",
        file: #file,
        function: #function,
        line: #line
    )
    return nil
}

@MainActor
func castToSpecialType<T>(_ value: Any, expectedType: T.Type, attr: String) -> T? {
    if expectedType == AXUIElement.self {
        return castToAXUIElement(value, attr: attr) as? T
    }
    return nil
}

@MainActor
func castToAXUIElement(_ value: Any, attr: String) -> AXUIElement? {
    if let cfValue = value as CFTypeRef?, CFGetTypeID(cfValue) == AXUIElementGetTypeID() {
        return (cfValue as! AXUIElement)
    }
    let typeDescription = String(describing: type(of: value))
    let valueDescription = String(describing: value)
    axDebugLog(
        "axValue: Expected AXUIElement for attribute '\(attr)', but got \(typeDescription): \(valueDescription)",
        file: #file,
        function: #function,
        line: #line
    )
    return nil
}
