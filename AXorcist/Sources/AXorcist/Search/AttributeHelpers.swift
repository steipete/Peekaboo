// AttributeHelpers.swift - Contains functions for fetching and formatting element attributes

import ApplicationServices // For AXUIElement related types
import CoreGraphics // For potential future use with geometry types from attributes
import Foundation

// Note: This file assumes Models (for ElementAttributes, AnyCodable),
// Logging (for debug), AccessibilityConstants, and Utils (for axValue) are available in the same module.
// And now Element for the new element wrapper.

// Define AttributeData and AttributeSource here as they are not found by the compiler
public enum AttributeSource: String, Codable {
    case direct // Directly from an AXAttribute
    case computed // Derived by this tool
}

public struct AttributeData: Codable {
    public let value: AnyCodable
    public let source: AttributeSource
}

// MARK: - Element Summary Helpers

// Removed getSingleElementSummary as it was unused.

// MARK: - Internal Fetch Logic Helpers

// Approach using direct property access within a switch statement
@MainActor
private func extractDirectPropertyValue(for attributeName: String, from element: Element, outputFormat: OutputFormat, isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> (value: Any?, handled: Bool) {
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
    var tempLogs: [String] = [] // For Element method calls
    var extractedValue: Any?
    var handled = true

    // Ensure logging parameters are passed to Element methods
    switch attributeName {
    case AXAttributeNames.kAXPathHintAttribute:
        extractedValue = element.attribute(Attribute<String>(AXAttributeNames.kAXPathHintAttribute), isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
    case AXAttributeNames.kAXRoleAttribute:
        extractedValue = element.role(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
    case AXAttributeNames.kAXSubroleAttribute:
        extractedValue = element.subrole(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
    case AXAttributeNames.kAXTitleAttribute:
        extractedValue = element.title(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
    case AXAttributeNames.kAXDescriptionAttribute:
        extractedValue = element.description(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
    case AXAttributeNames.kAXEnabledAttribute:
        let val = element.isEnabled(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
        extractedValue = val
        if outputFormat == .text_content { extractedValue = val?.description ?? AXMiscConstants.kAXNotAvailableString }
    case AXAttributeNames.kAXFocusedAttribute:
        let val = element.isFocused(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
        extractedValue = val
        if outputFormat == .text_content { extractedValue = val?.description ?? AXMiscConstants.kAXNotAvailableString }
    case AXAttributeNames.kAXHiddenAttribute:
        let val = element.isHidden(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
        extractedValue = val
        if outputFormat == .text_content { extractedValue = val?.description ?? AXMiscConstants.kAXNotAvailableString }
    case AXMiscConstants.isIgnoredAttributeKey:
        let val = element.isIgnored(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
        extractedValue = val
        if outputFormat == .text_content { extractedValue = val ? "true" : "false" }
    case "PID":
        let val = element.pid(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
        extractedValue = val
        if outputFormat == .text_content { extractedValue = val?.description ?? AXMiscConstants.kAXNotAvailableString }
    case AXAttributeNames.kAXElementBusyAttribute:
        let val = element.isElementBusy(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
        extractedValue = val
        if outputFormat == .text_content { extractedValue = val?.description ?? AXMiscConstants.kAXNotAvailableString }
    default:
        handled = false
    }
    currentDebugLogs.append(contentsOf: tempLogs) // Collect logs from Element method calls
    return (extractedValue, handled)
}

@MainActor
private func determineAttributesToFetch(requestedAttributes: [String], forMultiDefault: Bool, targetRole: String?, element: Element, isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> [String] {
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
    var attributesToFetch = requestedAttributes
    if forMultiDefault {
        attributesToFetch = [AXAttributeNames.kAXRoleAttribute, AXAttributeNames.kAXValueAttribute, AXAttributeNames.kAXTitleAttribute, AXAttributeNames.kAXIdentifierAttribute]
        if let role = targetRole, role == AXRoleNames.kAXStaticTextRole {
            attributesToFetch = [AXAttributeNames.kAXRoleAttribute, AXAttributeNames.kAXValueAttribute, AXAttributeNames.kAXIdentifierAttribute]
        }
    } else if attributesToFetch.isEmpty {
        var attrNames: CFArray?
        if AXUIElementCopyAttributeNames(element.underlyingElement, &attrNames) == .success, let names = attrNames as? [String] {
            attributesToFetch.append(contentsOf: names)
            dLog("determineAttributesToFetch: No specific attributes requested, fetched all \(names.count) available: \(names.joined(separator: ", "))")
        } else {
            dLog("determineAttributesToFetch: No specific attributes requested and failed to fetch all available names.")
        }
    }
    return attributesToFetch
}

// MARK: - Public Attribute Getters

@MainActor
public func getElementAttributes(_ element: Element, requestedAttributes: [String], forMultiDefault: Bool = false, targetRole: String? = nil, outputFormat: OutputFormat = .smart, isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> ElementAttributes {
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
    var tempLogs: [String] = [] // For Element method calls, cleared and appended for each.
    var result = ElementAttributes()
    let valueFormatOption: ValueFormatOption = (outputFormat == .verbose) ? .verbose : .default

    tempLogs.removeAll()
    dLog("getElementAttributes starting for element: \(element.briefDescription(option: valueFormatOption, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)), format: \(outputFormat)")
    currentDebugLogs.append(contentsOf: tempLogs)

    let attributesToFetch = determineAttributesToFetch(requestedAttributes: requestedAttributes, forMultiDefault: forMultiDefault, targetRole: targetRole, element: element, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs)
    dLog("Attributes to fetch: \(attributesToFetch.joined(separator: ", "))")

    for attr in attributesToFetch {
        var tempCallLogs: [String] = [] // Logs for a specific attribute fetching call
        if attr == AXAttributeNames.kAXParentAttribute {
            tempCallLogs.removeAll()
            let parent = element.parent(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempCallLogs)
            result[AXAttributeNames.kAXParentAttribute] = formatParentAttribute(parent, outputFormat: outputFormat, valueFormatOption: valueFormatOption, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempCallLogs) // formatParentAttribute will manage its own logs now
            currentDebugLogs.append(contentsOf: tempCallLogs) // Collect logs from element.parent and formatParentAttribute
            continue
        } else if attr == AXAttributeNames.kAXChildrenAttribute {
            tempCallLogs.removeAll()
            let children = element.children(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempCallLogs)
            result[attr] = formatChildrenAttribute(children, outputFormat: outputFormat, valueFormatOption: valueFormatOption, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempCallLogs) // Directly assign AnyCodable
            currentDebugLogs.append(contentsOf: tempCallLogs)
            continue
        } else if attr == AXAttributeNames.kAXFocusedUIElementAttribute {
            tempCallLogs.removeAll()
            let focused = element.focusedElement(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempCallLogs)
            result[attr] = formatFocusedUIElementAttribute(focused, outputFormat: outputFormat, valueFormatOption: valueFormatOption, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempCallLogs) // Directly assign AnyCodable
            currentDebugLogs.append(contentsOf: tempCallLogs)
            continue
        }

        tempCallLogs.removeAll()
        let (directValue, wasHandledDirectly) = extractDirectPropertyValue(for: attr, from: element, outputFormat: outputFormat, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempCallLogs)
        currentDebugLogs.append(contentsOf: tempCallLogs)
        var finalValueToStore: Any?

        if wasHandledDirectly {
            finalValueToStore = directValue
        } else {
            tempCallLogs.removeAll()
            let rawCFValue: CFTypeRef? = element.rawAttributeValue(named: attr, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempCallLogs)
            currentDebugLogs.append(contentsOf: tempCallLogs)
            if outputFormat == .text_content {
                finalValueToStore = formatRawCFValueForTextContent(rawCFValue)
            } else {
                finalValueToStore = formatCFTypeRef(rawCFValue, option: valueFormatOption, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs)
            }
        }

        if outputFormat == .smart {
            if let strVal = finalValueToStore as? String,
               strVal.isEmpty || strVal == "<nil>" || strVal == "AXValue (Illegal)" || strVal.contains("Unknown CFType") || strVal == AXMiscConstants.kAXNotAvailableString {
                continue
            }
        }
        result[attr] = AnyCodable(finalValueToStore)
    }

    tempLogs.removeAll()
    if result[AXMiscConstants.computedNameAttributeKey] == nil {
        if let name = element.computedName(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) {
            result[AXMiscConstants.computedNameAttributeKey] = AnyCodable(name)
        }
    }
    currentDebugLogs.append(contentsOf: tempLogs)

    tempLogs.removeAll()
    if result[AXMiscConstants.isClickableAttributeKey] == nil {
        let isButton = (element.role(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) == AXRoleNames.kAXButtonRole)
        let hasPressAction = element.isActionSupported(AXActionNames.kAXPressAction, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
        if isButton || hasPressAction {
            result[AXMiscConstants.isClickableAttributeKey] = AnyCodable(true)
        }
    }
    currentDebugLogs.append(contentsOf: tempLogs)

    tempLogs.removeAll()
    if outputFormat == .verbose && result[AXMiscConstants.computedPathAttributeKey] == nil {
        let path = element.generatePathString(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
        result[AXMiscConstants.computedPathAttributeKey] = AnyCodable(path)
    }
    currentDebugLogs.append(contentsOf: tempLogs)

    populateActionNamesAttribute(for: element, result: &result, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs)

    return result
}

@MainActor
private func populateActionNamesAttribute(for element: Element, result: inout ElementAttributes, isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) {
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
    var tempLogs: [String] = [] // For Element method calls
    if result[AXAttributeNames.kAXActionNamesAttribute] != nil {
        return
    }
    currentDebugLogs.append(contentsOf: tempLogs) // Appending potentially empty tempLogs, for consistency, though it does nothing here.

    var actionsToStore: [String]?
    tempLogs.removeAll()
    if let currentActions = element.supportedActions(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs), !currentActions.isEmpty {
        actionsToStore = currentActions
    } else {
        tempLogs.removeAll() // Clear before next call that uses it
        if let fallbackActions: [String] = element.attribute(Attribute<[String]>(AXAttributeNames.kAXActionsAttribute), isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs), !fallbackActions.isEmpty {
            actionsToStore = fallbackActions
        }
    }
    currentDebugLogs.append(contentsOf: tempLogs)

    tempLogs.removeAll()
    let pressActionSupported = element.isActionSupported(AXActionNames.kAXPressAction, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
    currentDebugLogs.append(contentsOf: tempLogs)
    if pressActionSupported {
        if actionsToStore == nil { actionsToStore = [AXActionNames.kAXPressAction] } else if !actionsToStore!.contains(AXActionNames.kAXPressAction) { actionsToStore!.append(AXActionNames.kAXPressAction) }
    }

    if let finalActions = actionsToStore, !finalActions.isEmpty {
        result[AXAttributeNames.kAXActionNamesAttribute] = AnyCodable(finalActions)
    } else {
        tempLogs.removeAll()
        let primaryNil = element.supportedActions(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) == nil
        currentDebugLogs.append(contentsOf: tempLogs)
        tempLogs.removeAll()
        let fallbackNil = element.attribute(Attribute<[String]>(AXAttributeNames.kAXActionsAttribute), isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) == nil
        currentDebugLogs.append(contentsOf: tempLogs)
        if primaryNil && fallbackNil && !pressActionSupported {
            result[AXAttributeNames.kAXActionNamesAttribute] = AnyCodable(AXMiscConstants.kAXNotAvailableString)
        } else {
            result[AXAttributeNames.kAXActionNamesAttribute] = AnyCodable("\(AXMiscConstants.kAXNotAvailableString) (no specific actions found or list empty)")
        }
    }
}

/// Encodes the given ElementAttributes dictionary into a new dictionary containing
/// a single key "json_representation" with the JSON string as its value.
/// If encoding fails, returns a dictionary with an error message.
@MainActor
public func encodeAttributesToJSONStringRepresentation(_ attributes: ElementAttributes) -> ElementAttributes {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted // Or .sortedKeys for deterministic output if needed
    do {
        let jsonData = try encoder.encode(attributes) // attributes is [String: AnyCodable]
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            return ["json_representation": AnyCodable(jsonString)]
        } else {
            return ["error": AnyCodable("Failed to convert encoded JSON data to string")]
        }
    } catch {
        return ["error": AnyCodable("Failed to encode attributes to JSON: \(error.localizedDescription)")]
    }
}

// MARK: - Computed Attributes

// New helper function to get only computed/heuristic attributes for matching
@MainActor
public func getComputedAttributes(for element: Element, isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> ElementAttributes {
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
    var tempLogs: [String] = [] // For Element method calls
    var attributes: ElementAttributes = [:]

    tempLogs.removeAll()
    currentDebugLogs.append(contentsOf: tempLogs)

    tempLogs.removeAll()
    if let name = element.computedName(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) {
        attributes[AXMiscConstants.computedNameAttributeKey] = AnyCodable(AttributeData(value: AnyCodable(name), source: .computed))
    }
    currentDebugLogs.append(contentsOf: tempLogs)

    tempLogs.removeAll()
    let isButton = (element.role(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) == AXRoleNames.kAXButtonRole)
    currentDebugLogs.append(contentsOf: tempLogs) // Collect logs from role call
    tempLogs.removeAll()
    let hasPressAction = element.isActionSupported(AXActionNames.kAXPressAction, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs)
    currentDebugLogs.append(contentsOf: tempLogs) // Collect logs from isActionSupported call

    if isButton || hasPressAction {
        attributes[AXMiscConstants.isClickableAttributeKey] = AnyCodable(AttributeData(value: AnyCodable(true), source: .computed))
    }

    // Ensure other computed attributes like ComputedPath also use methods with logging if they exist.
    // For now, this focuses on the direct errors.

    return attributes
}

// MARK: - Attribute Formatting Helpers (Additional)

// Formatting functions have been moved to AttributeFormatter.swift
// This includes: formatParentAttribute, formatChildrenAttribute, formatFocusedUIElementAttribute, formatRawCFValueForTextContent
