import AppKit
import Combine
import Foundation

@MainActor
final class WindowEventObserver: ObservableObject {
    private let actionLogger: ActionLogger
    private var observers: [NSObjectProtocol] = []
    private var lastResizeLogAt: [ObjectIdentifier: CFAbsoluteTime] = [:]
    private var lastMoveLogAt: [ObjectIdentifier: CFAbsoluteTime] = [:]

    init(actionLogger: ActionLogger) {
        self.actionLogger = actionLogger
        self.install()
    }

    deinit {
        for observer in self.observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func install() {
        let center = NotificationCenter.default

        func on(_ name: NSNotification.Name, handler: @escaping (NSWindow) -> Void) {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { notification in
                guard let window = notification.object as? NSWindow else { return }
                handler(window)
            }
            self.observers.append(observer)
        }

        on(NSWindow.didBecomeKeyNotification) { window in
            self.actionLogger.log(.window, "Window became key", details: self.windowDetails(window))
        }

        on(NSWindow.didResignKeyNotification) { window in
            self.actionLogger.log(.window, "Window resigned key", details: self.windowDetails(window))
        }

        on(NSWindow.didMiniaturizeNotification) { window in
            self.actionLogger.log(.window, "Window minimized", details: self.windowDetails(window))
        }

        on(NSWindow.didDeminiaturizeNotification) { window in
            self.actionLogger.log(.window, "Window restored", details: self.windowDetails(window))
        }

        on(NSWindow.didEnterFullScreenNotification) { window in
            self.actionLogger.log(.window, "Window entered full screen", details: self.windowDetails(window))
        }

        on(NSWindow.didExitFullScreenNotification) { window in
            self.actionLogger.log(.window, "Window exited full screen", details: self.windowDetails(window))
        }

        on(NSWindow.willCloseNotification) { window in
            self.actionLogger.log(.window, "Window will close", details: self.windowDetails(window))
        }

        // Move/resize are noisy; throttle per window.
        on(NSWindow.didMoveNotification) { window in
            let key = ObjectIdentifier(window)
            let now = CFAbsoluteTimeGetCurrent()
            if let last = self.lastMoveLogAt[key], now - last < 0.5 { return }
            self.lastMoveLogAt[key] = now
            self.actionLogger.log(.window, "Window moved", details: self.windowDetails(window))
        }

        on(NSWindow.didResizeNotification) { window in
            let key = ObjectIdentifier(window)
            let now = CFAbsoluteTimeGetCurrent()
            if let last = self.lastResizeLogAt[key], now - last < 0.5 { return }
            self.lastResizeLogAt[key] = now
            self.actionLogger.log(.window, "Window resized", details: self.windowDetails(window))
        }
    }

    private func windowDetails(_ window: NSWindow) -> String {
        let title = window.title.isEmpty ? "[Untitled]" : window.title
        let frame = window.frame.integral
        return "title='\(title)' x=\(Int(frame.origin.x)) y=\(Int(frame.origin.y)) " +
            "w=\(Int(frame.width)) h=\(Int(frame.height))"
    }
}
