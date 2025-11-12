// AttributeMatchingFunctions.swift - Specific attribute matching functions

import Foundation

@MainActor
func matchRoleAttribute(
    element: Element,
    expectedValue: String,
    matchType: JSONPathHintComponent.MatchType,
    elementDescriptionForLog: String
) -> Bool {
    let actual = element.role()
    GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message: "SC/MSC/Role: Actual='\(actual ?? "nil")'"))
    if actual == AXRoleNames.kAXTextAreaRole {
        let domClassList = element.attribute(Attribute<Any>(AXAttributeNames.kAXDOMClassListAttribute))
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .info,
            message: "SC/MSC/Role: ELEMENT IS AXTextArea. " +
                "Its AXDOMClassList is: \(String(describing: domClassList))"
        ))
    }
    return compareStrings(
        actual, expectedValue, matchType,
        caseSensitive: false,
        attributeName: AXAttributeNames.kAXRoleAttribute,
        elementDescriptionForLog: elementDescriptionForLog
    )
}

@MainActor
func matchSubroleAttribute(
    element: Element,
    expectedValue: String,
    matchType: JSONPathHintComponent.MatchType,
    elementDescriptionForLog: String
) -> Bool {
    let actual = element.subrole()
    GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message: "SC/MSC/Subrole: Actual='\(actual ?? "nil")'"))
    return compareStrings(
        actual, expectedValue, matchType,
        caseSensitive: false,
        attributeName: AXAttributeNames.kAXSubroleAttribute,
        elementDescriptionForLog: elementDescriptionForLog
    )
}

@MainActor
func matchIdentifierAttribute(
    element: Element,
    expectedValue: String,
    matchType: JSONPathHintComponent.MatchType,
    elementDescriptionForLog: String
) -> Bool {
    let actual = element.identifier()
    GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message: "SC/MSC/ID: Actual='\(actual ?? "nil")'"))
    return compareStrings(
        actual, expectedValue, matchType,
        caseSensitive: true,
        attributeName: AXAttributeNames.kAXIdentifierAttribute,
        elementDescriptionForLog: elementDescriptionForLog
    )
}

@MainActor
func matchDomClassListAttribute(
    element: Element,
    expectedValue: String,
    matchType: JSONPathHintComponent.MatchType,
    elementDescriptionForLog: String
) -> Bool {
    let actualRaw = element.attribute(Attribute<Any>(AXAttributeNames.kAXDOMClassListAttribute))
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "SC/MSC/DOMClassList: ActualRaw='\(String(describing: actualRaw))'"
    ))
    // First try DOM class list.
    if matchDomClassListCriterion(
        element: element,
        expectedValue: expectedValue,
        matchType: matchType,
        elementDescriptionForLog: elementDescriptionForLog
    ) {
        return true
    }

    // Fallback 1: AXDOMIdentifier
    let domIdMatch = matchSingleCriterion(
        element: element,
        key: AXAttributeNames.kAXDOMIdentifierAttribute,
        expectedValue: expectedValue,
        matchType: matchType,
        elementDescriptionForLog: elementDescriptionForLog
    )

    if domIdMatch {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/DOMClass: Fallback DOMIdentifier MATCH for token '\(expectedValue)'."
        ))
        return true
    }

    // Fallback 2: legacy AXIdentifier
    let identifierMatch = matchIdentifierAttribute(
        element: element,
        expectedValue: expectedValue,
        matchType: matchType,
        elementDescriptionForLog: elementDescriptionForLog
    )

    if identifierMatch {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/DOMClass: Fallback AXIdentifier MATCH for token '\(expectedValue)'."
        ))
    }
    return identifierMatch
}

@MainActor
func matchComputedNameAttributes(
    element: Element,
    expectedValue: String,
    matchType: JSONPathHintComponent.MatchType,
    attributeName: String,
    elementDescriptionForLog: String,
    includeValueInComputedName: Bool = false
) -> Bool {
    let computedName = element.computedName()

    if includeValueInComputedName {
        if let value = element.value() as? String {
            let combinedName = (computedName ?? "") + " " + value
            return compareStrings(
                combinedName, expectedValue, matchType,
                attributeName: attributeName,
                elementDescriptionForLog: elementDescriptionForLog
            )
        }
    }

    return compareStrings(
        computedName, expectedValue, matchType,
        attributeName: attributeName,
        elementDescriptionForLog: elementDescriptionForLog
    )
}
