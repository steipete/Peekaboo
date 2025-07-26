// CriteriaMatchingHelpers.swift - Helper functions for criteria matching

import Foundation

// MARK: - Criteria Matching Helper

@MainActor
public func elementMatchesAllCriteria(
    element: Element,
    criteria: [Criterion],
    matchType: JSONPathHintComponent.MatchType = .exact
) -> Bool {
    for criterion in criteria {
        let effectiveMatchType = criterion.matchType ?? matchType
        if !matchSingleCriterion(
            element: element,
            key: criterion.attribute,
            expectedValue: criterion.value,
            matchType: effectiveMatchType,
            elementDescriptionForLog: element.briefDescription(option: ValueFormatOption.raw)
        ) {
            return false
        }
    }
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "elementMatchesAllCriteria: Element '\(element.briefDescription(option: ValueFormatOption.raw))' " +
            "MATCHED ALL \(criteria.count) criteria: \(criteria)."
    ))
    return true
}

@MainActor
public func elementMatchesAnyCriterion(
    element: Element,
    criteria: [Criterion],
    matchType: JSONPathHintComponent.MatchType = .exact
) -> Bool {
    // If there are no criteria, it's vacuously false that any criterion matches.
    if criteria.isEmpty {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "elementMatchesAnyCriterion: No criteria provided. Returning false."
        ))
        return false
    }
    for criterion in criteria {
        // Use criterion's own match_type if present, else the overall one.
        let effectiveMatchType = criterion.matchType ?? matchType
        if matchSingleCriterion(
            element: element,
            key: criterion.attribute,
            expectedValue: criterion.value,
            matchType: effectiveMatchType,
            elementDescriptionForLog: element.briefDescription(option: ValueFormatOption.raw)
        ) {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "elementMatchesAnyCriterion: Element '\(element.briefDescription(option: ValueFormatOption.raw))' " +
                    "MATCHED criterion: \(criterion)."
            ))
            // Found one criterion that matches
            return true
        }
    }
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "elementMatchesAnyCriterion: Element '\(element.briefDescription(option: ValueFormatOption.raw))' " +
            "DID NOT MATCH ANY of \(criteria.count) criteria: \(criteria)."
    ))
    return false
}

@MainActor
public func elementMatchesCriteria(
    _ element: Element,
    criteria: [String: String],
    matchType: JSONPathHintComponent.MatchType = .exact
) -> Bool {
    let criterionArray = criteria.map { key, value in
        Criterion(attribute: key, value: value, matchType: nil)
    }
    return elementMatchesAllCriteria(element: element, criteria: criterionArray, matchType: matchType)
}
