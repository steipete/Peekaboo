// Element+ParameterizedAttributes.swift - Extension for parameterized attribute functionality

import ApplicationServices // For AXUIElement and other C APIs
import Foundation

// MARK: - Parameterized Attributes Extension
extension Element {
    @MainActor
    public func parameterizedAttribute<T>(
        _ attribute: Attribute<T>,
        forParameter parameter: Any,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) -> T? {
        func dLog(_ message: String) {
            if isDebugLoggingEnabled && false {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage(message, applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
            }
        }
        var cfParameter: CFTypeRef?

        // Convert Swift parameter to CFTypeRef for the API
        if var range = parameter as? CFRange {
            cfParameter = AXValueCreate(.cfRange, &range)
        } else if let string = parameter as? String {
            cfParameter = string as CFString
        } else if let number = parameter as? NSNumber {
            cfParameter = number
        } else if CFGetTypeID(parameter as CFTypeRef) != 0 { // Check if it's already a CFTypeRef-compatible type
            cfParameter = (parameter as CFTypeRef)
        } else {
            dLog("parameterizedAttribute: Unsupported parameter type \(type(of: parameter))")
            return nil
        }

        guard let actualCFParameter = cfParameter else {
            dLog("parameterizedAttribute: Failed to convert parameter to CFTypeRef.")
            return nil
        }

        var value: CFTypeRef?
        let error = AXUIElementCopyParameterizedAttributeValue(
            underlyingElement,
            attribute.rawValue as CFString,
            actualCFParameter,
            &value
        )

        if error != .success {
            dLog("parameterizedAttribute: Error \(error.rawValue) getting attribute \(attribute.rawValue)")
            return nil
        }

        guard let resultCFValue = value else { return nil }

        // Use axValue's unwrapping and casting logic if possible, by temporarily creating an element and attribute
        // This is a bit of a conceptual stretch, as axValue is designed for direct attributes.
        // A more direct unwrap using ValueUnwrapper might be cleaner here.
        let unwrappedValue = ValueUnwrapper.unwrap(
            resultCFValue,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )

        guard let finalValue = unwrappedValue else { return nil }

        // Perform type casting similar to axValue
        if T.self == String.self {
            if let str = finalValue as? String { return str as? T } else if let attrStr = finalValue as? NSAttributedString { return attrStr.string as? T }
            return nil
        }
        if let castedValue = finalValue as? T {
            return castedValue
        }
        dLog(
            "parameterizedAttribute: Fallback cast attempt for attribute '\(attribute.rawValue)' to type \(T.self) FAILED. Unwrapped value was \(type(of: finalValue)): \(finalValue)"
        )
        return nil
    }
}
