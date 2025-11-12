// AttributeExtractors.swift - Low-level attribute extraction logic

import ApplicationServices
import Foundation

// MARK: - Internal Fetch Logic Helpers

// Approach using direct property access within a switch statement
@MainActor
func extractDirectPropertyValue(
    for attributeName: String,
    from element: Element,
    outputFormat: OutputFormat
) -> (value: Any?, handled: Bool) {
    var extractedValue: Any?
    var handled = true

    switch attributeName {
    case AXAttributeNames.kAXPathHintAttribute:
        extractedValue = element.attribute(Attribute<String>(AXAttributeNames.kAXPathHintAttribute))
    case AXAttributeNames.kAXRoleAttribute:
        extractedValue = element.role()
    case AXAttributeNames.kAXSubroleAttribute:
        extractedValue = element.subrole()
    case AXAttributeNames.kAXTitleAttribute:
        extractedValue = element.title()
    case AXAttributeNames.kAXDescriptionAttribute:
        extractedValue = element.descriptionText() // Renamed
    case AXAttributeNames.kAXEnabledAttribute:
        let val = element.isEnabled()
        extractedValue = val
        if outputFormat == .textContent {
            extractedValue = val?.description ?? AXMiscConstants.kAXNotAvailableString
        }
    case AXAttributeNames.kAXFocusedAttribute:
        let val = element.isFocused()
        extractedValue = val
        if outputFormat == .textContent {
            extractedValue = val?.description ?? AXMiscConstants.kAXNotAvailableString
        }
    case AXAttributeNames.kAXHiddenAttribute:
        let val = element.isHidden()
        extractedValue = val
        if outputFormat == .textContent {
            extractedValue = val?.description ?? AXMiscConstants.kAXNotAvailableString
        }
    case AXMiscConstants.isIgnoredAttributeKey:
        let val = element.isIgnored()
        extractedValue = val
        if outputFormat == .textContent {
            extractedValue = val ? "true" : "false"
        }
    case "PID":
        let val = element.pid()
        extractedValue = val
        if outputFormat == .textContent {
            extractedValue = val?.description ?? AXMiscConstants.kAXNotAvailableString
        }
    case AXAttributeNames.kAXElementBusyAttribute:
        let val = element.isElementBusy()
        extractedValue = val
        if outputFormat == .textContent {
            extractedValue = val?.description ?? AXMiscConstants.kAXNotAvailableString
        }
    default:
        handled = false
    }
    return (extractedValue, handled)
}

@MainActor
func determineAttributesToFetch(
    requestedAttributes: [String]?,
    forMultiDefault: Bool,
    targetRole: String?,
    element: Element
) -> [String] {
    if forMultiDefault {
        return defaultMultiAttributes(for: targetRole)
    }

    if let requested = requestedAttributes, !requested.isEmpty {
        return requested
    }

    if let names = element.attributeNames(), !names.isEmpty {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "determineAttributesToFetch: No specific attributes requested, fetched all \(names.count)"
        ))
        return names
    }

    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "determineAttributesToFetch: Falling back to defaults; unable to fetch attribute names."
    ))
    return []
}

private func defaultMultiAttributes(for role: String?) -> [String] {
    let base = [
        AXAttributeNames.kAXRoleAttribute,
        AXAttributeNames.kAXValueAttribute,
        AXAttributeNames.kAXTitleAttribute,
        AXAttributeNames.kAXIdentifierAttribute,
    ]
    guard role == AXRoleNames.kAXStaticTextRole else { return base }
    return [
        AXAttributeNames.kAXRoleAttribute,
        AXAttributeNames.kAXValueAttribute,
        AXAttributeNames.kAXIdentifierAttribute,
    ]
}

// Function to get specifically computed attributes for an element
@MainActor
func getComputedAttributes(for element: Element) async -> [String: AttributeData] {
    var computedAttrs: [String: AttributeData] = [:]

    if let name = element.computedName() {
        computedAttrs[AXMiscConstants.computedNameAttributeKey] = AttributeData(
            value: .string(name),
            source: .computed
        )
        GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message:
            "getComputedAttributes: Computed name for element " +
                "\(element.briefDescription(option: .raw)) is '\(name)'."))
    } else {
        GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message:
            "getComputedAttributes: Element \(element.briefDescription(option: .raw)) " +
                "has no computed name."))
    }

    // Placeholder for other future purely computed attributes if needed
    // For example, isClickable could also be added here if not handled elsewhere:
    // let isButton = (element.role() == AXRoleNames.kAXButtonRole)
    // let hasPressAction = element.isActionSupported(AXActionNames.kAXPressAction)
    // if isButton || hasPressAction {
    //     computedAttrs[AXMiscConstants.isClickableAttributeKey] = AttributeData(
    //         value: .bool(true), source: .computed
    //     )
    // }

    return computedAttrs
}
