// NavigationUtils.swift - Additional navigation utilities

import Foundation

// This function demonstrates the requested pattern for trimming whitespace before splitting
@MainActor
public func navigateToElementWithTrimming(
    pathComponents: [String]
) -> [(String, String)] {
    var results: [(String, String)] = []

    for pathComponentString in pathComponents {
        // Add the requested trimming line before the split operation
        let trimmedPathComponentString = pathComponentString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Use the trimmed string in the split call
        let parts = trimmedPathComponentString.split(separator: ":", maxSplits: 1)

        if parts.count == 2 {
            results.append((String(parts[0]), String(parts[1])))
        }
    }

    return results
}
