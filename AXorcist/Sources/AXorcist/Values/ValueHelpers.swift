import ApplicationServices
import CoreGraphics // For CGPoint, CGSize etc.
import Foundation

// debug() is assumed to be globally available from Logging.swift
// Accessibility constants are now available through namespaced enums like AXAttributeNames, AXRoleNames, etc.

// ValueUnwrapper has been moved to its own file: ValueUnwrapper.swift

// MARK: - Attribute Value Accessors

@MainActor
public func copyAttributeValue(element: AXUIElement, attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    // This function is low-level, avoid extensive logging here unless specifically for this function.
    // Logging for attribute success/failure is better handled by the caller (axValue).
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
        return nil
    }
    return value
}

@MainActor
public func axValue<T>(
    of element: AXUIElement,
    attr: String,
    isDebugLoggingEnabled: Bool,
    currentDebugLogs: inout [String]
) -> T? {
    func dLog(_ message: String) {
        if isDebugLoggingEnabled {
            currentDebugLogs.append(message)
        }
    }

    let rawCFValue = copyAttributeValue(element: element, attribute: attr)
    let unwrappedValue = ValueUnwrapper.unwrap(
        rawCFValue,
        isDebugLoggingEnabled: isDebugLoggingEnabled,
        currentDebugLogs: &currentDebugLogs
    )

    guard let value = unwrappedValue else {
        return nil
    }

    // Call castValueToType from ValueCasters.swift
    return castValueToType(value, expectedType: T.self, attr: attr, dLog: dLog)
}

// MARK: - AXValueType String Helper

public func stringFromAXValueType(_ type: AXValueType) -> String {
    switch type {
    case .cgPoint: return "CGPoint (kAXValueCGPointType)"
    case .cgSize: return "CGSize (kAXValueCGSizeType)"
    case .cgRect: return "CGRect (kAXValueCGRectType)"
    case .cfRange: return "CFRange (kAXValueCFRangeType)"
    case .axError: return "AXError (kAXValueAXErrorType)"
    case .illegal: return "Illegal (kAXValueIllegalType)"
    default:
        // AXValueType is not exhaustive in Swift's AXValueType enum from ApplicationServices.
        // Common missing ones include Boolean (4), Number (5), Array (6), Dictionary (7), String (8), URL (9), etc.
        // We rely on ValueUnwrapper to handle these based on CFGetTypeID.
        // This function is mostly for AXValue encoded types.
        if type.rawValue == 4 { // kAXValueBooleanType is often 4 but not in the public enum
            return "Boolean (rawValue 4, contextually kAXValueBooleanType)"
        }
        return "Unknown AXValueType (rawValue: \(type.rawValue))"
    }
}
