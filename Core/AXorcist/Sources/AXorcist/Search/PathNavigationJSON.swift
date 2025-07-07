// PathNavigationJSON.swift - JSON path hint navigation

import ApplicationServices
import Foundation
import Logging

// Define logger for this file
private let logger = Logger(label: "AXorcist.PathNavigationJSON")

// MARK: - JSON PathHint Navigation

@MainActor
func navigateToElementByJSONPathHint(
    from startElement: Element,
    jsonPathHint: [JSONPathHintComponent],
    overallMaxDepth: Int = AXMiscConstants.defaultMaxDepthSearch,
    initialPathSegmentForLog: String = "Application"
) -> Element? {
    var currentElement = startElement
    var currentPathSegmentForLog = initialPathSegmentForLog

    for (index, pathComponent) in jsonPathHint.enumerated() {
        let componentLogString = pathComponent.descriptionForLog()
        currentPathSegmentForLog += " -> " + componentLogString
        if pathComponent.attribute.lowercased() == "application" {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "PathNav/JPHN: JSON path component \(index) is 'application'. " +
                    "Using current element (app root) as context for next component."
            ))
            continue
        }

        if index >= overallMaxDepth {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "PathNav/JPHN: Navigation aborted: JSON path hint index \(index) " +
                    "reached overallMaxDepth \(overallMaxDepth). Path so far: \(currentPathSegmentForLog)"
            ))
            return nil
        }

        if let nextElement = processJSONPathComponent(
            currentElement: currentElement,
            pathComponent: pathComponent,
            currentPathSegmentForLog: currentPathSegmentForLog,
            componentLogString: componentLogString
        ) {
            currentElement = nextElement
        } else {
            return nil
        }
    }

    GlobalAXLogger.shared.log(AXLogEntry(
        level: .info,
        message: "PathNav/JPHN: Navigation successful. " +
            "Final element: [\(currentElement.briefDescription(option: ValueFormatOption.smart))]. " +
            "Full path: \(currentPathSegmentForLog)"
    ))
    return currentElement
}

@MainActor
private func processJSONPathComponent(
    currentElement: Element,
    pathComponent: JSONPathHintComponent,
    currentPathSegmentForLog: String,
    componentLogString: String
) -> Element? {
    let currentElementDescForLog = currentElement.briefDescription(option: ValueFormatOption.smart)
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "PathNav/JPHN: Processing JSON path component '\(componentLogString)' " +
            "at element [\(currentElementDescForLog)]. Path: \(currentPathSegmentForLog)"
    ))

    let criteriaToMatch = convertJSONPathComponentToCriteria(pathComponent)
    let actualMatchType = pathComponent.matchType ?? .exact
    let actualMaxDepthForSearch = pathComponent.depth ?? 1

    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "PathNav/JPHN: Converted JSON component to criteria: \(criteriaToMatch). " +
            "MatchType: \(actualMatchType.rawValue), MaxDepthForSearch: \(actualMaxDepthForSearch)"
    ))

    if actualMaxDepthForSearch > 1 {
        if let deepMatch = findMatchRecursively(
            in: currentElement,
            criteria: criteriaToMatch,
            matchType: actualMatchType,
            maxDepth: actualMaxDepthForSearch,
            pathComponentForLog: componentLogString
        ) {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .info,
                message: "PathNav/JPHN: Deep match found for component '\(componentLogString)': " +
                    "[\(deepMatch.briefDescription(option: ValueFormatOption.smart))]"
            ))
            return deepMatch
        }
    } else {
        if let directChild = findMatchingChildJSON(
            parentElement: currentElement,
            criteriaToMatch: criteriaToMatch,
            matchType: actualMatchType,
            pathComponentForLog: componentLogString
        ) {
            return directChild
        }

        if elementMatchesAllCriteriaJSON(
            currentElement,
            criteria: criteriaToMatch,
            matchType: actualMatchType,
            forPathComponent: componentLogString
        ) {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "PathNav/JPHN: JSON path component '\(componentLogString)' " +
                    "matches current element [\(currentElementDescForLog)]."
            ))
            return currentElement
        }
    }

    GlobalAXLogger.shared.log(AXLogEntry(
        level: .warning,
        message: "PathNav/JPHN: JSON path component '\(componentLogString)' with criteria \(criteriaToMatch) " +
            "did not match any child or current element [\(currentElementDescForLog)]. " +
            "Path so far: \(currentPathSegmentForLog). Search depth was \(actualMaxDepthForSearch)."
    ))
    return nil
}

@MainActor
private func convertJSONPathComponentToCriteria(_ component: JSONPathHintComponent) -> [String: String] {
    // Use the component's simpleCriteria property which handles the attribute mapping
    component.simpleCriteria ?? [:]
}

@MainActor
private func findMatchingChildJSON(
    parentElement: Element,
    criteriaToMatch: [String: String],
    matchType: JSONPathHintComponent.MatchType,
    pathComponentForLog: String
) -> Element? {
    guard let children = getChildrenFromElement(parentElement) else {
        return nil
    }

    for (childIndex, child) in children.enumerated()
        where elementMatchesAllCriteriaJSON(
            child,
            criteria: criteriaToMatch,
            matchType: matchType,
            forPathComponent: pathComponentForLog
        )
    {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .info,
            message: "PathNav/FMCJ: Found matching child at index \(childIndex) " +
                "for JSON component [\(pathComponentForLog)]: " +
                "[\(child.briefDescription(option: ValueFormatOption.smart))]."
        ))
        return child
    }

    return nil
}

@MainActor
private func elementMatchesAllCriteriaJSON(
    _ element: Element,
    criteria: [String: String],
    matchType: JSONPathHintComponent.MatchType,
    forPathComponent _: String
) -> Bool {
    if criteria.isEmpty {
        return true
    }

    for (key, expectedValue) in criteria {
        let criterionDidMatch = matchSingleCriterion(
            element: element,
            key: key,
            expectedValue: expectedValue,
            matchType: matchType,
            elementDescriptionForLog: element.briefDescription(option: ValueFormatOption.smart)
        )

        if !criterionDidMatch {
            return false
        }
    }

    return true
}

@MainActor
private func findMatchRecursively(
    in rootElement: Element,
    criteria: [String: String],
    matchType: JSONPathHintComponent.MatchType,
    maxDepth: Int,
    pathComponentForLog: String
) -> Element? {
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "PathNav/FMR: Starting recursive search for component '\(pathComponentForLog)' " +
            "with maxDepth \(maxDepth) from [\(rootElement.briefDescription(option: ValueFormatOption.smart))]"
    ))

    var queue: [(element: Element, depth: Int)] = [(rootElement, 0)]
    var visited = Set<Element>()

    while !queue.isEmpty {
        let (currentElement, currentDepth) = queue.removeFirst()

        if visited.contains(currentElement) {
            continue
        }
        visited.insert(currentElement)

        if elementMatchesAllCriteriaJSON(
            currentElement,
            criteria: criteria,
            matchType: matchType,
            forPathComponent: pathComponentForLog
        ) {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .info,
                message: "PathNav/FMR: Found match at depth \(currentDepth): " +
                    "[\(currentElement.briefDescription(option: ValueFormatOption.smart))]"
            ))
            return currentElement
        }

        if currentDepth < maxDepth {
            if let children = currentElement.children() {
                for child in children {
                    queue.append((child, currentDepth + 1))
                }
            }
        }
    }

    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "PathNav/FMR: No match found in recursive search for component '\(pathComponentForLog)'"
    ))
    return nil
}
