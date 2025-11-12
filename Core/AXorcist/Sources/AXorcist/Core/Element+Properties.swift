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
        var output = "Dumping AX properties for Element: \(self.briefDescription())\n"

        output += _dumpRecursive(element: self.underlyingElement, currentIndent: "  ")
        return output
    }

    @MainActor
    private func _dumpRecursive(element: AXUIElement, currentIndent: String) -> String {
        var output = ""

        // Helper to append to output string with current indent
        func appendLine(_ text: String) {
            output += currentIndent + text + "\n"
        }

        // 1. ordinary attributes
        var attrCF: CFArray?
        let copyAttrNamesResult = AXUIElementCopyAttributeNames(element, &attrCF)
        if copyAttrNamesResult == .success {
            if let names = attrCF as? [String] {
                if names.isEmpty {
                    appendLine("Attributes: (No attributes found)")
                } else {
                    appendLine("Attributes:")
                    let attributeIndent = currentIndent + "  "
                    for name in names.sorted() {
                        var value: AnyObject?
                        let err = AXUIElementCopyAttributeValue(element, name as CFString, &value)
                        if err == .success {
                            if let childrenElements = value as? [AXUIElement] {
                                output += attributeIndent + "\(name): [\(childrenElements.count) children]\n"
                                // Only recurse on known children attributes for brevity
                                if name == kAXChildrenAttribute as String || name ==
                                    kAXVisibleChildrenAttribute as String || name ==
                                    kAXSelectedChildrenAttribute as String
                                {
                                    for _ in childrenElements {
                                        // output += _dumpRecursive(element: childAXUIElement, currentIndent:
                                        // attributeIndent + "  ")
                                    }
                                }
                            } else if let stringValue = value as? String, stringValue.isEmpty {
                                output += attributeIndent + "\(name): \"\" (empty string)\n"
                            } else if value is NSNull {
                                output += attributeIndent + "\(name): NSNull\n"
                            } else {
                                let valueDescription = String(describing: value ?? "nil" as AnyObject)
                                output += attributeIndent + "\(name): \(valueDescription)\n"
                            }
                        } else {
                            let axError = AXError(rawValue: err.rawValue)
                            let errorDetail = String(describing: axError ?? "Unknown AXError" as Any)
                            output += attributeIndent +
                                "\(name): (Error fetching value: \(errorDetail) - Code \(err.rawValue))\n"
                        }
                    }
                }
            } else {
                appendLine("Attributes: (Attribute names list was nil or not [String])")
            }
        } else {
            let axError = AXError(rawValue: copyAttrNamesResult.rawValue)
            let errorDetail = String(describing: axError ?? "Unknown AXError" as Any)
            appendLine(
                "Attributes: (Error copying attribute names: \(errorDetail) - Code \(copyAttrNamesResult.rawValue))"
            )
        }

        // 2. parameterized attributes
        var paramCF: CFArray?
        let copyParamAttrNamesResult = AXUIElementCopyParameterizedAttributeNames(element, &paramCF)
        if copyParamAttrNamesResult == .success {
            if let params = paramCF as? [String], !params.isEmpty {
                appendLine("Parameterized Attributes:")
                let paramSubIndent = currentIndent + "  "
                for param in params.sorted() {
                    var paramValue: CFTypeRef?
                    let paramErr = AXUIElementCopyParameterizedAttributeValue(
                        element,
                        param as CFString,
                        NSNumber(value: 0),
                        &paramValue
                    )
                    if paramErr == .success {
                        let valueStr = String(describing: paramValue ?? "nil" as Any)
                        output += paramSubIndent + "\(param)(param: 0): \(valueStr)\n"
                    } else {
                        let paramErrNull = AXUIElementCopyParameterizedAttributeValue(
                            element,
                            param as CFString,
                            CFConstants.cfNull!,
                            &paramValue
                        )
                        if paramErrNull == .success {
                            let valueStrNull = String(describing: paramValue ?? "nil" as Any)
                            output += paramSubIndent + "\(param)(param: CFConstants.cfNull): \(valueStrNull)\n"
                        } else {
                            let axError1 = AXError(rawValue: paramErr.rawValue)
                            let errorDetail1 = String(describing: axError1 ?? "Error" as Any)
                            let axError2 = AXError(rawValue: paramErrNull.rawValue)
                            let errorDetail2 = String(describing: axError2 ?? "Error" as Any)
                            output += paramSubIndent +
                                "\(param)(…): (Error fetching with common params: \(errorDetail1) (\(paramErr.rawValue)) / \(errorDetail2) (\(paramErrNull.rawValue)))\n"
                        }
                    }
                }
            } else {
                appendLine("Parameterized Attributes: (No names found or not [String])")
            }
        } else {
            let axError = AXError(rawValue: copyParamAttrNamesResult.rawValue)
            let errorDetail = String(describing: axError ?? "Unknown AXError" as Any)
            appendLine(
                "Parameterized Attributes: (Error copying names: \(errorDetail) - Code \(copyParamAttrNamesResult.rawValue))"
            )
        }

        // 3. actions
        var actCF: CFArray?
        let copyActionNamesResult = AXUIElementCopyActionNames(element, &actCF)
        if copyActionNamesResult == .success {
            if let actions = actCF as? [String], !actions.isEmpty {
                let joinedActions = actions.sorted().joined(separator: ", ")
                appendLine("Actions: \(joinedActions)")
            }
        } else {
            let axError = AXError(rawValue: copyActionNamesResult.rawValue)
            let errorDetail = String(describing: axError ?? "Unknown AXError" as Any)
            appendLine("Actions: (Error copying action names: \(errorDetail) - Code \(copyActionNamesResult.rawValue))")
        }
        return output
    }
}

/// Example usage: Dumps the focused element's AX properties to the console.
@MainActor
public func example_dumpFocusedElementToString() {
    #if DEBUG
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .info,
            message: "Attempting to dump focused element AX properties to string:"
        ))
        var outputString = "Focused Element Details:\n"
        if AXIsProcessTrustedWithOptions(nil) { // nil means check current process
            var focusedCF: CFTypeRef?
            let systemWideElement = AXUIElementCreateSystemWide()

            if AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedCF) ==
                .success
            {
                if let focusedAXUIEl = focusedCF as! AXUIElement? { // Safely cast to AXUIElement
                    let focusedElement = Element(focusedAXUIEl) // Create an Element instance
                    outputString += "Successfully obtained focused element. Dumping details:\n"
                    outputString += focusedElement.dump() // Call the updated dump method, added await
                } else {
                    outputString += "Focused element is nil (no element has focus, or could not be cast).\n"
                }
            } else {
                outputString += "Failed to get the focused UI element from system wide element.\n"
            }
        } else {
            outputString += "AXPermissions: Process is not trusted. Please enable Accessibility for this application.\n"
        }
        GlobalAXLogger.shared.log(AXLogEntry(level: .info, message: outputString))
    #else
        // print("example_dumpFocusedElementToString is only available in DEBUG builds.")
    #endif
}

// The old dumpProperties method is effectively replaced by the new public func dump() in Element extension.
// If dumpProperties was used externally with a different signature or purpose, that needs to be re-evaluated.
// For now, assuming the new dump() method fulfills its role.
