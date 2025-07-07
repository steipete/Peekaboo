// AXorcist+CommandHandlers.swift - Command handler methods for AXorcist

import AppKit
import ApplicationServices
import Foundation

// MARK: - Command Handlers Extension
extension AXorcist {

    // Placeholder for getting the focused element.
    // It should accept debug logging parameters and update logs.
    @MainActor
    public func handleGetFocusedElement(
        for appIdentifierOrNil: String? = nil,
        requestedAttributes: [String]? = nil,
        isDebugLoggingEnabled: Bool,
        currentDebugLogs: inout [String]
    ) -> HandlerResponse {
        func dLog(_ message: String) {
            if isDebugLoggingEnabled {
                currentDebugLogs.append(message)
            }
        }

        let appIdentifier = appIdentifierOrNil ?? focusedAppKeyValue
        dLog("[AXorcist.handleGetFocusedElement] Handling for app: \(appIdentifier)")

        guard let appElement = applicationElement(
            for: appIdentifier,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        ) else {
            let errorMsgText = "Application not found: \(appIdentifier)"
            dLog("[AXorcist.handleGetFocusedElement] \(errorMsgText)")
            return HandlerResponse(data: nil, error: errorMsgText, debug_logs: currentDebugLogs)
        }
        dLog("[AXorcist.handleGetFocusedElement] Successfully obtained application element for \(appIdentifier)")

        var cfValue: CFTypeRef?
        let copyAttributeStatus = AXUIElementCopyAttributeValue(
            appElement.underlyingElement,
            AXAttributeNames.kAXFocusedUIElementAttribute as CFString,
            &cfValue
        )

        guard copyAttributeStatus == .success, let rawAXElement = cfValue else {
            dLog(
                "[AXorcist.handleGetFocusedElement] Failed to copy focused element attribute or it was nil. Status: \(axErrorToString(copyAttributeStatus)). Application: \(appIdentifier)"
            )
            return HandlerResponse(
                data: nil,
                error: "Could not get the focused UI element for \(appIdentifier). Ensure a window of the application is focused. AXError: \(axErrorToString(copyAttributeStatus))",
                debug_logs: currentDebugLogs
            )
        }

        guard CFGetTypeID(rawAXElement) == AXUIElementGetTypeID() else {
            dLog(
                "[AXorcist.handleGetFocusedElement] Focused element attribute was not an AXUIElement. Application: \(appIdentifier)"
            )
            return HandlerResponse(
                data: nil,
                error: "Focused element was not a valid UI element for \(appIdentifier).",
                debug_logs: currentDebugLogs
            )
        }

        let focusedElement = Element(rawAXElement as! AXUIElement)
        dLog(
            "[AXorcist.handleGetFocusedElement] Successfully obtained focused element: \(focusedElement.briefDescription(option: .default, isDebugLoggingEnabled: isDebugLoggingEnabled, currentDebugLogs: &currentDebugLogs)) for application \(appIdentifier)"
        )

        let fetchedAttributes = getElementAttributes(
            focusedElement,
            requestedAttributes: requestedAttributes ?? [],
            forMultiDefault: false,
            targetRole: nil,
            outputFormat: .smart,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )

        let elementPathArray = focusedElement.generatePathArray(
            upTo: appElement,
            isDebugLoggingEnabled: isDebugLoggingEnabled,
            currentDebugLogs: &currentDebugLogs
        )

        let axElement = AXElement(attributes: fetchedAttributes, path: elementPathArray)

        return HandlerResponse(data: axElement, error: nil, debug_logs: currentDebugLogs)
    }

    // TODO: Add remaining command handler methods here...
    // This is a placeholder file to demonstrate the refactoring approach
    // The complete implementation would include all handle* methods
}
