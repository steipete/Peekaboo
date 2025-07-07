// ObserverTypes.swift - Types and structs for AXObserver management

import ApplicationServices
import Foundation

/// Handler function type for accessibility notification callbacks.
///
/// This handler is called when an observed accessibility notification occurs.
/// Parameters include the process ID, notification type, raw element reference,
/// and optional user info dictionary. The handler runs on the main actor
/// to ensure UI safety.
public typealias AXNotificationSubscriptionHandler = @MainActor ( /* element: Element, */
    pid_t,
    AXNotification,
    _ rawElement: AXUIElement,
    _ nsUserInfo: [String: Any]?
) -> Void

/// Key for tracking accessibility notification subscriptions.
///
/// Allows for both process-specific and global notification observers.
/// When `pid` is nil, the subscription applies globally for that notification type.
public struct AXNotificationSubscriptionKey: Hashable {
    /// Process ID to monitor, or nil for global monitoring.
    let pid: pid_t?

    /// The accessibility notification type to observe.
    let notification: AXNotification
}

/// Key combining process ID and notification type for observer tracking.
///
/// Used internally to manage active accessibility observers for specific
/// combinations of processes and notification types.
public struct AXObserverKeyAndPID: Hashable {
    /// Process ID being observed.
    let pid: pid_t

    /// Notification type being monitored.
    let key: AXNotification
}

/// Container for an active accessibility observer and its target process.
///
/// Pairs an AXObserver instance with the process ID it's monitoring,
/// used for managing the lifecycle of accessibility observers.
public struct AXObserverObjAndPID {
    /// The active accessibility observer.
    var observer: AXObserver

    /// Process ID that this observer is monitoring.
    var pid: pid_t
}

/// Token returned when subscribing to accessibility notifications.
///
/// Use this token to unsubscribe from notifications when they're no longer needed.
/// The token ensures that only the original subscriber can cancel the subscription.
///
/// ## Usage
///
/// ```swift
/// let token = observerCenter.subscribe(to: .valueChanged, for: pid) { ... }
/// // Later...
/// observerCenter.unsubscribe(token)
/// ```
public struct SubscriptionToken: Hashable {
    /// Unique identifier for this subscription.
    let id: UUID
}
