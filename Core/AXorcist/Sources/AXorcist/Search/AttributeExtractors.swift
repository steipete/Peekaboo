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
    if let extractor = AttributeDirectMapping(attributeName: attributeName) {
        return extractor.extract(from: element, format: outputFormat)
    }
    return (nil, false)
}

@MainActor
func determineAttributesToFetch(
    requestedAttributes: [String]?,
    forMultiDefault: Bool,
    targetRole: String?,
    element: Element
) -> [String] {
    if forMultiDefault { return defaultMultiAttributes(for: targetRole) }

    if let requested = requestedAttributes, !requested.isEmpty {
        return requested
    }

    return fetchAllAttributeNames(from: element)
}

@MainActor
private func fetchAllAttributeNames(from element: Element) -> [String] {
    guard let names = element.attributeNames(), !names.isEmpty else {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "determineAttributesToFetch: Falling back to defaults; unable to fetch attribute names."
        ))
        return []
    }

    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "determineAttributesToFetch: No specific attributes requested, fetched all \(names.count)"
    ))
    return names
}

private func defaultMultiAttributes(for role: String?) -> [String] {
    AttributeDefaultSet(role: role).attributes
}

private struct AttributeDefaultSet {
    let role: String?

    var attributes: [String] {
        let base = [
            AXAttributeNames.kAXRoleAttribute,
            AXAttributeNames.kAXValueAttribute,
            AXAttributeNames.kAXTitleAttribute,
            AXAttributeNames.kAXIdentifierAttribute,
        ]
        guard self.role == AXRoleNames.kAXStaticTextRole else { return base }
        return [
            AXAttributeNames.kAXRoleAttribute,
            AXAttributeNames.kAXValueAttribute,
            AXAttributeNames.kAXIdentifierAttribute,
        ]
    }
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
private struct AttributeDirectMapping {
    let attributeName: String
    private let strategyProvider: ((Element, OutputFormat) -> Any?)?

    init?(attributeName: String) {
        self.attributeName = attributeName
        self.strategyProvider = AttributeDirectMapping.makeStrategy(for: attributeName)
        if self.strategyProvider == nil {
            return nil
        }
    }

    func extract(from element: Element, format: OutputFormat) -> (value: Any?, handled: Bool) {
        guard let strategy = self.strategyProvider else { return (nil, false) }
        let value = strategy(element, format)
        return (value, true)
    }

    private static func makeStrategy(for attributeName: String) -> ((Element, OutputFormat) -> Any?)? {
        switch attributeName {
        case AXAttributeNames.kAXPathHintAttribute:
            return { element, _ in element.attribute(Attribute<String>(AXAttributeNames.kAXPathHintAttribute)) }
        case AXAttributeNames.kAXRoleAttribute:
            return { element, _ in element.role() }
        case AXAttributeNames.kAXSubroleAttribute:
            return { element, _ in element.subrole() }
        case AXAttributeNames.kAXTitleAttribute:
            return { element, _ in element.title() }
        case AXAttributeNames.kAXDescriptionAttribute:
            return { element, _ in element.descriptionText() }
        case AXAttributeNames.kAXEnabledAttribute:
            return AttributeDirectMapping.booleanFormatter { $0.isEnabled() }
        case AXAttributeNames.kAXFocusedAttribute:
            return AttributeDirectMapping.booleanFormatter { $0.isFocused() }
        case AXAttributeNames.kAXHiddenAttribute:
            return AttributeDirectMapping.booleanFormatter { $0.isHidden() }
        case AXMiscConstants.isIgnoredAttributeKey:
            return { element, format in
                let value = element.isIgnored()
                return format == .textContent ? (value ? "true" : "false") : value
            }
        case "PID":
            return AttributeDirectMapping.numericFormatter { element in
                guard let pid = element.pid() else { return nil }
                return Int(pid)
            }
        case AXAttributeNames.kAXElementBusyAttribute:
            return AttributeDirectMapping.booleanFormatter { $0.isElementBusy() }
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
        _ extractor: @escaping (Element) -> Int?
    ) -> ((Element, OutputFormat) -> Any?) {
        { element, format in
            guard let value = extractor(element) else { return nil }
            return format == .textContent ? value.description : value
        }
    }
}
