// ElementSearch.swift - Contains search and element collection logic

import ApplicationServices
import Foundation

// MARK: - Environment Variable & Global Constants

private func getEnvVar(_ name: String) -> String? {
    guard let value = getenv(name) else { return nil }
    return String(cString: value)
}

private let AXORC_JSON_LOG_ENABLED: Bool = {
    let envValue = getEnvVar("AXORC_JSON_LOG")?.lowercased()
    fputs("[ElementSearch.swift] AXORC_JSON_LOG env var value: \(envValue ?? "not set") -> JSON logging: \(envValue == "true")\n", stderr)
    return envValue == "true"
}()

// PathHintComponent and criteriaMatch are now in SearchCriteriaUtils.swift

// MARK: - Main Search Logic (findElementViaPathAndCriteria and its helpers)
@MainActor
func findElementViaPathAndCriteria(
    application: Element,
    locator: Locator,
    maxDepth: Int?,
    isDebugLoggingEnabledParam: Bool,
    currentDebugLogs: inout [String]
) -> Element? {
    var tempNilLogs: [String] = []

    // ADDED DEBUG LOGGING
    if isDebugLoggingEnabledParam {
        let pathHintDebug = locator.root_element_path_hint?.joined(separator: " -> ") ?? "nil"
        let initialMessage = "[findElementViaPathAndCriteria ENTRY] locator.criteria: \(locator.criteria), locator.root_element_path_hint: \(pathHintDebug)"
        currentDebugLogs.append(AXorcist.formatDebugLogMessage(initialMessage, applicationName: application.pid(isDebugLoggingEnabled: false, currentDebugLogs: &tempNilLogs).map { String($0) }, commandID: nil, file: #file, function: #function, line: #line))
    }
    // END ADDED DEBUG LOGGING

    func dLog(_ message: String, depth: Int? = nil, status: String? = nil, element: Element? = nil, c: [String: String]? = nil, md: Int? = nil) {
        if !AXORC_JSON_LOG_ENABLED && isDebugLoggingEnabledParam {
            var logMessage = message
            if let depth_ = depth, let status_ = status, let element_ = element {
                let role = element_.role(isDebugLoggingEnabled: false, currentDebugLogs: &tempNilLogs) ?? "nil"
                let title = element_.title(isDebugLoggingEnabled: false, currentDebugLogs: &tempNilLogs)?.truncated(to: 30) ?? "nil"
                let id = element_.identifier(isDebugLoggingEnabled: false, currentDebugLogs: &tempNilLogs)?.truncated(to: 30) ?? "nil"
                let criteriaDesc = c?.description.truncated(to: 50) ?? locator.criteria.description.truncated(to: 50)
                let maxDepthDesc = md ?? maxDepth ?? AXMiscConstants.defaultMaxDepthSearch
                logMessage = "search [D\(depth_)]: Path:\(element_.generatePathArray(upTo: application, isDebugLoggingEnabled: false, currentDebugLogs: &tempNilLogs).suffix(3).joined(separator: "/")), Status:\(status_), Elem:\(role) T:'\(title)' ID:'\(id)', Crit:\(criteriaDesc), MaxD:\(maxDepthDesc)"
            }
            let appPidString = application.pid(isDebugLoggingEnabled: false, currentDebugLogs: &tempNilLogs).map { String($0) }
            currentDebugLogs.append(AXorcist.formatDebugLogMessage(logMessage, applicationName: appPidString, commandID: nil, file: #file, function: #function, line: #line))
        }
    }

    func writeSearchLogEntry(depth: Int, element: Element?, criteriaForEntry: [String: String]?, maxDepthForEntry: Int, status: String, isMatch: Bool?) {
        if AXORC_JSON_LOG_ENABLED && isDebugLoggingEnabledParam {
            let role: String? = element?.role(isDebugLoggingEnabled: false, currentDebugLogs: &tempNilLogs)
            let title: String? = element?.title(isDebugLoggingEnabled: false, currentDebugLogs: &tempNilLogs)
            let identifier: String? = element?.identifier(isDebugLoggingEnabled: false, currentDebugLogs: &tempNilLogs)

            let entry = SearchLogEntry(
                d: depth,
                eR: role?.truncatedToMaxLogAbbrev(),
                eT: title?.truncatedToMaxLogAbbrev(),
                eI: identifier?.truncatedToMaxLogAbbrev(),
                mD: maxDepthForEntry,
                c: criteriaForEntry?.mapValues { $0.truncatedToMaxLogAbbrev() } ?? locator.criteria.mapValues { $0.truncatedToMaxLogAbbrev() },
                s: status,
                iM: isMatch
            )
            if let jsonData = try? JSONEncoder().encode(entry), let jsonString = String(data: jsonData, encoding: .utf8) {
                fputs("\(jsonString)\n", stderr)
            }
        }
    }

    @MainActor
    func navigateToElementByPathHint(pathHint: [PathHintComponent], initialSearchElement: Element, pathHintMaxDepth: Int) -> Element? {
        var currentElementInPath = initialSearchElement
        dLog("PathHintNav: Starting with \(pathHint.count) components from \(initialSearchElement.briefDescription(option: .default, isDebugLoggingEnabled: false, currentDebugLogs: &tempNilLogs))")

        for (index, pathComponent) in pathHint.enumerated() {
            let currentNavigationDepth = index
            dLog("PathHintNav: Visiting comp #\(index)", depth: currentNavigationDepth, status: "pathVis", element: currentElementInPath, c: pathComponent.criteria, md: pathHintMaxDepth)
            writeSearchLogEntry(depth: currentNavigationDepth, element: currentElementInPath, criteriaForEntry: pathComponent.criteria, maxDepthForEntry: pathHintMaxDepth, status: "pathVis", isMatch: nil)

            if !pathComponent.matches(element: currentElementInPath, isDebugLoggingEnabled: isDebugLoggingEnabledParam, axorcJsonLogEnabled: AXORC_JSON_LOG_ENABLED, currentDebugLogs: &currentDebugLogs) {
                dLog("PathHintNav: No match for comp #\(index)", depth: currentNavigationDepth, status: "pathNoMatch", element: currentElementInPath, c: pathComponent.criteria, md: pathHintMaxDepth)
                writeSearchLogEntry(depth: currentNavigationDepth, element: currentElementInPath, criteriaForEntry: pathComponent.criteria, maxDepthForEntry: pathHintMaxDepth, status: "pathNoMatch", isMatch: false)
                return nil
            }

            dLog("PathHintNav: Matched comp #\(index)", depth: currentNavigationDepth, status: "pathMatch", element: currentElementInPath, c: pathComponent.criteria, md: pathHintMaxDepth)
            writeSearchLogEntry(depth: currentNavigationDepth, element: currentElementInPath, criteriaForEntry: pathComponent.criteria, maxDepthForEntry: pathHintMaxDepth, status: "pathMatch", isMatch: true)

            if index == pathHint.count - 1 {
                return currentElementInPath
            }

            let nextPathComponentCriteria = pathHint[index + 1].criteria
            var foundNextChild: Element?
            if let children = currentElementInPath.children(isDebugLoggingEnabled: isDebugLoggingEnabledParam, currentDebugLogs: &currentDebugLogs) {
                for child in children {
                    let tempPathComponent = PathHintComponent(criteria: nextPathComponentCriteria)
                    if tempPathComponent.matches(element: child, isDebugLoggingEnabled: isDebugLoggingEnabledParam, axorcJsonLogEnabled: AXORC_JSON_LOG_ENABLED, currentDebugLogs: &currentDebugLogs) {
                        currentElementInPath = child
                        foundNextChild = child
                        break
                    }
                }
            }

            if foundNextChild == nil {
                dLog("PathHintNav: Could not find child for next comp #\(index + 1)", depth: currentNavigationDepth, status: "pathChildFail", element: currentElementInPath, c: nextPathComponentCriteria, md: pathHintMaxDepth)
                writeSearchLogEntry(depth: currentNavigationDepth, element: currentElementInPath, criteriaForEntry: nextPathComponentCriteria, maxDepthForEntry: pathHintMaxDepth, status: "pathChildFail", isMatch: false)
                return nil
            }
        }
        return currentElementInPath
    }

    @MainActor
    func traverseAndSearch(currentElement: Element, currentDepth: Int, effectiveMaxDepth: Int) -> Element? {
        dLog("Traverse: Visiting", depth: currentDepth, status: "vis", element: currentElement, md: effectiveMaxDepth)
        writeSearchLogEntry(depth: currentDepth, element: currentElement, criteriaForEntry: locator.criteria, maxDepthForEntry: effectiveMaxDepth, status: "vis", isMatch: nil)

        if criteriaMatch(element: currentElement, criteria: locator.criteria, isDebugLoggingEnabled: isDebugLoggingEnabledParam, axorcJsonLogEnabled: AXORC_JSON_LOG_ENABLED, currentDebugLogs: &currentDebugLogs) {
            dLog("Traverse: Found", depth: currentDepth, status: "found", element: currentElement, md: effectiveMaxDepth)
            writeSearchLogEntry(depth: currentDepth, element: currentElement, criteriaForEntry: locator.criteria, maxDepthForEntry: effectiveMaxDepth, status: "found", isMatch: true)
            return currentElement
        } else {
            writeSearchLogEntry(depth: currentDepth, element: currentElement, criteriaForEntry: locator.criteria, maxDepthForEntry: effectiveMaxDepth, status: "noMatch", isMatch: false)
        }

        if currentDepth >= effectiveMaxDepth {
            dLog("Traverse: MaxDepth", depth: currentDepth, status: "maxD", element: currentElement, md: effectiveMaxDepth)
            writeSearchLogEntry(depth: currentDepth, element: currentElement, criteriaForEntry: locator.criteria, maxDepthForEntry: effectiveMaxDepth, status: "maxD", isMatch: false)
            return nil
        }

        if let children = currentElement.children(isDebugLoggingEnabled: isDebugLoggingEnabledParam, currentDebugLogs: &currentDebugLogs) {
            for child in children {
                if let found = traverseAndSearch(currentElement: child, currentDepth: currentDepth + 1, effectiveMaxDepth: effectiveMaxDepth) {
                    return found
                }
            }
        }
        return nil
    }

    var searchStartElement = application
    let resolvedMaxDepth = maxDepth ?? AXMiscConstants.defaultMaxDepthSearch

    if let pathHintStrings = locator.root_element_path_hint, !pathHintStrings.isEmpty {
        let pathHintComponents = pathHintStrings.compactMap { PathHintComponent(pathSegment: $0, isDebugLoggingEnabled: isDebugLoggingEnabledParam, axorcJsonLogEnabled: AXORC_JSON_LOG_ENABLED, currentDebugLogs: &currentDebugLogs) }
        if !pathHintComponents.isEmpty && pathHintComponents.count == pathHintStrings.count {
            dLog("Starting path hint navigation. Number of components: \(pathHintComponents.count)")
            if let elementFromPathHint = navigateToElementByPathHint(pathHint: pathHintComponents, initialSearchElement: application, pathHintMaxDepth: pathHintComponents.count - 1) {
                dLog("Path hint navigation successful. New start: \(elementFromPathHint.briefDescription(option: .default, isDebugLoggingEnabled: false, currentDebugLogs: &tempNilLogs)). Starting criteria search.")
                searchStartElement = elementFromPathHint
            } else {
                dLog("Path hint navigation failed. Full search from app root.")
            }
        } else {
            dLog("Path hint strings provided but failed to parse into components or some were invalid. Full search from app root.")
        }
    } else {
        dLog("No path hint provided. Searching from application root.")
    }

    return traverseAndSearch(currentElement: searchStartElement, currentDepth: 0, effectiveMaxDepth: resolvedMaxDepth)
}

enum ElementMatchStatus {
    case fullMatch
    case partialMatch_actionMissing
    case noMatch
}

@MainActor
internal func evaluateElementAgainstCriteria(
    element: Element,
    locator: Locator,
    actionToVerify: String?,
    depth: Int,
    isDebugLoggingEnabled: Bool,
    currentDebugLogs: inout [String]
) -> ElementMatchStatus {
    func el_dLog(_ message: String) {
        if !AXORC_JSON_LOG_ENABLED && isDebugLoggingEnabled { currentDebugLogs.append(message) }
    }
    var tempLogs: [String] = []

    let currentElementRoleForLog: String? = element.role(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
    let wantedRoleFromCriteria = locator.criteria[AXAttributeNames.kAXRoleAttribute]

    var roleMatchesCriteria = false
    if let currentRole = currentElementRoleForLog, let roleToMatch = wantedRoleFromCriteria, !roleToMatch.isEmpty, roleToMatch != "*" {
        roleMatchesCriteria = (currentRole == roleToMatch)
    } else {
        roleMatchesCriteria = true
    }

    if !roleMatchesCriteria { return .noMatch }

    if !criteriaMatch(element: element, criteria: locator.criteria, isDebugLoggingEnabled: isDebugLoggingEnabled, axorcJsonLogEnabled: AXORC_JSON_LOG_ENABLED, currentDebugLogs: &currentDebugLogs) {
        return .noMatch
    }

    let actionRequirement = actionToVerify ?? locator.requireAction
    if let requiredAction = actionRequirement, !requiredAction.isEmpty {
        if !element.isActionSupported(requiredAction, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) {
            return .partialMatch_actionMissing
        }
    }
    return .fullMatch
}

@MainActor
public func search(element: Element,
                   locator: Locator,
                   requireAction: String?,
                   depth: Int = 0,
                   maxDepth: Int = AXMiscConstants.defaultMaxDepthSearch,
                   isDebugLoggingEnabled: Bool,
                   currentDebugLogs: inout [String]) -> Element? {
    var tempLogs: [String] = []
    if depth > maxDepth { return nil }

    let matchStatus = evaluateElementAgainstCriteria(element: element,
                                                     locator: locator,
                                                     actionToVerify: requireAction ?? locator.requireAction,
                                                     depth: depth,
                                                     isDebugLoggingEnabled: isDebugLoggingEnabled,
                                                     currentDebugLogs: &currentDebugLogs)

    if matchStatus == .fullMatch { return element }

    let childrenToSearch: [Element] = element.children(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) ?? []
    for childElement in childrenToSearch {
        if let found = search(element: childElement,
                              locator: locator,
                              requireAction: requireAction,
                              depth: depth + 1,
                              maxDepth: maxDepth,
                              isDebugLoggingEnabled: isDebugLoggingEnabled,
                              currentDebugLogs: &currentDebugLogs) {
            return found
        }
    }
    return nil
}

@MainActor
public func collectAll(
    appElement: Element,
    locator: Locator,
    currentElement: Element,
    depth: Int,
    maxDepth: Int,
    maxElements: Int,
    currentPath: [Element],
    elementsBeingProcessed: inout Set<Element>,
    foundElements: inout [Element],
    isDebugLoggingEnabled: Bool,
    currentDebugLogs: inout [String]
) {
    var tempLogs: [String] = []
    if elementsBeingProcessed.contains(currentElement) || currentPath.contains(currentElement) { return }
    elementsBeingProcessed.insert(currentElement)

    if foundElements.count >= maxElements || depth > maxDepth {
        elementsBeingProcessed.remove(currentElement)
        return
    }

    let matchStatus = evaluateElementAgainstCriteria(element: currentElement,
                                                     locator: locator,
                                                     actionToVerify: locator.requireAction,
                                                     depth: depth,
                                                     isDebugLoggingEnabled: isDebugLoggingEnabled,
                                                     currentDebugLogs: &currentDebugLogs)

    if matchStatus == .fullMatch {
        if !foundElements.contains(currentElement) {
            foundElements.append(currentElement)
        }
    }

    let childrenToExplore: [Element] = currentElement.children(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) ?? []
    elementsBeingProcessed.remove(currentElement)

    let newPath = currentPath + [currentElement]
    for child in childrenToExplore {
        if foundElements.count >= maxElements { break }
        collectAll(
            appElement: appElement,
            locator: locator,
            currentElement: child,
            depth: depth + 1,
            maxDepth: maxDepth,
            maxElements: maxElements,
            currentPath: newPath,
            elementsBeingProcessed: &elementsBeingProcessed,
            foundElements: &foundElements,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
    }
}

// Notes for compilation:
// 1. ValueUnwrapper.unwrap should be available.
// 2. AXorcist.formatDebugLogMessage should be available.
// 3. Element struct and its methods must be correctly defined.
// 4. Locator struct must be defined with `criteria: [String: String]`, `root_element_path_hint: [String]?`, and `requireAction: String?`.
// 5. AXAttributeNames.kAXRoleAttribute should be a defined constant (String).
// 6. ValueFormatOption enum (with .default, .short cases) must be available for Element.briefDescription.
// 7. SearchLogEntry struct is now in Models.swift
