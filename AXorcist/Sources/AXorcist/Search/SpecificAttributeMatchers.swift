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
        axWarningLog(
            "matchArrayAttribute [D\(depth)]: Could not decode expected array string " +
                "'\(expectedValueString)' for attribute '\(key)'. No match.",
            file: #file,
            function: #function,
            line: #line
        )
        return false
    }

    var actualArray: [String]?
    if key == AXAttributeNames.kAXActionNamesAttribute {
        actualArray = element.supportedActions()
    } else if key == AXAttributeNames.kAXAllowedValuesAttribute {
        actualArray = element.attribute(Attribute<[String]>(key))
    } else if key == AXAttributeNames.kAXChildrenAttribute {
        actualArray = element.children()?.map { childElement -> String in
            childElement.role() ?? "UnknownRole"
        }
    } else {
        axWarningLog(
            "matchArrayAttribute [D\(depth)]: Unknown array key '\(key)'. " +
                "This function needs to be extended for this key.",
            file: #file,
            function: #function,
            line: #line
        )
        return false
    }

    if let actual = actualArray {
        if Set(actual) != Set(expectedArray) {
            axDebugLog(
                "matchArrayAttribute [D\(depth)]: Array Attribute '\(key)' expected '\(expectedArray)', " +
                    "but found '\(actual)'. Sets differ. No match.",
                file: #file, function: #function, line: #line
            )
            return false
        }
        return true
    } else {
        if expectedArray.isEmpty {
            axDebugLog(
                "matchArrayAttribute [D\(depth)]: Array Attribute '\(key)' not found, " +
                    "but expected array was empty. Match for this key.",
                file: #file, function: #function, line: #line
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
                file: #file, function: #function, line: #line
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
    if let currentComputedNameAnyCodable = computedAttrs[computedNameKey]?.value as? AnyCodable,
       let currentComputedName = currentComputedNameAnyCodable.value as? String
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
                file: #file, function: #function, line: #line
            )
            return false
        }
        return true
    }
}
