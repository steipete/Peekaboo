// Element+ParameterizedAttributes.swift - Extension for parameterized attribute functionality

import ApplicationServices // For AXUIElement and other C APIs
import Foundation

// GlobalAXLogger is expected to be available in this module (AXorcistLib)

// MARK: - Parameterized Attributes Extension

extension Element {
    @MainActor
    public func parameterizedAttribute<T>(
        _ attribute: Attribute<T>,
        forParameter parameter: Any
    ) -> T? {
        guard let cfParameter = convertParameterToCFTypeRef(parameter, attribute: attribute) else {
            return nil
        }

        guard let resultCFValue = copyParameterizedAttributeValue(
            attribute: attribute,
            parameter: cfParameter
        ) else {
            return nil
        }

        guard let finalValue = ValueUnwrapper.unwrap(resultCFValue) else {
            axDebugLog("Unwrapping CFValue for parameterized attribute \(attribute.rawValue) resulted in nil.")
            return nil
        }

        return castValueToType(finalValue, attribute: attribute)
    }

    @MainActor
    private func convertParameterToCFTypeRef(_ parameter: Any, attribute: Attribute<some Any>) -> CFTypeRef? {
        if var range = parameter as? CFRange {
            return AXValueCreate(.cfRange, &range)
        } else if let string = parameter as? String {
            return string as CFString
        } else if let number = parameter as? NSNumber {
            return number
        } else if CFGetTypeID(parameter as CFTypeRef) != 0 {
            return parameter as CFTypeRef
        } else {
            axWarningLog("Unsupported parameter type \(type(of: parameter)) for attribute \(attribute.rawValue)")
            return nil
        }
    }

    @MainActor
    private func copyParameterizedAttributeValue(
        attribute: Attribute<some Any>,
        parameter: CFTypeRef
    ) -> CFTypeRef? {
        var value: CFTypeRef?
        let error = AXUIElementCopyParameterizedAttributeValue(
            underlyingElement,
            attribute.rawValue as CFString,
            parameter,
            &value
        )

        if error != .success {
            axDebugLog("Error \(error.rawValue) getting parameterized attribute \(attribute.rawValue)")
            return nil
        }

        guard let resultCFValue = value else {
            axDebugLog("Parameterized attribute \(attribute.rawValue) resulted in nil CFValue despite success.")
            return nil
        }

        return resultCFValue
    }

    @MainActor
    private func castValueToType<T>(_ finalValue: Any, attribute: Attribute<T>) -> T? {
        if T.self == String.self {
            if let str = finalValue as? String { return str as? T }
            if let attrStr = finalValue as? NSAttributedString { return attrStr.string as? T }
            axDebugLog(
                "Failed to cast unwrapped value for String attribute \(attribute.rawValue). " +
                    "Value: \(finalValue)"
            )
            return nil
        }

        if let castedValue = finalValue as? T {
            return castedValue
        }

        axWarningLog(
            "Fallback cast attempt for parameterized attribute '\(attribute.rawValue)' " +
                "to type \(T.self) FAILED. Unwrapped value was \(type(of: finalValue)): \(finalValue)"
        )
        return nil
    }
}

// MARK: - Specific Parameterized Attribute Accessors

public extension Element {
    @MainActor
    func string(forRange range: CFRange) -> String? {
        parameterizedAttribute(.stringForRangeParameterized, forParameter: range)
    }

    @MainActor
    func range(forLine line: Int) -> CFRange? {
        parameterizedAttribute(.rangeForLineParameterized, forParameter: NSNumber(value: line))
    }

    @MainActor
    func bounds(forRange range: CFRange) -> CGRect? {
        // The underlying attribute returns AXValueRef holding CGRect
        // The generic parameterizedAttribute should handle unwrapping if T is CGRect
        parameterizedAttribute(.boundsForRangeParameterized, forParameter: range)
    }

    @MainActor
    func line(forIndex index: Int) -> Int? {
        parameterizedAttribute(.lineForIndexParameterized, forParameter: NSNumber(value: index))
    }

    @MainActor
    func attributedString(forRange range: CFRange) -> NSAttributedString? {
        parameterizedAttribute(.attributedStringForRangeParameterized, forParameter: range)
    }

    @MainActor
    func cell(forColumn column: Int, row: Int) -> Element? {
        // Parameter for AXCellForColumnAndRowParameterized is an array of two NSNumbers: [col, row]
        let params = [NSNumber(value: column), NSNumber(value: row)]
        guard let axUIElement: AXUIElement = parameterizedAttribute(
            .cellForColumnAndRowParameterized,
            forParameter: params
        ) else {
            return nil
        }
        return Element(axUIElement)
    }

    @MainActor
    func actionDescription(_ actionName: String) -> String? {
        // kAXActionDescriptionAttribute is already Attribute<String>.actionDescription
        parameterizedAttribute(.actionDescription, forParameter: actionName)
    }
}
