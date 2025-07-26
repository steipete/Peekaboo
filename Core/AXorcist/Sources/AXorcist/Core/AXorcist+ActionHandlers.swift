import AppKit // For NSRunningApplication & NSValue
import ApplicationServices
import Foundation

/// Extension providing action execution handlers for AXorcist.
///
/// This extension handles:
/// - Performing accessibility actions on UI elements
/// - Action validation and error handling
/// - Setting element values (text, numeric, selection)
/// - Complex action coordination and validation
/// - Integration with element discovery and targeting
@MainActor
public extension AXorcist {
    // MARK: - Perform Action Handler

    func handlePerformAction(command: PerformActionCommand) -> AXResponse {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .info,
            message: "HandlePerformAction: App '\(String(describing: command.appIdentifier))', " +
                "Locator: \(command.locator), Action: \(command.action), " +
                "Value: \(String(describing: command.value))"
        ))

        let (foundElement, error) = findTargetElement(
            for: command.appIdentifier ?? "focused",
            locator: command.locator,
            maxDepthForSearch: command.maxDepthForSearch
        )

        guard let element = foundElement else {
            let errorMessage = error ?? "HandlePerformAction: Element not found for app " +
                "'\(String(describing: command.appIdentifier))' with locator \(command.locator)."
            GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: errorMessage))
            return .errorResponse(message: errorMessage, code: .elementNotFound)
        }
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "HandlePerformAction: Found element: " +
                "\(element.briefDescription(option: ValueFormatOption.smart))"
        ))

        // Check if action is supported before attempting
        if !element.isActionSupported(command.action) {
            let errorMessage = "HandlePerformAction: Action '\(command.action)' " +
                "is NOT supported by element " +
                "\(element.briefDescription(option: ValueFormatOption.smart))."
            GlobalAXLogger.shared.log(AXLogEntry(level: .warning, message: errorMessage))
            // Get available actions for better error reporting
            let availableActions = element.supportedActions() ?? []
            return .errorResponse(
                message: "\(errorMessage) Available actions: " +
                    "[\(availableActions.joined(separator: ", "))]",
                code: .actionNotSupported
            )
        }

        do {
            // Note: The performAction method doesn't take a value parameter
            // If the action requires a value, it should be set separately
            if let actionValue = command.value?.value {
                GlobalAXLogger.shared.log(AXLogEntry(
                    level: .warning,
                    message: "HandlePerformAction: Action value provided but not used: \(actionValue)"
                ))
            }

            try element.performAction(command.action)
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .info,
                message: "HandlePerformAction: Successfully performed action " +
                    "'\(command.action)' on " +
                    "\(element.briefDescription(option: ValueFormatOption.smart))."
            ))
            return .successResponse(
                payload: AnyCodable(["message": "Action '\(command.action)' performed successfully."])
            )
        } catch {
            let errorMessage = "HandlePerformAction: Failed to perform action " +
                "'\(command.action)' on " +
                "\(element.briefDescription(option: ValueFormatOption.smart)). " +
                "Error: \(error)"
            GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: errorMessage))
            return .errorResponse(message: errorMessage, code: .actionFailed)
        }
    }

    // MARK: - Set Focused Value Handler

    func handleSetFocusedValue(command: SetFocusedValueCommand) -> AXResponse {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .info,
            message: "HandleSetFocusedValue: App '\(String(describing: command.appIdentifier))', " +
                "Locator: \(command.locator), Value: '\(command.value)'"
        ))

        let (foundElement, error) = findTargetElement(
            for: command.appIdentifier ?? "focused",
            locator: command.locator,
            maxDepthForSearch: command.maxDepthForSearch
        )

        guard let element = foundElement else {
            let errorMessage = error ?? "HandleSetFocusedValue: Element not found for app " +
                "'\(String(describing: command.appIdentifier))' with locator \(command.locator)."
            GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: errorMessage))
            return .errorResponse(message: errorMessage, code: .elementNotFound)
        }
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "HandleSetFocusedValue: Found element: " +
                "\(element.briefDescription(option: ValueFormatOption.smart))"
        ))

        // Make sure the element is focusable, then focus it, then set its value.
        // This is a common pattern for text fields.

        // 1. Check if focusable (kAXFocusedAttribute should be settable)
        var isFocusable = false
        // Check if the element can have the focused attribute set
        if element.isAttributeSettable(named: AXAttributeNames.kAXFocusedAttribute) {
            isFocusable = true
        }

        if !isFocusable {
            // If not directly focusable by kAXFocusedAttribute, check if it can perform
            // kAXPressAction, which might make it focusable.
            if element.isActionSupported(AXActionNames.kAXPressAction) {
                GlobalAXLogger.shared.log(AXLogEntry(
                    level: .debug,
                    message: "HandleSetFocusedValue: Element not directly " +
                        "focusable by kAXFocusedAttribute, but supports kAXPressAction. " +
                        "Attempting press."
                ))
                do {
                    try element.performAction(.press)
                    GlobalAXLogger.shared.log(AXLogEntry(
                        level: .debug,
                        message: "HandleSetFocusedValue: Successfully pressed " +
                            "element to potentially gain focus."
                    ))
                } catch {
                    let pressError = "HandleSetFocusedValue: Element " +
                        "\(element.briefDescription(option: ValueFormatOption.smart)) " +
                        "could not be pressed to potentially gain focus."
                    GlobalAXLogger.shared.log(AXLogEntry(level: .warning, message: pressError))
                    // Continue to try setting value, but log this warning.
                }
            } else {
                let focusError = "HandleSetFocusedValue: Element " +
                    "\(element.briefDescription(option: ValueFormatOption.smart)) " +
                    "is not focusable (kAXFocusedAttribute not settable and " +
                    "kAXPressAction not supported). Cannot reliably set focused value."
                GlobalAXLogger.shared.log(AXLogEntry(level: .warning, message: focusError))
                // Proceed to set value anyway, but this is a warning.
            }
        }

        // 2. Attempt to set focus (best effort)
        if isFocusable {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "HandleSetFocusedValue: Attempting to set " +
                    "kAXFocusedAttribute to true for " +
                    "\(element.briefDescription(option: ValueFormatOption.smart))"
            ))
            if !element.setValue(true, forAttribute: AXAttributeNames.kAXFocusedAttribute) {
                GlobalAXLogger.shared.log(AXLogEntry(
                    level: .warning,
                    message: "HandleSetFocusedValue: Failed to set " +
                        "kAXFocusedAttribute for " +
                        "\(element.briefDescription(option: ValueFormatOption.smart)), " +
                        "but proceeding to set value."
                ))
            } else {
                // Short delay to allow UI to catch up after focusing, if necessary.
                // Consider if this is needed based on app behavior.
                // Thread.sleep(forTimeInterval: 0.05)
            }
        }

        // 3. Set the value (kAXValueAttribute)
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "HandleSetFocusedValue: Attempting to set " +
                "kAXValueAttribute to '\(command.value)' for " +
                "\(element.briefDescription(option: ValueFormatOption.smart))"
        ))
        if element.setValue(command.value, forAttribute: AXAttributeNames.kAXValueAttribute) {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .info,
                message: "HandleSetFocusedValue: Successfully set value for " +
                    "\(element.briefDescription(option: ValueFormatOption.smart))."
            ))
            return .successResponse(
                payload: AnyCodable([
                    "message": "Value '\(command.value)' set successfully on focused element.",
                ])
            )
        } else {
            let setError = "HandleSetFocusedValue: Failed to set " +
                "kAXValueAttribute for " +
                "\(element.briefDescription(option: ValueFormatOption.smart))."
            GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: setError))
            return .errorResponse(message: setError, code: .actionFailed)
        }
    }

    // MARK: - Extract Text Handler

    func handleExtractText(command: ExtractTextCommand) -> AXResponse {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .info,
            message: "HandleExtractText: App '\(String(describing: command.appIdentifier))', " +
                "Locator: \(command.locator), " +
                "IncludeChildren: \(String(describing: command.includeChildren)), " +
                "MaxDepth: \(String(describing: command.maxDepth))"
        ))

        let (foundElement, error) = findTargetElement(
            for: command.appIdentifier ?? "focused",
            locator: command.locator,
            maxDepthForSearch: command.maxDepthForSearch
        )

        guard let element = foundElement else {
            let errorMessage = error ?? "HandleExtractText: Element not found for app " +
                "'\(String(describing: command.appIdentifier))' with locator \(command.locator)."
            GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: errorMessage))
            return .errorResponse(message: errorMessage, code: .elementNotFound)
        }
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "HandleExtractText: Found element: " +
                "\(element.briefDescription(option: ValueFormatOption.smart))"
        ))

        if let textContent = getElementTextualContent(
            element: element,
            includeChildren: command.includeChildren ?? true,
            maxDepth: command.maxDepth ?? 5
        ) {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .info,
                message: "HandleExtractText: Extracted text: '\(textContent)'"
            ))
            return .successResponse(payload: AnyCodable(TextPayload(text: textContent)))
        } else {
            let message = "HandleExtractText: No text content found for " +
                "element \(element.briefDescription(option: ValueFormatOption.smart))."
            GlobalAXLogger.shared.log(AXLogEntry(level: .info, message: message))
            return .successResponse(payload: AnyCodable(TextPayload(text: ""))) // Success, but no text
        }
    }
}
