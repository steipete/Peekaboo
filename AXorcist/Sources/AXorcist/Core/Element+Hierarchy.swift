import ApplicationServices
import Foundation

// MARK: - Environment Variable Check for JSON Logging
// Copied from ElementSearch.swift - ideally this would be in a shared utility
private func getEnvVar(_ name: String) -> String? {
    guard let value = getenv(name) else { return nil }
    return String(cString: value)
}

private let AXORC_JSON_LOG_ENABLED: Bool = {
    let envValue = getEnvVar("AXORC_JSON_LOG")?.lowercased()
    // Explicitly log the check to stderr for debugging the env var itself, specific to Element+Hierarchy.swift
    fputs("[Element+Hierarchy.swift] AXORC_JSON_LOG env var value: \(envValue ?? "not set") -> JSON logging: \(envValue == "true")\n", stderr)
    return envValue == "true"
}()

// MARK: - Element Hierarchy Logic

extension Element {
    @MainActor
    public func children(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> [Element]? {
        func dLog(_ message: String) {
            if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage(message, applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
            }
        }

        let elementDescriptionForLog = self.briefDescription(
            option: .default,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
        if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
            currentDebugLogs.append(AXorcist.formatDebugLogMessage("Getting children for element: \(elementDescriptionForLog)", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
        }

        var childCollector = ChildCollector()

        collectDirectChildren(
            collector: &childCollector,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )

        collectAlternativeChildren(
            collector: &childCollector,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )

        collectApplicationWindows(
            collector: &childCollector,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )

        let result = childCollector.finalizeResults(dLog: { message in
            if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage(message, applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
            }
        })

        if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
            currentDebugLogs.append(AXorcist.formatDebugLogMessage("Final children count from Element.children: \(result?.count ?? 0)", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
        }
        return result
    }

    @MainActor
    private func collectDirectChildren(
        collector: inout ChildCollector,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) {
        if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
            currentDebugLogs.append(AXorcist.formatDebugLogMessage("collectDirectChildren: Attempting to fetch kAXChildrenAttribute directly.", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
        }

        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(self.underlyingElement, AXAttributeNames.kAXChildrenAttribute as CFString, &value)

        let selfDescForLog = (isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED) ? self.briefDescription(option: .short, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs) : "Element(json_log_on_or_debug_off)"

        if error == .success {
            if let childrenCFArray = value, CFGetTypeID(childrenCFArray) == CFArrayGetTypeID() {
                if let directChildrenUI = childrenCFArray as? [AXUIElement] {
                    if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
                        currentDebugLogs.append(AXorcist.formatDebugLogMessage("collectDirectChildren [\(selfDescForLog)]: Successfully fetched and cast \(directChildrenUI.count) direct children.", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
                    }
                    collector.addChildren(from: directChildrenUI)
                } else {
                    if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
                        currentDebugLogs.append(AXorcist.formatDebugLogMessage("collectDirectChildren [\(selfDescForLog)]: kAXChildrenAttribute was a CFArray but failed to cast to [AXUIElement]. TypeID: \(CFGetTypeID(childrenCFArray))", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
                    }
                }
            } else if let nonArrayValue = value {
                if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
                    currentDebugLogs.append(AXorcist.formatDebugLogMessage("collectDirectChildren [\(selfDescForLog)]: kAXChildrenAttribute was not a CFArray. TypeID: \(CFGetTypeID(nonArrayValue)). Value: \(String(describing: nonArrayValue))", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
                }
            } else {
                if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
                    currentDebugLogs.append(AXorcist.formatDebugLogMessage("collectDirectChildren [\(selfDescForLog)]: kAXChildrenAttribute was nil despite .success error code.", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
                }
            }
        } else if error == .noValue {
            if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage("collectDirectChildren [\(selfDescForLog)]: kAXChildrenAttribute has no value.", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
            }
        } else {
            if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage("collectDirectChildren [\(selfDescForLog)]: Error fetching kAXChildrenAttribute: \(error.rawValue)", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
            }
        }
    }

    @MainActor
    private func collectAlternativeChildren(
        collector: inout ChildCollector,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) {
        let alternativeAttributes: [String] = [
            AXAttributeNames.kAXVisibleChildrenAttribute, AXAttributeNames.kAXWebAreaChildrenAttribute, AXAttributeNames.kAXHTMLContentAttribute,
            AXAttributeNames.kAXARIADOMChildrenAttribute, AXAttributeNames.kAXDOMChildrenAttribute, AXAttributeNames.kAXApplicationNavigationAttribute,
            AXAttributeNames.kAXApplicationElementsAttribute, AXAttributeNames.kAXContentsAttribute, AXAttributeNames.kAXBodyAreaAttribute, AXAttributeNames.kAXDocumentContentAttribute,
            AXAttributeNames.kAXWebPageContentAttribute, AXAttributeNames.kAXSplitGroupContentsAttribute, AXAttributeNames.kAXLayoutAreaChildrenAttribute,
            AXAttributeNames.kAXGroupChildrenAttribute, AXAttributeNames.kAXSelectedChildrenAttribute, AXAttributeNames.kAXRowsAttribute, AXAttributeNames.kAXColumnsAttribute,
            AXAttributeNames.kAXTabsAttribute
        ]
        if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
            currentDebugLogs.append(AXorcist.formatDebugLogMessage("collectAlternativeChildren: Will iterate \(alternativeAttributes.count) alternative attributes.", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
        }

        for attrName in alternativeAttributes {
            collectChildrenFromAttribute(
                attributeName: attrName,
                collector: &collector,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &currentDebugLogs
            )
        }
    }

    @MainActor
    private func collectChildrenFromAttribute(
        attributeName: String,
        collector: inout ChildCollector,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) {
        var tempLogs: [String] = [] // attribute() method logs to this, and it respects AXORC_JSON_LOG_ENABLED internally

        // This initial log for the function call itself needs to be conditional
        if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
            currentDebugLogs.append(AXorcist.formatDebugLogMessage("collectChildrenFromAttribute: Trying '\(attributeName)'.", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
        }

        if let childrenUI: [AXUIElement] = attribute(
            Attribute<[AXUIElement]>(attributeName),
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &tempLogs // attribute() logs here conditionally
        ) {
            // Append tempLogs to currentDebugLogs *only if* they would have been logged by attribute() anyway
            if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED { currentDebugLogs.append(contentsOf: tempLogs) }

            if !childrenUI.isEmpty {
                if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
                    currentDebugLogs.append(AXorcist.formatDebugLogMessage("collectChildrenFromAttribute: Successfully fetched \(childrenUI.count) children from '\(attributeName)'.", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
                }
                collector.addChildren(from: childrenUI)
            } else {
                if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
                    currentDebugLogs.append(AXorcist.formatDebugLogMessage("collectChildrenFromAttribute: Fetched EMPTY array from '\(attributeName)'.", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
                }
            }
        } else {
            if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED { currentDebugLogs.append(contentsOf: tempLogs) }
            if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage("collectChildrenFromAttribute: Attribute '\(attributeName)' returned nil or was not [AXUIElement].", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
            }
        }
    }

    @MainActor
    private func collectApplicationWindows(
        collector: inout ChildCollector,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) {
        var tempLogsForRole: [String] = []
        let currentRole = self.role(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogsForRole)
        // Append role logs only if general debug logging is on and JSON is off
        if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED { currentDebugLogs.append(contentsOf: tempLogsForRole) }

        if currentRole == AXRoleNames.kAXApplicationRole as String {
            if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage("collectApplicationWindows: Element is AXApplication. Trying kAXWindowsAttribute.", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
            }
            var tempLogsForWindows: [String] = []
            if let windowElementsUI: [AXUIElement] = attribute(
                Attribute<[AXUIElement]>.windows,
                isDebugLoggingEnabled: isDebugLoggingEnabled,
                currentDebugLogs: &tempLogsForWindows
            ) {
                if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED { currentDebugLogs.append(contentsOf: tempLogsForWindows) }
                if !windowElementsUI.isEmpty {
                    if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
                        currentDebugLogs.append(AXorcist.formatDebugLogMessage("collectApplicationWindows: Successfully fetched \(windowElementsUI.count) windows.", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
                    }
                    collector.addChildren(from: windowElementsUI)
                } else {
                    if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
                        currentDebugLogs.append(AXorcist.formatDebugLogMessage("collectApplicationWindows: Fetched EMPTY array from kAXWindowsAttribute.", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
                    }
                }
            } else {
                if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED { currentDebugLogs.append(contentsOf: tempLogsForWindows) }
                if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
                    currentDebugLogs.append(AXorcist.formatDebugLogMessage("collectApplicationWindows: Attribute kAXWindowsAttribute returned nil.", applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
                }
            }
        }
    }

    // generatePathString() is now fully implemented in Element.swift
}

// MARK: - Child Collection Helper

private struct ChildCollector {
    private var collectedChildren: [Element] = []
    private var uniqueChildrenSet = Set<Element>()

    mutating func addChildren(from childrenUI: [AXUIElement]) {
        for childUI in childrenUI {
            let childElement = Element(childUI)
            if !uniqueChildrenSet.contains(childElement) {
                collectedChildren.append(childElement)
                uniqueChildrenSet.insert(childElement)
            }
        }
    }

    // dLog is now a closure passed in, which should itself be conditional
    func finalizeResults(dLog: (String) -> Void) -> [Element]? {
        if collectedChildren.isEmpty {
            dLog("ChildCollector.finalizeResults: No children found for element after all collection methods.")
            return nil
        } else {
            dLog("ChildCollector.finalizeResults: Found \(collectedChildren.count) unique children after all collection methods.")
            return collectedChildren
        }
    }
}
