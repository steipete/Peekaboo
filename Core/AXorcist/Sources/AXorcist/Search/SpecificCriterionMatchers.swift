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

    let matcher = DOMClassMatcher(
        value: domClassListValue,
        matchType: matchType,
        expectedValue: expectedValue,
        elementDescription: elementDescriptionForLog
    )
    return matcher.evaluate()
}

private struct DOMClassMatcher {
    let value: Any
    let matchType: JSONPathHintComponent.MatchType
    let expectedValue: String
    let elementDescription: String

    func evaluate() -> Bool {
        if let classArray = self.value as? [String] {
            return self.evaluateArray(classArray)
        }
        if let classString = self.value as? String {
            let components = classString.split(separator: " ").map(String.init)
            return self.evaluateArray(components, joinedString: classString)
        }

        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/DOMClass: \(self.elementDescription) attribute was not [String] or String " +
                "(type: \(type(of: self.value))). No match."
        ))
        return false
    }

    private func evaluateArray(_ array: [String], joinedString: String? = nil) -> Bool {
        let match = self.match(array: array, joinedString: joinedString)
        self.logResult(array: array, joinedString: joinedString, matchFound: match)
        return match
    }

    private func match(array: [String], joinedString: String?) -> Bool {
        switch self.matchType {
        case .exact:
            return array.contains(self.expectedValue)
        case .contains:
            return (joinedString ?? array.joined(separator: " ")).localizedCaseInsensitiveContains(self.expectedValue)
        case .containsAny:
            let expectedParts = self.expectedValue
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if let joined = joinedString {
                return expectedParts.contains { joined.localizedCaseInsensitiveContains($0) }
            }
            return array.contains { actual in
                expectedParts.contains { expected in actual.localizedCaseInsensitiveContains(expected) }
            }
        case .prefix:
            return array.contains { $0.hasPrefix(self.expectedValue) }
        case .suffix:
            return array.contains { $0.hasSuffix(self.expectedValue) }
        case .regex:
            self.logRegexHint(isArray: joinedString == nil)
            return array.contains { classEntry in
                classEntry.range(of: self.expectedValue, options: .regularExpression) != nil
            }
        }
    }

    private func logRegexHint(isArray: Bool) {
        let typeDescription = isArray ? "array of classes" : "space-separated class string"
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/DOMClass: Regex matching for \(typeDescription). " +
                "Element: \(self.elementDescription) Expected: \(self.expectedValue)."
        ))
    }

    private func logResult(array: [String], joinedString: String?, matchFound: Bool) {
        let representation = joinedString ?? array.description
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/DOMClass: \(self.elementDescription) match type '\(self.matchType.rawValue)' " +
                "with '\(self.expectedValue)' resolved to \(matchFound). Classes: \(representation)"
        ))
        let resultText = matchFound ? "MATCHED" : "MISMATCHED"
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "SC/DOMClass: \(self.elementDescription) \(resultText) expected '\(self.expectedValue)' " +
                "with type '\(self.matchType.rawValue)'."
        ))
    }
}
