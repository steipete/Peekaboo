// AttributeFormatters.swift - Attribute formatting logic

import ApplicationServices
import CoreGraphics
import Foundation

// Helper for formatting raw CFTypeRef values for .textContent output
@MainActor
func formatRawCFValueForTextContent(_ rawValue: CFTypeRef?) async -> String {
    guard let value = rawValue else { return AXMiscConstants.kAXNotAvailableString }
    let typeID = CFGetTypeID(value)
    if typeID == CFStringGetTypeID() {
        return (value as! String)
    } else if typeID == CFAttributedStringGetTypeID() {
        return (value as! NSAttributedString).string
    } else if typeID == AXValueGetTypeID() {
        let axVal = value as! AXValue
        return formatAXValue(axVal, option: ValueFormatOption.smart)
    } else if typeID == CFNumberGetTypeID() {
        return (value as! NSNumber).stringValue
    } else if typeID == CFBooleanGetTypeID() {
        return CFBooleanGetValue((value as! CFBoolean)) ? "true" : "false"
    } else {
        let typeDesc = CFCopyTypeIDDescription(typeID) as String? ?? "ComplexType"
        GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message:
            "formatRawCFValueForTextContent: Encountered unhandled CFTypeID \(typeID) - " +
                "\(typeDesc). Returning placeholder."))
        return "<\(typeDesc)>"
    }
}

@MainActor
func extractAndFormatAttribute(
    element: Element,
    attributeName: String,
    outputFormat: OutputFormat,
    valueFormatOption _: ValueFormatOption
) async -> AnyCodable? {
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "extractAndFormatAttribute: '\(attributeName)' for element \(element.briefDescription(option: .raw))"
    ))

    // Try to extract using known attribute handlers first
    if let extractedValue = await extractKnownAttribute(
        element: element,
        attributeName: attributeName,
        outputFormat: outputFormat
    ) {
        return AnyCodable(extractedValue)
    }

    // Fallback to raw attribute value
    return await extractRawAttribute(element: element, attributeName: attributeName, outputFormat: outputFormat)
}

@MainActor
private func extractKnownAttribute(element: Element, attributeName: String, outputFormat: OutputFormat) async -> Any? {
    switch attributeName {
    case AXAttributeNames.kAXPathHintAttribute:
        return element.attribute(Attribute<String>(AXAttributeNames.kAXPathHintAttribute))
    case AXAttributeNames.kAXRoleAttribute:
        return element.role()
    case AXAttributeNames.kAXSubroleAttribute:
        return element.subrole()
    case AXAttributeNames.kAXTitleAttribute:
        return element.title()
    case AXAttributeNames.kAXDescriptionAttribute:
        return element.descriptionText()
    case AXAttributeNames.kAXEnabledAttribute:
        return formatBooleanAttribute(element.isEnabled(), outputFormat: outputFormat)
    case AXAttributeNames.kAXFocusedAttribute:
        return formatBooleanAttribute(element.isFocused(), outputFormat: outputFormat)
    case AXAttributeNames.kAXHiddenAttribute:
        return formatBooleanAttribute(element.isHidden(), outputFormat: outputFormat)
    case AXMiscConstants.isIgnoredAttributeKey:
        let val = element.isIgnored()
        return outputFormat == .textContent ? (val ? "true" : "false") : val
    case "PID":
        return formatOptionalIntAttribute(element.pid(), outputFormat: outputFormat)
    case AXAttributeNames.kAXElementBusyAttribute:
        return formatBooleanAttribute(element.isElementBusy(), outputFormat: outputFormat)
    default:
        return nil
    }
}

@MainActor
private func formatBooleanAttribute(_ value: Bool?, outputFormat: OutputFormat) -> Any? {
    guard let val = value else { return nil }
    return outputFormat == .textContent ? val.description : val
}

@MainActor
private func formatOptionalIntAttribute(_ value: Int32?, outputFormat: OutputFormat) -> Any? {
    guard let val = value else { return nil }
    return outputFormat == .textContent ? val.description : val
}

@MainActor
private func extractRawAttribute(element: Element, attributeName: String,
                                 outputFormat: OutputFormat) async -> AnyCodable?
{
    let rawCFValue = element.rawAttributeValue(named: attributeName)

    if outputFormat == .textContent {
        let formatted = await formatRawCFValueForTextContent(rawCFValue)
        return AnyCodable(formatted)
    }

    guard let unwrapped = ValueUnwrapper.unwrap(rawCFValue) else {
        // Only log if rawCFValue was not nil initially
        if rawCFValue != nil {
            let cfTypeID = String(describing: CFGetTypeID(rawCFValue!))
            GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message:
                "extractAndFormatAttribute: '\(attributeName)' was non-nil CFTypeRef " +
                    "but unwrapped to nil. CFTypeID: \(cfTypeID)"))
            return AnyCodable("<Raw CFTypeRef: \(cfTypeID)>")
        }
        return nil
    }

    return AnyCodable(unwrapped)
}

@MainActor
func formatParentAttribute(
    _ parent: Element?,
    outputFormat: OutputFormat,
    valueFormatOption _: ValueFormatOption
) async -> AnyCodable {
    guard let parentElement = parent else { return AnyCodable(nil as String?) }
    if outputFormat == .textContent {
        return AnyCodable("Element: \(parentElement.role() ?? "?Role")")
    } else {
        return AnyCodable(parentElement.briefDescription(option: .raw))
    }
}

@MainActor
func formatChildrenAttribute(
    _ children: [Element]?,
    outputFormat: OutputFormat,
    valueFormatOption _: ValueFormatOption
) async -> AnyCodable {
    guard let actualChildren = children, !actualChildren.isEmpty else {
        return AnyCodable(nil as String?)
    }
    if outputFormat == .textContent {
        var childrenSummaries: [String] = []
        for childElement in actualChildren {
            childrenSummaries.append(childElement.briefDescription(option: .raw))
        }
        return AnyCodable("[\(childrenSummaries.joined(separator: ", "))]")
    } else {
        let childrenDescriptions = actualChildren.map { $0.briefDescription(option: .raw) }
        return AnyCodable(childrenDescriptions)
    }
}

@MainActor
func formatFocusedUIElementAttribute(
    _ focusedElement: Element?,
    outputFormat: OutputFormat,
    valueFormatOption _: ValueFormatOption
) async -> AnyCodable {
    guard let element = focusedElement else { return AnyCodable(nil as String?) }
    if outputFormat == .textContent {
        return AnyCodable("Focused: \(element.role() ?? "?Role") - \(element.title() ?? "?Title")")
    } else {
        return AnyCodable(element.briefDescription(option: .raw))
    }
}
