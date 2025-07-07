// AttributeFormatter.swift - Contains functions for formatting element attributes for display

import ApplicationServices
import Foundation

// Note: This file assumes Element, ValueFormatOption, and AXMiscConstants.kAXNotAvailableString are available.
// formatAXValue is assumed to be available from elsewhere (e.g., ValueFormatter.swift)

// Helper function to format the parent attribute
@MainActor
internal func formatParentAttribute(_ parent: Element?, outputFormat: OutputFormat, valueFormatOption: ValueFormatOption, isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> AnyCodable {
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
    var tempLogs: [String] = [] // For Element method calls
    guard let parentElement = parent else { return AnyCodable(nil as String?) }
    if outputFormat == .text_content {
        return AnyCodable("Element: \(parentElement.role(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) ?? "?Role")")
    } else {
        return AnyCodable(parentElement.briefDescription(option: valueFormatOption, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs))
    }
}

// Helper function to format the children attribute
@MainActor
internal func formatChildrenAttribute(_ children: [Element]?, outputFormat: OutputFormat, valueFormatOption: ValueFormatOption, isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> AnyCodable {
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
    var tempLogs: [String] = [] // For Element method calls
    guard let actualChildren = children, !actualChildren.isEmpty else { return AnyCodable("[]") }
    if outputFormat == .text_content {
        return AnyCodable("Array of \(actualChildren.count) Element(s)")
    } else if outputFormat == .verbose {
        var childrenSummaries: [String] = []
        for childElement in actualChildren {
            childrenSummaries.append(childElement.briefDescription(option: valueFormatOption, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs))
        }
        return AnyCodable("[\(childrenSummaries.joined(separator: ", "))]")
    } else { // .smart output
        return AnyCodable("Array of \(actualChildren.count) children")
    }
}

// Helper function to format the focused UI element attribute
@MainActor
internal func formatFocusedUIElementAttribute(_ focusedElement: Element?, outputFormat: OutputFormat, valueFormatOption: ValueFormatOption, isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> AnyCodable {
    func dLog(_ message: String) { if isDebugLoggingEnabled { currentDebugLogs.append(message) } }
    var tempLogs: [String] = [] // For Element method calls
    guard let actualFocusedElement = focusedElement else { return AnyCodable(nil as String?) }
    if outputFormat == .text_content {
        return AnyCodable("Element: \(actualFocusedElement.role(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs) ?? "?Role")")
    } else {
        return AnyCodable(actualFocusedElement.briefDescription(option: valueFormatOption, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &tempLogs))
    }
}

// Helper function to format a raw CFTypeRef for .text_content output
@MainActor
internal func formatRawCFValueForTextContent(_ rawValue: CFTypeRef?) -> String {
    guard let value = rawValue else { return AXMiscConstants.kAXNotAvailableString } // AXMiscConstants.kAXNotAvailableString needs to be defined
    let typeID = CFGetTypeID(value)
    if typeID == CFStringGetTypeID() { return (value as! String) } else if typeID == CFAttributedStringGetTypeID() { return (value as! NSAttributedString).string } else if typeID == AXValueGetTypeID() {
        let axVal = value as! AXValue
        // Assuming formatAXValue is globally available or accessible.
        // If it's in a specific file like ValueFormatter.swift, direct call might need qualification
        // or this function might need to be part of that file/extension.
        // For now, assume it's callable like this.
        return formatAXValue(axVal, option: .default) // Assumes formatAXValue returns String and ValueFormatOption.default is valid here
    } else if typeID == CFNumberGetTypeID() { return (value as! NSNumber).stringValue } else if typeID == CFBooleanGetTypeID() { return CFBooleanGetValue((value as! CFBoolean)) ? "true" : "false" } else { return "<\(CFCopyTypeIDDescription(typeID) as String? ?? "ComplexType")>" }
}
