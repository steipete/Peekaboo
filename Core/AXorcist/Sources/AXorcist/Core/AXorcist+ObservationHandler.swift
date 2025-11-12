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
        logObservationStart(command)

        let appIdentifier = command.appIdentifier ?? "focused"
        let locator = makeObservationLocator()

        let (targetElement, error) = findTargetElement(
            for: appIdentifier,
            locator: locator,
            maxDepthForSearch: command.maxDepthForSearch
        )

        guard let elementToObserve = targetElement else {
            return observationNotFoundResponse(
                appIdentifier: appIdentifier,
                locator: locator,
                error: error
            )
        }

        logObservationTarget(elementToObserve)

        let callback = makeObservationCallback()
        return startObservation(
            element: elementToObserve,
            command: command,
            callback: callback
        )
    }

    private func logObservationStart(_ command: ObserveCommand) {
        let details = command.includeElementDetails?.joined(separator: ", ") ?? "none"
        let message = [
            "HandleObserve: App \(command.appIdentifier ?? "focused")",
            "Notifications: \(command.notificationName.rawValue)",
            "Details: \(details)"
        ].joined(separator: ", ")
        GlobalAXLogger.shared.log(AXLogEntry(level: .info, message: message))
    }

    private func makeObservationLocator() -> Locator {
        let criteria = [Criterion(attribute: "pid", value: "self", matchType: .exact)]
        return Locator(criteria: criteria)
    }

    private func logObservationTarget(_ element: Element) {
        let message = [
            "HandleObserve: Element to observe:",
            element.briefDescription(option: ValueFormatOption.smart)
        ].joined(separator: " ")
        GlobalAXLogger.shared.log(AXLogEntry(level: .debug, message: message))
    }

    private func observationNotFoundResponse(
        appIdentifier: String,
        locator: Locator,
        error: String?
    ) -> AXResponse {
        let fallback = [
            "HandleObserve: Element to observe not found for app '\(appIdentifier)'",
            "locator \(String(describing: locator))"
        ].joined(separator: ", ")
        let errorMessage = error ?? fallback
        GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: errorMessage))
        return .errorResponse(message: errorMessage, code: .elementNotFound)
    }

    private func startObservation(
        element: Element,
        command: ObserveCommand,
        callback: @escaping AXObserverManager.AXNotificationCallback
    ) -> AXResponse {
        do {
            try AXObserverManager.shared.addObserver(
                for: element,
                notification: command.notificationName,
                callback: callback
            )
            let successMessage = [
                "HandleObserve: Successfully started observing '\(command.notificationName)' on",
                element.briefDescription(option: ValueFormatOption.smart)
            ].joined(separator: " ")
            GlobalAXLogger.shared.log(AXLogEntry(level: .info, message: successMessage))
            return .successResponse(payload: AnyCodable(["message": successMessage]))
        } catch let obError as AXObserverManager.ObserverError {
            let details = [
                "HandleObserve: Failed to add observer.",
                "Error: \(obError.localizedDescription) (Code: \(obError))",
                "Pid: \(element.pid()?.description ?? "N/A")",
                "Notification: \(command.notificationName)"
            ].joined(separator: " ")
            GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: details))
            return .errorResponse(message: details, code: .observationFailed)
        } catch {
            let details = [
                "HandleObserve: Failed to add observer with unknown error:",
                error.localizedDescription,
                "Element:",
                element.briefDescription(option: ValueFormatOption.smart),
                "Notification: \(command.notificationName)"
            ].joined(separator: " ")
            GlobalAXLogger.shared.log(AXLogEntry(level: .error, message: details))
            return .errorResponse(message: details, code: .observationFailed)
        }
    }

    private func makeObservationCallback() -> AXObserverManager.AXNotificationCallback {
        { _, axUIElement, notification, userInfo in
            let element = Element(axUIElement)
            let userInfoDesc = userInfo.map(String.init(describing:)) ?? "nil"
            let message = [
                "AXObserver CALLBACK:",
                "Element: \(element.briefDescription(option: ValueFormatOption.smart))",
                "Notification: \(notification as String)",
                "UserInfo: \(userInfoDesc)"
            ].joined(separator: " ")
            GlobalAXLogger.shared.log(AXLogEntry(level: .info, message: message))
        }
    }
}
