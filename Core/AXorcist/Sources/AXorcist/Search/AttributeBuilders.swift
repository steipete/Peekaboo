// AttributeBuilders.swift - Functions for building attribute collections

import ApplicationServices
import CoreGraphics
import Foundation

// MARK: - Attribute Collection Builders

@MainActor
func addBasicAttributes(to attributes: inout [String: AttributeValue], element: Element) async {
    if let role = element.role() {
        attributes[AXAttributeNames.kAXRoleAttribute] = .string(role)
    }
    if let subrole = element.subrole() {
        attributes[AXAttributeNames.kAXSubroleAttribute] = .string(subrole)
    }
    if let title = element.title() {
        attributes[AXAttributeNames.kAXTitleAttribute] = .string(title)
    }
    if let descriptionText = element.descriptionText() {
        attributes[AXAttributeNames.kAXDescriptionAttribute] = .string(descriptionText)
    }
    if let value = element.value() {
        attributes[AXAttributeNames.kAXValueAttribute] = AttributeValue(from: value)
    }
    if let help = element.attribute(Attribute<String>(AXAttributeNames.kAXHelpAttribute)) {
        attributes[AXAttributeNames.kAXHelpAttribute] = .string(help)
    }
    if let placeholder = element.attribute(Attribute<String>(AXAttributeNames.kAXPlaceholderValueAttribute)) {
        attributes[AXAttributeNames.kAXPlaceholderValueAttribute] = .string(placeholder)
    }
}

@MainActor
func addStateAttributes(to attributes: inout [String: AttributeValue], element: Element) async {
    attributes[AXAttributeNames.kAXEnabledAttribute] = .bool(element.isEnabled() ?? false)
    attributes[AXAttributeNames.kAXFocusedAttribute] = .bool(element.isFocused() ?? false)
    attributes[AXAttributeNames.kAXHiddenAttribute] = .bool(element.isHidden() ?? false)
    attributes[AXMiscConstants.isIgnoredAttributeKey] = .bool(element.isIgnored())
    attributes[AXAttributeNames.kAXElementBusyAttribute] = .bool(element.isElementBusy() ?? false)
}

@MainActor
func addGeometryAttributes(to attributes: inout [String: AttributeValue], element: Element) async {
    if let position = element.attribute(Attribute<CGPoint>(AXAttributeNames.kAXPositionAttribute)) {
        attributes[AXAttributeNames.kAXPositionAttribute] = AttributeValue(from: NSPointToDictionary(position))
    }
    if let size = element.attribute(Attribute<CGSize>(AXAttributeNames.kAXSizeAttribute)) {
        attributes[AXAttributeNames.kAXSizeAttribute] = AttributeValue(from: NSSizeToDictionary(size))
    }
}

@MainActor
func addHierarchyAttributes(
    to attributes: inout [String: AttributeValue],
    element: Element,
    valueFormatOption _: ValueFormatOption
) async {
    if let parent = element.parent() {
        attributes[AXAttributeNames.kAXParentAttribute] = .string(
            parent.briefDescription(option: .raw)
        )
    }
    if let children = element.children() {
        attributes[AXAttributeNames.kAXChildrenAttribute] = .array(
            children.map { .string($0.briefDescription(option: .raw)) }
        )
    }
}

@MainActor
func addActionAttributes(to attributes: inout [String: AttributeValue], element: Element) async {
    var actionsToStore: [String]?

    if let currentActions = element.supportedActions(), !currentActions.isEmpty {
        actionsToStore = currentActions
    } else if let fallbackActions: [String] = element.attribute(
        Attribute<[String]>(AXAttributeNames.kAXActionsAttribute)
    ), !fallbackActions.isEmpty {
        actionsToStore = fallbackActions
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "Used fallback kAXActionsAttribute for \(element.briefDescription(option: .raw))"
        ))
    }

    attributes[AXAttributeNames.kAXActionsAttribute] = actionsToStore != nil
        ? .array(actionsToStore!.map { .string($0) })
        : .null

    if element.isActionSupported(AXActionNames.kAXPressAction) {
        attributes["\(AXActionNames.kAXPressAction)_Supported"] = .bool(true)
    }
}

@MainActor
func addStandardStringAttributes(to attributes: inout [String: AttributeValue], element: Element) async {
    let standardAttributes = [
        AXAttributeNames.kAXRoleDescriptionAttribute,
        AXAttributeNames.kAXValueDescriptionAttribute,
        AXAttributeNames.kAXIdentifierAttribute,
    ]

    for attrName in standardAttributes {
        if attributes[attrName] == nil,
           let attrValue: String = element.attribute(Attribute<String>(attrName))
        {
            attributes[attrName] = .string(attrValue)
        }
    }
}

@MainActor
func addStoredAttributes(to attributes: inout [String: AttributeValue], element: Element) {
    guard let stored = element.attributes else { return }

    for (key, val) in stored where attributes[key] == nil {
        attributes[key] = val
    }
}

@MainActor
func addComputedProperties(to attributes: inout [String: AttributeValue], element: Element) async {
    if attributes[AXMiscConstants.computedNameAttributeKey] == nil,
       let name = element.computedName()
    {
        attributes[AXMiscConstants.computedNameAttributeKey] = .string(name)
    }

    if attributes[AXMiscConstants.computedPathAttributeKey] == nil {
        attributes[AXMiscConstants.computedPathAttributeKey] = .string(element.generatePathString())
    }

    if attributes[AXMiscConstants.isClickableAttributeKey] == nil {
        let isButton = element.role() == AXRoleNames.kAXButtonRole
        let hasPressAction = element.isActionSupported(AXActionNames.kAXPressAction)
        if isButton || hasPressAction {
            attributes[AXMiscConstants.isClickableAttributeKey] = .bool(true)
        }
    }
}
