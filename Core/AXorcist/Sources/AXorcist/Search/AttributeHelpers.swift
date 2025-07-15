// AttributeHelpers.swift - Main public API for attribute fetching and formatting

import ApplicationServices
import CoreGraphics
import Foundation

// MARK: - Public Attribute Getters

@MainActor
public func getElementAttributes(
    element: Element,
    attributes attrNames: [String],
    outputFormat: OutputFormat,
    valueFormatOption: ValueFormatOption = .smart
) async -> ([String: AnyCodable], [AXLogEntry]) {
    var result: [String: AnyCodable] = [:]

    let requestingStr = attrNames.isEmpty ? "all" : attrNames.joined(separator: ", ")
    GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message:
        "getElementAttributes called for element: \(element.briefDescription(option: .raw)), " +
            "requesting: \(requestingStr)"))

    let attributesToProcess = attrNames.isEmpty ? (element.attributeNames() ?? []) : attrNames

    for attr in attributesToProcess {
        if attr == AXAttributeNames.kAXParentAttribute {
            let parent = element.parent()
            result[AXAttributeNames.kAXParentAttribute] = await formatParentAttribute(
                parent,
                outputFormat: outputFormat,
                valueFormatOption: valueFormatOption
            )
        } else if attr == AXAttributeNames.kAXChildrenAttribute {
            let children = element.children()
            result[attr] = await formatChildrenAttribute(
                children,
                outputFormat: outputFormat,
                valueFormatOption: valueFormatOption
            )
        } else if attr == AXAttributeNames.kAXFocusedUIElementAttribute {
            let focused = element.focusedUIElement()
            result[attr] = await formatFocusedUIElementAttribute(
                focused,
                outputFormat: outputFormat,
                valueFormatOption: valueFormatOption
            )
        } else {
            result[attr] = await extractAndFormatAttribute(
                element: element,
                attributeName: attr,
                outputFormat: outputFormat,
                valueFormatOption: valueFormatOption
            )
        }
    }

    if outputFormat == .verbose, result[AXMiscConstants.computedPathAttributeKey] == nil {
        let path = element.generatePathString()
        result[AXMiscConstants.computedPathAttributeKey] = AnyCodable(path)
    }

    GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message:
        "getElementAttributes finished for element: \(element.briefDescription(option: .raw)). " +
            "Returning \(result.count) attributes."))
    return (result, [])
}

@MainActor
public func getAllElementDataForAXpector(
    for element: Element,
    outputFormat _: OutputFormat = .jsonString, // Typically .jsonString for AXpector
    valueFormatOption _: ValueFormatOption = .smart
) async -> ([String: AnyCodable], ElementDetails) {
    var attributes: [String: AnyCodable] = [:]
    var elementDetails = ElementDetails()

    let allAttributeNames = element.attributeNames() ?? []
    GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message:
        "getAllElementDataForAXpector: Fetching \(allAttributeNames.count) attributes for " +
            "\(element.briefDescription(option: .raw))."))

    for attrName in allAttributeNames {
        if attrName == AXAttributeNames.kAXChildrenAttribute || attrName == AXAttributeNames.kAXParentAttribute {
            continue
        }
        if AXAttributeNames.parameterizedAttributes.contains(attrName) {
            continue
        }

        let rawCFValue = element.rawAttributeValue(named: attrName)
        let swiftValue = rawCFValue.flatMap { ValueUnwrapper.unwrap($0) }
        attributes[attrName] = AnyCodable(swiftValue)
    }

    elementDetails.title = element.title()
    elementDetails.role = element.role()
    elementDetails.roleDescription = element.roleDescription()
    elementDetails.value = attributes[AXAttributeNames.kAXValueAttribute]?.value
    elementDetails.help = attributes[AXAttributeNames.kAXHelpAttribute]?.value
    elementDetails.isIgnored = element.isIgnored()

    var actionsToStore: [String]?
    if let currentActions = element.supportedActions(), !currentActions.isEmpty {
        actionsToStore = currentActions
    } else {
        if let fallbackActions: [String] = element.attribute(
            Attribute<[String]>(AXAttributeNames.kAXActionsAttribute)
        ), !fallbackActions.isEmpty {
            actionsToStore = fallbackActions
        }
    }
    elementDetails.actions = actionsToStore

    let pressActionSupported = element.isActionSupported(AXActionNames.kAXPressAction)
    let hasPressAction = elementDetails.actions?.contains(AXActionNames.kAXPressAction) ?? false
    elementDetails.isClickable = hasPressAction || pressActionSupported

    if let name = element.computedName() {
        let attributeData = AttributeData(value: AnyCodable(name), source: .computed)
        attributes[AXMiscConstants.computedNameAttributeKey] = AnyCodable(attributeData)
    }
    elementDetails.computedName = element.computedName()
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "getAllElementDataForAXpector: Finished processing for \(element.briefDescription(option: .raw))."
    ))
    return (attributes, elementDetails)
}

@MainActor
public func getElementFullDescription(
    element: Element,
    valueFormatOption: ValueFormatOption = .smart,
    includeActions: Bool = true,
    includeStoredAttributes: Bool = true,
    knownAttributes _: [String: AttributeData]? = nil
) async -> ([String: AnyCodable], [AXLogEntry]) {
    var attributes: [String: AnyCodable] = [:]
    GlobalAXLogger.shared.log(AXLogEntry(
        level: .debug,
        message: "getElementFullDescription called for element: \(element.briefDescription(option: .raw))"
    ))

    // Collect attributes in logical groups
    await addBasicAttributes(to: &attributes, element: element)
    await addStateAttributes(to: &attributes, element: element)
    await addGeometryAttributes(to: &attributes, element: element)
    await addHierarchyAttributes(to: &attributes, element: element, valueFormatOption: valueFormatOption)

    if includeActions {
        await addActionAttributes(to: &attributes, element: element)
    }

    await addStandardStringAttributes(to: &attributes, element: element)

    if includeStoredAttributes {
        addStoredAttributes(to: &attributes, element: element)
    }

    await addComputedProperties(to: &attributes, element: element)

    GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message:
        "getElementFullDescription finished for element: " +
            "\(element.briefDescription(option: .raw)). Returning \(attributes.count) attributes."))
    return (attributes, [])
}
