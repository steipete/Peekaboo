import AppKit
import Combine
import Foundation

@MainActor
final class WindowEventObserver: NSObject, ObservableObject {
    private let actionLogger: ActionLogger
    private var lastResizeLogAt: [ObjectIdentifier: CFAbsoluteTime] = [:]
    private var lastMoveLogAt: [ObjectIdentifier: CFAbsoluteTime] = [:]

    init(actionLogger: ActionLogger) {
        self.actionLogger = actionLogger
        super.init()
        self.install()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func install() {
        let center = NotificationCenter.default

        let notifications: [NSNotification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.didEnterFullScreenNotification,
            NSWindow.didExitFullScreenNotification,
            NSWindow.willCloseNotification,
            NSWindow.didMoveNotification,
            NSWindow.didResizeNotification,
        ]

        for name in notifications {
            center.addObserver(self, selector: #selector(self.handleWindowNotification(_:)), name: name, object: nil)
        }
    }

    @objc private func handleWindowNotification(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        switch notification.name {
        case NSWindow.didBecomeKeyNotification:
            self.actionLogger.log(.window, "Window became key", details: self.windowDetails(window))
        case NSWindow.didResignKeyNotification:
            self.actionLogger.log(.window, "Window resigned key", details: self.windowDetails(window))
        case NSWindow.didMiniaturizeNotification:
            self.actionLogger.log(.window, "Window minimized", details: self.windowDetails(window))
        case NSWindow.didDeminiaturizeNotification:
            self.actionLogger.log(.window, "Window restored", details: self.windowDetails(window))
        case NSWindow.didEnterFullScreenNotification:
            self.actionLogger.log(.window, "Window entered full screen", details: self.windowDetails(window))
        case NSWindow.didExitFullScreenNotification:
            self.actionLogger.log(.window, "Window exited full screen", details: self.windowDetails(window))
        case NSWindow.willCloseNotification:
            self.actionLogger.log(.window, "Window will close", details: self.windowDetails(window))
        case NSWindow.didMoveNotification:
            self.logThrottledWindowEvent(
                key: ObjectIdentifier(window),
                cache: &self.lastMoveLogAt,
                message: "Window moved",
                window: window)
        case NSWindow.didResizeNotification:
            self.logThrottledWindowEvent(
                key: ObjectIdentifier(window),
                cache: &self.lastResizeLogAt,
                message: "Window resized",
                window: window)
        default:
            break
        }
    }

    private func logThrottledWindowEvent(
        key: ObjectIdentifier,
        cache: inout [ObjectIdentifier: CFAbsoluteTime],
        message: String,
        window: NSWindow)
    {
        let now = CFAbsoluteTimeGetCurrent()
        if let last = cache[key], now - last < 0.5 { return }
        cache[key] = now
        self.actionLogger.log(.window, message, details: self.windowDetails(window))
    }

    private func windowDetails(_ window: NSWindow) -> String {
        let title = window.title.isEmpty ? "[Untitled]" : window.title
        let frame = window.frame.integral
        return "title='\(title)' x=\(Int(frame.origin.x)) y=\(Int(frame.origin.y)) " +
            "w=\(Int(frame.width)) h=\(Int(frame.height))"
    }
}
