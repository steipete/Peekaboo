// SpecificAttributeMatchers.swift - Contains specific helper functions for attribute matching.

import ApplicationServices
import Foundation

// Assumes Element, Attribute, AXMiscConstants.computedNameAttributeKey, AXMiscConstants.kAXNotAvailableString,
// AXAttributeNames.kAXRoleAttribute, AXAttributeNames.kAXEnabledAttribute,
// AXAttributeNames.kAXFocusedAttribute, AXAttributeNames.kAXHiddenAttribute,
// AXAttributeNames.kAXElementBusyAttribute, AXMiscConstants.isIgnoredAttributeKey, AXAttributeNames.kAXMainAttribute,
// AXAttributeNames.kAXActionNamesAttribute, AXAttributeNames.kAXAllowedValuesAttribute,
// AXAttributeNames.kAXChildrenAttribute are available.
// Assumes decodeExpectedArray (from ValueParser or similar) and
// getComputedAttributes (from AttributeHelpers) are available.

@MainActor
func matchStringAttribute(
    element: Element,
    key: String,
    expectedValueString: String,
    depth: Int
) -> Bool {
    if let currentValue = element.attribute(Attribute<String>(key)) {
        if currentValue != expectedValueString {
            axDebugLog(
                "attributesMatch [D\(depth)]: Attribute '\(key)' expected '\(expectedValueString)', " +
                    "but found '\(currentValue)'. No match.",
                file: #file,
                function: #function,
                line: #line
            )
            return false
        }
        return true
    } else {
        if expectedValueString.lowercased() == "nil" ||
            expectedValueString == AXMiscConstants.kAXNotAvailableString ||
            expectedValueString.isEmpty
        {
            axDebugLog(
                "attributesMatch [D\(depth)]: Attribute '\(key)' not found, but expected value " +
                    "('\(expectedValueString)') suggests absence is OK. Match for this key.",
                file: #file,
                function: #function,
                line: #line
            )
            return true
        } else {
            axDebugLog(
                "attributesMatch [D\(depth)]: Attribute '\(key)' " +
                    "(expected '\(expectedValueString)') not found or not convertible to String. No match.",
                file: #file,
                function: #function,
                line: #line
            )
            return false
        }
    }
}

@MainActor
func matchArrayAttribute(
    element: Element,
    key: String,
    expectedValueString: String,
    depth: Int
) -> Bool {
    guard let expectedArray = decodeExpectedArray(fromString: expectedValueString) else {
        logArrayAttributeWarning(
            "Could not decode expected array string '\(expectedValueString)' for attribute '\(key)'.",
            depth: depth)
        return false
    }

    switch fetchArrayAttribute(element: element, key: key) {
    case .unsupported:
        logArrayAttributeWarning(
            "Unknown array key '\(key)'. Extend matchArrayAttribute for this key.",
            depth: depth)
        return false
    case .missing:
        return handleMissingArrayAttribute(
            expectedArray: expectedArray,
            expectedValueString: expectedValueString,
            key: key,
            depth: depth)
    case .value(let actual):
        guard Set(actual) == Set(expectedArray) else {
            axDebugLog(
                "matchArrayAttribute [D\(depth)]: Array Attribute '\(key)' expected '\(expectedArray)', " +
                    "but found '\(actual)'. Sets differ. No match.",
                file: #file,
                function: #function,
                line: #line
            )
            return false
        }
        return true
    }
}

private enum ArrayAttributeFetchResult {
    case value([String])
    case missing
    case unsupported
}

@MainActor
private func fetchArrayAttribute(element: Element, key: String) -> ArrayAttributeFetchResult {
    switch key {
    case AXAttributeNames.kAXActionNamesAttribute:
        return element.supportedActions().map(ArrayAttributeFetchResult.value) ?? .missing
    case AXAttributeNames.kAXAllowedValuesAttribute:
        let value = element.attribute(Attribute<[String]>(key))
        return value.map(ArrayAttributeFetchResult.value) ?? .missing
    case AXAttributeNames.kAXChildrenAttribute:
        let children = element.children()?.map { $0.role() ?? "UnknownRole" }
        return children.map(ArrayAttributeFetchResult.value) ?? .missing
    default:
        return .unsupported
    }
}

@MainActor
private func handleMissingArrayAttribute(
    expectedArray: [String],
    expectedValueString: String,
    key: String,
    depth: Int) -> Bool
{
    if expectedArray.isEmpty {
        axDebugLog(
            "matchArrayAttribute [D\(depth)]: Array Attribute '\(key)' not found, " +
                "but expected array was empty. Match for this key.",
            file: #file,
            function: #function,
            line: #line
        )
        return true
    }
    axDebugLog(
        "matchArrayAttribute [D\(depth)]: Array Attribute '\(key)' " +
            "(expected '\(expectedValueString)') not found in element. No match.",
        file: #file,
        function: #function,
        line: #line
    )
    return false
}

private func logArrayAttributeWarning(_ message: String, depth: Int) {
    axWarningLog(
        "matchArrayAttribute [D\(depth)]: \(message)",
        file: #file,
        function: #function,
        line: #line
    )
}

@MainActor
func matchBooleanAttribute(
    element: Element,
    key: String,
    expectedValueString: String,
    depth: Int
) -> Bool {
    var currentBoolValue: Bool?

    switch key {
    case AXAttributeNames.kAXEnabledAttribute: currentBoolValue = element.isEnabled()
    case AXAttributeNames.kAXFocusedAttribute: currentBoolValue = element.isFocused()
    case AXAttributeNames.kAXHiddenAttribute: currentBoolValue = element.isHidden()
    case AXAttributeNames.kAXElementBusyAttribute: currentBoolValue = element.isElementBusy()
    case AXMiscConstants.isIgnoredAttributeKey: currentBoolValue = element.isIgnored()
    case AXAttributeNames.kAXMainAttribute: currentBoolValue = element.attribute(Attribute<Bool>(key))
    default:
        axWarningLog(
            "matchBooleanAttribute [D\(depth)]: Unknown boolean key '\(key)'. This should not happen.",
            file: #file,
            function: #function,
            line: #line
        )
        return false
    }

    if let actualBool = currentBoolValue {
        let expectedBool = expectedValueString.lowercased() == "true"
        if actualBool != expectedBool {
            axDebugLog(
                "attributesMatch [D\(depth)]: Boolean Attribute '\(key)' expected '\(expectedBool)', " +
                    "but found '\(actualBool)'. No match.",
                file: #file,
                function: #function,
                line: #line
            )
            return false
        }
        return true
    } else {
        axDebugLog(
            "attributesMatch [D\(depth)]: Boolean Attribute '\(key)' " +
                "(expected '\(expectedValueString)') not found in element. No match.",
            file: #file,
            function: #function,
            line: #line
        )
        return false
    }
}

@MainActor
func matchComputedNameAttributes(
    element: Element,
    computedNameEquals: String?,
    computedNameContains: String?,
    depth: Int
) async -> Bool {
    if computedNameEquals == nil, computedNameContains == nil {
        return true // No computed name criteria to match, so this part passes.
    }

    let computedAttrs = await getComputedAttributes(for: element)
    let computedNameKey = AXMiscConstants.computedNameAttributeKey
    if let currentComputedName = computedAttrs[computedNameKey]?.value.stringValue
    {
        if let equals = computedNameEquals {
            if currentComputedName != equals {
                axDebugLog(
                    "matchComputedNameAttributes [D\(depth)]: ComputedName '\(currentComputedName)' " +
                        "!= '\(equals)'. No match.",
                    file: #file,
                    function: #function,
                    line: #line
                )
                return false
            }
        }
        if let contains = computedNameContains {
            if !currentComputedName.localizedCaseInsensitiveContains(contains) {
                axDebugLog(
                    "matchComputedNameAttributes [D\(depth)]: ComputedName '\(currentComputedName)' " +
                        "does not contain '\(contains)'. No match.",
                    file: #file,
                    function: #function,
                    line: #line
                )
                return false
            }
        }
        return true
    } else {
        if computedNameEquals != nil || computedNameContains != nil {
            let equalsStr = computedNameEquals ?? "nil"
            let containsStr = computedNameContains ?? "nil"
            axDebugLog(
                "matchComputedNameAttributes [D\(depth)]: Locator requires ComputedName " +
                    "(equals: \(equalsStr), contains: \(containsStr)), " +
                    "but element has none or it's not a string. No match.",
                file: #file,
                function: #function,
                line: #line
            )
            return false
        }
        return true
    }
}
