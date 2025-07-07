// SpecificCriterionMatchers.swift - Specific criterion matching functions

import Foundation

// MARK: - Specific Criterion Matchers

@MainActor
func matchPidCriterion(element: Element, expectedValue: String, elementDescriptionForLog: String) -> Bool {
    let expectedPid = expectedValue
    if element.role() == AXRoleNames.kAXApplicationRole {
        guard let actualPidT = element.pid() else {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "SC/PID: \(elementDescriptionForLog) (app role) failed to provide PID. No match."
            ))
            return false
        }
        if String(actualPidT) == expectedPid {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "SC/PID: \(elementDescriptionForLog) (app role) PID \(actualPidT) " +
                    "MATCHES expected \(expectedPid)."
            ))
            return true
        } else {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "SC/PID: \(elementDescriptionForLog) (app role) PID \(actualPidT) " +
                    "MISMATCHES expected \(expectedPid)."
            ))
            return false
        }
    }
    guard let actualPidT = element.pid() else {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/PID: \(elementDescriptionForLog) failed to provide PID. No match."
        ))
        return false
    }
    let actualPidString = String(actualPidT)
    if actualPidString == expectedPid {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/PID: \(elementDescriptionForLog) PID \(actualPidString) " +
                "MATCHES expected \(expectedPid)."
        ))
        return true
    } else {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/PID: \(elementDescriptionForLog) PID \(actualPidString) " +
                "MISMATCHES expected \(expectedPid)."
        ))
        return false
    }
}

@MainActor
func matchIsIgnoredCriterion(element: Element, expectedValue: String, elementDescriptionForLog: String) -> Bool {
    let actualIsIgnored: Bool = element.isIgnored()
    let expectedBool = (expectedValue.lowercased() == "true")
    if actualIsIgnored == expectedBool {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/IsIgnored: \(elementDescriptionForLog) actual ('\(actualIsIgnored)') " +
                "MATCHES expected ('\(expectedBool)')."
        ))
        return true
    } else {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/IsIgnored: \(elementDescriptionForLog) actual ('\(actualIsIgnored)') " +
                "MISMATCHES expected ('\(expectedBool)')."
        ))
        return false
    }
}

@MainActor
func matchDomClassListCriterion(
    element: Element,
    expectedValue: String,
    matchType: JSONPathHintComponent.MatchType,
    elementDescriptionForLog: String
) -> Bool {
    guard let domClassListValue: Any = element.attribute(Attribute(AXAttributeNames.kAXDOMClassListAttribute)) else {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/DOMClass: \(elementDescriptionForLog) attribute was nil. No match."
        ))
        return false
    }

    var matchFound = false
    if let classListArray = domClassListValue as? [String] {
        switch matchType {
        case .exact:
            matchFound = classListArray.contains(expectedValue)
        case .contains:
            matchFound = classListArray.contains { $0.localizedCaseInsensitiveContains(expectedValue) }
        case .containsAny:
            let expectedParts = expectedValue.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            matchFound = classListArray.contains { actualPart in
                expectedParts.contains { expectedPart in actualPart.localizedCaseInsensitiveContains(expectedPart) }
            }
        case .prefix:
            matchFound = classListArray.contains { $0.hasPrefix(expectedValue) }
        case .suffix:
            matchFound = classListArray.contains { $0.hasSuffix(expectedValue) }
        case .regex:
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "SC/DOMClass: Regex matching for array of classes. " +
                    "Element: \(elementDescriptionForLog) Expected: \(expectedValue)."
            ))
            matchFound = classListArray.contains { item in
                item.range(of: expectedValue, options: .regularExpression) != nil
            }
        }
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/DOMClass: \(elementDescriptionForLog) (Array: \(classListArray)) " +
                "match type '\(matchType.rawValue)' with '\(expectedValue)' resolved to \(matchFound)."
        ))
    } else if let classListString = domClassListValue as? String {
        let classes = classListString.split(separator: " ").map(String.init)
        switch matchType {
        case .exact:
            matchFound = classes.contains(expectedValue)
        case .contains:
            matchFound = classListString.localizedCaseInsensitiveContains(expectedValue)
        case .containsAny:
            let expectedParts = expectedValue.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            matchFound = expectedParts.contains {
                classListString.localizedCaseInsensitiveContains($0)
            }
        case .prefix:
            matchFound = classes.contains { $0.hasPrefix(expectedValue) }
        case .suffix:
            matchFound = classes.contains { $0.hasSuffix(expectedValue) }
        case .regex:
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "SC/DOMClass: Regex matching for space-separated class string. " +
                    "Element: \(elementDescriptionForLog) Expected: \(expectedValue)."
            ))
            matchFound = classes.contains { item in
                item.range(of: expectedValue, options: .regularExpression) != nil
            }
        }
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/DOMClass: \(elementDescriptionForLog) (String: '\(classListString)') " +
                "match type '\(matchType.rawValue)' with '\(expectedValue)' resolved to \(matchFound)."
        ))
    } else {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/DOMClass: \(elementDescriptionForLog) attribute was not [String] or String " +
                "(type: \(type(of: domClassListValue))). No match."
        ))
        return false
    }

    if matchFound {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/DOMClass: \(elementDescriptionForLog) MATCHED expected '\(expectedValue)' " +
                "with type '\(matchType.rawValue)'. Classes: '\(domClassListValue)'"
        ))
    } else {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/DOMClass: \(elementDescriptionForLog) MISMATCHED expected '\(expectedValue)' " +
                "with type '\(matchType.rawValue)'. Classes: '\(domClassListValue)'"
        ))
    }
    return matchFound
}
