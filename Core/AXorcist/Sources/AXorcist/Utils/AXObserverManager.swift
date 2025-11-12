import ApplicationServices
import CoreFoundation
import Foundation

/// Manages accessibility observers for monitoring UI element changes.
///
/// `AXObserverManager` provides a centralized system for managing accessibility observers
/// that monitor changes to UI elements. It handles observer lifecycle, notification routing,
/// and ensures proper cleanup of resources.
///
/// ## Overview
///
/// The manager:
/// - Creates and manages AXObserver instances for monitoring UI elements
/// - Routes notifications to appropriate callbacks
/// - Handles observer lifecycle and cleanup
/// - Provides thread-safe observer management
///
/// This is a singleton class that should be accessed via ``shared``.
///
/// ## Topics
///
/// ### Getting the Shared Instance
///
/// - ``shared``
///
/// ### Managing Observers
///
/// - ``addObserver(for:notification:callback:)``
/// - ``removeObserver(for:notification:)``
/// - ``removeAllObservers(for:)``
///
/// ### Types
///
/// - ``AXNotificationCallback``
/// - ``ObserverError``
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

        if var observerInfo = observers[elementId] {
            observerInfo.callbacks[self.notificationKey(for: notification)] = callback
            observers[elementId] = observerInfo

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

            return
        }

        guard let pid = element.pid() else {
            throw ObserverError.other("Could not get PID for element")
        }

        var observer: AXObserver?
        let axCallback: AXObserverCallbackWithInfo = { observer, element, notification, userInfo, _ in
            AXObserverManager.shared.handleNotification(
                observer: observer,
                element: element,
                notification: notification,
                userInfo: userInfo
            )
        }

        let creationError = AXObserverCreateWithInfoCallback(
            pid,
            axCallback,
            &observer
        )

        guard creationError == .success, let observer else {
            axErrorLog("Failed to create observer: \(creationError)")
            throw ObserverError.couldNotCreateObserver
        }

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

        let runLoopSource = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        var callbacks: [CFString: AXNotificationCallback] = [:]
        callbacks[self.notificationKey(for: notification)] = callback

        observers[elementId] = ObserverInfo(
            observer: observer,
            runLoopSource: runLoopSource,
            callbacks: callbacks
        )

        axDebugLog("Created observer for PID \(pid) with notification \(notification.rawValue)")
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

    private func notificationKey(for notification: AXNotification) -> CFString {
        notification.rawValue as CFString
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
