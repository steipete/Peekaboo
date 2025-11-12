import ApplicationServices // For AXUIElement, CFTypeRef etc.
import Foundation

// debug() is assumed to be globally available from Logging.swift
// DEBUG_LOGGING_ENABLED is a global public var from Logging.swift

@MainActor
func attributesMatch(
    element: Element,
    matchDetails: [String: String],
    depth: Int
) async -> Bool {
    let criteriaDesc = matchDetails.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
    let roleForLog = element.role() ?? "nil"
    let titleForLog = element.title() ?? "nil"
    axDebugLog(
        "attributesMatch [D\(depth)]: Check. Role=\(roleForLog), Title=\(titleForLog). " +
            "Criteria: [\(criteriaDesc)]",
        file: #file,
        function: #function,
        line: #line
    )

    if await !matchComputedNameAttributes(
        element: element,
        computedNameEquals: matchDetails[AXMiscConstants.computedNameAttributeKey + "_equals"],
        computedNameContains: matchDetails[AXMiscConstants.computedNameAttributeKey + "_contains"],
        depth: depth
    ) {
        return false
    }

    return evaluateAttributeMatches(element: element, matchDetails: matchDetails, depth: depth)
}

@MainActor
private func evaluateAttributeMatches(
    element: Element,
    matchDetails: [String: String],
    depth: Int
) -> Bool {
    for (key, expectedValue) in matchDetails {
        if shouldSkipComputedCheck(key) || shouldSkipRoleCheck(key) {
            continue
        }

        if isBooleanAttribute(key) {
            if !matchBooleanAttribute(
                element: element,
                key: key,
                expectedValueString: expectedValue,
                depth: depth
            ) {
                return false
            }
            continue
        }

        if isArrayAttribute(key) {
            if !matchArrayAttribute(
                element: element,
                key: key,
                expectedValueString: expectedValue,
                depth: depth
            ) {
                return false
            }
            continue
        }

        if !matchStringAttribute(
            element: element,
            key: key,
            expectedValueString: expectedValue,
            depth: depth
        ) {
            return false
        }
    }

    axDebugLog(
        "attributesMatch [D\(depth)]: All attributes MATCHED criteria.",
        file: #file,
        function: #function,
        line: #line
    )
    return true
}

private func shouldSkipComputedCheck(_ key: String) -> Bool {
    key == AXMiscConstants.computedNameAttributeKey + "_equals" ||
        key == AXMiscConstants.computedNameAttributeKey + "_contains"
}

private func shouldSkipRoleCheck(_ key: String) -> Bool {
    key == AXAttributeNames.kAXRoleAttribute
}

private func isBooleanAttribute(_ key: String) -> Bool {
    let booleanKeys: Set<String> = [
        AXAttributeNames.kAXEnabledAttribute,
        AXAttributeNames.kAXFocusedAttribute,
        AXAttributeNames.kAXHiddenAttribute,
        AXAttributeNames.kAXElementBusyAttribute,
        AXMiscConstants.isIgnoredAttributeKey,
        AXAttributeNames.kAXMainAttribute
    ]
    return booleanKeys.contains(key)
}

private func isArrayAttribute(_ key: String) -> Bool {
    let arrayKeys: Set<String> = [
        AXAttributeNames.kAXActionNamesAttribute,
        AXAttributeNames.kAXAllowedValuesAttribute,
        AXAttributeNames.kAXChildrenAttribute
    ]
    return arrayKeys.contains(key)
}
