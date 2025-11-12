// StringComparisonLogic.swift - String comparison logic for criteria matching

import Foundation

// MARK: - String Comparison Logic

@MainActor
public func compareStrings(
    _ actualValueOptional: String?,
    _ expectedValue: String,
    _ matchType: JSONPathHintComponent.MatchType,
    caseSensitive: Bool = true,
    context: StringComparisonContext
) -> Bool {
    if let decision = handleEmptyActualValue(
        actualValue: actualValueOptional,
        expectedValue: expectedValue,
        matchType: matchType,
        context: context
    ) {
        return decision
    }

    let finalActual = formatValue(actualValueOptional!, caseSensitive: caseSensitive)
    let finalExpected = formatValue(expectedValue, caseSensitive: caseSensitive)
    let result = evaluateMatch(
        finalActual: finalActual,
        finalExpected: finalExpected,
        matchType: matchType
    )

    let metadata = MatchResultMetadata(
        actualValue: actualValueOptional!,
        expectedValue: expectedValue,
        matchType: matchType,
        caseSensitive: caseSensitive,
        didMatch: result
    )
    logMatchResult(context: context, metadata: metadata)
    return result
}

@MainActor
private func handleEmptyActualValue(
    actualValue: String?,
    expectedValue: String,
    matchType: JSONPathHintComponent.MatchType,
    context: StringComparisonContext
) -> Bool? {
    guard let actualValue, !actualValue.isEmpty else {
        let isEmptyMatch = expectedValue.isEmpty && matchType == .exact
        let message: String
        if isEmptyMatch {
            message = "SC/Compare: '\(context.attributeName)' on \(context.elementDescription): " +
                "Actual is nil/empty, Expected is empty. MATCHED with type '\(matchType.rawValue)'."
            GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message: message))
            return true
        }
        message = "SC/Compare: Attribute '\(context.attributeName)' on \(context.elementDescription) " +
            "(actual: nil/empty, expected: '\(expectedValue)', type: \(matchType.rawValue)) -> MISMATCH"
        GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message: message))
        return false
    }
    return nil
}

private func formatValue(_ value: String, caseSensitive: Bool) -> String {
    caseSensitive ? value : value.lowercased()
}

private func evaluateMatch(
    finalActual: String,
    finalExpected: String,
    matchType: JSONPathHintComponent.MatchType
) -> Bool {
    switch matchType {
    case .exact:
        return finalActual.localizedCompare(finalExpected) == .orderedSame
    case .contains:
        return finalActual.contains(finalExpected)
    case .regex:
        return finalActual.range(of: finalExpected, options: .regularExpression) != nil
    case .prefix:
        return finalActual.hasPrefix(finalExpected)
    case .suffix:
        return finalActual.hasSuffix(finalExpected)
    case .containsAny:
        return evaluateContainsAnyMatch(actual: finalActual, expected: finalExpected)
    }
}

private func evaluateContainsAnyMatch(actual: String, expected: String) -> Bool {
    let expectedSubstrings = expected.split(separator: ",")
        .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    if expectedSubstrings.isEmpty {
        return actual.isEmpty
    }
    return expectedSubstrings.contains { substring in actual.contains(substring) }
}

@MainActor
private func logMatchResult(
    context: StringComparisonContext,
    metadata: MatchResultMetadata
) {
    let matchStatus = metadata.didMatch ? "MATCH" : "MISMATCH"
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "SC/Compare: Attribute '\(context.attributeName)' on \(context.elementDescription) " +
            "(actual: '\(metadata.actualValue)', expected: '\(metadata.expectedValue)', " +
            "type: \(metadata.matchType.rawValue), caseSensitive: \(metadata.caseSensitive)) -> \(matchStatus)"
    ))
}

public struct StringComparisonContext {
    let attributeName: String
    let elementDescription: String
}

struct MatchResultMetadata {
    let actualValue: String
    let expectedValue: String
    let matchType: JSONPathHintComponent.MatchType
    let caseSensitive: Bool
    let didMatch: Bool
}
