// AXorcist+HandlerUtils.swift - Common handler utilities

import AppKit
import ApplicationServices
import Foundation

// MARK: - Handler Error Types
internal struct HandlerResponseError: Error {
    let message: String
    let logs: [String]?

    init(message: String, logs: [String]? = nil) {
        self.message = message
        self.logs = logs
    }
}

// MARK: - Handler Utilities Extension
extension AXorcist {

    /// Finds a target element using path hints and locator criteria
    /// - Parameters:
    ///   - appIdentifierOrNil: Application identifier (nil uses focused app)
    ///   - locator: Optional locator criteria for finding the element
    ///   - pathHint: Optional path hint for navigation from root
    ///   - isRootedAtApp: If true, starts from application element; if false, uses baseElement
    ///   - baseElement: Base element to start from (only used if isRootedAtApp is false)
    ///   - maxDepthForSearch: Maximum search depth for locator searches
    ///   - isDebugLoggingEnabled: Whether debug logging is enabled
    ///   - currentDebugLogs: Debug logs array to append to
    /// - Returns: Result containing the found Element or HandlerResponseError
    @MainActor
    internal func findTargetElement(
        for appIdentifierOrNil: String?,
        locator: Locator?,
        pathHint: [String]?,
        isRootedAtApp: Bool = true,
        baseElement: Element? = nil,
        maxDepthForSearch: Int? = nil,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) async -> Result<Element, HandlerResponseError> {

        func dLog(_ message: String) {
            if isDebugLoggingEnabled {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage(message, applicationName: appIdentifierOrNil, commandID: nil, file: #file, function: #function, line: #line))
            }
        }

        // Determine initial element
        let initialElement: Element
        if isRootedAtApp {
            let appIdentifier = appIdentifierOrNil ?? focusedAppKeyValue
            dLog("[findTargetElement] Getting application element for: \(appIdentifier)")

            guard let appElement = applicationElement(
                for: appIdentifier,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            ) else {
                let errorMessage = "Failed to get application element for identifier: \(appIdentifier)"
                dLog("[findTargetElement] \(errorMessage)")
                return .failure(HandlerResponseError(message: errorMessage, logs: currentDebugLogs))
            }
            initialElement = appElement
        } else {
            guard let providedBaseElement = baseElement else {
                let errorMessage = "Base element required when isRootedAtApp is false, but none provided"
                dLog("[findTargetElement] \(errorMessage)")
                return .failure(HandlerResponseError(message: errorMessage, logs: currentDebugLogs))
            }
            initialElement = providedBaseElement
        }

        var effectiveElement = initialElement

        // Navigate using path hint if provided
        if let pathHint = pathHint, !pathHint.isEmpty {
            dLog("[findTargetElement] Navigating with path_hint: \(pathHint.joined(separator: " -> ")) from root \(effectiveElement.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs))")

            guard let navigatedElement = navigateToElement(
                from: effectiveElement,
                pathHint: pathHint,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            ) else {
                let lastLogBeforeDebug = currentDebugLogs.last
                let errorMessage: String
                if let lastLog = lastLogBeforeDebug, lastLog.contains("CRITICAL_NAV_PARSE_FAILURE_MARKER") {
                    errorMessage = "Navigation parsing failed (critical marker found) for path hint: \(pathHint.joined(separator: " -> "))"
                } else if let lastLog = lastLogBeforeDebug, lastLog.contains("CHILD_MATCH_FAILURE_MARKER") {
                    errorMessage = "Navigation child match failed (child match marker found) for path hint: \(pathHint.joined(separator: " -> "))"
                } else {
                    errorMessage = "Failed to navigate using path hint: \(pathHint.joined(separator: " -> "))"
                }

                if isDebugLoggingEnabled {
                    if let actualLastLog = lastLogBeforeDebug {
                        dLog("[MARKER_CHECK] Checked lastLog for markers -> Error: '\(errorMessage)'. LastLog: '\(actualLastLog)'")
                    } else {
                        dLog("[MARKER_CHECK] currentDebugLogs was empty or lastLog was nil -> Error: '\(errorMessage)'")
                    }
                }
                dLog("[findTargetElement] \(errorMessage)")
                return .failure(HandlerResponseError(message: errorMessage, logs: currentDebugLogs))
            }
            effectiveElement = navigatedElement
            dLog("[findTargetElement] Successfully navigated path_hint. New effectiveElement: \(effectiveElement.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs))")
        }

        // Search using locator if provided
        if let actualLocator = locator {
            dLog("[findTargetElement] Locator provided. Searching from current effectiveElement: \(effectiveElement.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs)) using locator criteria: \(actualLocator.criteria)")

            let searchResult = self.search(
                element: effectiveElement,
                locator: actualLocator,
                requireAction: actualLocator.requireAction,
                depth: 0,
                maxDepth: maxDepthForSearch ?? AXMiscConstants.defaultMaxDepthSearch,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            )
            currentDebugLogs.append(contentsOf: searchResult.logs)

            dLog("[findTargetElement] Search completed. Logs from searchResult.logs count: \(searchResult.logs.count)")

            guard let foundElement = searchResult.foundElement else {
                let errorMessage = "Search failed. Could not find element matching locator criteria \(actualLocator.criteria) starting from element \(effectiveElement.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs))"
                if !currentDebugLogs.contains(errorMessage) {
                    currentDebugLogs.append(errorMessage)
                }
                dLog("[findTargetElement] \(errorMessage)")
                return .failure(HandlerResponseError(message: errorMessage, logs: currentDebugLogs))
            }

            dLog("[findTargetElement] Found element via locator: \(foundElement.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs))")
            return .success(foundElement)
        } else {
            // No locator, use effective element after path hint navigation
            dLog("[findTargetElement] No locator provided. Using current effectiveElement as target: \(effectiveElement.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs))")
            return .success(effectiveElement)
        }
    }
}
