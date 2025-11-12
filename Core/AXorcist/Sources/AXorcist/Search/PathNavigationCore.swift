// PathNavigationCore.swift - Core path navigation functions

import ApplicationServices
import Foundation

// MARK: - Core Navigation Functions

@MainActor
func navigateToElement(
    from startElement: Element,
    pathHint: [String],
    maxDepth: Int = AXMiscConstants.defaultMaxDepthSearch
) -> Element? {
    var currentElement = startElement
    var currentPathSegmentForLog = ""

    for (index, pathComponentString) in pathHint.enumerated() {
        currentPathSegmentForLog += (index > 0 ? " -> " : "") + pathComponentString

        if index == 0, pathComponentString.lowercased() == "application" {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "Path component 'application' encountered. " +
                    "Using current element (app root) as context for next component."
            ))
            continue
        }

        if index >= maxDepth {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "Navigation aborted: Path hint index \(index) reached maxDepth \(maxDepth). " +
                    "Path so far: \(currentPathSegmentForLog)"
            ))
            return nil
        }

        let criteriaToMatch = PathUtils.parseRichPathComponent(pathComponentString)
        guard !criteriaToMatch.isEmpty else {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .error,
                message: "CRITICAL_NAV_PARSE_FAILURE_MARKER: Empty or unparsable criteria " +
                    "from pathComponentString '\(pathComponentString)'"
            ))
            return nil
        }

        if let nextElement = processPathComponent(
            currentElement: currentElement,
            pathComponentString: pathComponentString,
            criteriaToMatch: criteriaToMatch,
            currentPathSegmentForLog: currentPathSegmentForLog
        ) {
            currentElement = nextElement
        } else {
            return nil
        }
    }

    let finalDescription = currentElement.briefDescription(option: .smart)
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "Navigation successful. Final element: \(finalDescription)"
    ))
    return currentElement
}

@MainActor
func processPathComponent(
    currentElement: Element,
    pathComponentString: String,
    criteriaToMatch: [String: String],
    currentPathSegmentForLog: String
) -> Element? {
    let currentElementDescForLog = currentElement.briefDescription(option: ValueFormatOption.smart)
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "Processing path component '\(pathComponentString)' at element [\(currentElementDescForLog)]. " +
            "Path: \(currentPathSegmentForLog)"
    ))

    if let matchingChild = findMatchingChild(
        parentElement: currentElement,
        criteriaToMatch: criteriaToMatch,
        pathComponentForLog: pathComponentString
    ) {
        return matchingChild
    }

    if elementMatchesAllCriteria(currentElement, criteria: criteriaToMatch, forPathComponent: pathComponentString) {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "Path component '\(pathComponentString)' matches current element [\(currentElementDescForLog)]."
        ))
        return currentElement
    }

    logNoMatchFound(
        currentElement: currentElement,
        pathComponentString: pathComponentString,
        criteriaToMatch: criteriaToMatch,
        currentPathSegmentForLog: currentPathSegmentForLog
    )
    return nil
}

@MainActor
func getChildrenFromElement(_ element: Element) -> [Element]? {
    guard let children = element.children() else {
        let currentElementDescForLog = element.briefDescription(option: ValueFormatOption.smart)
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "Element [\(currentElementDescForLog)] has no children (returned nil for .children())."
        ))
        return nil
    }
    if children.isEmpty {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "Element [\(element.briefDescription(option: ValueFormatOption.smart))] has zero children " +
                "(returned empty array for .children())."
        ))
    }
    return children
}
