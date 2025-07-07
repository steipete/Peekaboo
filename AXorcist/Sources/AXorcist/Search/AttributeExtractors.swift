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
    var attributesToFetch = requestedAttributes ?? []
    if forMultiDefault {
        attributesToFetch = [
            AXAttributeNames.kAXRoleAttribute,
            AXAttributeNames.kAXValueAttribute,
            AXAttributeNames.kAXTitleAttribute,
            AXAttributeNames.kAXIdentifierAttribute,
        ]
        if let role = targetRole, role == AXRoleNames.kAXStaticTextRole {
            attributesToFetch = [
                AXAttributeNames.kAXRoleAttribute,
                AXAttributeNames.kAXValueAttribute,
                AXAttributeNames.kAXIdentifierAttribute,
            ]
        }
    } else if attributesToFetch.isEmpty {
        if requestedAttributes == nil || requestedAttributes!.isEmpty {
            // If no specific attributes are requested, decide what to do based on context
            // This part of the logic for deciding what to fetch if nothing specific is requested
            // has been simplified or might be intended to be expanded.
            // For now, if forMultiDefault is true, it implies fetching a default set (e.g., for multi-element views)
            // otherwise, it might fetch all or a basic set.
            // This example assumes if not forMultiDefault, and no specifics, it fetches all available.
            if !forMultiDefault {
                // Example: Fetch all attribute names if none are specified and not for a multi-default scenario
                if let names = element.attributeNames() {
                    attributesToFetch.append(contentsOf: names)
                    GlobalAXLogger.shared.log(AXLogEntry(
                        level: .debug,
                        message: "determineAttributesToFetch: No specific attributes requested, " +
                            "fetched all \(names.count) available: \(names.joined(separator: ", "))"
                    ))
                } else {
                    GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message:
                        "determineAttributesToFetch: No specific attributes requested and " +
                            "failed to fetch all available names."))
                }
            } else {
                // For multi-default, or if the above block doesn't execute,
                // it might rely on a predefined default set or do nothing further here,
                // letting subsequent logic handle AXorcist.defaultAttributesToFetch if attributesToFetch remains empty.
                GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message:
                    "determineAttributesToFetch: No specific attributes requested. Using defaults or context-specific set."))
            }
        }
    }
    return attributesToFetch
}

// Function to get specifically computed attributes for an element
@MainActor
func getComputedAttributes(for element: Element) async -> [String: AttributeData] {
    var computedAttrs: [String: AttributeData] = [:]

    if let name = element.computedName() {
        computedAttrs[AXMiscConstants.computedNameAttributeKey] = AttributeData(
            value: AnyCodable(name),
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
    //         value: AnyCodable(true), source: .computed
    //     )
    // }

    return computedAttrs
}
