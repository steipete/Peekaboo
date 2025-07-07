// Element.swift - Wrapper for AXUIElement for a more Swift-idiomatic interface

import ApplicationServices // For AXUIElement and other C APIs
import Foundation
// We might need to import ValueHelpers or other local modules later

// MARK: - Environment Variable Check for JSON Logging
// Copied from ElementSearch.swift - ideally this would be in a shared utility
private func getEnvVar(_ name: String) -> String? {
    guard let value = getenv(name) else { return nil }
    return String(cString: value)
}

private let AXORC_JSON_LOG_ENABLED: Bool = {
    let envValue = getEnvVar("AXORC_JSON_LOG")?.lowercased()
    // Explicitly log the check to stderr for debugging the env var itself, specific to Element.swift
    fputs("[Element.swift] AXORC_JSON_LOG env var value: \(envValue ?? "not set") -> JSON logging: \(envValue == "true")\n", stderr)
    return envValue == "true"
}()

// Element struct is NOT @MainActor. Isolation is applied to members that need it.
public struct Element: Equatable, Hashable {
    public let underlyingElement: AXUIElement

    public init(_ element: AXUIElement) {
        self.underlyingElement = element
    }

    // Implement Equatable - no longer needs nonisolated as struct is not @MainActor
    public static func == (lhs: Element, rhs: Element) -> Bool {
        return CFEqual(lhs.underlyingElement, rhs.underlyingElement)
    }

    // Implement Hashable - no longer needs nonisolated
    public func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(underlyingElement))
    }

    // Generic method to get an attribute's value (converted to Swift type T)
    @MainActor
    public func attribute<T>(_ attribute: Attribute<T>, isDebugLoggingEnabled: Bool,
                             currentDebugLogs: inout [String]) -> T? {
        func dLog(_ message: String) {
            if isDebugLoggingEnabled && !AXORC_JSON_LOG_ENABLED {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage(message, applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
            }
        }

        if T.self == [AXUIElement].self {
            dLog("Element.attribute: Special handling for T == [AXUIElement]. Attribute: \(attribute.rawValue)")
            var value: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(self.underlyingElement, attribute.rawValue as CFString, &value)
            if error == .success {
                if let cfArray = value, CFGetTypeID(cfArray) == CFArrayGetTypeID() {
                    if let axElements = cfArray as? [AXUIElement] {
                        dLog("Element.attribute: Successfully fetched and cast \(axElements.count) AXUIElements for '\(attribute.rawValue)'.")
                        return axElements as? T // This cast should succeed due to the T.self check
                    } else {
                        dLog("Element.attribute: CFArray for '\(attribute.rawValue)' failed to cast to [AXUIElement].")
                    }
                } else if value != nil {
                    dLog("Element.attribute: Value for '\(attribute.rawValue)' was not a CFArray. TypeID: \(CFGetTypeID(value!))")
                } else {
                    dLog("Element.attribute: Value for '\(attribute.rawValue)' was nil despite .success.")
                }
            } else if error == .noValue {
                dLog("Element.attribute: Attribute '\(attribute.rawValue)' has no value.")
            } else {
                dLog("Element.attribute: Error fetching '\(attribute.rawValue)': \(error.rawValue)")
            }
            return nil // Return nil if any step above failed for [AXUIElement]
        } else {
            // RESTORED: Minimal survival path for common types, otherwise nil.
            // Full ValueUnwrapper logic is still TODO.
            dLog("Element.attribute: Using basic CFTypeRef conversion for T = \(String(describing: T.self)), Attribute: \(attribute.rawValue).")
            var value: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(self.underlyingElement, attribute.rawValue as CFString, &value)

            if error != .success {
                if error != .noValue { // Don't log for .noValue, it's common
                    dLog("Element.attribute: Error \(error.rawValue) fetching '\(attribute.rawValue)' for basic conversion.")
                }
                return nil
            }

            guard let unwrappedValue = value else {
                dLog("Element.attribute: Value was nil for '\(attribute.rawValue)' after fetch for basic conversion.")
                return nil
            }

            // Basic unwrapping for common types
            if T.self == String.self {
                if CFGetTypeID(unwrappedValue) == CFStringGetTypeID() {
                    return (unwrappedValue as! CFString) as String as? T
                }
            } else if T.self == Bool.self {
                if CFGetTypeID(unwrappedValue) == CFBooleanGetTypeID() {
                    let swiftBool = CFBooleanGetValue((unwrappedValue as! CFBoolean))
                    return swiftBool as? T
                }
            } else if T.self == Int.self {
                if CFGetTypeID(unwrappedValue) == CFNumberGetTypeID() {
                    var intValue: Int = 0
                    if CFNumberGetValue((unwrappedValue as! CFNumber), .sInt64Type, &intValue) {
                        return intValue as? T
                    }
                }
            } else if T.self == AXUIElement.self { // For single AXUIElement (e.g. parent)
                if CFGetTypeID(unwrappedValue) == AXUIElementGetTypeID() {
                    return unwrappedValue as? T // Direct cast should work as it's already AXUIElement
                }
            } // Add other common types like NSNumber, AXValue (for CGPoint etc.) as needed

            // If no specific conversion worked, try a direct cast (might work for Any or some CF-bridged types)
            if let directCast = unwrappedValue as? T {
                dLog("Element.attribute: Basic conversion succeeded with direct cast for T = \(String(describing: T.self)), Attribute: \(attribute.rawValue).")
                return directCast
            }

            dLog("Element.attribute: Basic conversion FAILED for T = \(String(describing: T.self)), Attribute: \(attribute.rawValue). Value type: \(CFGetTypeID(unwrappedValue))")
            return nil
        }
    }

    // Method to get the raw CFTypeRef? for an attribute
    // This is useful for functions like attributesMatch that do their own CFTypeID checking.
    // This also needs to be @MainActor as AXUIElementCopyAttributeValue should be on main thread.
    @MainActor
    public func rawAttributeValue(
        named attributeName: String,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) -> CFTypeRef? {
        func dLog(_ message: String) {
            if isDebugLoggingEnabled && false {
                currentDebugLogs.append(AXorcist.formatDebugLogMessage(message, applicationName: nil, commandID: nil, file: #file, function: #function, line: #line))
            }
        }
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(self.underlyingElement, attributeName as CFString, &value)
        if error == .success {
            return value // Caller is responsible for CFRelease if it's a new object they own.
            // For many get operations, this is a copy-get rule, but some are direct gets.
            // Since we just return it, the caller should be aware or this function should manage it.
            // Given AXSwift patterns, often the raw value isn't directly exposed like this,
            // or it is clearly documented. For now, let's assume this is for internal use by attributesMatch
            // which previously used copyAttributeValue which likely returned a +1 ref count object.
        } else if error == .attributeUnsupported {
            dLog("rawAttributeValue: Attribute \(attributeName) unsupported for element \(self.underlyingElement)")
        } else if error == .noValue {
            dLog("rawAttributeValue: Attribute \(attributeName) has no value for element \(self.underlyingElement)")
        } else {
            dLog(
                "rawAttributeValue: Error getting attribute \(attributeName) for element \(self.underlyingElement): \(error.rawValue)"
            )
        }
        return nil // Return nil if not success or if value was nil (though success should mean value is populated)
    }

    // Remaining properties and methods will stay here for now
    // (e.g., children, parameterizedAttribute, briefDescription, generatePathString, static factories)
    // Action methods have been moved to Element+Actions.swift

    // @MainActor public var children: [Element]? { ... }

    // @MainActor
    // public func generatePathString() -> String { ... }

    // MARK: - Attribute Accessors (Raw and Typed)

    // ... existing attribute accessors ...

    // MARK: - Computed Properties for Common Attributes & Heuristics

    // ... existing properties like role, title, isEnabled ...

    /// A computed name for the element, derived from common attributes like title, value, description, etc.
    /// This provides a general-purpose, human-readable name.
    @MainActor
    // Convert from a computed property to a method to accept logging parameters
    public func computedName(isDebugLoggingEnabled: Bool, currentDebugLogs: inout [String]) -> String? {
        // Now uses the passed-in logging parameters for its internal calls
        if let titleStr = self.title(isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs),
           !titleStr.isEmpty, titleStr != AXMiscConstants.kAXNotAvailableString { return titleStr }

        if let valueStr: String = self.value(
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        ) as? String, !valueStr.isEmpty, valueStr != AXMiscConstants.kAXNotAvailableString { return valueStr }

        if let descStr = self.description(
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        ), !descStr.isEmpty, descStr != AXMiscConstants.kAXNotAvailableString { return descStr }

        if let helpStr: String = self.attribute(
            Attribute<String>(AXAttributeNames.kAXHelpAttribute),
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        ), !helpStr.isEmpty, helpStr != AXMiscConstants.kAXNotAvailableString { return helpStr }
        if let phValueStr: String = self.attribute(
            Attribute<String>(AXAttributeNames.kAXPlaceholderValueAttribute),
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        ), !phValueStr.isEmpty, phValueStr != AXMiscConstants.kAXNotAvailableString { return phValueStr }

        let roleNameStr: String = self.role(
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        ) ?? "Element"

        if let roleDescStr: String = self.roleDescription(
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        ), !roleDescStr.isEmpty, roleDescStr != AXMiscConstants.kAXNotAvailableString {
            return "\(roleDescStr) (\(roleNameStr))"
        }
        return nil
    }

    // MARK: - Path and Hierarchy
}
