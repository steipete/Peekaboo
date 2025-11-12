// StringComparisonLogic.swift - String comparison logic for criteria matching

import Foundation

// MARK: - String Comparison Logic

@MainActor
public func compareStrings(
    _ actualValueOptional: String?,
    _ expectedValue: String,
    _ matchType: JSONPathHintComponent.MatchType,
    caseSensitive: Bool = true,
    attributeName: String,
    elementDescriptionForLog: String
) -> Bool {
    guard let actualValue = actualValueOptional, !actualValue.isEmpty else {
        let isEmptyMatch = expectedValue.isEmpty && matchType == .exact

        if isEmptyMatch {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "SC/Compare: '\(attributeName)' on \(elementDescriptionForLog): " +
                    "Actual is nil/empty, Expected is empty. MATCHED with type '\(matchType.rawValue)'."
            ))
            return true
        } else {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "SC/Compare: Attribute '\(attributeName)' on \(elementDescriptionForLog) " +
                    "(actual: nil/empty, expected: '\(expectedValue)', type: \(matchType.rawValue)) -> MISMATCH"
            ))
            return false
        }
    }

    let finalActual = caseSensitive ? actualValue : actualValue.lowercased()
    let finalExpected = caseSensitive ? expectedValue : expectedValue.lowercased()
    var result = false

    switch matchType {
    case .exact:
        result = (finalActual.localizedCompare(finalExpected) == .orderedSame)
    case .contains:
        result = finalActual.contains(finalExpected)
    case .regex:
        result = (finalActual.range(of: finalExpected, options: .regularExpression) != nil)
    case .prefix:
        result = finalActual.hasPrefix(finalExpected)
    case .suffix:
        result = finalActual.hasSuffix(finalExpected)
    case .containsAny:
        let expectedSubstrings = finalExpected.split(separator: ",")
            .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if expectedSubstrings.isEmpty, finalActual.isEmpty {
            result = true
        } else {
            result = expectedSubstrings.contains { substring in
                finalActual.contains(substring)
            }
        }
    }

    let matchStatus = result ? "MATCH" : "MISMATCH"
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "SC/Compare: Attribute '\(attributeName)' on \(elementDescriptionForLog) " +
            "(actual: '\(actualValue)', expected: '\(expectedValue)', type: \(matchType.rawValue), " +
            "caseSensitive: \(caseSensitive)) -> \(matchStatus)"
    ))
    return result
}
