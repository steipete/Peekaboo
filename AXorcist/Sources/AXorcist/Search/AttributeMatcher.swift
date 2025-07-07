import ApplicationServices // For AXUIElement, CFTypeRef etc.
import Foundation

// debug() is assumed to be globally available from Logging.swift
// DEBUG_LOGGING_ENABLED is a global public var from Logging.swift

@MainActor
internal func attributesMatch(
    element: Element,
    matchDetails: [String: String],
    depth: Int,
    isDebugLoggingEnabled: Bool,
    currentDebugLogs: inout [String]
) -> Bool {
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
    var tempLogs: [String] = [] // For Element method calls

    let criteriaDesc = matchDetails.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
    let roleForLog = element.role(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) ?? "nil"
    let titleForLog = element.title(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) ?? "nil"
    dLog("attributesMatch [D\(depth)]: Check. Role=\(roleForLog), Title=\(titleForLog). Criteria: [\(criteriaDesc)]")

    if !matchComputedNameAttributes(
        element: element,
        computedNameEquals: matchDetails[AXMiscConstants.computedNameAttributeKey + "_equals"],
        computedNameContains: matchDetails[AXMiscConstants.computedNameAttributeKey + "_contains"],
        depth: depth,
        isDebugLoggingEnabled: isDebugLoggingEnabled,
        currentDebugLogs: &currentDebugLogs
    ) {
        return false
    }

    for (key, expectedValue) in matchDetails {
        if key == AXMiscConstants.computedNameAttributeKey + "_equals" || key == AXMiscConstants.computedNameAttributeKey + "_contains" { continue }
        if key ==
            AXAttributeNames.kAXRoleAttribute { continue } // Already handled by ElementSearch's role check or not a primary filter here

        if key == AXAttributeNames.kAXEnabledAttribute || key == AXAttributeNames.kAXFocusedAttribute || key == AXAttributeNames.kAXHiddenAttribute || key ==
            AXAttributeNames.kAXElementBusyAttribute || key == AXMiscConstants.isIgnoredAttributeKey || key == AXAttributeNames.kAXMainAttribute {
            if !matchBooleanAttribute(
                element: element,
                key: key,
                expectedValueString: expectedValue,
                depth: depth,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            ) {
                return false
            }
            continue
        }

        if key == AXAttributeNames.kAXActionNamesAttribute || key == AXAttributeNames.kAXAllowedValuesAttribute || key == AXAttributeNames.kAXChildrenAttribute {
            if !matchArrayAttribute(
                element: element,
                key: key,
                expectedValueString: expectedValue,
                depth: depth,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            ) {
                return false
            }
            continue
        }

        if !matchStringAttribute(
            element: element,
            key: key,
            expectedValueString: expectedValue,
            depth: depth,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        ) {
            return false
        }
    }

    dLog("attributesMatch [D\(depth)]: All attributes MATCHED criteria.")
    return true
}
