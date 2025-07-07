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

    for (key, expectedValue) in matchDetails {
        if key == AXMiscConstants.computedNameAttributeKey + "_equals" ||
            key == AXMiscConstants.computedNameAttributeKey + "_contains"
        {
            continue
        }
        if key ==
            AXAttributeNames.kAXRoleAttribute
        {
            continue // Already handled by ElementSearch's role check or not a primary filter here
        }

        if key == AXAttributeNames.kAXEnabledAttribute ||
            key == AXAttributeNames.kAXFocusedAttribute ||
            key == AXAttributeNames.kAXHiddenAttribute ||
            key == AXAttributeNames.kAXElementBusyAttribute ||
            key == AXMiscConstants.isIgnoredAttributeKey ||
            key == AXAttributeNames.kAXMainAttribute
        {
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

        if key == AXAttributeNames.kAXActionNamesAttribute ||
            key == AXAttributeNames.kAXAllowedValuesAttribute ||
            key == AXAttributeNames.kAXChildrenAttribute
        {
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
