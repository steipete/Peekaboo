// PathNavigationMatching.swift - Element matching functions for path navigation

import ApplicationServices
import Foundation

// MARK: - Element Matching

// New helper to check if an element matches all given criteria
@MainActor
func elementMatchesAllCriteria(
    _ element: Element,
    criteria: [String: String],
    forPathComponent pathComponentForLog: String // For logging
) -> Bool {
    let elementDescriptionForLog = element.briefDescription(option: ValueFormatOption.smart)
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .info,
        message: "PN/EMAC_START: Checking element [\(elementDescriptionForLog)] for component [\(pathComponentForLog)]. Criteria: \(criteria)"
    ))

    if criteria.isEmpty {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "PN/EMAC: Criteria empty for component [\(pathComponentForLog)]. " +
                "Element [\(elementDescriptionForLog)] considered a match by default."
        ))
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .info,
            message: "PN/EMAC_END: Element [\(elementDescriptionForLog)] MATCHED (empty criteria) for component [\(pathComponentForLog)]."
        ))
        return true
    }

    for (key, expectedValue) in criteria {
        let matchTypeForKey: JSONPathHintComponent
            .MatchType = (key.lowercased() == AXAttributeNames.kAXDOMClassListAttribute.lowercased()) ? .contains :
            .exact
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "PN/EMAC_CRITERION: Checking criterion '\(key): \(expectedValue)' " +
                "(matchType: \(matchTypeForKey.rawValue)) on element [\(elementDescriptionForLog)] " +
                "for component [\(pathComponentForLog)]."
        ))

        let criterionDidMatch = matchSingleCriterion(
            element: element,
            key: key,
            expectedValue: expectedValue,
            matchType: matchTypeForKey,
            elementDescriptionForLog: elementDescriptionForLog
        )
        let message =
            "PN/EMAC_CRITERION_RESULT: Criterion '\(key): \(expectedValue)' on [\(elementDescriptionForLog)] for [\(pathComponentForLog)]: \(criterionDidMatch ? "MATCHED" : "FAILED")"
        GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message: message))

        if !criterionDidMatch {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "PN/EMAC: Element [\(elementDescriptionForLog)] FAILED to match criterion '\(key): \(expectedValue)' " +
                    "for component [\(pathComponentForLog)]."
            ))
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .info,
                message: "PN/EMAC_END: Element [\(elementDescriptionForLog)] FAILED for component [\(pathComponentForLog)]."
            ))
            return false
        }
    }

    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "PN/EMAC: Element [\(elementDescriptionForLog)] successfully MATCHED ALL criteria for component [\(pathComponentForLog)]."
    ))
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .info,
        message: "PN/EMAC_END: Element [\(elementDescriptionForLog)] MATCHED ALL criteria for component [\(pathComponentForLog)]."
    ))
    return true
}

@MainActor
func findMatchingChild(
    parentElement: Element,
    criteriaToMatch: [String: String],
    pathComponentForLog: String
) -> Element? {
    guard let children = getChildrenFromElement(parentElement) else {
        return nil
    }

    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "PN/FMC: Searching for matching child among \(children.count) children of " +
            "[\(parentElement.briefDescription(option: ValueFormatOption.smart))] for component [\(pathComponentForLog)]."
    ))

    for (childIndex, child) in children.enumerated()
        where elementMatchesAllCriteria(child, criteria: criteriaToMatch, forPathComponent: pathComponentForLog)
    {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .info,
            message: "PN/FMC: Found matching child at index \(childIndex) for component [\(pathComponentForLog)]: " +
                "[\(child.briefDescription(option: ValueFormatOption.smart))]."
        ))
        return child
    }

    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "PN/FMC: No matching child found for component [\(pathComponentForLog)] among \(children.count) children."
    ))
    return nil
}

@MainActor
func logNoMatchFound(
    currentElement: Element,
    pathComponentString: String,
    criteriaToMatch: [String: String],
    currentPathSegmentForLog: String
) {
    let currentElementDescForLog = currentElement.briefDescription(option: ValueFormatOption.smart)
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .warning,
        message: "Path component '\(pathComponentString)' with criteria \(criteriaToMatch) did not match any child " +
            "or current element [\(currentElementDescForLog)]. Path so far: \(currentPathSegmentForLog)"
    ))
}
