// AXUtilities.swift - Utility functions for performing AX actions and setting values.

import ApplicationServices
import Foundation

// GlobalAXLogger is assumed available

@MainActor
public enum AXUtilities {

    public static func performAXAction(_ actionName: String, on element: Element) -> AXError {
        axDebugLog("AXUtilities: Attempting to perform action '\(actionName)' on element: \(element.briefDescription())")
        if element.isActionSupported(actionName) {
            do {
                try element.performAction(Attribute<String>(actionName)) // Assuming actionName is a raw string for a known AXAction
                axDebugLog("AXUtilities: Action '\(actionName)' performed successfully on \(element.briefDescription())")
                return .success
            } catch let error as AccessibilityError {
                axErrorLog("AXUtilities: Action failed for '\(actionName)' on \(element.briefDescription()). Error: \(error)")
                return .failure
            } catch {
                axErrorLog("AXUtilities: Unexpected error performing action '\(actionName)' on \(element.briefDescription()). Error: \(error)")
                return .failure // Generic failure for unexpected errors
            }
        } else {
            axWarningLog("AXUtilities: Action '\(actionName)' is not supported by element \(element.briefDescription())")
            return .actionUnsupported
        }
    }

    public static func performSetValueAction(forElement element: Element, valueToSet: Any?) -> (error: AXError, errorMessage: String?) {
        axDebugLog("AXUtilities: Attempting to set value for element: \(element.briefDescription()) with value: \(String(describing: valueToSet))")

        let attributeName = AXAttributeNames.kAXValueAttribute

        var cfValue: CFTypeRef?
        if let nsValue = valueToSet as? NSObject {
            cfValue = nsValue
        } else if let strValue = valueToSet as? String {
            cfValue = strValue as CFString
        } else if valueToSet == nil {
            axDebugLog("AXUtilities: valueToSet is nil. Attempting to set attribute to nil/empty.")
        } else {
            let errorMsg = "AXUtilities: Value type for attribute '\(attributeName)' is not directly convertible to CFTypeRef: \(String(describing: valueToSet)). Type: \(type(of: valueToSet))"
            axErrorLog(errorMsg)
            return (.apiDisabled, errorMsg)
        }

        let error = AXUIElementSetAttributeValue(element.underlyingElement, attributeName as CFString, cfValue ?? CFConstants.cfBooleanFalse!)

        if error == .success {
            axDebugLog("AXUtilities: Successfully set attribute '\(attributeName)' on \(element.briefDescription())")
            return (.success, nil)
        } else {
            let errorMsg = "AXUtilities: Failed to set attribute '\(attributeName)' on \(element.briefDescription()). Error: \(error)"
            axErrorLog(errorMsg)
            return (error, errorMsg)
        }
    }
}
