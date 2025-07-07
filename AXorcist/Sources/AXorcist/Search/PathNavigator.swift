// PathNavigator.swift - Contains logic for navigating element hierarchies using path hints

import ApplicationServices
import Foundation

// Note: Assumes Element, PathUtils, Attribute, AXorcist.formatDebugLogMessage are available.

// Helper to check if the current element matches a specific attribute-value pair
@MainActor
internal func currentElementMatchesPathComponent(
    _ element: Element,
    attributeName: String,
    expectedValue: String,
    isDebugLoggingEnabled: Bool,
    currentDebugLogs: inout [String] // For logging
) -> Bool {
    if attributeName.isEmpty { // Should not happen if parsePathComponent is robust
        return false
    }
    // Assuming Element.attribute can handle logging appropriately based on isDebugLoggingEnabled and AXORC_JSON_LOG_ENABLED
    if let actualValue = element.attribute(Attribute<String>(attributeName), isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs) {
        if actualValue == expectedValue {
            return true
        }
    }
    return false
}

// Updated navigateToElement to prioritize children
@MainActor
internal func navigateToElement(
    from startElement: Element,
    pathHint: [String],
    isDebugLoggingEnabled: Bool,
    currentDebugLogs: inout [String]
) -> Element? {
    func dLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        // Use the passed-in isDebugLoggingEnabled
        if isDebugLoggingEnabled {
            // Assumes AXorcist.formatDebugLogMessage is accessible, might need to be public or this moved to an AXorcist extension.
            // For now, let it be, build will tell if it's an issue.
            currentDebugLogs.append(AXorcist.formatDebugLogMessage(message, applicationName: nil, commandID: nil, file: file, function: function, line: line))
        }
    }

    var currentElement = startElement
    var currentPathSegmentForLog = ""

    for (index, pathComponentString) in pathHint.enumerated() {
        currentPathSegmentForLog += (index > 0 ? " -> " : "") + pathComponentString
        // Element.briefDescription needs access to logging parameters
        let briefDesc = currentElement.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs)
        dLog("Navigating: Processing path component '\(pathComponentString)' from current element: \(briefDesc)")

        let (attributeName, expectedValue) = PathUtils.parsePathComponent(pathComponentString)
        guard !attributeName.isEmpty else {
            dLog("CRITICAL_NAV_PARSE_FAILURE_MARKER: Empty attribute name from pathComponentString '\(pathComponentString)'")
            return nil
        }

        var foundMatchForThisComponent = false
        var newElementForNextStep: Element?

        // Priority 1: Check children using Element.children()
        if let childrenFromElementDotChildren = currentElement.children(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs) {
            dLog("Child count from Element.children(): \(childrenFromElementDotChildren.count)")
            for child in childrenFromElementDotChildren {
                let childBriefDescForLog = child.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs)
                if let actualValue = child.attribute(Attribute<String>(attributeName), isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs) {
                    dLog("  [Nav Child Check 1] Child: \(childBriefDescForLog), Attribute '\(attributeName)': [\(actualValue)] (Expected: [\(expectedValue)])")
                    if actualValue == expectedValue {
                        dLog("Matched child (from Element.children): \(childBriefDescForLog) for '\(attributeName):\(expectedValue)'")
                        newElementForNextStep = child
                        foundMatchForThisComponent = true
                        break
                    }
                }
            }
        } else {
            dLog("Current element \(briefDesc) has no children from Element.children() or children array was nil.")
        }

        // FALLBACK: If no child matched via Element.children(), try direct AXAttributeNames.kAXChildrenAttribute call (Heisenbug workaround)
        if !foundMatchForThisComponent {
            currentDebugLogs.append(AXorcist.formatDebugLogMessage("navigateToElement: No match from Element.children(). Trying direct AXAttributeNames.kAXChildrenAttribute fallback.", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))

            var directChildrenValue: CFTypeRef?
            let directChildrenError = AXUIElementCopyAttributeValue(currentElement.underlyingElement, AXAttributeNames.kAXChildrenAttribute as CFString, &directChildrenValue)

            let currentElementDescForFallbackLog = isDebugLoggingEnabled ? currentElement.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs) : "Element(debug_off)"
            currentDebugLogs.append(AXorcist.formatDebugLogMessage("navigateToElement: Fallback is for element: \(currentElementDescForFallbackLog)", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))

            if directChildrenError == .success, let cfArray = directChildrenValue, CFGetTypeID(cfArray) == CFArrayGetTypeID() {
                if let directAxElements = cfArray as? [AXUIElement] {
                    currentDebugLogs.append(AXorcist.formatDebugLogMessage("navigateToElement: Direct AXAttributeNames.kAXChildrenAttribute fallback found \(directAxElements.count) raw children for \(currentElementDescForFallbackLog).", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
                    for axChild in directAxElements {
                        let childElement = Element(axChild)
                        let childBriefDescForLogFallback = childElement.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs)
                        if let actualValue = childElement.attribute(Attribute<String>(attributeName), isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs) {
                            dLog("  [Nav Child Check 2-Fallback] Child: \(childBriefDescForLogFallback), Attribute '\(attributeName)': [\(actualValue)] (Expected: [\(expectedValue)])")
                            if actualValue == expectedValue {
                                currentDebugLogs.append(AXorcist.formatDebugLogMessage("navigateToElement: Matched child (from direct fallback) for '\(attributeName):\(expectedValue)' on \(currentElementDescForFallbackLog). Child: \(childElement.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs))", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
                                newElementForNextStep = childElement
                                foundMatchForThisComponent = true
                                break
                            }
                        }
                    }
                } else {
                    currentDebugLogs.append(AXorcist.formatDebugLogMessage("navigateToElement: Direct AXAttributeNames.kAXChildrenAttribute fallback: CFArray failed to cast to [AXUIElement] for \(currentElementDescForFallbackLog).", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
                }
            } else if directChildrenError != .success {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage("navigateToElement: Direct AXAttributeNames.kAXChildrenAttribute fallback: Error fetching for \(currentElementDescForFallbackLog): \(directChildrenError.rawValue)", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
            } else {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage("navigateToElement: Direct AXAttributeNames.kAXChildrenAttribute fallback: No children or not an array for \(currentElementDescForFallbackLog).", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
            }
        }

        // Priority 2: If no child matched (even after fallback), check current element itself
        if !foundMatchForThisComponent {
            // Pass currentDebugLogs by reference to the global currentElementMatchesPathComponent
            let matchResult = currentElementMatchesPathComponent(
                currentElement,
                attributeName: attributeName,
                expectedValue: expectedValue,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs // Pass by ref
            )

            if matchResult {
                dLog("Current element \(briefDesc) itself matches '\(attributeName):\(expectedValue)'. Retaining current element for this step.")
                newElementForNextStep = currentElement
                foundMatchForThisComponent = true
            }
        }

        if foundMatchForThisComponent, let nextElement = newElementForNextStep {
            currentElement = nextElement
        } else {
            dLog("Neither current element \(briefDesc) nor its children (after all checks) matched '\(attributeName):\(expectedValue)'. Path: \(currentPathSegmentForLog) // CHILD_MATCH_FAILURE_MARKER")
            return nil
        }
    }

    dLog("Navigation successful. Final element: \(currentElement.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs))")
    return currentElement
}
