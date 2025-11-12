// PathNavigationMatching.swift - Element matching functions for path navigation

import ApplicationServices
import Foundation

private let smartValueFormat: ValueFormatOption = .smart

private func logPathNavigation(_ level: AXLogLevel, _ message: String) {
    GlobalAXLogger.shared.log(AXLogEntry(level: level, message: message))
}

// MARK: - Element Matching

// New helper to check if an element matches all given criteria
@MainActor
func elementMatchesAllCriteria(
    _ element: Element,
    criteria: [String: String],
    forPathComponent pathComponentForLog: String // For logging
) -> Bool {
    let elementDescription = element.briefDescription(option: smartValueFormat)
    logCriteriaEvaluationStart(
        elementDescription: elementDescription,
        component: pathComponentForLog,
        criteria: criteria
    )

    if criteria.isEmpty {
        logEmptyCriteriaMatch(elementDescription: elementDescription, component: pathComponentForLog)
        return true
    }

    for (key, expectedValue) in criteria {
        let matchType = matchTypeForCriterionKey(key)
        logCriterionCheck(
            key: key,
            expectedValue: expectedValue,
            matchType: matchType,
            elementDescription: elementDescription,
            component: pathComponentForLog
        )

        let didMatch = criterionMatches(
            element: element,
            key: key,
            expectedValue: expectedValue,
            matchType: matchType,
            component: pathComponentForLog
        )

        if !didMatch {
            logCriterionFailure(
                key: key,
                expectedValue: expectedValue,
                elementDescription: elementDescription,
                component: pathComponentForLog
            )
            return false
        }
    }

    logCriteriaSuccess(elementDescription: elementDescription, component: pathComponentForLog)
    return true
}

private func logCriteriaEvaluationStart(
    elementDescription: String,
    component: String,
    criteria: [String: String]
) {
    let message = "PN/EMAC_START: Checking element [\(elementDescription)] for component [\(component)]. "
        + "Criteria: \(criteria)"
    logPathNavigation(.info, message)
}

private func logEmptyCriteriaMatch(elementDescription: String, component: String) {
    let debugMessage = "PN/EMAC: Criteria empty for component [\(component)]. "
        + "Element [\(elementDescription)] considered a match by default."
    logPathNavigation(.debug, debugMessage)
    let infoMessage = "PN/EMAC_END: Element [\(elementDescription)] MATCHED (empty criteria) "
        + "for component [\(component)]."
    logPathNavigation(.info, infoMessage)
}

private func matchTypeForCriterionKey(_ key: String) -> JSONPathHintComponent.MatchType {
    let domClassAttribute = AXAttributeNames.kAXDOMClassListAttribute.lowercased()
    return key.lowercased() == domClassAttribute ? .contains : .exact
}

private func logCriterionCheck(
    key: String,
    expectedValue: String,
    matchType: JSONPathHintComponent.MatchType,
    elementDescription: String,
    component: String
) {
    let message = "PN/EMAC_CRITERION: Checking criterion '\(key): \(expectedValue)' (matchType: \(matchType.rawValue)) "
        + "on element [\(elementDescription)] for component [\(component)]."
    logPathNavigation(.debug, message)
}

private func criterionMatches(
    element: Element,
    key: String,
    expectedValue: String,
    matchType: JSONPathHintComponent.MatchType,
    component: String
) -> Bool {
    let elementDescription = element.briefDescription(option: smartValueFormat)
    let didMatch = matchSingleCriterion(
        element: element,
        key: key,
        expectedValue: expectedValue,
        matchType: matchType,
        elementDescriptionForLog: elementDescription
    )
    logCriterionResult(
        key: key,
        expectedValue: expectedValue,
        elementDescription: elementDescription,
        component: component,
        didMatch: didMatch
    )
    return didMatch
}

private func logCriterionResult(
    key: String,
    expectedValue: String,
    elementDescription: String,
    component: String,
    didMatch: Bool
) {
    let status = didMatch ? "MATCHED" : "FAILED"
    let message = "PN/EMAC_CRITERION_RESULT: Criterion '\(key): \(expectedValue)' on [\(elementDescription)] "
        + "for [\(component)]: \(status)"
    logPathNavigation(.debug, message)
}

private func logCriterionFailure(
    key: String,
    expectedValue: String,
    elementDescription: String,
    component: String
) {
    let debugMessage = "PN/EMAC: Element [\(elementDescription)] FAILED to match criterion '\(key): \(expectedValue)' "
        + "for component [\(component)]."
    logPathNavigation(.debug, debugMessage)
    let infoMessage = "PN/EMAC_END: Element [\(elementDescription)] FAILED for component [\(component)]."
    logPathNavigation(.info, infoMessage)
}

private func logCriteriaSuccess(elementDescription: String, component: String) {
    let debugMessage = "PN/EMAC: Element [\(elementDescription)] successfully MATCHED ALL criteria for component "
        + "[\(component)]."
    logPathNavigation(.debug, debugMessage)
    let infoMessage = "PN/EMAC_END: Element [\(elementDescription)] MATCHED ALL criteria for component [\(component)]."
    logPathNavigation(.info, infoMessage)
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

    let parentDescription = parentElement.briefDescription(option: smartValueFormat)
    let searchMessage = "PN/FMC: Searching for matching child among \(children.count) children of "
        + "[\(parentDescription)] for component [\(pathComponentForLog)]."
    logPathNavigation(.debug, searchMessage)

    for (childIndex, child) in children.enumerated()
        where elementMatchesAllCriteria(child, criteria: criteriaToMatch, forPathComponent: pathComponentForLog)
    {
        let childDescription = child.briefDescription(option: smartValueFormat)
        let matchMessage = "PN/FMC: Found matching child at index \(childIndex) for component "
            + "[\(pathComponentForLog)]: [\(childDescription)]."
        logPathNavigation(.info, matchMessage)
        return child
    }

    let failureMessage =
        "PN/FMC: No matching child found for component [\(pathComponentForLog)] among \(children.count) children."
    logPathNavigation(.debug, failureMessage)
    return nil
}

@MainActor
func logNoMatchFound(
    currentElement: Element,
    pathComponentString: String,
    criteriaToMatch: [String: String],
    currentPathSegmentForLog: String
) {
    let elementDescription = currentElement.briefDescription(option: smartValueFormat)
    let message = "Path component '\(pathComponentString)' with criteria \(criteriaToMatch) did not match any child "
        + "or current element [\(elementDescription)]. Path so far: \(currentPathSegmentForLog)"
    logPathNavigation(.warning, message)
}
