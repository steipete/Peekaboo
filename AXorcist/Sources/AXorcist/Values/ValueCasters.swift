// ValueCasters.swift - Contains type casting helper functions for AX values

import ApplicationServices
import CoreGraphics // For CGPoint, CGSize
import Foundation

// Note: Assumes Element (for castToElementArray) is available.

@MainActor
internal func castValueToType<T>(_ value: Any, expectedType: T.Type, attr: String, dLog: (String) -> Void) -> T? {
    // Handle basic types
    if let result = castToBasicType(value, expectedType: expectedType, attr: attr, dLog: dLog) {
        return result
    }

    // Handle array types
    if let result = castToArrayType(value, expectedType: expectedType, attr: attr, dLog: dLog) {
        return result
    }

    // Handle geometry types
    if let result = castToGeometryType(value, expectedType: expectedType, attr: attr, dLog: dLog) {
        return result
    }

    // Handle special types
    if let result = castToSpecialType(value, expectedType: expectedType, attr: attr, dLog: dLog) {
        return result
    }
    // Direct cast fallback
    if let directCast = value as? T {
        return directCast
    }

    dLog(
        "axValue: Fallback cast attempt for attribute '\(attr)' to type \(T.self) FAILED. " +
            "Unwrapped value was \(type(of: value)): \(value)"
    )
    return nil
}

@MainActor
internal func castToBasicType<T>(_ value: Any, expectedType: T.Type, attr: String, dLog: (String) -> Void) -> T? {
    switch expectedType {
    case is String.Type:
        return castToString(value, attr: attr, dLog: dLog) as? T
    case is Bool.Type:
        return castToBool(value, attr: attr, dLog: dLog) as? T
    case is Int.Type:
        return castToInt(value, attr: attr, dLog: dLog) as? T
    case is Double.Type:
        return castToDouble(value, attr: attr, dLog: dLog) as? T
    default:
        return nil
    }
}

@MainActor
internal func castToString(_ value: Any, attr: String, dLog: (String) -> Void) -> String? {
    if let str = value as? String {
        return str
    } else if let attrStr = value as? NSAttributedString {
        return attrStr.string
    }
    dLog("axValue: Expected String for attribute '\(attr)', but got \(type(of: value)): \(value)")
    return nil
}

@MainActor
internal func castToBool(_ value: Any, attr: String, dLog: (String) -> Void) -> Bool? {
    if let boolVal = value as? Bool {
        return boolVal
    } else if let numVal = value as? NSNumber {
        return numVal.boolValue
    }
    dLog("axValue: Expected Bool for attribute '\(attr)', but got \(type(of: value)): \(value)")
    return nil
}

@MainActor
internal func castToInt(_ value: Any, attr: String, dLog: (String) -> Void) -> Int? {
    if let intVal = value as? Int {
        return intVal
    } else if let numVal = value as? NSNumber {
        return numVal.intValue
    }
    dLog("axValue: Expected Int for attribute '\(attr)', but got \(type(of: value)): \(value)")
    return nil
}

@MainActor
internal func castToDouble(_ value: Any, attr: String, dLog: (String) -> Void) -> Double? {
    if let doubleVal = value as? Double {
        return doubleVal
    } else if let numVal = value as? NSNumber {
        return numVal.doubleValue
    }
    dLog("axValue: Expected Double for attribute '\(attr)', but got \(type(of: value)): \(value)")
    return nil
}

@MainActor
internal func castToArrayType<T>(_ value: Any, expectedType: T.Type, attr: String, dLog: (String) -> Void) -> T? {
    switch expectedType {
    case is [AXUIElement].Type:
        return castToAXUIElementArray(value, attr: attr, dLog: dLog) as? T
    case is [Element].Type:
        return castToElementArray(value, attr: attr, dLog: dLog) as? T
    case is [String].Type:
        return castToStringArray(value, attr: attr, dLog: dLog) as? T
    default:
        return nil
    }
}

@MainActor
internal func castToAXUIElementArray(_ value: Any, attr: String, dLog: (String) -> Void) -> [AXUIElement]? {
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
    dLog("axValue: Expected [AXUIElement] for attribute '\(attr)', but got \(type(of: value)): \(value)")
    return nil
}

@MainActor
internal func castToElementArray(_ value: Any, attr: String, dLog: (String) -> Void) -> [Element]? {
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
    dLog("axValue: Expected [Element] for attribute '\(attr)', but got \(type(of: value)): \(value)")
    return nil
}

@MainActor
internal func castToStringArray(_ value: Any, attr: String, dLog: (String) -> Void) -> [String]? {
    if let stringArray = value as? [Any?] {
        let result = stringArray.compactMap { $0 as? String }
        if result.count == stringArray.count {
            return result
        }
    }
    dLog("axValue: Expected [String] for attribute '\(attr)', but got \(type(of: value)): \(value)")
    return nil
}

@MainActor
internal func castToGeometryType<T>(_ value: Any, expectedType: T.Type, attr: String, dLog: (String) -> Void) -> T? {
    switch expectedType {
    case is CGPoint.Type:
        return castToCGPoint(value, attr: attr, dLog: dLog) as? T
    case is CGSize.Type:
        return castToCGSize(value, attr: attr, dLog: dLog) as? T
    default:
        return nil
    }
}

@MainActor
internal func castToCGPoint(_ value: Any, attr: String, dLog: (String) -> Void) -> CGPoint? {
    if let pointVal = value as? CGPoint {
        return pointVal
    }
    dLog("axValue: Expected CGPoint for attribute '\(attr)', but got \(type(of: value)): \(value)")
    return nil
}

@MainActor
internal func castToCGSize(_ value: Any, attr: String, dLog: (String) -> Void) -> CGSize? {
    if let sizeVal = value as? CGSize {
        return sizeVal
    }
    dLog("axValue: Expected CGSize for attribute '\(attr)', but got \(type(of: value)): \(value)")
    return nil
}

@MainActor
internal func castToSpecialType<T>(_ value: Any, expectedType: T.Type, attr: String, dLog: (String) -> Void) -> T? {
    if expectedType == AXUIElement.self {
        return castToAXUIElement(value, attr: attr, dLog: dLog) as? T
    }
    return nil
}

@MainActor
internal func castToAXUIElement(_ value: Any, attr: String, dLog: (String) -> Void) -> AXUIElement? {
    if let cfValue = value as CFTypeRef?, CFGetTypeID(cfValue) == AXUIElementGetTypeID() {
        return (cfValue as! AXUIElement)
    }
    let typeDescription = String(describing: type(of: value))
    let valueDescription = String(describing: value)
    dLog("axValue: Expected AXUIElement for attribute '\(attr)', but got \(typeDescription): \(valueDescription)")
    return nil
}
