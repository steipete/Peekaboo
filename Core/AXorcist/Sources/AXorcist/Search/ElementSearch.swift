// ElementSearch.swift - Contains search and element collection logic

import ApplicationServices
import Foundation
import Logging

private let logger = Logger(label: "AXorcist.ElementSearch")

// MARK: - Main Element Finding Orchestration

/// Provides sophisticated UI element search capabilities using accessibility APIs.
///
/// `ElementSearch` implements advanced search algorithms for finding UI elements
/// based on various criteria including text content, element type, attributes,
/// and hierarchical paths. It supports both exhaustive searches and optimized
/// path-based navigation.
///
/// ## Overview
///
/// The search system:
/// - Supports multiple search criteria with flexible matching
/// - Optimizes searches using path hints when available
/// - Handles complex element hierarchies efficiently
/// - Provides timeout protection for long searches
/// - Supports fuzzy text matching and attribute-based filtering
///
/// ## Topics
///
/// ### Primary Search Function
///
/// - ``findTargetElement(for:locator:maxDepthForSearch:)``
///
/// ### Search Types
///
/// - ``Locator`` - Combines search criteria with path hints
/// - ``SearchCriterion`` - Individual search conditions
/// - ``PathStep`` - Navigation steps for path-based search
///
/// ### Helper Functions
///
/// - ``collectAllUIElements(_:maxDepth:)``
/// - ``findElementByCriteria(startingFrom:criteria:depth:)``
class ElementSearch {
    // This is a placeholder for documentation - the actual implementation uses free functions
}

/**
 Unified function to find a target element based on application, locator (criteria and/or JSON path hint).
 This is the primary entry point for handlers.
 */
@MainActor
public func findTargetElement(
    for appIdentifier: String,
    locator: Locator,
    maxDepthForSearch: Int
) -> (element: Element?, error: String?) {

    let locatorDebug = logFindTargetSetup(
        appIdentifier: appIdentifier,
        locator: locator,
        maxDepth: maxDepthForSearch
    )
    let pathHintDebugString = locatorDebug.pathHint
    let criteriaDebugString = locatorDebug.criteria
    resetTraversalState()
    defer { traversalDeadline = nil }

    guard let appElement = getApplicationElement(for: appIdentifier) else {
        logger.error("FTE: No app element for \(appIdentifier)")
        return (nil, "Application not found or not accessible: \(appIdentifier)")
    }

    var currentSearchElement = appElement
    var searchStartingPointDescription = "application root \(appElement.briefDescription(option: .smart))"

    let pathResult = performPathNavigation(
        currentElement: currentSearchElement,
        locator: locator,
        maxDepthForSearch: maxDepthForSearch,
        pathHintDebugString: pathHintDebugString,
        searchStartingPointDescription: searchStartingPointDescription
    )

    if let error = pathResult.error {
        return (nil, error)
    }
    currentSearchElement = pathResult.element
    searchStartingPointDescription = pathResult.description ?? searchStartingPointDescription

    if locator.criteria.isEmpty {
        if locator.rootElementPathHint?.isEmpty ?? true {
            let noCriteriaError = "FTE: No criteria, no path hint"
            logger.error("\(noCriteriaError)")
            return (nil, noCriteriaError)
        }
        logger.info(
            logSegments(
                "FTE: PH only -> \(currentSearchElement.briefDescription(option: .smart))"
            )
        )
        return (currentSearchElement, nil)
    }

    let criteriaResult = applyCriteriaSearch(
        startElement: currentSearchElement,
        locator: locator,
        maxDepthForSearch: maxDepthForSearch,
        searchStartingPointDescription: searchStartingPointDescription
    )

    if let error = criteriaResult.error {
        return (nil, error)
    }
    return (criteriaResult.element, nil)
}

private func performPathNavigation(
    currentElement: Element,
    locator: Locator,
    maxDepthForSearch: Int,
    pathHintDebugString: String,
    searchStartingPointDescription: String
) -> (element: Element, description: String?, error: String?) {
    var element = currentElement
    var description = searchStartingPointDescription

    guard let jsonPathComponents = locator.rootElementPathHint, !jsonPathComponents.isEmpty else {
        logger.debug(
            logSegments(
                "FTE: No PH",
                "search from \(searchStartingPointDescription)"
            )
        )
        return (element, description, nil)
    }

    logger.debug(
        logSegments(
            "FTE: PH=\(jsonPathComponents.count)",
            "from \(searchStartingPointDescription)"
        )
    )

    let pathSteps = jsonPathComponents.map { component -> PathStep in
        let attributeName = component.axAttributeName ?? component.attribute
        let criterion = Criterion(attribute: attributeName, value: component.value, matchType: component.matchType)
        return PathStep(
            criteria: [criterion],
            matchType: component.matchType,
            matchAllCriteria: true,
            maxDepthForStep: component.depth
        )
    }

    if let navigatedElement = findDescendantAtPath(
        currentRoot: element,
        pathComponents: pathSteps,
        maxDepth: maxDepthForSearch,
        debugSearch: locator.debugPathSearch ?? false
    ) {
        logger.info(
            logSegments(
                "FTE: Path nav OK -> \(navigatedElement.briefDescription(option: ValueFormatOption.smart))"
            )
        )
        element = navigatedElement
        let pathElementDescription = element.briefDescription(option: ValueFormatOption.smart)
        description = "navigated path element \(pathElementDescription)"
        return (element, description, nil)
    }

    let pathFailedError = logSegments(
        "FTE: Path nav failed",
        "at: [\(pathHintDebugString)]"
    )
    logger.warning(pathFailedError)
    return (element, description, pathFailedError)
}

private func applyCriteriaSearch(
    startElement: Element,
    locator: Locator,
    maxDepthForSearch: Int,
    searchStartingPointDescription: String
) -> (element: Element?, error: String?) {
    let criteriaCount = locator.criteria.count
    let matchAll = locator.matchAll ?? true
    let matchType = locator.criteria.first?.matchType?.rawValue ?? "default/exact"
    logger.debug(
        logSegments(
            "FTE: Apply C=\(criteriaCount) from \(searchStartingPointDescription)",
            "MA=\(matchAll)",
            "MT=\(matchType)"
        )
    )

    let finalSearchMatchType = locator.criteria.first?.matchType ?? .exact
    let finalSearchMatchAll = locator.matchAll ?? true

    let searchVisitor = SearchVisitor(
        criteria: locator.criteria,
        matchType: finalSearchMatchType,
        matchAllCriteria: finalSearchMatchAll,
        stopAtFirstMatch: axorcStopAtFirstMatch,
        maxDepth: maxDepthForSearch
    )

    traverseAndSearch(
        element: startElement,
        visitor: searchVisitor,
        currentDepth: 0,
        maxDepth: maxDepthForSearch
    )

    if let foundMatch = searchVisitor.foundElement {
        let foundDescription = foundMatch.briefDescription(option: .smart)
        logger.info(
            logSegments(
                "FindTargetEl: Found final descendant matching criteria: \(foundDescription)",
                "Nodes visited = \(traversalNodeCounter)"
            )
        )
        return (foundMatch, nil)
    }

    let criteriaDesc = locator.criteria.map { "\($0.attribute):\($0.value)" }.joined(separator: ", ")
    let finalSearchError = logSegments(
        "FTE: Not found C=[\(criteriaDesc)] from \(searchStartingPointDescription)",
        "Max depth visited = \(searchVisitor.deepestDepthReached) of \(maxDepthForSearch)",
        "Nodes visited = \(traversalNodeCounter)"
    )
    logger.warning(finalSearchError)
    return (nil, finalSearchError)
}

private func logFindTargetSetup(
    appIdentifier: String,
    locator: Locator,
    maxDepth: Int
) -> (pathHint: String, criteria: String) {
    let pathHint = locator.rootElementPathHint?
        .map { $0.descriptionForLog() }
        .joined(separator: "\n    -> ") ?? "nil"
    let criteria = describeCriteria(locator.criteria)
    logger.info(
        logSegments(
            "FTE: App='\(appIdentifier)'",
            "D=\(maxDepth)",
            "C=\(criteria)",
            "PH=\(locator.rootElementPathHint?.count ?? 0)"
        )
    )
    return (pathHint, criteria)
}

private func resetTraversalState() {
    traversalNodeCounter = 0
    traversalDeadline = Date().addingTimeInterval(axorcTraversalTimeout)
}

// MARK: - Element Collection Logic

@MainActor
public func collectAllElements(
    from startElement: Element,
    matching criteria: [Criterion]? = nil,
    maxDepth: Int = AXMiscConstants.defaultMaxDepthSearch,
    includeIgnored: Bool = false
) -> [Element] {
    let criteriaDebugString = criteria?
        .map { "\($0.attribute):\($0.value)(\($0.matchType?.rawValue ?? "exact"))" }
        .joined(separator: ", ")
        ?? "all"
    logger.info(
        logSegments(
            "CA: From [\(startElement.briefDescription(option: ValueFormatOption.smart))]",
            "C=[\(criteriaDebugString)]",
            "D=\(maxDepth)",
            "I=\(includeIgnored)"
        )
    )

    let visitor = CollectAllVisitor(criteria: criteria, includeIgnored: includeIgnored)
    traverseAndSearch(element: startElement, visitor: visitor, currentDepth: 0, maxDepth: maxDepth)

    logger.info("CA: Found \(visitor.collectedElements.count)")
    return visitor.collectedElements
}

// MARK: - Generic Tree Traversal with Visitor

// Protocol for visitors used in tree traversal
@MainActor
public protocol ElementVisitor {
    // If visit returns .stop, traversal stops. If .skipChildren, children of current element are not visited.
    // Otherwise, traversal continues (.continue).
    func visit(element: Element, depth: Int) -> TreeVisitorResult
}

public enum TreeVisitorResult {
    case `continue`
    case skipChildren
    case stop
}

@MainActor
public func traverseAndSearch(
    element: Element,
    visitor: any ElementVisitor,
    currentDepth: Int,
    maxDepth: Int
) {
    let elementDescription = element.briefDescription(option: ValueFormatOption.smart)

    guard currentDepth <= maxDepth else {
        logTraversalDepthExceeded(maxDepth, elementDescription)
        return
    }

    traversalNodeCounter += 1
    let visitResult = visitor.visit(element: element, depth: currentDepth)

    switch visitResult {
    case .stop:
        logTraversalEvent("STOP", elementDescription: elementDescription, depth: currentDepth)
        return
    case .skipChildren:
        logTraversalEvent("SKIP_CHILDREN", elementDescription: elementDescription, depth: currentDepth)
        return // Do not process children
    case .continue:
        logTraversalEvent(
            "CONTINUE",
            elementDescription: elementDescription,
            depth: currentDepth,
            extra: "Processing children"
        )
        // Continue to process children
    }

    // Maintain a static visited set per traversal to avoid cycles.
    // We store the CFHash of AXUIElement to uniquely identify.
    struct VisitedSet { nonisolated(unsafe) static var set = Set<UInt>() }

    if let children = element.children(strict: false), !children.isEmpty,
       axorcScanAll || (element.role().map { containerRoles.contains($0) } ?? false) {
        // Abort if we are past the deadline
        if let deadline = traversalDeadline, Date() > deadline {
            logger.warning("Traverse: global search timeout (\(axorcTraversalTimeout)s) reached. Aborting traversal.")
            return
        }

        for child in children {
            let hashVal: UInt = CFHash(child.underlyingElement)
            if !VisitedSet.set.insert(hashVal).inserted {
                continue // already visited; skip to avoid cycles
            }
            traverseAndSearch(element: child, visitor: visitor, currentDepth: currentDepth + 1, maxDepth: maxDepth)
            if let searchVisitor = visitor as? SearchVisitor,
               searchVisitor.stopAtFirstMatchInternal,
               searchVisitor.foundElement != nil {
                logger.debug(
                    logSegments(
                        "Traverse: SearchVisitor found match and stopAtFirstMatch is true",
                        "Stopping traversal early"
                    )
                )
                return // Stop traversal early
            }
        }
    }
}

private func logTraversalDepthExceeded(_ maxDepth: Int, _ elementDescription: String) {
    logger.debug(
        logSegments(
            "Traverse: Max depth \(maxDepth) reached at [\(elementDescription)]",
            "Stopping this branch"
        )
    )
}

private func logTraversalEvent(
    _ event: String,
    elementDescription: String,
    depth: Int,
    extra: String? = nil
) {
    var messageParts = [
        "Traverse: Visitor requested \(event) at [\(elementDescription)]",
        "depth \(depth)"
    ]
    if let extra {
        messageParts.append(extra)
    }
    logger.debug(logSegments(messageParts))
}

// MARK: - Search Visitor Implementation

@MainActor
public class SearchVisitor: ElementVisitor {
    public var foundElement: Element? // Stores the first element that matches criteria
    public var allFoundElements: [Element] = [] // Stores all elements that match criteria
    private let criteria: [Criterion]
    internal let stopAtFirstMatchInternal: Bool
    private let maxDepth: Int
    private var currentMaxDepthReachedByVisitor: Int = 0
    private let matchType: JSONPathHintComponent.MatchType
    private let matchAllCriteriaBool: Bool
    public var deepestDepthReached: Int { currentMaxDepthReachedByVisitor }

    init(
        criteria: [Criterion],
        matchType: JSONPathHintComponent.MatchType = .exact, // Added with default
        matchAllCriteria: Bool = true, // Added with default
        stopAtFirstMatch: Bool = false,
        maxDepth: Int = AXMiscConstants.defaultMaxDepthSearch
    ) {
        self.criteria = criteria
        self.matchType = matchType
        self.matchAllCriteriaBool = matchAllCriteria
        self.stopAtFirstMatchInternal = stopAtFirstMatch
        self.maxDepth = maxDepth

        let criteriaDesc = describeCriteria(self.criteria)
        logger.debug(
            logSegments(
                "SearchVisitor Init: Criteria: \(criteriaDesc)",
                "StopAtFirst: \(stopAtFirstMatchInternal)",
                "MaxDepth: \(maxDepth)",
                "MatchType: \(matchType)",
                "MatchAll: \(matchAllCriteria)"
            )
        )
    }

    @MainActor
    public func visit(element: Element, depth: Int) -> TreeVisitorResult {
        let elementDesc = element.briefDescription(option: ValueFormatOption.smart)
        currentMaxDepthReachedByVisitor = max(currentMaxDepthReachedByVisitor, depth)

        if depth > maxDepth {
            logger.debug(
                logSegments(
                    "SearchVisitor: Max depth \(maxDepth) reached internally at [\(elementDesc)]",
                    "Skipping"
                )
            )
            return .skipChildren
        }

        logger.debug("SV: [\(elementDesc)] @\(depth) C:\(criteria.count)")

        var matches = false
        if matchAllCriteriaBool {
            // Use the stored matchType
            if elementMatchesAllCriteria(element: element, criteria: criteria, matchType: self.matchType) {
                matches = true
            }
        } else {
            // Use the stored matchType
            if elementMatchesAnyCriterion(element: element, criteria: criteria, matchType: self.matchType) {
                matches = true
            }
        }

        if matches {
            logger.debug("SV: ✓ [\(elementDesc)] @\(depth)")
            foundElement = element
            allFoundElements.append(element)
            if stopAtFirstMatchInternal {
                logger.debug("SV: Stop (first match)")
                return .stop
            }
        } else {
            logger.debug("SV: ✗ [\(elementDesc)] @\(depth)")
        }
        return .continue
    }

    // Resets the visitor state for reuse, e.g., when searching different branches of a tree.
    public func reset() {
        self.foundElement = nil
        self.allFoundElements.removeAll()
        self.currentMaxDepthReachedByVisitor = 0 // Reset depth
        // logger.debug("SearchVisitor reset.") // Optional: for debugging visitor lifecycle
    }
}

// MARK: - Collect All Visitor Implementation

@MainActor
public class CollectAllVisitor: ElementVisitor {
    private(set) var collectedElements: [Element] = []
    let criteria: [Criterion]?
    let includeIgnored: Bool

    init(criteria: [Criterion]? = nil, includeIgnored: Bool = false) {
        self.criteria = criteria
        self.includeIgnored = includeIgnored
        let criteriaDebug = criteria?
            .map { "\($0.attribute):\($0.value)(\($0.matchType?.rawValue ?? "exact"))" }
            .joined(separator: ", ")
            ?? "all"
        logger.debug("CollectAllVisitor Init: Criteria: [\(criteriaDebug)], IncludeIgnored: \(includeIgnored)")
    }

    public func visit(element: Element, depth: Int) -> TreeVisitorResult {
        let elementDesc = element.briefDescription(option: ValueFormatOption.smart)
        logger.debug("CAV: [\(elementDesc)] @\(depth)")

        if !includeIgnored && element.isIgnored() {
            logger.debug("CAV: Skip ignored [\(elementDesc)]")
            return .skipChildren // Skip ignored elements and their children if not including ignored
        }

        if let criteria = criteria {
            if elementMatchesAllCriteria(element: element, criteria: criteria) {
                logger.debug("CAV: + [\(elementDesc)] (match)")
                collectedElements.append(element)
            } else {
                logger.debug("CollectAllVisitor: [\(elementDesc)] did NOT match criteria.")
            }
        } else {
            // No criteria, collect all (respecting includeIgnored)
            logger.debug("CollectAllVisitor: Adding [\(elementDesc)] (no criteria given).")
            collectedElements.append(element)
        }
        return .continue
    }
}

// Note: Ensure `getApplicationElement` from PathNavigator is accessible and synchronous.
// Ensure `navigateToElementByJSONPathHint` from PathNavigator is accessible and synchronous.
// Ensure `elementMatchesAllCriteria` from SearchCriteriaUtils is accessible and synchronous.
// Ensure `Criterion` struct and `Locator` struct are defined and accessible.
// AXMiscConstants should be available.
// Example: public enum AXMiscConstants { public static let defaultMaxDepthSearch: Int = 10 }

private func describeCriteria(_ criteria: [Criterion]) -> String {
    let description = criteria.map { criterion in
        "[\(criterion.attribute):\(criterion.value), match:\(criterion.matchType?.rawValue ?? "exact")]"
    }.joined(separator: ", ")
    return description.isEmpty ? "none" : description
}


// Container roles that can have meaningful descendants. Non-container roles are treated as leaves.
private let containerRoles: Set<String> = [
    AXRoleNames.kAXApplicationRole,
    AXRoleNames.kAXWindowRole,
    AXRoleNames.kAXGroupRole,
    AXRoleNames.kAXScrollAreaRole,
    AXRoleNames.kAXSplitGroupRole,
    AXRoleNames.kAXLayoutAreaRole,
    AXRoleNames.kAXLayoutItemRole,
    AXRoleNames.kAXWebAreaRole,
    AXRoleNames.kAXListRole,
    AXRoleNames.kAXOutlineRole,
    AXRoleNames.kAXUnknownRole,
    "AXGeneric", "AXSection", "AXArticle", "AXSplitter", "AXScrollBar", "AXPane"
]

// MARK: - Search Timeout Handling

/// Global deadline used by `traverseAndSearch` to abort extremely long walks.
/// It is _only_ set for the duration of a single public search call and then cleared again.
nonisolated(unsafe) private var traversalDeadline: Date?

/// Counts how many nodes have been visited during the current `findTargetElement` invocation.
nonisolated(unsafe) private var traversalNodeCounter: Int = 0

/// Default timeout (seconds) for a full tree traversal. Override at runtime by setting `axorcTraversalTimeout`.
nonisolated(unsafe) public var axorcTraversalTimeout: TimeInterval = 30

/// When true, traversal will ignore `containerRoles` pruning and descend into *every* child of every element.
/// Enable via CLI flag `--scan-all`.
nonisolated(unsafe) public var axorcScanAll: Bool = false

/// Controls whether SearchVisitor should stop at the first element that satisfies the final locator criteria.
/// CLI flag `--no-stop-first` sets this to `false`.
nonisolated(unsafe) public var axorcStopAtFirstMatch: Bool = true
