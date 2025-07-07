// PathNavigationUtilities.swift - Utility functions for path navigation

import AppKit
import ApplicationServices
import Foundation
import Logging

// Define logger for this file
private let logger = Logger(label: "AXorcist.PathNavigationUtilities")

// MARK: - Application Element Utilities

@MainActor
public func getApplicationElement(for bundleIdentifier: String) -> Element? {
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "PN/AppEl: Attempting to get application element for bundle identifier '\(bundleIdentifier)'."
    ))

    guard let runningApp = NSWorkspace.shared.runningApplications.first(where: {
        $0.bundleIdentifier == bundleIdentifier
    }) else {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .warning,
            message: "PN/AppEl: Could not find running application with bundle identifier '\(bundleIdentifier)'."
        ))
        return nil
    }
    let pid = runningApp.processIdentifier
    let appElement = Element(AXUIElementCreateApplication(pid))
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .info,
        message: "PN/AppEl: Obtained application element for '\(bundleIdentifier)' (PID: \(pid)): " +
            "[\(appElement.briefDescription(option: ValueFormatOption.smart))]"
    ))
    return appElement
}

@MainActor
public func getApplicationElement(for processId: pid_t) -> Element? {
    let appElement = Element(AXUIElementCreateApplication(processId))
    let bundleIdMessagePart = if let runningApp = NSRunningApplication(processIdentifier: processId),
                                 let bId = runningApp.bundleIdentifier
    {
        " (\(bId))"
    } else {
        ""
    }
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .info,
        message: "PN/AppEl: Obtained application element for PID \(processId)\(bundleIdMessagePart): " +
            "[\(appElement.briefDescription(option: ValueFormatOption.smart))]"
    ))
    return appElement
}

// MARK: - Element from Path (High-Level)

@MainActor
public func getElement(
    appIdentifier: String,
    pathHint: [Any],
    maxDepth: Int = AXMiscConstants.defaultMaxDepthSearch
) -> Element? {
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "PN/GetEl: Attempting to get element for app '\(appIdentifier)' with path hint (count: \(pathHint.count))."
    ))

    let startElement: Element? = if let pid = pid_t(appIdentifier) {
        getApplicationElement(for: pid)
    } else {
        getApplicationElement(for: appIdentifier)
    }

    guard let rootElement = startElement else {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .warning,
            message: "PN/GetEl: Could not get root application element for '\(appIdentifier)'."
        ))
        return nil
    }

    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "PN/GetEl: Root element for '\(appIdentifier)' is " +
            "[\(rootElement.briefDescription(option: ValueFormatOption.smart))]. Processing path hint."
    ))

    if let stringPathHint = pathHint as? [String] {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "PN/GetEl: Interpreting path hint as [String]. Count: \(stringPathHint.count). " +
                "Hint: \(stringPathHint.joined(separator: " -> "))"
        ))
        return navigateToElement(from: rootElement, pathHint: stringPathHint, maxDepth: maxDepth)
    } else if let jsonPathHint = pathHint as? [JSONPathHintComponent] {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "PN/GetEl: Interpreting path hint as [JSONPathHintComponent]. Count: \(jsonPathHint.count). " +
                "Hint: \(jsonPathHint.map { $0.descriptionForLog() }.joined(separator: " -> "))"
        ))
        let initialLogSegment = rootElement.role() == AXRoleNames.kAXApplicationRole ? "Application" : rootElement
            .briefDescription(option: ValueFormatOption.smart)
        return navigateToElementByJSONPathHint(
            from: rootElement,
            jsonPathHint: jsonPathHint,
            overallMaxDepth: maxDepth,
            initialPathSegmentForLog: initialLogSegment
        )
    } else {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .error,
            message: "PN/GetEl: Path hint type is not [String] or [JSONPathHintComponent]. Hint: \(pathHint). Cannot navigate."
        ))
        return nil
    }
}

// MARK: - Path-based Search

@MainActor
func findDescendantAtPath(
    currentRoot: Element,
    pathComponents: [PathStep],
    maxDepth _: Int,
    debugSearch _: Bool
) -> Element? {
    var currentElement = currentRoot
    logger
        .debug(
            "PN/findDescendantAtPath: Starting path navigation. Initial root: \(currentElement.briefDescription(option: .smart)). Path components: \(pathComponents.count)"
        )

    for (pathComponentIndex, component) in pathComponents.enumerated() {
        logger
            .debug(
                "PN/findDescendantAtPath: Processing component. Current: \(currentElement.briefDescription(option: .smart))"
            )

        let searchVisitor = SearchVisitor(
            criteria: component.criteria,
            matchType: component.matchType ?? .exact,
            matchAllCriteria: component.matchAllCriteria ?? true,
            stopAtFirstMatch: true,
            maxDepth: component.maxDepthForStep ?? 1
        )

        // Children of the current element are where we search for the next path component
        logger
            .debug(
                "PN/findDescendantAtPath: [Component \(pathComponentIndex + 1)] Current element for child search: \(currentElement.briefDescription(option: .smart))"
            )

        guard let childrenToSearch = currentElement.children(strict: false), !childrenToSearch.isEmpty else {
            let componentNum = pathComponentIndex + 1
            let elementDesc = currentElement.briefDescription(option: .smart)
            logger.warning(
                "PN/findDescendantAtPath: [Component \(componentNum)] No children found (or list was empty) for \(elementDesc). Path navigation cannot proceed further down this branch."
            )
            return nil
        }
        logger
            .debug(
                "PN/findDescendantAtPath: [Component \(pathComponentIndex + 1)] Found \(childrenToSearch.count) children to search."
            )

        var foundMatchForThisComponent: Element?
        for child in childrenToSearch {
            searchVisitor.reset()
            traverseAndSearch(
                element: child,
                visitor: searchVisitor,
                currentDepth: 0,
                maxDepth: component.maxDepthForStep ?? 1
            )
            if let foundUnwrapped = searchVisitor.foundElement {
                let componentNum = pathComponentIndex + 1
                let componentDesc = component.descriptionForLog()
                let childDesc = foundUnwrapped.briefDescription(option: ValueFormatOption.smart)
                logger.info(
                    "PN/findDescendantAtPath: [Component \(componentNum)] MATCHED component criteria \(componentDesc) on child: \(childDesc)"
                )
                foundMatchForThisComponent = foundUnwrapped
                break
            }
        }

        if let nextElement = foundMatchForThisComponent {
            currentElement = nextElement
            logger
                .debug(
                    "PN/findDescendantAtPath: [Component \(pathComponentIndex + 1)] Advancing to next element: \(currentElement.briefDescription(option: .smart))"
                )
        } else {
            let componentNum = pathComponentIndex + 1
            let componentDesc = component.descriptionForLog()
            let elementDesc = currentElement.briefDescription(option: .smart)
            logger.warning(
                "PN/findDescendantAtPath: [Component \(componentNum)] FAILED to find match for component criteria: \(componentDesc) within children of \(elementDesc)"
            )
            return nil
        }
    }
    logger
        .info(
            "PN/findDescendantAtPath: Successfully navigated full path. Final element: \(currentElement.briefDescription(option: .smart))"
        )
    return currentElement
}
