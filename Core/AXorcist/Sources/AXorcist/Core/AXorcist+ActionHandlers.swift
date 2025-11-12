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
        self.logPerformActionStart(command)

        let appIdentifier = command.appIdentifier ?? "focused"
        let (foundElement, errorMessage) = findTargetElement(
            for: appIdentifier,
            locator: command.locator,
            maxDepthForSearch: command.maxDepthForSearch
        )

        guard let element = foundElement else {
            let fallback = missingElementMessage(
                prefix: "HandlePerformAction",
                appIdentifier: appIdentifier,
                locatorDescription: String(describing: command.locator)
            )
            let message = errorMessage ?? fallback
            GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: message))
            return .errorResponse(message: message, code: .elementNotFound)
        }

        if let errorResponse = self.validateActionSupport(command.action, for: element) {
            return errorResponse
        }
        return self.execute(action: command.action, on: element, value: command.value)
    }

    // MARK: - Set Focused Value Handler

    func handleSetFocusedValue(command: SetFocusedValueCommand) -> AXResponse {
        self.logSetFocusedValueStart(command)

        let appIdentifier = command.appIdentifier ?? "focused"
        let (foundElement, errorMessage) = findTargetElement(
            for: appIdentifier,
            locator: command.locator,
            maxDepthForSearch: command.maxDepthForSearch
        )

        guard let element = foundElement else {
            let fallback = missingElementMessage(
                prefix: "HandleSetFocusedValue",
                appIdentifier: appIdentifier,
                locatorDescription: String(describing: command.locator)
            )
            let message = errorMessage ?? fallback
            GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: message))
            return .errorResponse(message: message, code: .elementNotFound)
        }

        if self.ensureFocusCapability(for: element) {
            self.setFocus(on: element)
        }
        return self.setValue(command.value, on: element)
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

// MARK: - Shared Helpers

extension AXorcist {
    private func logPerformActionStart(_ command: PerformActionCommand) {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .info,
            message: "HandlePerformAction: App '\(String(describing: command.appIdentifier))', " +
                "Locator: \(command.locator), Action: \(command.action), " +
                "Value: \(String(describing: command.value))"
        ))
    }

    private func logSetFocusedValueStart(_ command: SetFocusedValueCommand) {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .info,
            message: "HandleSetFocusedValue: App '\(String(describing: command.appIdentifier))', " +
                "Locator: \(command.locator), Value: '\(command.value)'"
        ))
    }

    private func validateActionSupport(_ action: String, for element: Element) -> AXResponse? {
        guard element.isActionSupported(action) else {
            let description = element.briefDescription(option: ValueFormatOption.smart)
            let errorMessage = "HandlePerformAction: Action '\(action)' is NOT supported by element \(description)."
            GlobalAXLogger.shared.log(AXLogEntry(level: .warning, message: errorMessage))
            let availableActions = element.supportedActions() ?? []
            let message = "\(errorMessage) Available actions: [\(availableActions.joined(separator: ", "))]"
            return .errorResponse(message: message, code: .actionNotSupported)
        }
        return nil
    }

    private func execute(action: String, on element: Element, value: AnyCodable?) -> AXResponse {
        if let actionValue = value?.value {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .warning,
                message: "HandlePerformAction: Action value provided but not used: \(actionValue)"
            ))
        }

        do {
            try element.performAction(action)
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .info,
                message: "HandlePerformAction: Successfully performed action '\(action)' on " +
                    "\(element.briefDescription(option: ValueFormatOption.smart))."
            ))
            return .successResponse(
                payload: AnyCodable(["message": "Action '\(action)' performed successfully."])
            )
        } catch {
            let errorMessage = "HandlePerformAction: Failed to perform action '\(action)' on " +
                "\(element.briefDescription(option: ValueFormatOption.smart)). Error: \(error)"
            GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: errorMessage))
            return .errorResponse(message: errorMessage, code: .actionFailed)
        }
    }

    private func ensureFocusCapability(for element: Element) -> Bool {
        if element.isAttributeSettable(named: AXAttributeNames.kAXFocusedAttribute) {
            return true
        }

        let elementDescription = element.briefDescription(option: ValueFormatOption.smart)
        guard element.isActionSupported(AXActionNames.kAXPressAction) else {
            let focusError = [
                "HandleSetFocusedValue: Element \(elementDescription) is not focusable",
                "(kAXFocusedAttribute not settable and kAXPressAction not supported)."
            ].joined(separator: " ")
            GlobalAXLogger.shared.log(AXLogEntry(level: .warning, message: focusError))
            return false
        }

        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "HandleSetFocusedValue: Element not directly focusable by kAXFocusedAttribute, " +
                "but supports kAXPressAction. Attempting press."
        ))
        do {
            try element.performAction(.press)
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .debug,
                message: "HandleSetFocusedValue: Successfully pressed element to potentially gain focus."
            ))
        } catch {
            let pressError = [
                "HandleSetFocusedValue: Element \(elementDescription) could not be pressed",
                "to potentially gain focus."
            ].joined(separator: " ")
            GlobalAXLogger.shared.log(AXLogEntry(level: .warning, message: pressError))
        }
        return false
    }

    private func setFocus(on element: Element) {
        let elementDescription = element.briefDescription(option: ValueFormatOption.smart)
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "HandleSetFocusedValue: Attempting to set kAXFocusedAttribute to true for \(elementDescription)"
        ))
        if element.setValue(true, forAttribute: AXAttributeNames.kAXFocusedAttribute) { return }
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .warning,
            message: [
                "HandleSetFocusedValue: Failed to set kAXFocusedAttribute for \(elementDescription),",
                "but proceeding to set value."
            ].joined(separator: " ")
        ))
    }

    private func setValue(_ value: String, on element: Element) -> AXResponse {
        let elementDescription = element.briefDescription(option: ValueFormatOption.smart)
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "HandleSetFocusedValue: Attempting to set kAXValueAttribute to '\(value)' " +
                "for \(elementDescription)"
        ))
        if element.setValue(value, forAttribute: AXAttributeNames.kAXValueAttribute) {
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .info,
                message: "HandleSetFocusedValue: Successfully set value for \(elementDescription)."
            ))
            return .successResponse(
                payload: AnyCodable(["message": "Value '\(value)' set successfully on focused element."])
            )
        }

        let setError = "HandleSetFocusedValue: Failed to set kAXValueAttribute for \(elementDescription)."
        GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: setError))
        return .errorResponse(message: setError, code: .actionFailed)
    }

    private func missingElementMessage(prefix: String, appIdentifier: String, locatorDescription: String) -> String {
        "\(prefix): Element not found for app '\(appIdentifier)' with locator \(locatorDescription)."
    }
}
