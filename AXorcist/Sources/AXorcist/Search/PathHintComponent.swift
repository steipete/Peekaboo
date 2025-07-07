// PathHintComponent.swift - Path hint component for basic string path hints

import Foundation

// MARK: - PathHintComponent Definition

// This PathHintComponent is simpler and used for basic string path hints if ever needed again.
// For new functionality, JSONPathHintComponent is preferred.
@MainActor
public struct PathHintComponent {
    // MARK: Lifecycle

    public init?(pathSegment: String) {
        self.originalSegment = pathSegment
        var parsedCriteria = PathUtils.parseRichPathComponent(pathSegment)

        if parsedCriteria.isEmpty {
            let fallbackPairs = pathSegment
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            for pair in fallbackPairs {
                let keyValue = pair.split(separator: "=", maxSplits: 1)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if keyValue.count == 2 {
                    parsedCriteria[String(keyValue[0])] = String(keyValue[1])
                }
            }
        }

        var mappedCriteria: [String: String] = [:]
        for (rawKey, value) in parsedCriteria {
            if let mappedKey = Self.attributeAliases[rawKey] {
                mappedCriteria[mappedKey] = value
            } else {
                mappedCriteria[rawKey] = value // Keep unmapped keys as-is
            }
        }

        if mappedCriteria.isEmpty {
            axWarningLog("PathHintComponent: Path segment '\(pathSegment)' produced no usable criteria after parsing.")
            return nil
        }
        self.criteria = mappedCriteria
        axDebugLog("PathHintComponent initialized. Segment: '\(pathSegment)' => criteria: \(mappedCriteria)")
    }

    init(criteria: [String: String], originalSegment: String = "") {
        self.criteria = criteria
        self.originalSegment = originalSegment.isEmpty && !criteria.isEmpty ? "criteria_only_init" : originalSegment
    }

    // MARK: Public

    public let criteria: [String: String]
    public let originalSegment: String

    // MARK: Internal

    // PathHintComponent uses exact matching by default when calling elementMatchesCriteria
    func matches(element: Element) -> Bool {
        elementMatchesCriteria(
            element,
            criteria: self.criteria,
            matchType: JSONPathHintComponent.MatchType.exact
        )
    }

    // MARK: Private

    // Corrected: PathUtils.attributeKeyMappings might be the intended property
    // Ensure this is the correct static property in PathUtils
    private static let attributeAliases: [String: String] = PathUtils.attributeKeyMappings
}
