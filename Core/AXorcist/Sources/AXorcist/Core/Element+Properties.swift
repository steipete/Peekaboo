import ApplicationServices
import Foundation

// GlobalAXLogger should be available

// MARK: - Element Common Attribute Getters & Status Properties

public extension Element {
    // Common Attribute Getters - now simplified
    @MainActor func role() -> String? {
        attribute(Attribute<String>.role)
    }

    @MainActor func subrole() -> String? {
        attribute(Attribute<String>.subrole)
    }

    @MainActor func title() -> String? {
        attribute(Attribute<String>.title)
    }

    // Renamed from 'description' to 'descriptionText'
    @MainActor func descriptionText() -> String? {
        attribute(Attribute<String>.description)
    }

    @MainActor func isEnabled() -> Bool? {
        attribute(Attribute<Bool>.enabled)
    }

    @MainActor func value() -> Any? {
        attribute(Attribute<Any>(AXAttributeNames.kAXValueAttribute))
    }

    @MainActor func roleDescription() -> String? {
        attribute(Attribute<String>.roleDescription)
    }

    @MainActor func help() -> String? {
        attribute(Attribute<String>.help)
    }

    @MainActor func identifier() -> String? {
        attribute(Attribute<String>.identifier)
    }

    // Status Properties - simplified
    @MainActor func isFocused() -> Bool? {
        attribute(Attribute<Bool>.focused)
    }

    @MainActor func isHidden() -> Bool? {
        attribute(Attribute<Bool>.hidden)
    }

    @MainActor func isElementBusy() -> Bool? {
        attribute(Attribute<Bool>.busy)
    }

    @MainActor func isIgnored() -> Bool {
        attribute(Attribute<Bool>.hidden) == true
    }

    @MainActor func pid() -> pid_t? {
        var pidRef: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            self.underlyingElement,
            AXAttributeNames.kAXPIDAttribute as CFString,
            &pidRef
        )
        if error == .success, let pidNum = pidRef as? NSNumber {
            return pid_t(pidNum.intValue)
        } else {
            // Use the global axDebugLog helper function for simplicity and correctness
            axDebugLog("Failed to get PID for element: \(error.rawValue)",
                       details: ["element": AnyCodable(String(describing: self.underlyingElement))])
        }
        return nil
    }

    // Hierarchy and Relationship Getters - simplified
    @MainActor func parent() -> Element? {
        guard let parentElementUI: AXUIElement = attribute(.parent) else { return nil }
        return Element(parentElementUI)
    }

    @MainActor func windows() -> [Element]? {
        guard let windowElementsUI: [AXUIElement] = attribute(.windows) else { return nil }
        return windowElementsUI.map { Element($0) }
    }

    @MainActor func mainWindow() -> Element? {
        guard let windowElementUI = attribute(.mainWindow) else { return nil }
        return Element(windowElementUI)
    }

    @MainActor func focusedWindow() -> Element? {
        guard let windowElementUI = attribute(.focusedWindow) else { return nil }
        return Element(windowElementUI)
    }

    // Attempts to get the focused UI element within this element (e.g., a focused text field in a window).
    @MainActor
    func focusedUIElement() -> Element? {
        // Use the specific type for the attribute, non-optional generic
        guard let elementUI: AXUIElement = attribute(Attribute<AXUIElement>.focusedUIElement) else { return nil }
        return Element(elementUI)
    }

    // Action-related - simplified
    @MainActor
    func supportedActions() -> [String]? {
        attribute(Attribute<[String]>.actionNames)
    }

    // domIdentifier - simplified to a single method, was previously a computed property and a method.
    @MainActor func domIdentifier() -> String? {
        attribute(Attribute<String>(AXAttributeNames.kAXDOMIdentifierAttribute))
    }

    @MainActor func defaultButton() -> Element? {
        guard let buttonAXUIElement = attribute(.defaultButton) else { return nil }
        return Element(buttonAXUIElement)
    }

    @MainActor func cancelButton() -> Element? {
        guard let buttonAXUIElement = attribute(.cancelButton) else { return nil }
        return Element(buttonAXUIElement)
    }

    // Specific UI Buttons in a Window
    @MainActor func closeButton() -> Element? {
        guard let buttonAXUIElement = attribute(.closeButton) else { return nil }
        return Element(buttonAXUIElement)
    }

    @MainActor func zoomButton() -> Element? {
        guard let buttonAXUIElement = attribute(.zoomButton) else { return nil }
        return Element(buttonAXUIElement)
    }

    @MainActor func minimizeButton() -> Element? {
        guard let buttonAXUIElement = attribute(.minimizeButton) else { return nil }
        return Element(buttonAXUIElement)
    }

    @MainActor func toolbarButton() -> Element? {
        guard let buttonAXUIElement = attribute(.toolbarButton) else { return nil }
        return Element(buttonAXUIElement)
    }

    @MainActor func fullScreenButton() -> Element? {
        guard let buttonAXUIElement = attribute(.fullScreenButton) else { return nil }
        return Element(buttonAXUIElement)
    }

    // Proxy (e.g. for web content)
    @MainActor func proxy() -> Element? {
        guard let proxyAXUIElement = attribute(.proxy) else { return nil }
        return Element(proxyAXUIElement)
    }

    // Grow Area (e.g. for resizing window)
    @MainActor func growArea() -> Element? {
        guard let growAreaAXUIElement = attribute(.growArea) else { return nil }
        return Element(growAreaAXUIElement)
    }

    @MainActor func header() -> Element? {
        guard let headerAXUIElement = attribute(.header) else { return nil }
        return Element(headerAXUIElement)
    }

    // Scroll Area properties
    @MainActor func horizontalScrollBar() -> Element? {
        guard let scrollBarAXUIElement = attribute(.horizontalScrollBar) else { return nil }
        return Element(scrollBarAXUIElement)
    }

    @MainActor func verticalScrollBar() -> Element? {
        guard let scrollBarAXUIElement = attribute(.verticalScrollBar) else { return nil }
        return Element(scrollBarAXUIElement)
    }

    // Common Value-Holding Attributes (as specific types)
    // ... existing code ...

    // MARK: - Attribute Names

    @MainActor func attributeNames() -> [String]? {
        var attrNames: CFArray?
        let error = AXUIElementCopyAttributeNames(self.underlyingElement, &attrNames)
        if error == .success, let names = attrNames as? [String] {
            return names
        }
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "Failed to get attribute names for element: \(error.rawValue)"
        ))
        return nil
    }

    // MARK: - AX Property Dumping

    @MainActor
    func dump() -> String {
        var builder = AXPropertyDumpBuilder(root: self.underlyingElement, description: self.briefDescription())
        return builder.build()
    }
}


@MainActor
private struct AXPropertyDumpBuilder {
    private enum AttributeFetchResult {
        case success([String])
        case failure(AXError)
    }

    let root: AXUIElement
    let description: String
    private var lines: [String]

    init(root: AXUIElement, description: String) {
        self.root = root
        self.description = description
        self.lines = []
    }

    mutating func build() -> String {
        self.lines.append("Dumping AX properties for Element: \(self.description)")
        self.appendAttributes(for: self.root, indent: "  ")
        self.appendParameterizedAttributes(for: self.root, indent: "  ")
        return self.lines.joined(separator: "\n")
    }

    private mutating func appendAttributes(for element: AXUIElement, indent: String) {
        switch self.attributeNames(for: element) {
        case let .success(names) where names.isEmpty:
            self.appendLine(indent, "Attributes: (No attributes found)")
        case let .success(names):
            self.appendLine(indent, "Attributes:")
            for name in names.sorted() {
                self.appendAttributeValue(name: name, element: element, indent: indent + "  ")
            }
        case let .failure(error):
            let detail = String(describing: error)
            self.appendLine(indent, "Attributes: (Error copying names: \(detail) - Code \(error.rawValue))")
        }
    }

    private mutating func appendAttributeValue(name: String, element: AXUIElement, indent: String) {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard result == .success else {
            let detail = String(describing: AXError(rawValue: result.rawValue) ?? "Unknown AXError" as Any)
            self.appendLine(indent, "\(name): (Error fetching value: \(detail) - Code \(result.rawValue))")
            return
        }

        if let children = value as? [AXUIElement] {
            self.appendLine(indent, "\(name): [\(children.count) children]")
            return
        }

        if let stringValue = value as? String, stringValue.isEmpty {
            self.appendLine(indent, "\(name): \"\" (empty string)")
            return
        }

        if value is NSNull {
            self.appendLine(indent, "\(name): NSNull")
            return
        }

        let description = String(describing: value ?? "nil" as AnyObject)
        self.appendLine(indent, "\(name): \(description)")
    }

    private mutating func appendParameterizedAttributes(for element: AXUIElement, indent: String) {
        switch self.parameterizedAttributeNames(for: element) {
        case let .success(names) where names.isEmpty:
            self.appendLine(indent, "Parameterized Attributes: (None)")
        case let .success(names):
            self.appendLine(indent, "Parameterized Attributes:")
            for name in names.sorted() {
                let description = self.parameterizedValueDescription(name: name, element: element)
                self.appendLine(indent + "  ", description)
            }
        case let .failure(error):
            let detail = String(describing: error)
            let message = "Parameterized Attributes: (Error copying names: \(detail) - " +
                "Code \(error.rawValue))"
            self.appendLine(indent, message)
        }
    }

    private func attributeNames(for element: AXUIElement) -> AttributeFetchResult {
        var names: CFArray?
        let result = AXUIElementCopyAttributeNames(element, &names)
        guard result == .success else { return .failure(AXError(rawValue: result.rawValue) ?? .failure) }
        return .success((names as? [String]) ?? [])
    }

    private func parameterizedAttributeNames(for element: AXUIElement) -> AttributeFetchResult {
        var names: CFArray?
        let result = AXUIElementCopyParameterizedAttributeNames(element, &names)
        guard result == .success else { return .failure(AXError(rawValue: result.rawValue) ?? .failure) }
        return .success((names as? [String]) ?? [])
    }

    private func parameterizedValueDescription(name: String, element: AXUIElement) -> String {
        let zeroParameter: AnyObject = NSNumber(value: 0)
        if let value = self.parameterValue(name: name, element: element, parameter: zeroParameter) {
            return "\(name)(param: 0): \(value)"
        }

        let nullParameter: AnyObject = (CFConstants.cfNull ?? kCFNull)
        if let value = self.parameterValue(name: name, element: element, parameter: nullParameter) {
            return "\(name)(param: CFConstants.cfNull): \(value)"
        }

        return "\(name)(…): (Error fetching value with common parameters)"
    }

    private func parameterValue(name: String, element: AXUIElement, parameter: AnyObject) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            name as CFString,
            parameter,
            &value
        )
        guard result == .success else { return nil }
        return String(describing: value ?? "nil" as Any)
    }

    private mutating func appendLine(_ indent: String, _ text: String) {
        self.lines.append(indent + text)
    }
}
