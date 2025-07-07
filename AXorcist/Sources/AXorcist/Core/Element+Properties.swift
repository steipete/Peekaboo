import ApplicationServices
import Foundation

// MARK: - Element Common Attribute Getters & Status Properties

extension Element {
    // Common Attribute Getters - now methods to accept logging parameters
    @MainActor public func role(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> String? {
        attribute(
            Attribute<String>.role,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
    }
    @MainActor public func subrole(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> String? {
        attribute(
            Attribute<String>.subrole,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
    }
    @MainActor public func title(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> String? {
        attribute(
            Attribute<String>.title,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
    }
    @MainActor public func description(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> String? {
        attribute(
            Attribute<String>.description,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
    }
    @MainActor public func isEnabled(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> Bool? {
        attribute(
            Attribute<Bool>.enabled,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
    }
    @MainActor public func value(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> Any? {
        attribute(
            Attribute<Any>.value,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
    }
    @MainActor public func roleDescription(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> String? {
        attribute(
            Attribute<String>.roleDescription,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
    }
    @MainActor public func help(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> String? {
        attribute(
            Attribute<String>.help,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
    }
    @MainActor public func identifier(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> String? {
        attribute(
            Attribute<String>.identifier,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
    }

    // Status Properties - now methods
    @MainActor public func isFocused(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> Bool? {
        attribute(
            Attribute<Bool>.focused,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
    }
    @MainActor public func isHidden(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> Bool? {
        attribute(
            Attribute<Bool>.hidden,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
    }
    @MainActor public func isElementBusy(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> Bool? {
        attribute(
            Attribute<Bool>.busy,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
    }

    @MainActor public func isIgnored(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> Bool {
        if attribute(
            Attribute<Bool>.hidden,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        ) == true {
            return true
        }
        return false
    }

    @MainActor public func pid(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> pid_t? {
        // This function doesn't call self.attribute, so its logging is self-contained if any.
        // For now, assuming AXUIElementGetPid doesn't log through our system.
        // If verbose logging of this specific call is needed, add dLog here.
        var processID: pid_t = 0
        let error = AXUIElementGetPid(self.underlyingElement, &processID)
        if error == .success {
            return processID
        }
        // Optional: dLog if error and isDebugLoggingEnabled
        return nil
    }

    // Hierarchy and Relationship Getters - now methods
    @MainActor public func parent(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> Element? {
        guard let parentElementUI: AXUIElement = attribute(
            Attribute<AXUIElement>.parent,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        ) else { return nil }
        return Element(parentElementUI)
    }

    @MainActor public func windows(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> [Element]? {
        guard let windowElementsUI: [AXUIElement] = attribute(
            Attribute<[AXUIElement]>.windows,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        ) else { return nil }
        return windowElementsUI.map { Element($0) }
    }

    @MainActor public func mainWindow(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> Element? {
        guard let windowElementUI = attribute(
            Attribute<AXUIElement?>.mainWindow,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        ) else { return nil }
        return Element(windowElementUI!)
    }

    @MainActor public func focusedWindow(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> Element? {
        guard let windowElementUI = attribute(
            Attribute<AXUIElement?>.focusedWindow,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        ) else { return nil }
        return Element(windowElementUI!)
    }

    @MainActor public func focusedElement(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> Element? {
        guard let elementUI = attribute(
            Attribute<AXUIElement?>.focusedElement,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        ) else { return nil }
        return Element(elementUI!)
    }

    // Action-related - now a method
    @MainActor
    public func supportedActions(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> [String]? {
        return attribute(
            Attribute<[String]>.actionNames,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )
    }

    @MainActor public var domIdentifier: String? {
        get {
            var logs: [String] = [] // Logging for this specific getter, will be discarded if not used by caller
            return attribute(Attribute<String>(AXAttributeNames.kAXDOMIdentifierAttribute), isDebugLoggingEnabled: false, currentDebugLogs: &logs)
        }
    }

    @MainActor public func domIdentifier(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> String? {
        return attribute(Attribute<String>(AXAttributeNames.kAXDOMIdentifierAttribute), isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs)
    }
}
