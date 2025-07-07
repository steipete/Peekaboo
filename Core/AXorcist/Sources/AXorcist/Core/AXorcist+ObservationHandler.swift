import ApplicationServices
import Foundation

/// Extension providing accessibility notification observation handlers for AXorcist.
///
/// This extension handles:
/// - Setting up AXObserver instances for notifications
/// - Managing notification subscriptions and callbacks
/// - Real-time event monitoring and processing
/// - Element detail extraction for observed events
/// - Cleanup and lifecycle management of observers
@MainActor
public extension AXorcist {
    func handleObserve(command: ObserveCommand) -> AXResponse {
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .info,
            message: "HandleObserve: App \(command.appIdentifier ?? "focused"), " +
                "Notifications: \(command.notificationName.rawValue), " +
                "Details: \(command.includeElementDetails?.joined(separator: ", ") ?? "none")"
        ))

        let appIdentifier = command.appIdentifier ?? "focused"
        // Use Criterion for pid matching
        let criteria = [Criterion(attribute: "pid", value: "self", matchType: .exact)]
        let locator = Locator(criteria: criteria)

        let (targetElement, error) = findTargetElement(
            for: appIdentifier,
            locator: locator,
            maxDepthForSearch: command.maxDepthForSearch
        )

        guard let elementToObserve = targetElement else {
            let errorMessage = error ??
                "HandleObserve: Element to observe not found for app '\(appIdentifier)' with locator \(String(describing: locator))."
            GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: errorMessage))
            return .errorResponse(message: errorMessage, code: .elementNotFound)
        }
        GlobalAXLogger.shared.log(AXLogEntry(
            level: .debug,
            message: "HandleObserve: Element to observe: \(elementToObserve.briefDescription(option: ValueFormatOption.smart))"
        ))

        let callback: AXObserverManager.AXNotificationCallback = { _, axUIElement, notification, userInfo in
            let element = Element(axUIElement)
            let userInfoDesc = userInfo != nil ? String(describing: userInfo!) : "nil"
            GlobalAXLogger.shared.log(AXLogEntry(
                level: .info,
                message: "AXObserver CALLBACK: Element: \(element.briefDescription(option: ValueFormatOption.smart)), " +
                    "Notification: \(notification as String), UserInfo: \(userInfoDesc)"
            ))

            // Here, you would typically send this event data back to the client that initiated the observation.
            // This might involve a registered callback URL, a WebSocket, or another IPC mechanism.
            // For now, we just log it.
        }

        do {
            try AXObserverManager.shared.addObserver(
                for: elementToObserve,
                notification: command.notificationName,
                callback: callback
            )
            let successMessage =
                "HandleObserve: Successfully started observing '\(command.notificationName)' on \(elementToObserve.briefDescription(option: ValueFormatOption.smart))."
            GlobalAXLogger.shared.log(AXLogEntry(level: .info, message: successMessage))
            return .successResponse(payload: AnyCodable(["message": successMessage]))
        } catch let obError as AXObserverManager.ObserverError {
            let errorMessage = "HandleObserve: Failed to add observer. " +
                "Error: \(obError.localizedDescription) (Code: \(obError)). " +
                "Pid for element: \(elementToObserve.pid()?.description ?? "N/A") " +
                "Notification: \(command.notificationName)"
            GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: errorMessage))
            return .errorResponse(message: errorMessage, code: .observationFailed)
        } catch {
            let errorMessage = "HandleObserve: Failed to add observer with unknown error: " +
                "\(error.localizedDescription) for element " +
                "\(elementToObserve.briefDescription(option: ValueFormatOption.smart)) " +
                "Notification: \(command.notificationName)"
            GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: errorMessage))
            return .errorResponse(message: errorMessage, code: .observationFailed)
        }
    }
}
