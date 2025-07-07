//
//  Element+ConvenienceAttributes.swift
//  AXorcist
//
//  Convenience attribute accessors for common operations
//

import ApplicationServices
import CoreGraphics
import Foundation

public extension Element {
    // MARK: - Position and Size

    /// Get the position (CGPoint) of the element
    @MainActor
    func position() -> CGPoint? {
        attribute(Attribute<CGPoint>.position)
    }

    /// Set the position of the element
    @MainActor
    func setPosition(_ point: CGPoint) -> AXError {
        guard let axValue = AXValue.create(point: point) else {
            return .failure
        }
        return AXUIElementSetAttributeValue(
            underlyingElement,
            AXAttributeNames.kAXPositionAttribute as CFString,
            axValue
        )
    }

    /// Get the size (CGSize) of the element
    @MainActor
    func size() -> CGSize? {
        attribute(Attribute<CGSize>.size)
    }

    /// Set the size of the element
    @MainActor
    func setSize(_ size: CGSize) -> AXError {
        guard let axValue = AXValue.create(size: size) else {
            return .failure
        }
        return AXUIElementSetAttributeValue(underlyingElement, AXAttributeNames.kAXSizeAttribute as CFString, axValue)
    }

    /// Get the frame (CGRect) of the element
    @MainActor
    func frame() -> CGRect? {
        guard let origin = position(),
              let size = size()
        else {
            return nil
        }
        return CGRect(origin: origin, size: size)
    }

    /// Set the frame of the element
    @MainActor
    func setFrame(_ rect: CGRect) {
        _ = setPosition(rect.origin)
        _ = setSize(rect.size)
    }

    /// Set the frame using separate origin and size
    @MainActor
    func setFrame(origin: CGPoint, size: CGSize) {
        _ = setPosition(origin)
        _ = setSize(size)
    }

    // MARK: - Window State

    /// Check if the element is minimized
    @MainActor
    func isMinimized() -> Bool? {
        attribute(Attribute<Bool>.minimized)
    }

    /// Set the minimized state
    @MainActor
    func setMinimized(_ isMinimized: Bool) -> AXError {
        AXUIElementSetAttributeValue(
            underlyingElement,
            AXAttributeNames.kAXMinimizedAttribute as CFString,
            isMinimized as CFBoolean
        )
    }

    /// Check if the element is in fullscreen
    @MainActor
    func isFullScreen() -> Bool? {
        attribute(Attribute<Bool>.fullScreen)
    }

    /// Set fullscreen state
    @MainActor
    func setFullScreen(_ fullScreen: Bool) -> AXError {
        AXUIElementSetAttributeValue(
            underlyingElement,
            AXAttributeNames.kAXFullScreenAttribute as CFString,
            fullScreen as CFBoolean
        )
    }

    // MARK: - Text Attributes

    /// Get selected text
    @MainActor
    func selectedText() -> String? {
        attribute(Attribute<String>.selectedText)
    }

    /// Get selected text range
    @MainActor
    func selectedTextRange() -> CFRange? {
        attribute(Attribute<CFRange>.selectedTextRange)
    }

    /// Get visible character range
    @MainActor
    func visibleCharacterRange() -> CFRange? {
        attribute(Attribute<CFRange>.visibleCharacterRange)
    }

    /// Get number of characters
    @MainActor
    func numberOfCharacters() -> Int? {
        attribute(Attribute<Int>.numberOfCharacters)
    }

    // MARK: - Hierarchy Navigation

    // Note: children() method is already defined in Element+Hierarchy.swift

    /// Get selected children
    @MainActor
    func selectedChildren() -> [Element]? {
        guard let selectedUI: [AXUIElement] = attribute(.selectedChildren) else { return nil }
        return selectedUI.map { Element($0) }
    }

    /// Get visible children
    @MainActor
    func visibleChildren() -> [Element]? {
        guard let visibleUI: [AXUIElement] = attribute(.visibleChildren) else { return nil }
        return visibleUI.map { Element($0) }
    }

    // MARK: - Application Attributes

    /// Get the main menu bar element of an application. This is typically called on an Element representing an
    /// application.
    @MainActor
    func mainMenu() -> Element? {
        guard let menuBarUI = attribute(Attribute<AXUIElement>.mainMenu) else { return nil }
        return Element(menuBarUI)
    }

    /// Check if the application element is the frontmost application. This is typically called on an Element
    /// representing an application.
    @MainActor
    func isFrontmost() -> Bool? {
        attribute(Attribute<Bool>.frontmost)
    }

    /// Check if the application represented by this element is hidden. This is typically called on an Element
    /// representing an application.
    @MainActor
    func isApplicationHidden() -> Bool? {
        attribute(Attribute<Bool>.hidden)
    }

    /// Check if element is main (e.g., the main window of an application). This is typically called on an Element
    /// representing a window.
    @MainActor
    func isMain() -> Bool? {
        attribute(Attribute<Bool>(AXAttributeNames.kAXMainAttribute))
    }

    /// Check if element is modal
    @MainActor
    func isModal() -> Bool? {
        attribute(Attribute<Bool>.modal)
    }

    // MARK: - Table/List Attributes

    /// Get rows
    @MainActor
    func rows() -> [Element]? {
        guard let rowsUI: [AXUIElement] = attribute(.rows) else { return nil }
        return rowsUI.map { Element($0) }
    }

    /// Get columns
    @MainActor
    func columns() -> [Element]? {
        guard let columnsUI: [AXUIElement] = attribute(.columns) else { return nil }
        return columnsUI.map { Element($0) }
    }

    /// Get visible rows
    @MainActor
    func visibleRows() -> [Element]? {
        guard let rowsUI: [AXUIElement] = attribute(.visibleRows) else { return nil }
        return rowsUI.map { Element($0) }
    }

    /// Get visible columns
    @MainActor
    func visibleColumns() -> [Element]? {
        guard let columnsUI: [AXUIElement] = attribute(.visibleColumns) else { return nil }
        return columnsUI.map { Element($0) }
    }

    // MARK: - Value Attributes

    /// Get minimum value
    @MainActor
    func minValue() -> Any? {
        attribute(Attribute<Any>(AXAttributeNames.kAXMinValueAttribute))
    }

    /// Get maximum value
    @MainActor
    func maxValue() -> Any? {
        attribute(Attribute<Any>(AXAttributeNames.kAXMaxValueAttribute))
    }

    /// Get value increment
    @MainActor
    func valueIncrement() -> Any? {
        attribute(Attribute<Any>(AXAttributeNames.kAXValueIncrementAttribute))
    }

    // MARK: - URL Attribute

    /// Get URL for elements that represent disk or network items
    @MainActor
    func url() -> URL? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            underlyingElement,
            AXAttributeNames.kAXURLAttribute as CFString,
            &value
        )
        guard error == .success,
              let cfURL = value as! CFURL?
        else {
            return nil
        }
        return cfURL as URL
    }

    // MARK: - System-Wide Element Attributes

    /// If this element is the SystemWide element, gets the currently focused application.
    /// Returns nil if this element is not the SystemWide element or if the attribute cannot be retrieved.
    @MainActor
    func focusedApplicationElement() -> Element? {
        guard let appElementUI: AXUIElement = attribute(Attribute<AXUIElement>.focusedApplication) else { return nil }
        return Element(appElementUI)
    }
}
