// AXorcist+QueryHandlers.swift - Query and search operation handlers

import AppKit
import ApplicationServices
import Foundation

// MARK: - Query & Search Handlers Extension
extension AXorcist {

    // MARK: - handleQuery

    @MainActor
    public func handleQuery(
        for appIdentifierOrNil: String?,
        locator: Locator,
        pathHint: [String]?,
        maxDepth: Int?,
        requestedAttributes: [String]?,
        outputFormat: OutputFormat?,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) async -> HandlerResponse {

        func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }

        let appIdentifier = appIdentifierOrNil ?? self.focusedAppKeyValue
        dLog("Handling query for app: \(appIdentifier)")

        guard let appElement = applicationElement(
            for: appIdentifier,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        ) else {
            return HandlerResponse(
                data: nil,
                error: "Application not found: \(appIdentifier)",
                debug_logs: isDebugLoggingEnabled ? currentDebugLogs : nil
            )
        }

        var effectiveElement = appElement
        if let pathHint = pathHint, !pathHint.isEmpty {
            dLog("Navigating with path_hint: \(pathHint.joined(separator: " -> "))")
            if let navigatedElement = navigateToElement(
                from: effectiveElement,
                pathHint: pathHint,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            ) {
                effectiveElement = navigatedElement
            } else {
                return HandlerResponse(
                    data: nil,
                    error: "Element not found via path hint: \(pathHint.joined(separator: " -> "))",
                    debug_logs: isDebugLoggingEnabled ? currentDebugLogs : nil
                )
            }
        }

        let appSpecifiers = ["application", "bundle_id", "pid", "path"]
        let criteriaKeys = locator.criteria.keys
        let isAppOnlyLocator = criteriaKeys.allSatisfy { appSpecifiers.contains($0) } && criteriaKeys.count == 1

        var foundElement: Element?

        if isAppOnlyLocator {
            dLog("Locator is app-only (criteria: \(locator.criteria)). Using appElement directly.")
            foundElement = effectiveElement
        } else {
            dLog("Locator contains element-specific criteria or is complex. Proceeding with search.")
            var searchStartElementForLocator = effectiveElement
            if let rootPathHint = locator.root_element_path_hint, !rootPathHint.isEmpty {
                dLog(
                    "Locator has root_element_path_hint: \(rootPathHint.joined(separator: " -> ")). Navigating from app element first."
                )
                guard let containerElement = navigateToElement(
                    from: appElement,
                    pathHint: rootPathHint,
                    isDebugLoggingEnabled: isDebugLoggingEnabled,
                    currentDebugLogs: &currentDebugLogs
                ) else {
                    return HandlerResponse(
                        data: nil,
                        error: "Container for locator not found via root_element_path_hint: \(rootPathHint.joined(separator: " -> "))",
                        debug_logs: isDebugLoggingEnabled ? currentDebugLogs : nil
                    )
                }
                searchStartElementForLocator = containerElement
                dLog(
                    "Searching with locator within container found by root_element_path_hint: \(searchStartElementForLocator.briefDescription(option: ValueFormatOption.default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs))"
                )
            } else {
                dLog(
                    "Searching with locator from element (determined by main path_hint or app root): \(searchStartElementForLocator.briefDescription(option: ValueFormatOption.default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs))"
                )
            }

            let searchResult = self.search(
                element: searchStartElementForLocator,
                locator: locator,
                requireAction: locator.requireAction,
                depth: 0,
                maxDepth: maxDepth ?? AXMiscConstants.defaultMaxDepthSearch,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            )
            foundElement = searchResult.foundElement
        }

        if let elementToQuery = foundElement {
            var attributes = getElementAttributes(
                elementToQuery,
                requestedAttributes: requestedAttributes ?? [],
                forMultiDefault: false,
                targetRole: locator.criteria[AXAttributeNames.kAXRoleAttribute],
                outputFormat: outputFormat ?? .smart,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            )
            if outputFormat == .json_string {
                attributes = encodeAttributesToJSONStringRepresentation(attributes)
            }

            let axElement = AXElement(attributes: attributes)
            return HandlerResponse(
                data: axElement,
                error: nil,
                debug_logs: isDebugLoggingEnabled ? currentDebugLogs : nil
            )
        } else {
            return HandlerResponse(
                data: nil,
                error: "No element matches single query criteria with locator or app-only locator failed to resolve.",
                debug_logs: isDebugLoggingEnabled ? currentDebugLogs : nil
            )
        }
    }

    // MARK: - handleGetAttributes

    @MainActor
    public func handleGetAttributes(
        for appIdentifierOrNil: String?,
        locator: Locator,
        requestedAttributes: [String]?,
        pathHint: [String]?,
        maxDepth: Int?,
        outputFormat: OutputFormat?,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) async -> HandlerResponse {

        func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }

        let appIdentifier = appIdentifierOrNil ?? self.focusedAppKeyValue
        dLog("Handling get_attributes command for app: \(appIdentifier)")

        // Use findTargetElement to get the target element
        let targetElementResult = await self.findTargetElement(
            for: appIdentifier,
            locator: locator,
            pathHint: pathHint,
            maxDepthForSearch: maxDepth ?? AXMiscConstants.defaultMaxDepthSearch,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )

        let foundElement: Element
        switch targetElementResult {
        case .failure(let errorData):
            return HandlerResponse(
                data: nil,
                error: errorData.message,
                debug_logs: errorData.logs ?? currentDebugLogs
            )
        case .success(let element):
            foundElement = element
        }

        dLog(
            "handleGetAttributes: Element found: \(foundElement.briefDescription(option: ValueFormatOption.default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs)). Fetching attributes: \(requestedAttributes ?? ["all"])..."
        )

        let elementToQuery = foundElement
        var attributes = getElementAttributes(
            elementToQuery,
            requestedAttributes: requestedAttributes ?? [],
            forMultiDefault: false,
            targetRole: locator.criteria[AXAttributeNames.kAXRoleAttribute],
            outputFormat: outputFormat ?? .smart,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
        if outputFormat == .json_string {
            attributes = encodeAttributesToJSONStringRepresentation(attributes)
        }
        dLog(
            "Successfully fetched attributes for element \(elementToQuery.briefDescription(option: ValueFormatOption.default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs))."
        )

        let axElement = AXElement(attributes: attributes)
        return HandlerResponse(
            data: axElement,
            error: nil,
            debug_logs: isDebugLoggingEnabled ? currentDebugLogs : nil
        )
    }

    @MainActor
    public func handleDescribeElement(
        for appIdentifierOrNil: String?,
        locator: Locator,
        pathHint: [String]?,
        maxDepth: Int?,
        requestedAttributes: [String]?,
        outputFormat: OutputFormat?,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) async -> HandlerResponse {

        func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }

        let appIdentifier = appIdentifierOrNil ?? self.focusedAppKeyValue
        dLog("Handling describe_element for app: \(appIdentifier)")

        let searchMaxDepth = maxDepth ?? AXMiscConstants.defaultMaxDepthSearch

        // Use findTargetElement to get the target element
        let targetElementResult = await self.findTargetElement(
            for: appIdentifier,
            locator: locator,
            pathHint: pathHint,
            maxDepthForSearch: searchMaxDepth,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )

        let elementToDescribe: Element
        switch targetElementResult {
        case .failure(let errorData):
            return HandlerResponse(
                data: nil,
                error: errorData.message,
                debug_logs: errorData.logs ?? currentDebugLogs
            )
        case .success(let element):
            elementToDescribe = element
        }

        dLog(
            "[AXorcist.handleDescribeElement] Element found: \(elementToDescribe.briefDescription(option: ValueFormatOption.default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs)). Now describing."
        )

        // Get application element for path generation
        guard let appElement = applicationElement(
            for: appIdentifier,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        ) else {
            return HandlerResponse(
                data: nil,
                error: "Application not found: \(appIdentifier)",
                debug_logs: isDebugLoggingEnabled ? currentDebugLogs : nil
            )
        }

        var attributes = getElementAttributes(
            elementToDescribe,
            requestedAttributes: requestedAttributes ?? ["all"],
            forMultiDefault: true,
            targetRole: locator.criteria[AXAttributeNames.kAXRoleAttribute],
            outputFormat: outputFormat ?? .verbose,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
        if outputFormat == .json_string {
            attributes = encodeAttributesToJSONStringRepresentation(attributes)
        }

        let axElement = AXElement(
            attributes: attributes,
            path: elementToDescribe.generatePathArray(upTo: appElement, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs)
        )

        return HandlerResponse(data: axElement, error: nil, debug_logs: currentDebugLogs)
    }
}
