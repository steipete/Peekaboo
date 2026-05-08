import AppKit
import ApplicationServices
import AXorcist
import CoreGraphics
import Foundation

/// Testable abstraction over a UI accessibility element.
///
/// The production implementation wraps AXorcist's `Element`; tests can provide an in-memory tree with the same
/// observable attributes and action behavior.
@MainActor
public protocol AutomationElementRepresenting: Sendable {
    var name: String? { get }
    var label: String? { get }
    var roleDescription: String? { get }
    var identifier: String? { get }
    var role: String? { get }
    var subrole: String? { get }
    var frame: CGRect? { get }
    var value: Any? { get }
    var stringValue: String? { get }
    var actionNames: [String] { get }
    var isValueSettable: Bool { get }
    var isEnabled: Bool { get }
    var isFocused: Bool { get }
    var isOffscreen: Bool { get }
    var anchorPoint: CGPoint? { get }
    var automationChildren: [any AutomationElementRepresenting] { get }

    func performAutomationAction(_ actionName: String) throws
    func setAutomationValue(_ value: UIElementValue) throws
    func stringAttribute(_ name: String) -> String?
    func intAttribute(_ name: String) -> Int?
}

/// Typed wrapper around an accessibility element used by action-first input paths.
public struct AutomationElement: Sendable, AutomationElementRepresenting {
    public let element: Element

    public init(_ element: Element) {
        self.element = element
    }

    @MainActor
    public var name: String? {
        self.element.title()
            ?? self.element.label()
            ?? self.element.descriptionText()
            ?? self.element.roleDescription()
            ?? self.stringValue
    }

    @MainActor
    public var label: String? {
        self.element.label()
    }

    @MainActor
    public var roleDescription: String? {
        self.element.roleDescription()
    }

    @MainActor
    public var identifier: String? {
        self.element.identifier()
    }

    @MainActor
    public var role: String? {
        self.element.role()
    }

    @MainActor
    public var subrole: String? {
        self.element.subrole()
    }

    @MainActor
    public var frame: CGRect? {
        self.element.frame()
    }

    @MainActor
    public var value: Any? {
        self.element.value()
    }

    @MainActor
    public var stringValue: String? {
        self.value as? String
    }

    @MainActor
    public var actionNames: [String] {
        self.element.supportedActions() ?? []
    }

    @MainActor
    public var isValueSettable: Bool {
        self.element.isAttributeSettable(named: AXAttributeNames.kAXValueAttribute)
    }

    @MainActor
    public var isEnabled: Bool {
        self.element.isEnabled() ?? true
    }

    @MainActor
    public var isFocused: Bool {
        self.element.isFocused() ?? false
    }

    @MainActor
    public var isOffscreen: Bool {
        guard let frame else { return false }
        let visibleFrame = NSScreen.screens
            .map(\.visibleFrame)
            .reduce(CGRect.null) { partial, screenFrame in
                partial.isNull ? screenFrame : partial.union(screenFrame)
            }
        guard !visibleFrame.isNull else { return false }
        return frame.intersection(visibleFrame).isNull
    }

    @MainActor
    public var parent: AutomationElement? {
        self.element.parent().map(AutomationElement.init)
    }

    @MainActor
    public var children: [AutomationElement] {
        (self.element.children() ?? []).map(AutomationElement.init)
    }

    @MainActor
    public var anchorPoint: CGPoint? {
        self.frame.map { CGPoint(x: $0.midX, y: $0.midY) }
    }

    @MainActor
    public var automationChildren: [any AutomationElementRepresenting] {
        self.children
    }

    @MainActor
    public func performAutomationAction(_ actionName: String) throws {
        _ = try self.element.performAction(actionName)
    }

    @MainActor
    public func setAutomationValue(_ value: UIElementValue) throws {
        let error = AXUIElementSetAttributeValue(
            self.element.underlyingElement,
            AXAttributeNames.kAXValueAttribute as CFString,
            value.accessibilityValue as CFTypeRef)
        guard error == .success else {
            throw AccessibilitySystemError(error)
        }
    }

    @MainActor
    public func stringAttribute(_ name: String) -> String? {
        self.element.attribute(Attribute<String>(name))
    }

    @MainActor
    public func intAttribute(_ name: String) -> Int? {
        self.element.attribute(Attribute<Int>(name))
    }
}
