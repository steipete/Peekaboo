// SpecificAttributeMatchers.swift - Contains specific helper functions for attribute matching.

import ApplicationServices
import Foundation

// Assumes Element, Attribute, AXMiscConstants.computedNameAttributeKey, AXMiscConstants.kAXNotAvailableString,
// AXAttributeNames.kAXRoleAttribute, AXAttributeNames.kAXEnabledAttribute, AXAttributeNames.kAXFocusedAttribute, AXAttributeNames.kAXHiddenAttribute,
// AXAttributeNames.kAXElementBusyAttribute, AXMiscConstants.isIgnoredAttributeKey, AXAttributeNames.kAXMainAttribute,
// AXAttributeNames.kAXActionNamesAttribute, AXAttributeNames.kAXAllowedValuesAttribute, AXAttributeNames.kAXChildrenAttribute are available.
// Assumes decodeExpectedArray (from ValueParser or similar) and getComputedAttributes (from AttributeHelpers) are available.

@MainActor
internal func matchStringAttribute(
    element: Element,
    key: String,
    expectedValueString: String,
    depth: Int,
    isDebugLoggingEnabled: Bool,
    currentDebugLogs: inout [String]
) -> Bool {
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
    var tempLogs: [String] = [] // For Element method calls

    if let currentValue = element.attribute(
        Attribute<String>(key),
        isDebugLoggingEnabled: isDebugLoggingEnabled,
        currentDebugLogs: &tempLogs
    ) {
        if currentValue != expectedValueString {
            dLog(
                "attributesMatch [D\(depth)]: Attribute '\(key)' expected '\(expectedValueString)', but found '\(currentValue)'. No match."
            )
            return false
        }
        return true
    } else {
        if expectedValueString
            .lowercased() == "nil" || expectedValueString == AXMiscConstants.kAXNotAvailableString || expectedValueString.isEmpty {
            dLog(
                "attributesMatch [D\(depth)]: Attribute '\(key)' not found, but expected value ('\(expectedValueString)') suggests absence is OK. Match for this key."
            )
            return true
        } else {
            dLog(
                "attributesMatch [D\(depth)]: Attribute '\(key)' (expected '\(expectedValueString)') not found or not convertible to String. No match."
            )
            return false
        }
    }
}

@MainActor
internal func matchArrayAttribute(
    element: Element,
    key: String,
    expectedValueString: String,
    depth: Int,
    isDebugLoggingEnabled: Bool,
    currentDebugLogs: inout [String]
) -> Bool {
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
    var tempLogs: [String] = [] // For Element method calls

    guard let expectedArray = decodeExpectedArray(
        fromString: expectedValueString,
        isDebugLoggingEnabled: isDebugLoggingEnabled,
        currentDebugLogs: &currentDebugLogs
    ) else {
        dLog(
            "matchArrayAttribute [D\(depth)]: Could not decode expected array string '\(expectedValueString)' for attribute '\(key)'. No match."
        )
        return false
    }

    var actualArray: [String]?
    if key == AXAttributeNames.kAXActionNamesAttribute {
        actualArray = element.supportedActions(
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &tempLogs
        )
    } else if key == AXAttributeNames.kAXAllowedValuesAttribute {
        actualArray = element.attribute(
            Attribute<[String]>(key),
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &tempLogs
        )
    } else if key == AXAttributeNames.kAXChildrenAttribute {
        actualArray = element.children(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)?
            .map { childElement -> String in
                var childLogs: [String] = []
                return childElement
                    .role(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &childLogs) ?? "UnknownRole"
            }
    } else {
        dLog(
            "matchArrayAttribute [D\(depth)]: Unknown array key '\(key)'. This function needs to be extended for this key."
        )
        return false
    }

    if let actual = actualArray {
        if Set(actual) != Set(expectedArray) {
            dLog(
                "matchArrayAttribute [D\(depth)]: Array Attribute '\(key)' expected '\(expectedArray)', but found '\(actual)'. Sets differ. No match."
            )
            return false
        }
        return true
    } else {
        if expectedArray.isEmpty {
            dLog(
                "matchArrayAttribute [D\(depth)]: Array Attribute '\(key)' not found, but expected array was empty. Match for this key."
            )
            return true
        }
        dLog(
            "matchArrayAttribute [D\(depth)]: Array Attribute '\(key)' (expected '\(expectedValueString)') not found in element. No match."
        )
        return false
    }
}

@MainActor
internal func matchBooleanAttribute(
    element: Element,
    key: String,
    expectedValueString: String,
    depth: Int,
    isDebugLoggingEnabled: Bool,
    currentDebugLogs: inout [String]
) -> Bool {
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
    var tempLogs: [String] = [] // For Element method calls
    var currentBoolValue: Bool?

    switch key {
    case AXAttributeNames.kAXEnabledAttribute: currentBoolValue = element.isEnabled(
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &tempLogs
        )
    case AXAttributeNames.kAXFocusedAttribute: currentBoolValue = element.isFocused(
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &tempLogs
        )
    case AXAttributeNames.kAXHiddenAttribute: currentBoolValue = element.isHidden(
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &tempLogs
        )
    case AXAttributeNames.kAXElementBusyAttribute: currentBoolValue = element.isElementBusy(
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &tempLogs
        )
    case AXMiscConstants.isIgnoredAttributeKey: currentBoolValue = element.isIgnored(
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &tempLogs
        )
    case AXAttributeNames.kAXMainAttribute: currentBoolValue = element.attribute(
            Attribute<Bool>(key),
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &tempLogs
        )
    default:
        dLog("matchBooleanAttribute [D\(depth)]: Unknown boolean key '\(key)'. This should not happen.")
        return false
    }

    if let actualBool = currentBoolValue {
        let expectedBool = expectedValueString.lowercased() == "true"
        if actualBool != expectedBool {
            dLog(
                "attributesMatch [D\(depth)]: Boolean Attribute '\(key)' expected '\(expectedBool)', but found '\(actualBool)'. No match."
            )
            return false
        }
        return true
    } else {
        dLog(
            "attributesMatch [D\(depth)]: Boolean Attribute '\(key)' (expected '\(expectedValueString)') not found in element. No match."
        )
        return false
    }
}

@MainActor
internal func matchComputedNameAttributes(
    element: Element,
    computedNameEquals: String?,
    computedNameContains: String?,
    depth: Int,
    isDebugLoggingEnabled: Bool,
    currentDebugLogs: inout [String]
) -> Bool {
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
    var tempLogs: [String] = [] // For Element method calls

    if computedNameEquals == nil && computedNameContains == nil {
        return true // No computed name criteria to match, so this part passes.
    }

    // getComputedAttributes will need logging parameters
    let computedAttrs = getComputedAttributes(
        for: element,
        isDebugLoggingEnabled: isDebugLoggingEnabled,
        currentDebugLogs: &tempLogs
    )
    // Assuming AXMiscConstants.computedNameAttributeKey is a globally defined constant string for the key like "computedName"
    // And AttributeData has a `value: AnyCodable?` property
    if let currentComputedNameAnyCodable = computedAttrs[AXMiscConstants.computedNameAttributeKey]?.value as? AnyCodable,
       let currentComputedName = currentComputedNameAnyCodable.value as? String {
        if let equals = computedNameEquals {
            if currentComputedName != equals {
                dLog(
                    "matchComputedNameAttributes [D\(depth)]: ComputedName '\(currentComputedName)' != '\(equals)'. No match."
                )
                return false
            }
        }
        if let contains = computedNameContains {
            if !currentComputedName.localizedCaseInsensitiveContains(contains) {
                dLog(
                    "matchComputedNameAttributes [D\(depth)]: ComputedName '\(currentComputedName)' does not contain '\(contains)'. No match."
                )
                return false
            }
        }
        return true
    } else {
        // Only log failure if there was a criteria for computed name.
        if computedNameEquals != nil || computedNameContains != nil {
            dLog(
                "matchComputedNameAttributes [D\(depth)]: Locator requires ComputedName (equals: \(computedNameEquals ?? "nil"), contains: \(computedNameContains ?? "nil")), but element has none or it's not a string. No match."
            )
            return false
        }
        return true // No criteria, and no computed name, effectively a pass for this sub-check.
    }
}
