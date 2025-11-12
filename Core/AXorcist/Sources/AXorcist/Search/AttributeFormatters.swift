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
) async -> AttributeValue? {
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
        return AttributeValue(from: extractedValue)
    }

    // Fallback to raw attribute value
    return await extractRawAttribute(element: element, attributeName: attributeName, outputFormat: outputFormat)
}

@MainActor
private func extractKnownAttribute(element: Element, attributeName: String, outputFormat: OutputFormat) async -> Any? {
    AttributeFormatterMapping(attributeName: attributeName)
        .extract(from: element, format: outputFormat)
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
private func extractRawAttribute(
    element: Element,
    attributeName: String,
    outputFormat: OutputFormat
) async -> AttributeValue? {
    let rawCFValue = element.rawAttributeValue(named: attributeName)

    if outputFormat == .textContent {
        let formatted = await formatRawCFValueForTextContent(rawCFValue)
        return .string(formatted)
    }

    guard let unwrapped = ValueUnwrapper.unwrap(rawCFValue) else {
        // Only log if rawCFValue was not nil initially
        if rawCFValue != nil {
            let cfTypeID = String(describing: CFGetTypeID(rawCFValue!))
            GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message:
                "extractAndFormatAttribute: '\(attributeName)' was non-nil CFTypeRef " +
                    "but unwrapped to nil. CFTypeID: \(cfTypeID)"))
            return .string("<Raw CFTypeRef: \(cfTypeID)>")
        }
        return nil
    }

    return AttributeValue(from: unwrapped)
}

@MainActor
func formatParentAttribute(
    _ parent: Element?,
    outputFormat: OutputFormat,
    valueFormatOption _: ValueFormatOption
) async -> AttributeValue {
    guard let parentElement = parent else { return .null }
    if outputFormat == .textContent {
        return .string("Element: \(parentElement.role() ?? "?Role")")
    } else {
        return .string(parentElement.briefDescription(option: .raw))
    }
}

@MainActor
func formatChildrenAttribute(
    _ children: [Element]?,
    outputFormat: OutputFormat,
    valueFormatOption _: ValueFormatOption
) async -> AttributeValue {
    guard let actualChildren = children, !actualChildren.isEmpty else {
        return .null
    }
    if outputFormat == .textContent {
        var childrenSummaries: [String] = []
        for childElement in actualChildren {
            childrenSummaries.append(childElement.briefDescription(option: .raw))
        }
        return .string("[\(childrenSummaries.joined(separator: ", "))]")
    } else {
        let childrenDescriptions = actualChildren.map { $0.briefDescription(option: .raw) }
        return .array(childrenDescriptions.map { .string($0) })
    }
}

@MainActor
func formatFocusedUIElementAttribute(
    _ focusedElement: Element?,
    outputFormat: OutputFormat,
    valueFormatOption _: ValueFormatOption
) async -> AttributeValue {
    guard let element = focusedElement else { return .null }
    if outputFormat == .textContent {
        return .string("Focused: \(element.role() ?? "?Role") - \(element.title() ?? "?Title")")
    } else {
        return .string(element.briefDescription(option: .raw))
    }
}
private struct AttributeFormatterMapping {
    let attributeName: String

    func extract(from element: Element, format: OutputFormat) -> Any? {
        guard let strategy = self.strategy else { return nil }
        return strategy(element, format)
    }

    private var strategy: ((Element, OutputFormat) -> Any?)? {
        switch self.attributeName {
        case AXAttributeNames.kAXPathHintAttribute:
            return { element, _ in
                element.attribute(Attribute<String>(AXAttributeNames.kAXPathHintAttribute))
            }
        case AXAttributeNames.kAXRoleAttribute:
            return { element, _ in element.role() }
        case AXAttributeNames.kAXSubroleAttribute:
            return { element, _ in element.subrole() }
        case AXAttributeNames.kAXTitleAttribute:
            return { element, _ in element.title() }
        case AXAttributeNames.kAXDescriptionAttribute:
            return { element, _ in element.descriptionText() }
        case AXAttributeNames.kAXEnabledAttribute:
            return AttributeFormatterMapping.booleanFormatter { $0.isEnabled() }
        case AXAttributeNames.kAXFocusedAttribute:
            return AttributeFormatterMapping.booleanFormatter { $0.isFocused() }
        case AXAttributeNames.kAXHiddenAttribute:
            return AttributeFormatterMapping.booleanFormatter { $0.isHidden() }
        case AXMiscConstants.isIgnoredAttributeKey:
            return { element, format in
                let value = element.isIgnored()
                return format == .textContent ? (value ? "true" : "false") : value
            }
        case "PID":
            return AttributeFormatterMapping.numericFormatter { $0.pid() }
        case AXAttributeNames.kAXElementBusyAttribute:
            return AttributeFormatterMapping.booleanFormatter { $0.isElementBusy() }
        default:
            return nil
        }
    }

    private static func booleanFormatter(
        _ extractor: @escaping (Element) -> Bool?
    ) -> ((Element, OutputFormat) -> Any?) {
        { element, format in
            guard let value = extractor(element) else { return nil }
            return format == .textContent ? value.description : value
        }
    }

    private static func numericFormatter(
        _ extractor: @escaping (Element) -> Int32?
    ) -> ((Element, OutputFormat) -> Any?) {
        { element, format in
            guard let value = extractor(element) else { return nil }
            return format == .textContent ? value.description : value
        }
    }
}
