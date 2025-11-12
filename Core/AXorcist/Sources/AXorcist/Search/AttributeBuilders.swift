// AttributeBuilders.swift - Functions for building attribute collections

import ApplicationServices
import CoreGraphics
import Foundation

// MARK: - Attribute Collection Builders

@MainActor
func addBasicAttributes(to attributes: inout [String: AnyCodable], element: Element) async {
    if let role = element.role() {
        attributes[AXAttributeNames.kAXRoleAttribute] = AnyCodable(role)
    }
    if let subrole = element.subrole() {
        attributes[AXAttributeNames.kAXSubroleAttribute] = AnyCodable(subrole)
    }
    if let title = element.title() {
        attributes[AXAttributeNames.kAXTitleAttribute] = AnyCodable(title)
    }
    if let descriptionText = element.descriptionText() {
        attributes[AXAttributeNames.kAXDescriptionAttribute] = AnyCodable(descriptionText)
    }
    if let value = element.value() {
        attributes[AXAttributeNames.kAXValueAttribute] = AnyCodable(value)
    }
    if let help = element.attribute(Attribute<String>(AXAttributeNames.kAXHelpAttribute)) {
        attributes[AXAttributeNames.kAXHelpAttribute] = AnyCodable(help)
    }
    if let placeholder = element.attribute(Attribute<String>(AXAttributeNames.kAXPlaceholderValueAttribute)) {
        attributes[AXAttributeNames.kAXPlaceholderValueAttribute] = AnyCodable(placeholder)
    }
}

@MainActor
func addStateAttributes(to attributes: inout [String: AnyCodable], element: Element) async {
    attributes[AXAttributeNames.kAXEnabledAttribute] = AnyCodable(element.isEnabled())
    attributes[AXAttributeNames.kAXFocusedAttribute] = AnyCodable(element.isFocused())
    attributes[AXAttributeNames.kAXHiddenAttribute] = AnyCodable(element.isHidden())
    attributes[AXMiscConstants.isIgnoredAttributeKey] = AnyCodable(element.isIgnored())
    attributes[AXAttributeNames.kAXElementBusyAttribute] = AnyCodable(element.isElementBusy())
}

@MainActor
func addGeometryAttributes(to attributes: inout [String: AnyCodable], element: Element) async {
    if let position = element.attribute(Attribute<CGPoint>(AXAttributeNames.kAXPositionAttribute)) {
        attributes[AXAttributeNames.kAXPositionAttribute] = AnyCodable(NSPointToDictionary(position))
    }
    if let size = element.attribute(Attribute<CGSize>(AXAttributeNames.kAXSizeAttribute)) {
        attributes[AXAttributeNames.kAXSizeAttribute] = AnyCodable(NSSizeToDictionary(size))
    }
}

@MainActor
func addHierarchyAttributes(
    to attributes: inout [String: AnyCodable],
    element: Element,
    valueFormatOption _: ValueFormatOption
) async {
    if let parent = element.parent() {
        attributes[AXAttributeNames.kAXParentAttribute] = AnyCodable(
            parent.briefDescription(option: .raw)
        )
    }
    if let children = element.children() {
        attributes[AXAttributeNames.kAXChildrenAttribute] = AnyCodable(
            children.map { $0.briefDescription(option: .raw) }
        )
    }
}

@MainActor
func addActionAttributes(to attributes: inout [String: AnyCodable], element: Element) async {
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
        ? AnyCodable(actionsToStore)
        : AnyCodable(nil as [String]?)

    if element.isActionSupported(AXActionNames.kAXPressAction) {
        attributes["\(AXActionNames.kAXPressAction)_Supported"] = AnyCodable(true)
    }
}

@MainActor
func addStandardStringAttributes(to attributes: inout [String: AnyCodable], element: Element) async {
    let standardAttributes = [
        AXAttributeNames.kAXRoleDescriptionAttribute,
        AXAttributeNames.kAXValueDescriptionAttribute,
        AXAttributeNames.kAXIdentifierAttribute,
    ]

    for attrName in standardAttributes {
        if attributes[attrName] == nil,
           let attrValue: String = element.attribute(Attribute<String>(attrName))
        {
            attributes[attrName] = AnyCodable(attrValue)
        }
    }
}

@MainActor
func addStoredAttributes(to attributes: inout [String: AnyCodable], element: Element) {
    guard let stored = element.attributes else { return }

    for (key, val) in stored where attributes[key] == nil {
        attributes[key] = val
    }
}

@MainActor
func addComputedProperties(to attributes: inout [String: AnyCodable], element: Element) async {
    if attributes[AXMiscConstants.computedNameAttributeKey] == nil,
       let name = element.computedName()
    {
        attributes[AXMiscConstants.computedNameAttributeKey] = AnyCodable(name)
    }

    if attributes[AXMiscConstants.computedPathAttributeKey] == nil {
        attributes[AXMiscConstants.computedPathAttributeKey] = AnyCodable(element.generatePathString())
    }

    if attributes[AXMiscConstants.isClickableAttributeKey] == nil {
        let isButton = element.role() == AXRoleNames.kAXButtonRole
        let hasPressAction = element.isActionSupported(AXActionNames.kAXPressAction)
        if isButton || hasPressAction {
            attributes[AXMiscConstants.isClickableAttributeKey] = AnyCodable(true)
        }
    }
}
