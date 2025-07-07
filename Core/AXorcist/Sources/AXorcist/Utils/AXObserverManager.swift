import ApplicationServices
import CoreFoundation
import Foundation

@MainActor
public class AXObserverManager {
    // MARK: Lifecycle

    private init() {}

    // MARK: Public

    // Typealias for notification callback - matches AXObserverCallbackWithInfo but without refcon
    public typealias AXNotificationCallback = (AXObserver, AXUIElement, CFString, CFDictionary?) -> Void

    // Error types
    public enum ObserverError: Error {
        case couldNotCreateObserver
        case addNotificationFailed(AXError)
        case other(String)
    }

    // Singleton instance
    public static let shared = AXObserverManager()

    // Add observer for an element and notification
    public func addObserver(
        for element: Element,
        notification: AXNotification,
        callback: @escaping AXNotificationCallback
    ) throws {
        let elementId = ObjectIdentifier(element.underlyingElement as AnyObject)

        observerLock.lock()
        defer { observerLock.unlock() }

        // Check if we already have an observer for this element
        if var observerInfo = observers[elementId] {
            // Add the callback for this notification
            observerInfo.callbacks[notification.rawValue as CFString] = callback
            observers[elementId] = observerInfo

            // Add the notification to the existing observer
            let error = AXObserverAddNotification(
                observerInfo.observer,
                element.underlyingElement,
                notification.rawValue as CFString,
                nil
            )
            if error != .success {
                axErrorLog("Failed to add notification: \(error)")
                throw ObserverError.addNotificationFailed(error)
            }
        } else {
            // Create a new observer
            guard let pid = element.pid() else {
                throw ObserverError.other("Could not get PID for element")
            }

            var observer: AXObserver?

            // Create the callback function for the observer
            let observerCallback: AXObserverCallbackWithInfo = { observer, element, notification, userInfo, _ in
                // Since we can't pass refcon through AXObserverCreateWithInfoCallback,
                // we need to use a different approach to get back to the manager
                AXObserverManager.shared.handleNotification(
                    observer: observer,
                    element: element,
                    notification: notification,
                    userInfo: userInfo
                )
            }

            let error = AXObserverCreateWithInfoCallback(
                pid,
                observerCallback,
                &observer
            )

            guard error == .success, let observer else {
                axErrorLog("Failed to create observer: \(error)")
                throw ObserverError.couldNotCreateObserver
            }

            // Add the notification
            let addError = AXObserverAddNotification(
                observer,
                element.underlyingElement,
                notification.rawValue as CFString,
                nil
            )
            if addError != .success {
                axErrorLog("Failed to add notification: \(addError)")
                throw ObserverError.addNotificationFailed(addError)
            }

            // Get the run loop source and add it to the main run loop
            let runLoopSource = AXObserverGetRunLoopSource(observer)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

            // Store the observer info
            var callbacks: [CFString: AXNotificationCallback] = [:]
            callbacks[notification.rawValue as CFString] = callback
            let observerInfo = ObserverInfo(
                observer: observer,
                runLoopSource: runLoopSource,
                callbacks: callbacks
            )
            observers[elementId] = observerInfo

            axDebugLog("Created observer for PID \(pid) with notification \(notification.rawValue)")
        }
    }

    // Remove observer for an element and notification
    public func removeObserver(for element: Element, notification: AXNotification) throws {
        let elementId = ObjectIdentifier(element.underlyingElement as AnyObject)

        observerLock.lock()
        defer { observerLock.unlock() }

        guard var observerInfo = observers[elementId] else {
            // No observer for this element
            return
        }

        // Remove the notification from the observer
        let error = AXObserverRemoveNotification(
            observerInfo.observer,
            element.underlyingElement,
            notification.rawValue as CFString
        )
        if error != .success {
            axErrorLog("Failed to remove notification: \(error)")
            throw ObserverError.other("Failed to remove notification: \(error)")
        }

        // Remove the callback
        observerInfo.callbacks.removeValue(forKey: notification.rawValue as CFString)

        // If no more callbacks, remove the observer entirely
        if observerInfo.callbacks.isEmpty {
            // Remove from run loop
            CFRunLoopRemoveSource(CFRunLoopGetMain(), observerInfo.runLoopSource, .defaultMode)

            // Invalidate the observer
            CFRunLoopSourceInvalidate(observerInfo.runLoopSource)

            // Remove from our storage
            observers.removeValue(forKey: elementId)

            axDebugLog("Removed observer for element")
        } else {
            // Update the observer info with removed callback
            observers[elementId] = observerInfo
        }
    }

    // Remove all observers
    public func removeAllObservers() {
        observerLock.lock()
        defer { observerLock.unlock() }

        for (_, observerInfo) in observers {
            // Remove from run loop
            CFRunLoopRemoveSource(CFRunLoopGetMain(), observerInfo.runLoopSource, .defaultMode)

            // Invalidate the observer
            CFRunLoopSourceInvalidate(observerInfo.runLoopSource)
        }

        observers.removeAll()
        axDebugLog("Removed all observers")
    }

    // MARK: Private

    // Private storage for observers and callbacks
    private struct ObserverInfo {
        let observer: AXObserver
        let runLoopSource: CFRunLoopSource
        var callbacks: [CFString: AXNotificationCallback] = [:]
    }

    private var observers: [ObjectIdentifier: ObserverInfo] = [:]
    private let observerLock = NSLock()

    // Handle incoming notifications
    private func handleNotification(
        observer: AXObserver,
        element: AXUIElement,
        notification: CFString,
        userInfo: CFDictionary?
    ) {
        let elementId = ObjectIdentifier(element as AnyObject)

        observerLock.lock()
        let observerInfo = observers[elementId]
        observerLock.unlock()

        guard let observerInfo,
              let callback = observerInfo.callbacks[notification]
        else {
            axWarningLog("Received notification '\(notification)' but no callback found")
            return
        }

        // Call the callback
        callback(observer, element, notification, userInfo)
    }
}
