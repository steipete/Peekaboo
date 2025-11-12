// Element+ApplicationActions.swift - Application-specific actions for Element

import ApplicationServices
import Foundation

public extension Element {
    // Helper to set a boolean attribute value.
    // Returns true on success, false on failure.
    @MainActor
    private func setBooleanAttribute(_ attributeName: String, value: Bool) -> Bool {
        let cfValue: CFBoolean = CFConstants.cfBoolean(from: value)
        let error = AXUIElementSetAttributeValue(underlyingElement, attributeName as CFString, cfValue)
        if error != AXError.success {
            axErrorLog(
                "Failed to set attribute \(attributeName) to \(value). "
                    + "Error: \(error.rawValue) - \(error.localizedDescription)"
            )
            return false
        }
        axDebugLog("Successfully set attribute \(attributeName) to \(value).")
        return true
    }

    /// Activates the application represented by this element by bringing it to the front.
    /// This is typically called on an Element representing an application.
    /// - Returns: `true` if the action was successful, `false` otherwise.
    @MainActor
    func activate() -> Bool {
        axDebugLog("Attempting to activate application (element: \(self.briefDescription()))")
        // Try to set kAXFrontmostAttribute. If not settable or fails, fallback to kAXRaiseAction.
        guard isAttributeSettable(named: AXAttributeNames.kAXFrontmostAttribute) else {
            axWarningLog(
                "kAXFrontmostAttribute is not settable for element \(self.briefDescription()). "
                    + "Falling back to .raise action."
            )
            // Use the throwing performAction and handle potential errors, or make it non-throwing if that's the design.
            // For now, assuming it should succeed or log internally, returning bool.
            do {
                try self.performAction(.raise) // Fallback to raise action
                return true // If performAction succeeded
            } catch {
                axErrorLog(
                    "Fallback action .raise failed for element \(self.briefDescription()): "
                        + error.localizedDescription
                )
                return false // If performAction failed
            }
        }
        let success = setBooleanAttribute(AXAttributeNames.kAXFrontmostAttribute, value: true)
        if !success {
            axWarningLog(
                "Setting kAXFrontmostAttribute failed for \(self.briefDescription()). "
                    + "Falling back to .raise action."
            )
            // Similar handling for the fallback action
            do {
                try self.performAction(.raise)
                return true
            } catch {
                axErrorLog(
                    "Fallback action .raise failed after setBooleanAttribute failed for "
                        + "\(self.briefDescription()): \(error.localizedDescription)"
                )
                return false
            }
        }
        return true
    }

    /// Hides the application represented by this element.
    /// This is typically called on an Element representing an application.
    /// - Returns: `true` if the action was successful, `false` otherwise.
    @MainActor
    func hideApplication() -> Bool {
        axDebugLog("Attempting to hide application (element: \(self.briefDescription()))")
        if !isAttributeSettable(named: AXAttributeNames.kAXHiddenAttribute) {
            axWarningLog(
                "Attribute \(AXAttributeNames.kAXHiddenAttribute) is not settable for "
                    + "element \(self.briefDescription())."
            )
            return false
        }
        return setBooleanAttribute(AXAttributeNames.kAXHiddenAttribute, value: true)
    }

    /// Unhides the application represented by this element.
    /// This is typically called on an Element representing an application.
    /// - Returns: `true` if the action was successful, `false` otherwise.
    @MainActor
    func unhideApplication() -> Bool {
        axDebugLog("Attempting to unhide application (element: \(self.briefDescription()))")
        if !isAttributeSettable(named: AXAttributeNames.kAXHiddenAttribute) {
            axWarningLog(
                "Attribute \(AXAttributeNames.kAXHiddenAttribute) is not settable for "
                    + "element \(self.briefDescription())."
            )
            return false
        }
        return setBooleanAttribute(AXAttributeNames.kAXHiddenAttribute, value: false)
    }
}
