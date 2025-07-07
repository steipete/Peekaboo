// AXorcist+CollectAllHandler.swift - CollectAll operation handler

import AppKit
import ApplicationServices
import Foundation

// MARK: - CollectAll Handler Extension
extension AXorcist {

    private func encode(_ output: CollectAllOutput) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let jsonData = try encoder.encode(output)
            return String(data: jsonData, encoding: .utf8) ?? "{\"error\":\"Failed to encode CollectAllOutput to string (fallback)\"}"
        } catch {
            let errorMsgForLog = "Exception encoding CollectAllOutput: \(error.localizedDescription)"
            self.recursiveCallDebugLogs.append(errorMsgForLog)
            return "{\"command_id\":\"Unknown\", \"success\":false, \"command\":\"Unknown\", \"error_message\":\"Catastrophic JSON encoding failure for CollectAllOutput. Original error logged.\", \"collected_elements\":[], \"debug_logs\":[\"Catastrophic JSON encoding failure as well.\"]}"
        }
    }

    @MainActor
    public func handleCollectAll(
        for appIdentifierOrNil: String?,
        locator: Locator?,
        pathHint: [String]?,
        maxDepth: Int?,
        requestedAttributes: [String]?,
        outputFormat: OutputFormat?,
        commandId: String?,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: [String]
    ) -> String {
        self.recursiveCallDebugLogs.removeAll()
        self.recursiveCallDebugLogs.append(contentsOf: currentDebugLogs)

        let effectiveCommandId = commandId ?? "collectAll_internal_id_error"

        func dLog(
            _ message: String,
            _ file: String = #file,
            _ function: String = #function,
            _ line: Int = #line
        ) {
            let logMessage = AXorcist.formatDebugLogMessage(
                message,
                applicationName: appIdentifierOrNil,
                commandID: effectiveCommandId,
                file: file,
                function: function,
                line: line
            )
            self.recursiveCallDebugLogs.append(logMessage)
        }

        let appNameForLog = appIdentifierOrNil ?? "N/A"
        let locatorDesc = locator != nil ? String(describing: locator!.criteria) : "nil"
        let pathHintDesc = String(describing: pathHint)
        let maxDepthDesc = String(describing: maxDepth)
        dLog(
            "[AXorcist.handleCollectAll] Starting. App: \(appNameForLog), Locator: \(locatorDesc), PathHint: \(pathHintDesc), MaxDepth: \(maxDepthDesc)"
        )

        let recursionDepthLimit = (maxDepth != nil && maxDepth! >= 0) ? maxDepth! : AXMiscConstants.defaultMaxDepthCollectAll
        let attributesToFetch = requestedAttributes ?? AXorcist.defaultAttributesToFetch
        let effectiveOutputFormat = outputFormat ?? .smart

        dLog(
            "Effective recursionDepthLimit: \(recursionDepthLimit), attributesToFetch: \(attributesToFetch.count) items, effectiveOutputFormat: \(effectiveOutputFormat.rawValue)"
        )

        let appIdentifier = appIdentifierOrNil ?? focusedAppKeyValue
        dLog("Using app identifier: \(appIdentifier)")

        guard let appElement = applicationElement(
            for: appIdentifier,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &self.recursiveCallDebugLogs
        ) else {
            let errorMsg = "Failed to get app element for identifier: \(appIdentifier)"
            dLog(errorMsg)
            return encode(CollectAllOutput(
                command_id: effectiveCommandId,
                success: false,
                command: "collectAll",
                collected_elements: [],
                app_bundle_id: appIdentifier,
                debug_logs: self.recursiveCallDebugLogs
            ))
        }

        var startElement: Element
        if let hint = pathHint, !hint.isEmpty {
            let pathHintString = hint.joined(separator: " -> ")
            dLog("Navigating to path hint: \(pathHintString)")
            guard let navigatedElement = navigateToElement(
                from: appElement,
                pathHint: hint,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &self.recursiveCallDebugLogs
            ) else {
                let lastLogBeforeError = self.recursiveCallDebugLogs.last
                var errorMsg = "Failed to navigate to path: \(pathHintString)"
                if let lastLog = lastLogBeforeError, lastLog == "CRITICAL_NAV_PARSE_FAILURE_MARKER" {
                    errorMsg = "Navigation parsing failed: Critical marker found."
                } else if let lastLog = lastLogBeforeError, lastLog == "CHILD_MATCH_FAILURE_MARKER" {
                    errorMsg = "Navigation child match failed: Child match marker found."
                }
                dLog(errorMsg)
                return encode(CollectAllOutput(
                    command_id: effectiveCommandId,
                    success: false,
                    command: "collectAll",
                    collected_elements: [],
                    app_bundle_id: appIdentifier,
                    debug_logs: self.recursiveCallDebugLogs
                ))
            }
            startElement = navigatedElement
        } else {
            dLog("Using app element as start element")
            startElement = appElement
        }

        if let loc = locator {
            dLog("Locator provided. Searching for element from current startElement: \(startElement.briefDescription(option: ValueFormatOption.default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &self.recursiveCallDebugLogs)) with locator criteria: \(String(describing: loc.criteria))")

            let searchResultCollectAll = self.search(element: startElement,
                                                     locator: loc,
                                                     requireAction: loc.requireAction,
                                                     depth: 0,
                                                     maxDepth: AXMiscConstants.defaultMaxDepthSearch,
                                                     isDebugLoggingEnabled: isDebugLoggingEnabled,
                                                     currentDebugLogs: &self.recursiveCallDebugLogs)
            self.recursiveCallDebugLogs.append(contentsOf: searchResultCollectAll.logs)

            if let locatedStartElement = searchResultCollectAll.foundElement {
                dLog("Locator found element: \(locatedStartElement.briefDescription(option: ValueFormatOption.default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &self.recursiveCallDebugLogs)). This will be the root for collectAll recursion.")
                startElement = locatedStartElement
            } else {
                let errorMsg = "Failed to find element with provided locator criteria: \(String(describing: loc.criteria)). Cannot start collectAll."
                dLog(errorMsg)
                return encode(CollectAllOutput(
                    command_id: effectiveCommandId,
                    success: false,
                    command: "collectAll",
                    collected_elements: [],
                    app_bundle_id: appIdentifier,
                    debug_logs: self.recursiveCallDebugLogs
                ))
            }
        }

        var collectedAXElements: [AXElement] = []
        var collectRecursively: ((AXUIElement, Int) -> Void)!
        collectRecursively = { axUIElement, currentDepth in
            if currentDepth > recursionDepthLimit {
                dLog(
                    "Reached recursionDepthLimit (\(recursionDepthLimit)) at element \(Element(axUIElement).briefDescription(option: ValueFormatOption.default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &self.recursiveCallDebugLogs)), stopping recursion for this branch."
                )
                return
            }

            let currentElement = Element(axUIElement)
            dLog("Collecting element \(currentElement.briefDescription(option: ValueFormatOption.default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &self.recursiveCallDebugLogs)) at depth \(currentDepth)")

            let fetchedAttrs = getElementAttributes(
                currentElement,
                requestedAttributes: attributesToFetch,
                forMultiDefault: true,
                targetRole: nil,
                outputFormat: effectiveOutputFormat,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &self.recursiveCallDebugLogs
            )

            let elementPath = currentElement.generatePathArray(
                upTo: appElement,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &self.recursiveCallDebugLogs
            )
            let axElement = AXElement(attributes: fetchedAttrs, path: elementPath)
            collectedAXElements.append(axElement)

            // Use the sophisticated child collection from Element+Hierarchy.swift instead of basic kAXChildrenAttribute
            // This is critical for web areas and Electron apps where children may be in alternative attributes
            if let children = currentElement.children(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &self.recursiveCallDebugLogs) {
                dLog(
                    "Element \(currentElement.briefDescription(option: ValueFormatOption.default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &self.recursiveCallDebugLogs)) has \(children.count) children at depth \(currentDepth). Recursing."
                )
                for childElement in children {
                    collectRecursively(childElement.underlyingElement, currentDepth + 1)
                }
            } else {
                dLog(
                    "No children found for element \(currentElement.briefDescription(option: ValueFormatOption.default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &self.recursiveCallDebugLogs)) at depth \(currentDepth)"
                )
            }
        }

        dLog(
            "Starting recursive collection from start element: \(startElement.briefDescription(option: ValueFormatOption.default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &self.recursiveCallDebugLogs))"
        )

        // Start recursion from the determined startElement
        if !self.recursiveCallDebugLogs.contains(where: { $0.contains("Failed to find element with provided locator criteria") && $0.contains("Cannot start collectAll") }) {
            // Only start if locator search (if any) didn't critically fail and try to return early.
            collectRecursively(startElement.underlyingElement, 0)
        }

        let output = CollectAllOutput(
            command_id: effectiveCommandId,
            success: true, // Assuming success if we reach here, errors would have returned earlier
            command: "collectAll",
            collected_elements: collectedAXElements,
            app_bundle_id: appIdentifier,
            debug_logs: self.recursiveCallDebugLogs
        )
        return encode(output)
    }
}
