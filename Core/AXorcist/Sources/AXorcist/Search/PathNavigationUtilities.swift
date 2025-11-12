// PathNavigationUtilities.swift - Utility functions for path navigation

import AppKit
import ApplicationServices
import Foundation
import Logging

// Define logger for this file
private let logger = Logger(label: "AXorcist.PathNavigationUtilities")
private let smartValueFormat: ValueFormatOption = .smart

private func logPathNavigation(_ level: AXLogLevel, _ message: String) {
    GlobalAXLogger.shared.log(AXLogEntry(level: level, message: message))
}

// MARK: - Application Element Utilities

@MainActor
public func getApplicationElement(for bundleIdentifier: String) -> Element? {
    let attemptMessage = "PN/AppEl: Attempting to get application element for bundle identifier '"
        + "\(bundleIdentifier)'."
    logPathNavigation(.debug, attemptMessage)

    guard let runningApp = NSWorkspace.shared.runningApplications.first(where: {
        $0.bundleIdentifier == bundleIdentifier
    }) else {
        let failureMessage =
            "PN/AppEl: Could not find running application with bundle identifier '\(bundleIdentifier)'."
        logPathNavigation(.warning, failureMessage)
        return nil
    }
    let pid = runningApp.processIdentifier
    let appElement = Element(AXUIElementCreateApplication(pid))
    let description = appElement.briefDescription(option: smartValueFormat)
    let successMessage = "PN/AppEl: Obtained application element for '\(bundleIdentifier)' (PID: \(pid)): "
        + "[\(description)]"
    logPathNavigation(.info, successMessage)
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
    let description = appElement.briefDescription(option: smartValueFormat)
    let message = "PN/AppEl: Obtained application element for PID \(processId)\(bundleIdMessagePart): "
        + "[\(description)]"
    logPathNavigation(.info, message)
    return appElement
}

// MARK: - Element from Path (High-Level)

@MainActor
public func getElement(
    appIdentifier: String,
    pathHint: [Any],
    maxDepth: Int = AXMiscConstants.defaultMaxDepthSearch
) -> Element? {
    let attemptMessage = "PN/GetEl: Attempting to get element for app '\(appIdentifier)' with path hint "
        + "(count: \(pathHint.count))."
    logPathNavigation(.debug, attemptMessage)

    let startElement: Element? = if let pid = pid_t(appIdentifier) {
        getApplicationElement(for: pid)
    } else {
        getApplicationElement(for: appIdentifier)
    }

    guard let rootElement = startElement else {
        let failureMessage = "PN/GetEl: Could not get root application element for '\(appIdentifier)'."
        logPathNavigation(.warning, failureMessage)
        return nil
    }

    let rootDescription = rootElement.briefDescription(option: smartValueFormat)
    let rootMessage = "PN/GetEl: Root element for '\(appIdentifier)' is [\(rootDescription)]. Processing path hint."
    logPathNavigation(.debug, rootMessage)

    if let stringPathHint = pathHint as? [String] {
        let stringHintMessage = "PN/GetEl: Interpreting path hint as [String]. Count: \(stringPathHint.count). "
            + "Hint: \(stringPathHint.joined(separator: " -> "))"
        logPathNavigation(.debug, stringHintMessage)
        return navigateToElement(from: rootElement, pathHint: stringPathHint, maxDepth: maxDepth)
    } else if let jsonPathHint = pathHint as? [JSONPathHintComponent] {
        let jsonHintDetails = jsonPathHint.map { $0.descriptionForLog() }.joined(separator: " -> ")
        let jsonHintMessage =
            "PN/GetEl: Interpreting path hint as [JSONPathHintComponent]. Count: \(jsonPathHint.count). "
            + "Hint: \(jsonHintDetails)"
        logPathNavigation(.debug, jsonHintMessage)
        let initialLogSegment = rootElement.role() == AXRoleNames.kAXApplicationRole ? "Application" : rootElement
            .briefDescription(option: smartValueFormat)
        return navigateToElementByJSONPathHint(
            from: rootElement,
            jsonPathHint: jsonPathHint,
            overallMaxDepth: maxDepth,
            initialPathSegmentForLog: initialLogSegment
        )
    } else {
        let errorMessage =
            "PN/GetEl: Path hint type is not [String] or [JSONPathHintComponent]. Hint: \(pathHint). Cannot navigate."
        logPathNavigation(.error, errorMessage)
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
    logPathSearchStart(currentElement: currentElement, componentCount: pathComponents.count)

    for (index, component) in pathComponents.enumerated() {
        logProcessingComponent(index: index, element: currentElement)

        guard let children = childrenForPathComponent(element: currentElement, componentIndex: index) else {
            return nil
        }

        let match = findMatch(for: component, among: children, componentIndex: index)
        guard let nextElement = match else {
            logNoMatch(component: component, element: currentElement, index: index)
            return nil
        }

        currentElement = nextElement
        logAdvancement(index: index, element: currentElement)
    }

    logPathSearchCompletion(finalElement: currentElement)
    return currentElement
}

private func logPathSearchStart(currentElement: Element, componentCount: Int) {
    let elementDescription = currentElement.briefDescription(option: smartValueFormat)
    let message = "PN/findDescendantAtPath: Starting path navigation. Initial root: \(elementDescription). "
        + "Path components: \(componentCount)"
    logger.debug(message)
}

private func logProcessingComponent(index: Int, element: Element) {
    let elementDescription = element.briefDescription(option: smartValueFormat)
    let message = "PN/findDescendantAtPath: Processing component. Current: \(elementDescription)"
    logger.debug(message)
}

private func childrenForPathComponent(element: Element, componentIndex: Int) -> [Element]? {
    let elementDescription = element.briefDescription(option: smartValueFormat)
    let componentLabel = componentNumber(for: componentIndex)
    let childSearchMessage =
        "PN/findDescendantAtPath: [Component \(componentLabel)] Current element for child search: \(elementDescription)"
    logger.debug(childSearchMessage)

    guard let children = element.children(strict: false), !children.isEmpty else {
        let warning =
            "PN/findDescendantAtPath: [Component \(componentLabel)] No children found (or list was empty) "
            + "for \(elementDescription). Path navigation cannot proceed further down this branch."
        logger.warning(warning)
        return nil
    }

    let countMessage =
        "PN/findDescendantAtPath: [Component \(componentLabel)] Found \(children.count) children to search."
    logger.debug(countMessage)
    return children
}

private func findMatch(
    for component: PathStep,
    among children: [Element],
    componentIndex: Int
) -> Element? {
    let searchVisitor = SearchVisitor(
        criteria: component.criteria,
        matchType: component.matchType ?? .exact,
        matchAllCriteria: component.matchAllCriteria ?? true,
        stopAtFirstMatch: true,
        maxDepth: component.maxDepthForStep ?? 1
    )

    for child in children {
        searchVisitor.reset()
        traverseAndSearch(
            element: child,
            visitor: searchVisitor,
            currentDepth: 0,
            maxDepth: component.maxDepthForStep ?? 1
        )
        if let foundElement = searchVisitor.foundElement {
            logMatch(component: component, element: foundElement, index: componentIndex)
            return foundElement
        }
    }

    return nil
}

private func logMatch(component: PathStep, element: Element, index: Int) {
    let componentLabel = componentNumber(for: index)
    let componentDescription = component.descriptionForLog()
    let elementDescription = element.briefDescription(option: smartValueFormat)
    let message =
        "PN/findDescendantAtPath: [Component \(componentLabel)] MATCHED component criteria \(componentDescription) "
        + "on child: \(elementDescription)"
    logger.info(message)
}

private func logAdvancement(index: Int, element: Element) {
    let componentLabel = componentNumber(for: index)
    let elementDescription = element.briefDescription(option: smartValueFormat)
    let message =
        "PN/findDescendantAtPath: [Component \(componentLabel)] Advancing to next element: \(elementDescription)"
    logger.debug(message)
}

private func logNoMatch(component: PathStep, element: Element, index: Int) {
    let componentLabel = componentNumber(for: index)
    let componentDescription = component.descriptionForLog()
    let elementDescription = element.briefDescription(option: smartValueFormat)
    let message = "PN/findDescendantAtPath: [Component \(componentLabel)] FAILED to find match for component "
        + "criteria: \(componentDescription) within children of \(elementDescription)"
    logger.warning(message)
}

private func logPathSearchCompletion(finalElement: Element) {
    let elementDescription = finalElement.briefDescription(option: smartValueFormat)
    let message =
        "PN/findDescendantAtPath: Successfully navigated full path. Final element: \(elementDescription)"
    logger.info(message)
}

private func componentNumber(for index: Int) -> Int {
    index + 1
}
