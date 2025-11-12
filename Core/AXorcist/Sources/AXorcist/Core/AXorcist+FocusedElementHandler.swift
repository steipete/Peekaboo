import ApplicationServices
import Foundation

/// Extension providing focused element discovery and handling for AXorcist.
///
/// This extension handles:
/// - Retrieving the currently focused accessibility element
/// - Cross-application focus tracking
/// - Focused element attribute extraction
/// - Focus change monitoring and reporting
/// - Integration with application targeting
@MainActor
public extension AXorcist {
    func handleGetFocusedElement(command: GetFocusedElementCommand) -> AXResponse {
        let appInfo = String(describing: command.appIdentifier)
        let attributes = command.attributesToReturn?.joined(separator: ", ") ?? "default"
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .info,
            message: "HandleGetFocused: App '\(appInfo)', Attributes: \(attributes)"
        ))

        guard let appElement = getApplicationElement(for: command.appIdentifier ?? "focused") else {
            let target = String(describing: command.appIdentifier)
            let errorMessage =
                "HandleGetFocused: Could not get application element for '\(target)'."
            GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: errorMessage))
            return .errorResponse(message: errorMessage, code: .elementNotFound)
        }
        let appDescription = appElement.briefDescription(option: ValueFormatOption.smart)
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "HandleGetFocused: Got app element: \(appDescription)"
        ))

        guard let focusedElement = appElement.focusedUIElement() else {
            let target = String(describing: command.appIdentifier)
            let elementDescription = appElement.briefDescription(option: ValueFormatOption.smart)
            let errorMessage =
                "HandleGetFocused: No focused element found for application '\(target)' (\(elementDescription))."
            GlobalAXLogger.shared.log(AXLogEntry(level: .info, message: errorMessage))
            // This is not necessarily an error, could be a valid state.
            // Return success with an empty payload or specific indication.
            return .successResponse(payload: AnyCodable(NoFocusPayload(message: "No focused element found.")))
        }
        let focusedDescription = focusedElement.briefDescription(option: ValueFormatOption.smart)
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "HandleGetFocused: Focused element: \(focusedDescription)"
        ))

        let attributesToFetch = command.attributesToReturn ?? AXMiscConstants.defaultAttributesToFetch
        let elementData = buildQueryResponse(
            element: focusedElement,
            attributesToFetch: attributesToFetch,
            includeChildrenBrief: command.includeChildrenBrief ?? false
        )

        return .successResponse(payload: AnyCodable(elementData))
    }
}
